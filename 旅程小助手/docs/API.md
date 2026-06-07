# 旅程小助手 — API 接口文档

**Base URL**: `http://<host>:8000/api/v1`

**通用响应格式**:
```json
{
  "code": 0,
  "message": "success",
  "data": {}
}
```

**错误码**:
| code | 说明 |
|------|------|
| 0 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未授权 |
| 404 | 资源不存在 |
| 500 | 服务器内部错误 |
| 502 | 第三方 API 调用失败（DeepSeek / 高德） |

---

## 1. 健康检查

### GET `/health`

**响应**:
```json
{
  "status": "ok",
  "version": "1.0.0-mvp"
}
```

---

## 2. AI 对话（DeepSeek 中转）

### POST `/chat`

**请求体**:
```json
{
  "messages": [
    {"role": "user", "content": "成都有什么好玩的？"}
  ],
  "stream": false
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| messages | array | 是 | OpenAI 格式消息列表 |
| stream | bool | 否 | 是否流式，默认 false |

**响应**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "content": "成都推荐宽窄巷子、锦里、大熊猫基地...",
    "usage": {"prompt_tokens": 10, "completion_tokens": 200}
  }
}
```

---

## 3. 目的地对比

### POST `/compare/destinations`

非流式对比 — 全量返回对比表格 + 推荐 + 评分 + 天气。

**请求体**:
```json
{
  "destinations": ["成都", "重庆", "西安"],
  "travel_days": 3,
  "budget_level": "medium",
  "purpose": "food",
  "with_who": "couple",
  "with_pet": false,
  "travel_style": "free",
  "preferred_season": "秋季",
  "special_needs": "",
  "departure_date": "2026-10-01",
  "device_id": "web-xxx"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| destinations | string[] | 是 | 2-5 个目的地 |
| travel_days | int | 否 | 计划天数，默认 3，范围 1-30 |
| budget_level | string | 否 | `low` / `medium` / `high` |
| purpose | string | 否 | 旅行目的：`leisure`/`culture`/`food`/`adventure`/`honeymoon`/`family`/`shopping` |
| with_who | string | 否 | 同行人：`alone`/`couple`/`family`/`friends` |
| with_pet | bool | 否 | 是否带宠物，默认 false |
| travel_style | string | 否 | `free`/`guided`/`half` |
| preferred_season | string | 否 | 偏好季节 |
| special_needs | string | 否 | 特殊需求 |
| departure_date | string | 否 | 出发日期 YYYY-MM-DD |
| device_id | string | 否 | 设备 ID（用于记忆历史对比） |

**响应**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "table": {
      "headers": ["维度", "成都", "重庆", "西安"],
      "rows": [
        {"dimension": "预算费用（人均预估）", "values": ["约1500元", "约1400元", "约1600元"], "detail": "成都和重庆消费水平相近，西安稍高"},
        {"dimension": "特色美食体验", "values": ["火锅/串串/担担面", "小面/火锅/酸辣粉", "肉夹馍/凉皮/泡馍"], "detail": "成都美食最多元..."}
      ]
    },
    "recommendation": "如果偏好美食和夜景，推荐重庆...",
    "verdict": "推荐重庆",
    "scores": [
      {"destination": "成都", "overall": 4.5, "details": {"性价比": 4.5, "美食": 5.0, "景点丰富度": 4.0}},
      {"destination": "重庆", "overall": 4.3, "details": {"性价比": 4.5, "美食": 4.5, "景点丰富度": 4.0}}
    ],
    "weather": [
      {"city": "成都", "weather": "多云", "temperature": "25", "wind": "南风 2级", "humidity": "65%"},
      {"city": "重庆", "weather": "晴", "temperature": "28", "wind": "北风 1级", "humidity": "60%"}
    ]
  }
}
```

### POST `/compare/destinations/stream`

流式对比 (SSE) — 逐维度返回，前端渐进渲染。

**请求体**: 同非流式 POST `/compare/destinations`

**响应**: `text/event-stream`

```
data: {"type": "status", "text": "正在分析目的地数据..."}

data: {"type": "status", "text": "AI 正在多维度对比分析..."}

data: {"type": "row", "data": {"dimension": "预算费用（人均预估）", "values": ["约1500元", "约1400元"]}}

data: {"type": "row", "data": {"dimension": "特色美食体验", "values": ["火锅/串串", "小面/火锅"]}}

data: {"type": "complete", "data": {"rows": [...], "recommendation": "...", "verdict": "...", "scores": [...]}}

data: {"type": "weather", "data": [{"city": "成都", "weather": "多云", "temperature": "25"}, ...]}

event: done
data: {}
```

**事件类型**:
| type | 说明 |
|------|------|
| `status` | 状态更新文本 |
| `row` | 单个维度对比行 |
| `complete` | 全部生成完毕（含推荐、结论、评分） |
| `weather` | 实时天气数据 |
| `error` | 错误信息 |

### 对比历史

#### GET `/compare/history?device_id=xxx&limit=10`

获取设备级对比历史列表。

#### GET `/compare/history/{comp_id}`

获取单条对比历史明细（完整对比结果数据）。

#### DELETE `/compare/history/{comp_id}`

删除单条对比历史记录。

---

## 4. 行程生成

### POST `/itinerary/generate`

非流式 — 全量返回行程规划。

**请求体**:
```json
{
  "destination": "成都",
  "date": "2026-06-15",
  "preferences": ["美食", "历史文化"],
  "pace": "moderate",
  "days": 3,
  "with_pet": false
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| destination | string | 是 | 目的地城市 |
| date | string | 是 | 日期 YYYY-MM-DD |
| preferences | string[] | 否 | 偏好标签，如 ["美食","自然","文化"] |
| pace | string | 否 | `relaxed` / `moderate` / `intense` |
| days | int | 否 | 行程天数，默认 1，范围 1-7 |
| with_pet | bool | 否 | 是否带宠物 |

**响应**（单日）:
```json
{
  "code": 0,
  "data": {
    "destination": "成都",
    "date": "2026-06-15",
    "days": 1,
    "title": "成都一日美食文化之旅",
    "items": [
      {
        "time": "09:00",
        "name": "宽窄巷子",
        "type": "attraction",
        "address": "成都市青羊区",
        "duration_minutes": 90,
        "tips": "建议早上前往，人少拍照佳",
        "is_local": false,
        "local_tip": ""
      }
    ],
    "summary": "今日行程涵盖..."
  }
}
```

**响应**（多日）:
```json
{
  "code": 0,
  "data": {
    "destination": "成都",
    "date": "2026-06-15",
    "days": 3,
    "title": "成都三日深度游",
    "day_plans": [
      {
        "day": 1,
        "date": "2026-06-15",
        "title": "市区文化探索",
        "items": [...],
        "summary": "第一天以市区文化景点为主...",
        "accommodation": {
          "name": "成都太古里亚朵酒店",
          "area": "锦江区",
          "price_range": "400-600元/晚",
          "reason": "位于市中心，出行方便，周边美食众多",
          "tips": "建议提前一周预订"
        }
      }
    ],
    "summary": "三日行程精华..."
  }
}
```

### POST `/itinerary/generate/stream`

流式行程生成 (SSE) — 逐项返回。

**请求体**: 同非流式

**响应**: `text/event-stream`

```
data: {"type": "status", "text": "正在搜索景点..."}

data: {"type": "item", "day": 1, "data": {"time": "09:00", "name": "宽窄巷子", ...}}

data: {"type": "day_title", "day": 1, "data": {"title": "市区文化探索", "summary": "..."}}

data: {"type": "accommodation", "day": 1, "data": {"name": "成都太古里亚朵酒店", ...}}

data: {"type": "complete", "data": {"destination": "成都", "days": 3, "day_plans": [...]}}

event: done
data: {}
```

**事件类型**:
| type | 说明 |
|------|------|
| `status` | 状态更新 |
| `item` | 单个行程项目 |
| `day_title` | 当天标题和摘要 |
| `accommodation` | 住宿推荐 |
| `complete` | 生成完毕，含完整数据 |
| `error` | 错误信息 |

---

## 5. 高德 POI 搜索

### GET `/poi/search`

**Query 参数**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| keywords | string | 是 | 搜索关键词 |
| city | string | 否 | 城市限定 |
| types | string | 否 | POI 类型 |

**响应**:
```json
{
  "code": 0,
  "data": {
    "pois": [
      {
        "id": "B001...",
        "name": "宽窄巷子",
        "address": "成都市青羊区",
        "location": "104.05,30.67",
        "type": "风景名胜"
      }
    ]
  }
}
```

---

## 6. 用户缓存

### GET `/cache/{device_id}`
获取设备级缓存数据。

### POST `/cache`
```json
{
  "device_id": "uuid-xxx",
  "key": "last_destination",
  "value": "成都"
}
```

### DELETE `/cache/{device_id}/{key}`
删除指定缓存项。

---

## 7. 旅行文案

### GET `/content/travel`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| destination | string | 是 | 目的地 |
| source | string | 否 | `xiaohongshu` / `douyin` |
| limit | int | 否 | 默认 10 |

---

## 8. 用户认证

### POST `/auth/register`
```json
{
  "username": "traveler",
  "email": "traveler@example.com",
  "password": "123456"
}
```

返回 `access_token` + `user`（id, username, avatar, bio, travel_preferences, created_at）。

### POST `/auth/login`
```json
{"username": "traveler", "password": "123456"}
```

返回同注册。

### GET `/auth/me`
**Header**: `Authorization: Bearer <token>`
返回当前登录用户信息。

### PUT `/auth/me`
更新个人资料。支持字段：`avatar`, `bio`, `travel_preferences`, `username`, `email`。

---

## 9. 用户资料

### GET `/users/{username}`
查看用户公开主页（含统计：行程数、粉丝数、关注数）。

### GET `/users/{username}/itineraries`
获取用户公开行程列表。

---

## 10. 社交功能

### 关注/取关
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/social/follow/{user_id}` | 关注用户 |
| DELETE | `/social/follow/{user_id}` | 取消关注 |
| GET | `/social/followers/{user_id}` | 粉丝列表 |
| GET | `/social/following/{user_id}` | 关注列表 |

### 行程分享
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/social/itineraries` | 保存/分享行程 |
| GET | `/social/itineraries` | 我的行程列表 |
| DELETE | `/social/itineraries/{id}` | 删除行程 |
| GET | `/social/feed` | 公开 Feed（首页灵感流） |
| GET | `/social/share/{share_token}` | 分享链接获取（无需登录） |

### 点赞/评论
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/social/itineraries/{id}/like` | 点赞 |
| DELETE | `/social/itineraries/{id}/like` | 取消点赞 |
| POST | `/social/itineraries/{id}/comments` | 添加评论 |
| GET | `/social/itineraries/{id}/comments` | 获取评论 |

### 好友
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/social/friend-request/{user_id}` | 发送好友请求 |
| POST | `/social/friend-request/{user_id}/accept` | 接受请求 |
| GET | `/social/friends` | 好友列表 |

---

## 11. 出行查询

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/travel/weather?city=成都` | 实时天气 |
| GET | `/travel/weather/batch?cities=成都,重庆` | 批量天气 |
| GET | `/travel/hotels?city=成都&check_in=2026-06-10&check_out=2026-06-12` | 酒店（模拟） |
| GET | `/travel/restaurants?city=成都&cuisine=川菜` | 餐厅（模拟） |
| GET | `/travel/flights?from_city=北京&to_city=成都&date=2026-06-15` | 机票（模拟） |
| GET | `/travel/trains?from_station=北京&to_station=成都&date=2026-06-15` | 火车票（模拟） |
