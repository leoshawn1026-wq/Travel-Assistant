# 旅程小助手 - 数据库设计

## 概述

Web 版使用 **SQLAlchemy 2.0 (async)** ORM，开发期使用 SQLite，生产环境切换 PostgreSQL
只需修改 `DATABASE_URL` 环境变量即可。

## 表结构

### 1. users — 用户表

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 用户 ID |
| username | VARCHAR(50) UNIQUE | 用户名 |
| email | VARCHAR(255) UNIQUE | 邮箱 |
| hashed_password | VARCHAR(255) | bcrypt 哈希密码 |
| avatar | VARCHAR(500) | 头像 URL |
| bio | TEXT | 个人简介 |
| travel_preferences | JSON | 旅行偏好 `{purpose, budget_level, travel_style, with_who, ...}` |
| created_at | DATETIME | 注册时间 |
| updated_at | DATETIME | 更新时间 |

**索引**: `username`, `email`

### 2. saved_itineraries — 保存的行程

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 行程 ID |
| user_id | INTEGER FK→users | 所属用户 |
| title | VARCHAR(200) | 行程标题 |
| destination | VARCHAR(100) | 目的地 |
| itinerary_data | JSON | 完整行程数据（与 API 响应结构一致） |
| is_public | BOOLEAN | 是否公开 |
| like_count | INTEGER | 点赞数 |
| share_token | VARCHAR(64) | 分享链接令牌 |
| created_at | DATETIME | 创建时间 |
| updated_at | DATETIME | 更新时间 |

**索引**: `user_id`, `share_token`

### 3. follows — 用户关注

| 字段 | 类型 | 说明 |
|------|------|------|
| follower_id | INTEGER PK FK→users | 关注者 |
| following_id | INTEGER PK FK→users | 被关注者 |
| created_at | DATETIME | 关注时间 |

**联合主键**: (follower_id, following_id)

### 4. itinerary_likes — 行程点赞

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 点赞 ID |
| user_id | INTEGER FK→users | 点赞用户 |
| itinerary_id | INTEGER FK→saved_itineraries | 被点赞行程 |
| created_at | DATETIME | 点赞时间 |

**唯一约束**: (user_id, itinerary_id)
**索引**: `user_id`, `itinerary_id`

### 5. itinerary_comments — 行程评论

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 评论 ID |
| user_id | INTEGER FK→users | 评论者 |
| itinerary_id | INTEGER FK→saved_itineraries | 所属行程 |
| content | TEXT | 评论内容 |
| created_at | DATETIME | 评论时间 |

### 6. friends — 好友关系

| 字段 | 类型 | 说明 |
|------|------|------|
| user_id | INTEGER PK FK→users | 用户 |
| friend_id | INTEGER PK FK→users | 好友 |
| status | ENUM(pending/accepted) | 状态 |
| created_at | DATETIME | 建立时间 |

**联合主键**: (user_id, friend_id)

### 7. 遗留表（cache.db — 旧系统）

| 表名 | 用途 |
|------|------|
| user_cache | 设备级键值缓存 |
| comparison_history | 对比历史记录 |
| chat_history | AI 对话历史 |
| conversations | 多对话管理 |
| response_cache | AI 响应缓存 |
| travel_content | 爬虫旅行文案 |

这些表仍通过 `cache_db.py`（aiosqlite 直连）访问，未迁移到 SQLAlchemy。

## 如何迁移到 PostgreSQL

```python
# 1. 在 .env 中添加（示例）
# DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/travel_web

# 2. 在 core/database.py 中，engine 会自动使用 DATABASE_URL 环境变量
# 3. 安装 asyncpg: pip install asyncpg
# 4. 重启服务即可，所有 SQLAlchemy 模型自动建表
```

> **注意**：如果切换 PostgreSQL，需要把 `travel_preferences` 字段从 JSON 改为
> `JSONB`（PostgreSQL 原生支持），以获得更好的查询性能。
