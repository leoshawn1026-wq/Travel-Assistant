# WanderWise — AI 旅行规划前端

基于 **Next.js 16 + React 19 + TypeScript + Tailwind CSS v4** 构建的 AI 旅行规划 Web 前端。

## 设计系统

| 令牌 | 值 |
|------|------|
| 品牌色 | `#2D6A4F` (wander-green) |
| 背景色 | `#F7F5F0` (cream) |
| 深色 | `#1a1a18` (wander-dark) |
| 标题字 | **Playfair Display** (serif) |
| 正文字 | **DM Sans** (sans-serif) |

## 页面

| 路由 | 说明 |
|------|------|
| `/` | 首页 — 品牌着陆页 + 灵感 Feed + 社区 |
| `/compare` | 多维度目的地对比 — SSE 流式 |
| `/itinerary/new` | AI 行程定制 — SSE 流式 |
| `/auth/login` | 登录 |
| `/auth/register` | 注册 |
| `/profile/[username]` | 用户主页 |

## 快速开始

```powershell
npm install
npm run dev
```

访问 http://localhost:3000

## 技术栈

- **框架**: Next.js 16.2.7 (Turbopack)
- **语言**: TypeScript
- **样式**: Tailwind CSS v4
- **字体**: Playfair Display + DM Sans (Google Fonts)
- **图标**: @tabler/icons-react
- **API**: fetch (SSE 流式解析)
- **认证**: JWT + React Context
