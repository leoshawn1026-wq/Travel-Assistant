# WanderWise 🛠️ 项目错题本

> 记录开发过程中踩过的坑、根因和解决方案，避免重复犯错。

---

## 目录

1. [Pydantic v2 严格模式：None→str 不自动转换](#1-pydantic-v2-严格模式nonestr-不自动转换)
2. [WatchFiles 热重载漏检测文件改动](#2-watchfiles-热重载漏检测文件改动)
3. [前端端口被旧进程占用](#3-前端端口被旧进程占用)
4. [bcrypt 版本不存在](#4-bcrypt-版本不存在)
5. [Shell 编码问题导致 API 请求 400](#5-shell-编码问题导致-api-请求-400)
6. [SSE 流式事件格式不统一](#6-sse-流式事件格式不统一)
7. [DeepSeek API 响应 JSON 解析失败](#7-deepseek-api-响应-json-解析失败)
8. [AI 返回的 JSON 中字段缺失或类型不符](#8-ai-返回的-json-中字段缺失或类型不符)
9. [env 变量名冲突导致启动失败](#9-env-变量名冲突导致启动失败)
10. [对比历史明细接口数据序列化问题](#10-对比历史明细接口数据序列化问题)
11. [Turbopack 崩溃 + 旧进程残留导致前端 500](#11-turbopack-崩溃--旧进程残留导致前端-500)
12. [Windows 僵尸端口 + 多文件配置不同步](#12-windows-僵尸端口--多文件配置不同步)

---

## 1. Pydantic v2 严格模式：None→str 不自动转换

### 现象
前端报错 `"undefined" is not valid JSON`，后端返回 502。

### 根因
- AI 返回的 JSON 中包含 `"local_tip": null`
- Pydantic v2 默认严格模式下，`str = ""` 不会自动把 `None` 转成 `""`，校验失败
- 后端返回 502 错误，前端 `JSON.parse(JSON.stringify(undefined))` 抛出异常

### 解决
在 services 层加防御性 `s()` 助手函数：

```python
def s(v, default=""):
    return v if isinstance(v, str) and v else default
```

同时给 Model 加上宽松配置：

```python
class ItineraryItem(BaseModel):
    model_config = {"coerce_numbers_to_str": True}
    time: str = ""
    name: str = ""
    ...
```

**教训**: Pydantic v2 的 `str` 字段不自动接受 `None`，AI 输出的 JSON 不可信，services 层必须做防御性转换。

### 涉及文件
- `backend/app/services/itinerary.py` — `_parse_item()` `_parse_items()` 中的 `s()` 助手
- `backend/app/models/schemas.py` — `ItineraryItem.model_config`

---

## 2. WatchFiles 热重载漏检测文件改动

### 现象
改了 `itinerary.py` 或 `schemas.py`，但后端没有自动重启，改了 `deepseek.py` 却能检测到。

### 根因
- uvicorn 的 WatchFiles reloader 基于文件系统事件监听
- 某些文件（特别是 import 链深处的模块）可能不被 WatchFiles 追踪
- 可能是缓存或 import 时机问题

### 解决
```bash
# 杀掉旧进程后重启
# Windows
taskkill //F //IM python //IM uvicorn

# 然后重新启动
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**教训**: 修改 services 层或 models 层后，如果热重载没生效，直接杀掉进程手动重启，不要依赖 WatchFiles。

---

## 3. 前端端口被旧进程占用

### 现象
```bash
⚠ Port 3000 is in use by process 16412, using available port 3001 instead.
```

### 根因
- 上次关闭终端时 Next.js 进程没被杀掉
- 新启动的 dev server 被迫 fallback 到 3001
- 访问 3000 时看到的还是旧版 JS bundle，导致功能异常

### 解决
```bash
# 杀掉指定端口进程
taskkill //PID 16412 //F

# 或直接用
npx kill-port 3000
```

**教训**: 每次重启前端前先确保 3000 端口是空闲的。启动脚本中可以加端口检查。

---

## 4. bcrypt 版本不存在

### 现象
```bash
pip install -r requirements.txt 失败
ERROR: Could not find a version that satisfies the requirement bcrypt==5.0.1
```

### 根因
- `bcrypt` Python 包的历史版本中**不存在 5.0.1**
- PyPI 上 bcrypt 的版本号是 3.x → 4.x → 5.0.0（之后是 5.1.x）

### 解决
将 `requirements.txt` 中的 `bcrypt==5.0.1` 改为 `bcrypt==5.0.0`

**教训**: 写死版本号前确认 PyPI 上确实存在该版本。

---

## 5. Shell 编码问题导致 API 请求 400

### 现象
```bash
curl -X POST ... -d '{"destinations":["成都","重庆"]}'  → 400
```

### 根因
- Windows 终端编码（GBK）与 JSON UTF-8 编码不兼容
- 中文字符在 curl 传输过程中被破坏

### 解决
使用 Python 的 `urllib.request` 发送请求，保证 UTF-8 编码：

```python
import urllib.request, json
req = urllib.request.Request(url, data=json.dumps(body).encode('utf-8'), headers={"Content-Type": "application/json"})
urllib.request.urlopen(req).read()
```

**教训**: Windows 终端下用 curl 发中文 JSON 可能出问题，改用 Python 脚本验证。

---

## 6. SSE 流式事件格式不统一

### 现象
前端解析 SSE 时，不同端点的数据结构不一致，导致解析混乱。

### 问题细节
| 端点 | SSE 事件格式 |
|------|-------------|
| `/chat/stream` | `{"t": "逐字token"}` |
| `/compare/destinations/stream` | `{"type": "row", "data": {...}}` |
| `/itinerary/generate/stream` | `{"type": "item", "day": 1, "data": {...}}` |

聊天是纯文本逐字流，对比和行程是结构化事件流。

### 解决
每个端点各自独立解析，前端 switch-case 区分 `event.type`：

```typescript
switch (event.type) {
  case "status": ...
  case "row": ...
  case "complete": ...
}
```

**教训**: 设计 SSE 事件时统一约定 `{ type, data }` 格式。聊天因为是最底层的 token 流，格式不同可以接受。

---

## 7. DeepSeek API 响应 JSON 解析失败

### 现象
AI 返回的内容中 JSON 被 markdown 代码块包裹（````json ... ````），或包含多余文本。

### 根因
- DeepSeek 模型有时会在 JSON 前后加解释性文字
- 或者用 ```json 包裹但没严格按照 instruction 执行

### 解决
`_extract_json()` 三层回退解析：

```python
def _extract_json(text: str) -> str:
    # 1. 直接解析
    # 2. 提取 ```json ... ``` 块
    # 3. 找第一个 { 到最后一个 } 的部分
```

**教训**: AI 输出不可预测，解析层要做充分容错。

### 涉及文件
- `backend/app/services/compare.py` — `_extract_json()`
- `backend/app/services/itinerary.py` — `_extract_json()`

---

## 8. AI 返回的 JSON 中字段缺失或类型不符

### 现象
对比或行程结果中缺少某些字段，导致前端渲染空白或报错。

### 常见情况
| 问题 | 示例 | 解决 |
|------|------|------|
| 字段缺失 | AI 没返回 `recommendation` | `.get("recommendation", "")` |
| 类型不匹配 | `scores` 是字符串而非数组 | try/except 兜底 |
| 数组长度不对 | `values` 长度与目的地数量不一致 | 不兜底，让前端处理显示 |

### 解决
每一层都做 `.get()` 带默认值 + fallback 兜底：

```python
complete_data = {
    "rows": data.get("rows", []),
    "recommendation": data.get("recommendation", ""),
}
```

极端情况调用 `_fallback_table()` 返回硬编码兜底数据。

**教训**: AI 输出 JSON 不做任何假设，每个字段都要防御性读取。

---

## 9. env 变量名冲突导致启动失败

### 现象
```bash
ValidationError: database_url Extra inputs are not permitted
```

### 根因
- 在 `.env` 中写了 `DATABASE_URL` 而不是 `DATABASE_PATH`
- Pydantic Settings 检测到未定义的字段名，抛出 ValidationError

### 解决
`.env` 中使用 `DATABASE_PATH=./data/cache.db`，而非 `DATABASE_URL`

**教训**: `.env.example` 已经写明了正确的字段名，复制后不要擅自改名。

---

## 10. 对比历史明细接口数据序列化问题

### 现象
保存对比历史时，Pydantic 对象无法直接 `json.dumps()`。

### 根因
- `CompareRow` 是 Pydantic BaseModel，不是普通 dict
- `json.dumps(parsed)` 时遇到 BaseModel 对象会报错
- SQLite 只能存字符串

### 解决
保存前手动转 dict：

```python
parsed_for_db = {
    k: v if not isinstance(v, list) else [
        item.model_dump() if hasattr(item, 'model_dump') else item
        for item in v
    ]
    for k, v in parsed.items()
}
result_data = json.dumps(parsed_for_db, ensure_ascii=False)
```

**教训**: 需要序列化 Pydantic 对象时，显式调用 `.model_dump()`，不要依赖默认的 JSON 序列化。

---

## 11. Turbopack 崩溃 + 旧进程残留导致前端 500

### 现象
前端访问返回 500，Turbopack 报错 `exit code: 0xc0000142`（STATUS_DLL_INIT_FAILED）。

### 根因
- 旧的前端 dev server 进程残留（PID 31648），卡在 3000 端口返回损坏的 JS bundle
- 新启动的 dev server 被迫 fallback 到 3001 端口
- 用户访问 3000 看到的是坏掉的旧进程
- `taskkill //F //IM node` 有时杀不干净（有子进程残留）

### 解决
```bash
# 方法 1：按端口杀
npx kill-port 3000 3001

# 方法 2：按 PID 杀
taskkill //PID <进程号> //F

# 方法 3：彻底清理后重启
rm -rf .next
npm install   # 重新安装 native 模块
npm run dev
```

**教训**: 每次重启前确认端口空闲。多级 `taskkill //F //IM node` 后最好用 `lsof` 或 `netstat -ano | findstr :3000` 确认干净。

---

## 12. Windows 僵尸端口 + 多文件配置不同步

### 现象
- 重启后端/前端后端口变了（如 8000→8003），但前端依然连旧端口
- 访问管理后台看到空白/loading 转圈
- `taskkill //F //IM node` 后端口仍被占用（显示已死的 PID）

### 根因
1. **Windows TCP 端口僵尸**：进程被 kill 后 TCP 端口条目不立即释放，`netstat -ano` 仍显示 LISTENING，新进程无法绑定
2. **配置散落多文件**：前端的 API URL 写在 `web/.env.local` 和 `web/src/lib/api.ts`（fallback），后端的端口和 CORS 写在 `backend/.env`，换端口时只改了启动参数没同步更新这三个地方
3. **Turbopack 编译缓存**：换端口后重新启动 dev server，Turbopack 可能命中旧缓存，编译产物仍是旧 URL

### 解决
创建统一启动脚本 `start.sh`，自动处理：

```bash
# 1. 杀光遗留进程
taskkill //F //IM python //IM node

# 2. 检测僵尸端口，被占则递增找空闲
find_free_port() { ... }

# 3. 同步更新所有配置
#    backend/.env  → PORT 和 CORS_ORIGINS
#    web/.env.local → NEXT_PUBLIC_API_URL

# 4. 启动前后端
uvicorn app.main:app --port $BACKEND_PORT
next dev -p $FRONTEND_PORT
```

核心逻辑：**端口只在一个地方定（脚本顶部的配置区），自动扩散到所有配置文件和启动命令**。

### 涉及文件
- `start.sh` — 项目根目录的一键启动脚本
- `backend/.env` — PORT、CORS_ORIGINS 自动更新
- `web/.env.local` — NEXT_PUBLIC_API_URL 自动更新
- `web/src/lib/api.ts` — 默认 fallback 改为 8000

### 教训
1. **配置集中化**：端口号只在一个地方定义，其他文件通过脚本自动同步
2. **启动脚本化**：不要手动敲启动命令，用脚本来保证环境一致性
3. **Windows 端口管理**：启动前先 `taskkill //F` 清理，再用 `netstat -ano | findstr :PORT` 确认干净
4. **Turbopack 缓存**：换端口后删除 `.next/` 目录避免编译缓存污染

---

## 通用原则

1. **AI 输出不可信** — 所有 AI 返回的数据必须经过防御性清洗
2. **热重载不可靠** — 改核心文件后手动重启
3. **端口检查** — 启动前确认端口未被占用
4. **版本确认** — 写死包版本前验证 PyPI 存在
5. **编码意识** — Windows 下中文 + curl = 潜在灾难
6. **SSE 格式统一** — 流式事件用 `{ type, data }` 约定
7. **Pydantic v2 严格模式** — str 不会自动接受 None
8. **JWT 退出后仍有效** — JWT 无服务端状态，退出登录后 token 仍可用至过期。需要用黑名单机制（cache_db 存 token 指纹）在登出时标记失效
9. **Windows 端口僵尸进程** — uvicorn `--reload` 在 Windows 上会产生僵尸 TCP 条目，`taskkill //F` 无法完全释放端口。解决：`netstat -ano | findstr :PORT` 找到残留 PID 逐个杀；如果仍不释放，换端口启动或重启系统
