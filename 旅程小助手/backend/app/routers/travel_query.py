"""出行查询路由 — 天气(高德) / 酒店 / 餐厅 / 机票 / 火车票"""
import random
from fastapi import APIRouter, Query
from app.models.schemas import ApiResponse
from app.services.amap import amap_service

router = APIRouter(prefix="/travel", tags=["出行查询"])

# ── 模拟数据引擎 ──
_HOTEL_TEMPLATES = [
    {"name": "{city}国际大酒店", "area": "市中心", "price": "400-800", "rating": 4.6, "type": "豪华型", "tags": ["商务", "泳池", "健身房"], "tips": "市中心地标，交通便利"},
    {"name": "{city}悦享酒店", "area": "商业区", "price": "250-500", "rating": 4.4, "type": "舒适型", "tags": ["含早", "停车场"], "tips": "性价比之选，适合自由行"},
    {"name": "{city}特色民宿·{adj}", "area": "老城区", "price": "180-380", "rating": 4.7, "type": "民宿", "tags": ["特色装修", "本地体验"], "tips": "闹中取静，老板热情"},
    {"name": "{city}度假山庄", "area": "近郊", "price": "600-1500", "rating": 4.8, "type": "度假型", "tags": ["温泉", "亲子", "含早"], "tips": "适合家庭/情侣度假"},
    {"name": "{city}青年旅舍", "area": "大学城", "price": "60-150", "rating": 4.2, "type": "青旅", "tags": ["床位", "社交"], "tips": "背包客首选，氛围好"},
]
_HOTEL_ADJS = ["胡同里的", "花园", "江景", "山景", "文艺", "禅意"]

_RESTAURANT_TEMPLATES = [
    {"name": "{city}老字号·{adj}", "area": "美食街", "cuisine": "本地菜", "price": "60-120", "rating": 4.6, "type": "local", "tags": ["老店", "排队王"], "tips": "本地人从小吃到大"},
    {"name": "{adj}{cuisine}餐厅", "area": "商圈", "cuisine_override": True, "price": "100-200", "rating": 4.4, "type": "popular", "tags": ["网红", "适合拍照"], "tips": "建议提前预约"},
    {"name": "街角小吃集", "area": "步行街", "cuisine": "各种小吃", "price": "15-50", "rating": 4.3, "type": "street_food", "tags": ["烟火气", "边走边吃"], "tips": "空着肚子去"},
    {"name": "{city}海鲜酒楼", "area": "沿江路", "cuisine": "海鲜", "price": "150-300", "rating": 4.5, "type": "formal", "tags": ["海鲜", "包间"], "tips": "适合商务宴请"},
    {"name": "{city}素食馆", "area": "文化区", "cuisine": "素食", "price": "40-80", "rating": 4.3, "type": "healthy", "tags": ["清淡", "养生"], "tips": "环境雅致"},
]
_RESTAURANT_ADJS = ["正宗", "老牌", "地道", "巷子里的", "百年"]

_AIRLINES = ["中国国航", "东方航空", "南方航空", "海南航空", "春秋航空", "四川航空", "厦门航空", "深圳航空"]
_CITIES_POOL = ["北京", "上海", "广州", "深圳", "成都", "杭州", "西安", "重庆", "武汉", "南京", "长沙", "昆明", "青岛", "大连", "厦门", "三亚"]


def _pick(n: int, templates: list, city: str, **extra) -> list:
    """从模板生成 n 个模拟数据项"""
    items = []
    used = set()
    for _ in range(n):
        t = random.choice(templates)
        key = t["name"]
        if key in used:
            continue
        used.add(key)
        item = dict(t)
        item["name"] = t["name"].format(city=city, adj=random.choice(_HOTEL_ADJS if "adj" in t["name"] else _RESTAURANT_ADJS), cuisine=extra.get("cuisine", "本地菜"))
        item["address"] = f"{city}{t['area']}"
        if t.get("cuisine_override"):
            item["cuisine"] = extra.get("cuisine", "创意菜")
        # 给评分加一点随机抖动，让数据看起来更真实
        item["rating"] = round(min(5.0, item["rating"] + random.uniform(-0.3, 0.3)), 1)
        items.append(item)
    return items


# ── 天气（高德实况） ──

@router.get("/weather", response_model=ApiResponse)
async def get_weather(city: str = Query(..., description="城市名")):
    """获取实时天气"""
    data = await amap_service.get_weather(city)
    if not data.get("success"):
        return ApiResponse(code=404, message="天气数据获取失败", data={})
    return ApiResponse(data=data)


@router.get("/weather/batch", response_model=ApiResponse)
async def get_weather_batch(cities: str = Query(..., description="城市名，逗号分隔")):
    """批量获取天气"""
    city_list = [c.strip() for c in cities.split(",") if c.strip()]
    if not city_list:
        return ApiResponse(code=400, message="请至少提供一个城市")
    data = await amap_service.get_weather_batch(city_list)
    return ApiResponse(data=data)


# ── 酒店 ──

@router.get("/hotels", response_model=ApiResponse)
async def search_hotels(
    city: str = Query(..., description="城市"),
    check_in: str = Query("", description="入住日期"),
    check_out: str = Query("", description="离店日期"),
    keyword: str = Query("", description="关键词"),
    limit: int = Query(default=6, le=20),
):
    """搜索酒店推荐"""
    random.seed(city + keyword)
    items = _pick(min(limit, 6), _HOTEL_TEMPLATES, city)
    # 按评分排序
    items.sort(key=lambda x: x["rating"], reverse=True)
    # 价格格式化成字符串
    for item in items:
        item["price_display"] = f"¥{item['price']}/晚"
    return ApiResponse(data={"items": items, "total": len(items)})


# ── 餐厅 ──

@router.get("/restaurants", response_model=ApiResponse)
async def search_restaurants(
    city: str = Query(..., description="城市"),
    cuisine: str = Query("", description="菜系偏好"),
    limit: int = Query(default=6, le=20),
):
    """搜索餐厅推荐"""
    random.seed(city + cuisine)
    items = _pick(min(limit, 6), _RESTAURANT_TEMPLATES, city, cuisine=cuisine)
    items.sort(key=lambda x: x["rating"], reverse=True)
    for item in items:
        item["price_display"] = f"¥{item['price']}/人"
    return ApiResponse(data={"items": items, "total": len(items)})


# ── 机票 ──

@router.get("/flights", response_model=ApiResponse)
async def search_flights(
    from_city: str = Query(..., description="出发城市"),
    to_city: str = Query(..., description="到达城市"),
    date: str = Query("", description="出发日期"),
    limit: int = Query(default=6, le=20),
):
    """查询机票价格参考"""
    random.seed(from_city + to_city + date)
    airlines = random.sample(_AIRLINES, min(limit, 4))
    flights = []
    base_price = 400 + abs(hash(from_city + to_city)) % 600
    for i, airline in enumerate(airlines):
        dep_hour = random.choice([7, 8, 9, 10, 11, 13, 14, 15, 16, 18, 19, 21])
        duration_h = random.choice([1.5, 2, 2.5, 3, 3.5, 4])
        arr_hour = dep_hour + int(duration_h)
        price = base_price + random.randint(-150, 200) + i * 50
        flights.append({
            "airline": airline,
            "flight_no": f"{['CA','MU','CZ','HU','9C','3U'][i]}{1000+hash(airline)%9000:04d}",
            "departure": f"{from_city}机场",
            "arrival": f"{to_city}机场",
            "depart_time": f"{dep_hour:02d}:{random.choice(['00','15','30','45'])}",
            "arrive_time": f"{arr_hour:02d}:{random.choice(['00','15','30','45'])}",
            "duration": f"{int(duration_h)}h{random.choice(['00','15','30','45'])}",
            "price": f"¥{max(200, price)}",
            "tips": random.choice(["经济舱含餐", "特价票不可退", "含23kg行李", "机型空客A320"]),
        })
    return ApiResponse(data={"items": flights, "total": len(flights)})


# ── 火车票 ──

@router.get("/trains", response_model=ApiResponse)
async def search_trains(
    from_station: str = Query(..., description="出发站/城市"),
    to_station: str = Query(..., description="到达站/城市"),
    date: str = Query("", description="出发日期"),
    limit: int = Query(default=6, le=20),
):
    """查询火车票价格参考"""
    random.seed(from_station + to_station + date)
    dist = abs(hash(from_station + to_station)) % 2000 + 200  # 模拟距离
    base_second_price = max(100, dist // 5 * 3)  # ~0.6元/km
    trains = []

    types = [
        ("G", "高铁", [250, 400, 750], dist // 3),
        ("D", "动车", [160, 260, 0], dist // 2),
        ("K", "快速", [80, 130, 240], dist),
    ]
    for prefix, name, seat_multiples, duration_min in types:
        duration_h = duration_min // 60
        duration_m = duration_min % 60
        dep_hour = random.choice([6, 7, 8, 9, 10, 13, 14, 15, 18, 19, 20])
        seat_types = [
            {"type": "二等座", "price": f"¥{base_second_price}", "available": random.choice(["充足", "余19张", "余5张"])},
            {"type": "一等座", "price": f"¥{int(base_second_price * seat_multiples[1] / 250)}", "available": random.choice(["余9张", "余3张", "充足"])},
        ]
        if seat_multiples[2] > 0:
            seat_types.append({
                "type": "商务座",
                "price": f"¥{int(base_second_price * seat_multiples[2] / 250)}",
                "available": random.choice(["余2张", "余5张", "已售罄"]),
            })
        trains.append({
            "train_no": f"{prefix}{1000 + hash(from_station+to_station+prefix) % 9000:04d}",
            "type": name,
            "departure": f"{from_station}站",
            "arrival": f"{to_station}站",
            "depart_time": f"{dep_hour:02d}:{random.choice(['00','12','24','36','48'])}",
            "arrive_time": f"{(dep_hour + duration_h) % 24:02d}:{duration_m:02d}",
            "duration": f"{duration_h}h{duration_m:02d}",
            "seat_types": seat_types,
        })
    return ApiResponse(data={"items": trains, "total": len(trains)})
