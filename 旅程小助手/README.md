# WanderWise — AI 旅行规划

**不再纠结去哪里，只需出发。**

WanderWise 用 AI 分析你的旅行偏好，帮你决策目的地并定制完整旅程方案。覆盖**决策 → 规划 → 执行**全链路。

## 🎯 四大核心功能

```
① AI 目的地对比   ② 智能行程定制    ③ 旅行信息聚合    ④ 旅行社区
────────────────────────────────────────────────────────────
输入人数/预算/      AI 生成按天       行程页内直接查     发现真实行程
动机，AI 从气候/    排布的完整行程，    酒店/餐厅/天气     → 一键复制为
费用/体验/签证      支持拖拽调整/      /机票/火车票，      我的方案
等维度打分排序      局部重生/导出      信息不出页面        点赞/收藏/评论
                                                         /好友/旅伴匹配
```

| 功能 | 说明 |
|------|------|
| 📊 **AI 目的地对比** | 输入人数/预算/旅行动机，AI 从气候、费用、体验、签证等多维度为候选目的地打分排序，告别选择困难 |
| 🗺️ **智能行程定制** | 确定目的地后，AI 立即生成按天排布的完整行程，支持编辑调整、保存分享（规划中：拖拽调整、局部重生、PDF/长图导出） |
| 🌤️ **旅行信息聚合** | 在行程页内直接查询酒店推荐、餐厅评分、实时天气，以及机票和火车票价格参考，信息不出页面 |
| 👥 **旅行社区** | 发现其他旅行者分享的真实行程，一键复制为自己的方案。支持点赞、收藏、评论与好友系统，旅伴匹配即将上线 |

## 🚀 快速开始

### 后端

```powershell
cd backend
pip install -r requirements.txt
copy .env.example .env   # 填入 DeepSeek + 高德 API 密钥
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

验证：http://localhost:8000/health

### 前端

```powershell
cd web
npm install
npm run dev
```

访问：http://localhost:3000

## 📁 项目结构

```
旅程小助手/
├── backend/         # FastAPI 后端 (Python 3.10+)
│   ├── app/
│   │   ├── core/    #   DB / JWT / 依赖注入
│   │   ├── models/  #   Pydantic + SQLAlchemy 模型
│   │   ├── routers/ #   11 个 API 路由模块
│   │   └── services/ # DeepSeek / 对比 / 行程 / 高德 / 额度
│   └── requirements.txt
├── web/             # Next.js 前端 (TypeScript)
│   ├── src/
│   │   ├── app/     #   8 个页面 (App Router)
│   │   ├── components/ # Navbar、ErrorBoundary
│   │   └── lib/     #   API 客户端 / 认证上下文
│   └── package.json
├── docs/            # 文档
│   ├── ARCHITECTURE.md
│   ├── API.md
│   ├── DATABASE.md
│   ├── ROADMAP.md   # 产品定位 + 版本迭代清单
│   ├── TROUBLESHOOTING.md  # 项目错题本
│   └── DEPLOYMENT.md
├── CLAUDE.md        # 项目规范
└── README.md
```

## 🛠 技术栈

| 层 | 技术 |
|----|------|
| 前端 | Next.js 16.2.7, React 19, TypeScript, Tailwind CSS v4 |
| 后端 | FastAPI, SQLAlchemy 2.0 (async), JWT, bcrypt |
| AI | DeepSeek (deepseek-v4-flash) |
| 地图/天气 | 高德 Web 服务 API |
| 数据库 | SQLite (dev) / PostgreSQL (prod 可切换) |
| 设计 | Playfair Display + DM Sans + WanderWise 设计系统 |

## 📖 文档

- [产品定位 & 路线图](docs/ROADMAP.md)
- [架构说明](docs/ARCHITECTURE.md)
- [接口文档](docs/API.md)
- [数据库设计](docs/DATABASE.md)
- [部署指南](docs/DEPLOYMENT.md)
- [项目错题本](docs/TROUBLESHOOTING.md)

## ⚠️ 环境要求

- Python 3.10+
- Node.js 18+
- 高德 Web 服务 API Key — [申请](https://lbs.amap.com/)
- DeepSeek API Key — [申请](https://platform.deepseek.com/)

## 许可证

仅供学习研究使用。
