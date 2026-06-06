# 旅程小助手 - 接口文档

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
| 500 | 服务器内部错误 |
| 502 | 第三方 API 调用失败 |

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

## 3. 目的地对比（MVP 核心）

### POST `/compare/destinations`

**请求体**:
```json
{
  "destinations": ["成都", "重庆", "西安"],
  "criteria": ["budget", "weather", "attractions", "transport", "food"],
  "travel_days": 3,
  "budget_level": "medium"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| destinations | string[] | 是 | 2-5 个目的地 |
| criteria | string[] | 否 | 对比维度，默认全选 |
| travel_days | int | 否 | 计划天数，默认 3 |
| budget_level | string | 否 | low/medium/high |

**响应**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "table": {
      "headers": ["维度", "成都", "重庆", "西安"],
      "rows": [
        {"dimension": "预算(3天)", "values": ["约1500元", "约1400元", "约1600元"]},
        {"dimension": "最佳季节", "values": ["3-5月/9-11月", "10-12月", "4-5月/9-10月"]},
        {"dimension": "必去景点", "values": ["大熊猫基地", "洪崖洞", "兵马俑"]},
        {"dimension": "交通便利度", "values": ["★★★★☆", "★★★★☆", "★★★☆☆"]},
        {"dimension": "特色美食", "values": ["火锅/串串", "小面/火锅", "肉夹馍/凉皮"]}
      ]
    },
    "recommendation": "如果偏好美食和夜景，推荐重庆..."
  }
}
```

---

## 4. 单日行程生成（MVP 核心）

### POST `/itinerary/generate`

**请求体**:
```json
{
  "destination": "成都",
  "date": "2026-06-15",
  "preferences": ["美食", "历史文化"],
  "pace": "moderate"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| destination | string | 是 | 目的地城市 |
| date | string | 是 | 日期 YYYY-MM-DD |
| preferences | string[] | 否 | 偏好标签 |
| pace | string | 否 | relaxed/moderate/intense |

**响应**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "destination": "成都",
    "date": "2026-06-15",
    "title": "成都一日美食文化之旅",
    "items": [
      {
        "time": "09:00",
        "name": "宽窄巷子",
        "type": "attraction",
        "address": "成都市青羊区",
        "duration_minutes": 90,
        "tips": "建议早上前往，人少拍照佳"
      },
      {
        "time": "12:00",
        "name": "陈麻婆豆腐",
        "type": "food",
        "address": "成都市青羊区西玉龙街",
        "duration_minutes": 60,
        "tips": "正宗川菜，建议提前预约"
      }
    ],
    "summary": "今日行程涵盖..."
  }
}
```

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
  "message": "success",
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

**请求体**:
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

## 7. 旅行文案（爬虫入库后查询）

### GET `/content/travel`

**Query 参数**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| destination | string | 是 | 目的地 |
| source | string | 否 | xiaohongshu/douyin |
| limit | int | 否 | 默认 10 |

**响应**:
```json
{
  "code": 0,
  "message": "success",
  "data": {
    "items": [
      {
        "title": "成都三日游攻略",
        "content": "第一天：宽窄巷子...",
        "source": "xiaohongshu",
        "tags": ["美食", "攻略"]
      }
    ]
  }
}
```
