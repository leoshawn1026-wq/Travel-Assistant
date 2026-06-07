#!/bin/bash
# ═══════════════════════════════════════════════════
# WanderWise 一键启动脚本
# 自动检测空闲端口 + 同步所有配置文件
# ═══════════════════════════════════════════════════

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
WEB_DIR="$ROOT_DIR/web"

# ── 配置区（只改这里，其他自动同步） ──
DESIRED_BACKEND_PORT=8003
DESIRED_FRONTEND_PORT=3001

# ── 颜色 ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# ── 杀光已有进程 ──
cleanup_processes() {
  warn "清理遗留进程..."
  taskkill //F //IM python 2>/dev/null || true
  taskkill //F //IM node 2>/dev/null || true
  sleep 2
}

# ── 查找空闲端口（跳过僵尸） ──
find_free_port() {
  local base=$1
  local port=$base
  local max_tries=20
  local tries=0
  while [ $tries -lt $max_tries ]; do
    if ! netstat -ano 2>/dev/null | grep -qE "[:.]${port} .*LISTENING"; then
      echo "$port"
      return 0
    fi
    # 尝试杀掉占用进程
    local zombie_pid
    zombie_pid=$(netstat -ano 2>/dev/null | grep -E "[:.]${port} " | grep LISTENING | head -1 | awk '{print $NF}')
    if [ -n "$zombie_pid" ] && [ "$zombie_pid" != "0" ]; then
      taskkill //F //PID "$zombie_pid" 2>/dev/null || true
      sleep 1
      if ! netstat -ano 2>/dev/null | grep -qE "[:.]${port} .*LISTENING"; then
        echo "$port"
        return 0
      fi
    fi
    port=$((port + 1))
    tries=$((tries + 1))
  done
  echo "$base"
  return 1
}

# ── 更新后端 .env ──
update_backend_env() {
  local backend_port=$1
  local frontend_port=$2
  local env_file="$BACKEND_DIR/.env"

  # 更新 PORT
  if grep -q "^PORT=" "$env_file"; then
    sed -i "s/^PORT=.*/PORT=${backend_port}/" "$env_file"
  else
    echo "PORT=${backend_port}" >> "$env_file"
  fi

  # 更新 CORS_ORIGINS（保留已有非 localhost 的 origin）
  local existing
  existing=$(grep "^CORS_ORIGINS=" "$env_file" | sed 's/^CORS_ORIGINS=//')
  local new_cors="http://localhost:${frontend_port}"
  # 如果已有 CORS 包含非 localhost 的地址（如 lhr.life），追加保留
  if echo "$existing" | grep -qE '(https?://[^l]|\.lhr\.life|\.ngrok)'; then
    local extra
    extra=$(echo "$existing" | tr ',' '\n' | grep -vE 'localhost' | tr '\n' ',' | sed 's/,$//')
    new_cors="${new_cors},${extra}"
  fi
  if grep -q "^CORS_ORIGINS=" "$env_file"; then
    sed -i "s|^CORS_ORIGINS=.*|CORS_ORIGINS=${new_cors}|" "$env_file"
  else
    echo "CORS_ORIGINS=${new_cors}" >> "$env_file"
  fi

  info "后端 .env → PORT=${backend_port}, CORS 已包含 :${frontend_port}"
}

# ── 更新前端 .env.local ──
update_frontend_env() {
  local backend_port=$1
  local env_local="$WEB_DIR/.env.local"

  echo "NEXT_PUBLIC_API_URL=http://localhost:${backend_port}/api/v1" > "$env_local"

  info "前端 .env.local → NEXT_PUBLIC_API_URL=http://localhost:${backend_port}/api/v1"
}

# ── 启动后端 ──
start_backend() {
  local port=$1
  info "启动后端 (port ${port})..."
  cd "$BACKEND_DIR"
  mkdir -p logs
  nohup python -m uvicorn app.main:app --host 0.0.0.0 --port "$port" --reload \
    > logs/backend.log 2>&1 &

  # 等待就绪
  for i in $(seq 1 12); do
    if netstat -ano 2>/dev/null | grep -qE ":${port} .*LISTENING"; then
      info "后端已就绪 → http://localhost:${port}"
      info "API 文档 → http://localhost:${port}/docs"
      return 0
    fi
    sleep 1
  done

  error "后端启动超时，检查 logs/backend.log"
  return 1
}

# ── 启动前端 ──
start_frontend() {
  local port=$1
  info "启动前端 (port ${port})..."
  cd "$WEB_DIR"
  mkdir -p logs
  nohup npm run dev -- -p "$port" \
    > logs/frontend.log 2>&1 &

  # 等待就绪
  for i in $(seq 1 20); do
    if netstat -ano 2>/dev/null | grep -qE ":${port} .*LISTENING"; then
      # 额外等一会让 Turbopack 完成首次编译
      sleep 3
      info "前端已就绪 → http://localhost:${port}"
      return 0
    fi
    sleep 1
  done

  error "前端启动超时，检查 logs/frontend.log"
  cat "$WEB_DIR/logs/frontend.log" 2>/dev/null | tail -20
  return 1
}

# ── 打印摘要 ──
print_summary() {
  local bp=$1 fp=$2
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  WanderWise 启动完成"
  echo "═══════════════════════════════════════════"
  echo "  前端  → http://localhost:${fp}"
  echo "  后端  → http://localhost:${bp}"
  echo "  API   → http://localhost:${bp}/docs"
  echo "  管理后台 → http://localhost:${fp}/admin"
  echo "═══════════════════════════════════════════"
  echo "  后端日志: tail -f $BACKEND_DIR/logs/backend.log"
  echo "  前端日志: tail -f $WEB_DIR/logs/frontend.log"
  echo "  停止服务: taskkill //F //IM python //IM node"
  echo "═══════════════════════════════════════════"
}

# ═══════════════════════════════════════════════
# 主流程
# ═══════════════════════════════════════════════

echo ""
echo "  ╔══════════════════════════════╗"
echo "  ║   WanderWise 启动脚本         ║"
echo "  ╚══════════════════════════════╝"
echo ""

# 1. 清理
cleanup_processes

# 2. 找空闲端口
BACKEND_PORT=$(find_free_port "$DESIRED_BACKEND_PORT")
FRONTEND_PORT=$(find_free_port "$DESIRED_FRONTEND_PORT")

if [ "$BACKEND_PORT" != "$DESIRED_BACKEND_PORT" ]; then
  warn "后端端口 ${DESIRED_BACKEND_PORT} 被占，已切换至 ${BACKEND_PORT}"
fi
if [ "$FRONTEND_PORT" != "$DESIRED_FRONTEND_PORT" ]; then
  warn "前端端口 ${DESIRED_FRONTEND_PORT} 被占，已切换至 ${FRONTEND_PORT}"
fi

# 3. 更新配置
update_backend_env "$BACKEND_PORT" "$FRONTEND_PORT"
update_frontend_env "$BACKEND_PORT"

# 4. 启动服务
start_backend "$BACKEND_PORT" || exit 1
start_frontend "$FRONTEND_PORT" || exit 1

# 5. 摘要
print_summary "$BACKEND_PORT" "$FRONTEND_PORT"
