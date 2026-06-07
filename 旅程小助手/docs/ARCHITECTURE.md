# 旅程小助手 — 架构说明

## 1. 总体架构

```
┌──────────────────────────────────────────────────────────────────────┐
│               WanderWise — Next.js 16 前端                           │
│  ┌──────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐   │
│  │ 首页      │ │ 目的地对比   │ │ AI 行程定制   │ │ 个人主页     │   │
│  │ 灵感Feed  │ │ SSE 流式     │ │ SSE 流式     │ │ 关注/粉丝    │   │
│  │ WanderWise│ │ 多维度表格   │ │ 多日/单日    │ │ 行程列表     │   │
│  │ 品牌页    │ │ 画像匹配    │ │ 住宿推荐    │ │              │   │
│  └────┬─────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘   │
│       │              │                │                │            │
│       └──────────────┴────────────────┴────────────────┘            │
│                          │ fetch / SSE                              │
└──────────────────────────┼──────────────────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│              FastAPI 后端 (Python 3.10+ / Uvicorn)                    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  API 路由 (routers/)                                          │   │
│  │  chat  compare  itinerary  poi  auth  users  social  travel  │   │
│  └──────────┬───────────────────────────────────────────────────┘   │
│             ▼                                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Services 层                                                  │   │
│  │  ┌─────────────┐ ┌────────────┐ ┌──────────┐ ┌──────────┐  │   │
│  │  │ DeepSeek    │ │ Compare    │ │Itinerary │ │ 高德 Amap│  │   │
│  │  │ 流式/非流式  │ │ 记忆+评分  │ │ POI+生成  │ │ 天气/搜索│  │   │
│  │  └─────────────┘ └────────────┘ └──────────┘ └──────────┘  │   │
│  └──────────────────────┬───────────────────────────────────────┘   │
│                         ▼                                           │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  数据层                                                      │   │
│  │  SQLAlchemy 2.0 (async) — users, social, itineraries        │   │
│  │  aiosqlite — cache, comparison_history, chat_history        │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────────────────┘
                           ▼
            DeepSeek API / 高德 Web API / SQLite
```

## 2. 技术选型

| 层级 | 技术 | 说明 |
|------|------|------|
| Web 前端 | Next.js 16.2.7 + React 19 + TypeScript | Turbopack, App Router |
| 样式 | Tailwind CSS v4 | WanderWise 设计系统 |
| 状态管理 | React Context + fetch | 轻量 |
| 后端 | FastAPI + Uvicorn (WatchFiles) | 异步高性能, auto OpenAPI |
| ORM | SQLAlchemy 2.0 (async, aiosqlite) | 开发期 SQLite, 生产可切 PG |
| AI | DeepSeek (deepseek-v4-flash) | API 由后端统一托管 |
| 地图/天气 | 高德 Web 服务 API | POI 搜索、地理编码、天气 |
| 认证 | JWT (python-jose) + bcrypt | 无状态 Token, 7 天有效 |

### 设计系统 (WanderWise)

| 令牌 | 值 |
|------|------|
| 品牌色 `--color-wander-green` | `#2D6A4F` |
| 背景 `--color-cream` | `#F7F5F0` |
| 深色 `--color-wander-dark` | `#1a1a18` |
| 强调色 `--color-wander-green-bright` | `#74C69D` |
| 标题字 | Playfair Display (serif) |
| 正文字 | DM Sans (sans-serif) |

## 3. 功能模块

### P0 — 核心
1. **目的地对比** — 多维度表格 + 流式 SSE + 用户画像(目的/预算/同行人/宠物) + 评分 + 实时天气 + 历史记忆
2. **AI 行程生成** — 单日/多日行程 + 流式 SSE + 高德 POI 增强 + 住宿推荐 + 本地人提示
3. **用户认证** — 注册/登录/JWT/个人资料
4. **个人主页** — 用户资料、行程列表、关注/粉丝

### P1 — Web 增强
1. **社交系统** — 关注/粉丝、点赞、评论、好友
2. **旅行灵感 Feed** — 首页瀑布流展示公开行程
3. **出行查询** — 天气、酒店、餐厅、机票、火车票

### P2 — 规划中
- 行程导出 PDF / 分享卡片
- 地图路线可视化 (高德 JS API)
- AI 预算估算
- 出发清单生成
- 携程/美团联盟返佣对接

## 4. 目录结构

```
旅程小助手/
├── backend/                        # Python FastAPI 后端
│   ├── app/
│   │   ├── main.py                 # 入口 — 路由注册 + 生命周期
│   │   ├── config.py               # 环境配置 (.env)
│   │   ├── core/
│   │   │   ├── database.py         # SQLAlchemy 引擎 & 会话
│   │   │   ├── security.py         # JWT + bcrypt
│   │   │   └── deps.py             # 依赖注入 (get_current_user)
│   │   ├── models/
│   │   │   ├── schemas.py          # Pydantic 请求/响应
│   │   │   ├── user.py             # User ORM 模型
│   │   │   └── social.py           # 社交/行程 ORM 模型
│   │   ├── routers/                # API 路由 (11 模块)
│   │   │   ├── chat.py             # AI 对话
│   │   │   ├── compare.py          # 目的地对比 (含 SSE 流式)
│   │   │   ├── itinerary.py        # 行程生成 (含 SSE 流式)
│   │   │   ├── poi.py              # 高德 POI 搜索
│   │   │   ├── cache.py            # 用户缓存
│   │   │   ├── content.py          # 旅行文案
│   │   │   ├── admin.py            # 管理后台
│   │   │   ├── auth.py             # 注册/登录
│   │   │   ├── users.py            # 用户资料
│   │   │   ├── social.py           # 社交功能
│   │   │   └── travel_query.py     # 出行查询
│   │   └── services/               # 业务服务层
│   │       ├── deepseek.py         # DeepSeek API 封装 (流式/非流式)
│   │       ├── compare.py          # 对比服务 + 维度构建 + 记忆
│   │       ├── itinerary.py        # 行程生成 + POI 增强
│   │       ├── amap.py             # 高德地图服务
│   │       └── cache_db.py         # 设备缓存 + 对比历史 (aiosqlite)
│   ├── data/                       # SQLite 数据库文件
│   ├── requirements.txt
│   └── .env.example
├── web/                            # Next.js 前端
│   ├── src/
│   │   ├── app/
│   │   │   ├── page.tsx            # 首页 (WanderWise 品牌页)
│   │   │   ├── layout.tsx          # 根布局 (Playfair + DM Sans 字体)
│   │   │   ├── globals.css         # Tailwind v4 + 设计 Token
│   │   │   ├── compare/page.tsx    # 目的地对比 (SSE 流式渲染)
│   │   │   ├── itinerary/new/page.tsx  # 行程定制
│   │   │   ├── auth/login/page.tsx     # 登录
│   │   │   ├── auth/register/page.tsx  # 注册
│   │   │   └── profile/[username]/page.tsx  # 用户主页
│   │   ├── components/
│   │   │   └── Navbar.tsx          # WanderWise 导航栏
│   │   └── lib/
│   │       ├── api.ts              # API 客户端封装
│   │       └── auth-context.tsx     # 认证上下文
│   ├── package.json
│   └── next.config.ts
├── docs/
│   ├── ARCHITECTURE.md             # 本文档
│   ├── API.md                      # 接口文档
│   ├── DATABASE.md                 # 数据库设计
│   ├── ROADMAP.md                  # 产品路线图
│   └── DEPLOYMENT.md               # 部署指南
└── README.md
```

## 5. 关键数据流

### 5.1 目的地对比 (流式)

```
用户输入目的地 + 画像 (目的/预算/同行人/宠物/天数)
        │
        ▼ POST /api/v1/compare/destinations/stream
    CompareService.compare_stream()
        │
        ├──► 查询历史 (device_id → cache_db)
        │
        ├──► 构建动态维度 (12 个维度)
        │    核心: 预算 / 季节 / 交通
        │    目的加成: 美食/浪漫/亲子/文化/探险/购物
        │    同行人: 独自/情侣/家庭
        │    补充: 住宿 / 语言 / 门票
        │
        ├──► DeepSeek chat_stream → 逐维度解析
        │    每次解析到新 row → yield SSE "row" 事件
        │
        ├──► 全部完成 → yield "complete" (推荐+评分+结论)
        │
        ├──► 高德天气 API → yield "weather"
        │
        └──► 存入 history → 前端 SSE 结束
        │
        ▼
    前端渐进渲染: 表格行逐条出现 + 最后评分卡片 + 天气
```

### 5.2 AI 行程生成 (流式)

```
用户输入目的地 + 日期 + 天数 + 偏好 + 是否带宠物
        │
        ▼ POST /api/v1/itinerary/generate/stream
    ItineraryService.generate_stream()
        │
        ├──► 高德 POI 并发搜索 (景点+美食)
        │
        ├──► DeepSeek chat_stream → 逐项解析
        │    解析到 item → yield "item" (含时间/地点/建议)
        │    解析到 day plan → yield "day_title"
        │    解析到 accommodation → yield "accommodation"
        │
        ├──► 全部完成 → yield "complete"
        │
        ▼
    前端: 行程实时填充，逐项展现
```

### 5.3 记忆系统

```
用户每次对比 → 与 device_id 绑定存储
    └── comparison_history (SQLite / cache.db)
        含: 目的地、画像参数、推荐结果、评分
        下次对比时自动读取最后 5 条，注入 AI prompt 上下文
```

## 6. 安全

- **API Key 托管**: `DEEPSEEK_API_KEY`、`AMAP_API_KEY` 仅存于后端 `.env`
- **密码安全**: bcrypt 哈希
- **JWT**: Token 7 天有效
- **爬虫合规**: 仅抓取公开页面
