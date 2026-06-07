# WanderWise 生产部署指南

## 一、部署架构

```
用户 → HTTPS → Nginx (443) ─┬→ http://127.0.0.1:3000 (Next.js 前端)
                             └→ http://127.0.0.1:8002 (FastAPI 后端)
```

## 二、前置条件

| 项目 | 要求 |
|------|------|
| 服务器 | Linux (推荐 Ubuntu 22.04+) 或 Windows Server |
| 域名 | 已备案域名，DNS 指向服务器 IP |
| Python | 3.10+ |
| Node.js | 18+ |
| Nginx | 1.24+（Linux） |
| 数据库 | SQLite（开发）/ PostgreSQL 16+（生产推荐） |

## 三、快速部署（Linux）

### 1. 克隆项目

```bash
git clone <repo-url> /var/www/wanderwise
cd /var/www/wanderwise
```

### 2. 后端

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 配置环境变量
cp .env.production .env
# 编辑 .env 填入真实密钥
nano .env

# 初始化数据库
python -m alembic upgrade head

# 启动（使用 nohup 或 systemd）
nohup python -m uvicorn app.main:app --host 127.0.0.1 --port 8002 > ../logs/backend.log 2>&1 &
```

### 3. 前端

```bash
cd web
npm install
npm run build

# 启动（生产模式）
NEXT_PUBLIC_API_URL=http://127.0.0.1:8002/api/v1 npm start > ../logs/frontend.log 2>&1 &
```

### 4. Nginx 反向代理

```bash
sudo cp deploy/nginx.conf /etc/nginx/sites-available/wanderwise
sudo ln -s /etc/nginx/sites-available/wanderwise /etc/nginx/sites-enabled/

# 编辑配置文件，将 yourdomain.com 替换为你的域名
sudo nano /etc/nginx/sites-available/wanderwise

# 申请 SSL 证书
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# 重启 Nginx
sudo nginx -t
sudo systemctl reload nginx
```

### 5. 配置 systemd 服务（推荐）

```bash
sudo cp deploy/wanderwise.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable wanderwise
sudo systemctl start wanderwise
```

## 四、Windows 部署

```powershell
# 一键启动（开发/测试）
start-prod.bat

# 或注册为 Windows 服务：
# 使用 NSSM: https://nssm.cc/
nssm install WanderWise "C:\path\to\python.exe" "-m uvicorn app.main:app --host 0.0.0.0 --port 8002"
```

## 五、环境变量配置

### `.env` 必填项

| 变量 | 说明 | 获取方式 |
|------|------|---------|
| `DEEPSEEK_API_KEY` | DeepSeek API 密钥 | https://platform.deepseek.com |
| `AMAP_API_KEY` | 高德地图 API 密钥 | https://lbs.amap.com |
| `JWT_SECRET` | JWT 签名密钥 | `openssl rand -hex 32` |

### 生产环境检查清单

- [ ] `DEBUG=false` — 关闭调试模式
- [ ] `JWT_SECRET` 设置为随机 64 位字符串
- [ ] `CORS_ORIGINS` 设置为你的域名
- [ ] `RATE_LIMIT_PER_MINUTE` 设置为 `20`（或适当值）
- [ ] `OPENAPI_ENABLED=false` — 关闭 API 文档
- [ ] `.env` 文件已加入 `.gitignore`

## 六、数据库迁移

```bash
# 创建新迁移（改模型后执行）
cd backend
python -m alembic revision --autogenerate -m "描述变更"
python -m alembic upgrade head

# PostgreSQL 切换
# 1. 安装 asyncpg: pip install asyncpg
# 2. 修改 .env: DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/wanderwise
# 3. 修改 alembic.ini 中的 sqlalchemy.url
# 4. 执行: python -m alembic upgrade head
```

## 七、验证

| 检查项 | 命令 |
|--------|------|
| 后端健康 | `curl https://yourdomain.com/health` |
| 前端访问 | 浏览器打开 `https://yourdomain.com` |
| 注册登录 | 测试注册 → 登录 → 退出 完整流程 |
| AI 对比 | 测试对比流式 SSE 输出 |
| 行程生成 | 测试行程流式 SSE 输出 |

## 八、运维

### 查看日志

```bash
tail -f logs/backend.log
tail -f logs/frontend.log
journalctl -u wanderwise -f   # systemd 方式
```

### 重启服务

```bash
sudo systemctl restart wanderwise   # Linux
# 或
./start-prod.bat                    # Windows
```

### 更新代码

```bash
git pull
cd backend && source venv/bin/activate && pip install -r requirements.txt
python -m alembic upgrade head
sudo systemctl restart wanderwise
cd ../web && npm install && npm run build && sudo systemctl restart wanderwise
```
