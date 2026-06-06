# 旅程小助手 - 架构说明

## 1. 总体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (iOS / Android)               │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │ AI 对话  │  │ 目的地对比   │  │ 我的收藏行程       │    │
│  │  首页    │  │   (MVP核心)  │  │ SharedPreferences  │    │
│  └────┬─────┘  └──────┬───────┘  └─────────┬──────────┘    │
│       │               │                     │                │
│       └───────────────┴─────────────────────┘                │
│                       │ Dio HTTP                             │
└───────────────────────┼─────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              FastAPI 后端 (Python 3.10+)                     │
│  ┌────────────┐ ┌────────────┐ ┌──────────┐ ┌────────────┐ │
│  │ DeepSeek   │ │ 高德 POI   │ │ 用户缓存 │ │ 爬虫清洗   │ │
│  │ 中转代理   │ │ 封装服务   │ │ SQLite   │ │ (离线脚本) │ │
│  └────────────┘ └────────────┘ └──────────┘ └────────────┘ │
└───────────────────────┬─────────────────────────────────────┘
                        ▼
        DeepSeek-R1 API / 高德 Web API / 公开旅行文案
```

## 2. 技术选型

| 层级 | 技术 | 说明 |
|------|------|------|
| 移动端 | Flutter 3.x | 一套代码适配 iOS + Android |
| 网络 | Dio | 拦截器、超时、错误统一处理 |
| 本地存储 | shared_preferences | 收藏行程 JSON 持久化 |
| 后端 | FastAPI + Uvicorn | 异步高性能，自动 OpenAPI |
| 缓存 | SQLite (aiosqlite) | 用户偏好与对话缓存 |
| AI | DeepSeek-R1 | 后端统一托管 API Key |
| 地图 | 高德 Web 服务 API | POI 搜索、地理编码 |
| 爬虫 | requests + BeautifulSoup | 仅抓取公开文案，离线入库 |

## 3. 安全与合规

- **密钥托管**：`DEEPSEEK_API_KEY`、`AMAP_API_KEY` 仅存于后端 `.env`，前端仅配置 `BASE_URL`
- **隐私权限**：定位权限按需申请，隐私政策页面说明数据用途
- **爬虫合规**：仅抓取公开页面，遵守 robots.txt，不做登录态爬取
- **HTTPS**：生产环境强制 TLS，禁止明文传输用户数据

## 4. MVP 范围（第一阶段）

### 已实现
1. **目的地对比页**：多目的地表格对比（预算/天气/景点/交通/美食）
2. **单日行程生成**：基于 DeepSeek + 高德 POI 生成结构化行程
3. **AI 对话首页**：基础流式/非流式对话
4. **收藏行程**：本地 SharedPreferences 增删查

### 后续迭代
- 多日行程、地图路线可视化
- 小红书/抖音文案实时推荐
- 用户账号体系与云端同步
- 推送与行程提醒

## 5. 目录结构

```
旅程小助手/
├── backend/                 # Python FastAPI 后端
│   ├── app/
│   │   ├── main.py          # 应用入口
│   │   ├── config.py        # 环境配置
│   │   ├── models/          # Pydantic 数据模型
│   │   ├── routers/         # API 路由
│   │   └── services/        # 业务服务层
│   ├── crawler/             # 离线爬虫脚本
│   ├── requirements.txt
│   └── .env.example
├── mobile/                  # Flutter 客户端
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/            # API、配置、存储
│   │   ├── models/
│   │   ├── services/
│   │   ├── pages/
│   │   └── widgets/
│   ├── android/
│   └── ios/
└── docs/
    ├── ARCHITECTURE.md
    ├── API.md
    └── DEPLOYMENT.md
```

## 6. 数据流（单日行程生成）

```
用户输入目的地 + 日期 + 偏好
        │
        ▼
Flutter ComparePage / HomePage
        │
        ▼ POST /api/v1/itinerary/generate
FastAPI ItineraryService
        │
        ├─► AmapService.search_poi()  获取景点/餐饮 POI
        │
        └─► DeepSeekService.chat()    生成结构化行程 JSON
        │
        ▼
返回 ItineraryResponse → 用户可收藏到本地
```
