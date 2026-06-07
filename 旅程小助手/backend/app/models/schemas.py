"""Pydantic 请求/响应模型"""
from typing import Any, Optional
from pydantic import BaseModel, Field


# ---------- 通用 ----------
class ApiResponse(BaseModel):
    code: int = 0
    message: str = "success"
    data: Any = None


# ---------- AI 对话 ----------
class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    stream: bool = False
    device_id: str = Field(default="")  # 设备 ID（用于额度管理）


class ChatResponseData(BaseModel):
    content: str
    usage: Optional[dict] = None


# ---------- 目的地对比 ----------
class CompareRequest(BaseModel):
    destinations: list[str] = Field(..., min_length=2, max_length=5)
    criteria: list[str] = Field(
        default=["budget", "weather", "attractions", "transport", "food"]
    )
    travel_days: int = Field(default=3, ge=1, le=30)
    budget_level: str = Field(default="medium")  # low / medium / high
    # 新增用户画像
    purpose: str = Field(default="leisure")  # leisure/culture/food/adventure/honeymoon/family/shopping
    with_who: str = Field(default="alone")   # alone/couple/family/friends
    with_pet: bool = Field(default=False)    # 是否带宠物
    travel_style: str = Field(default="free")  # free/guided/half
    preferred_season: str = Field(default="")
    special_needs: str = Field(default="")
    departure_date: str = Field(default="")
    # 记忆相关
    device_id: str = Field(default="")


class CompareRow(BaseModel):
    dimension: str
    values: list[str]
    detail: str = ""


class CompareTable(BaseModel):
    headers: list[str]
    rows: list[CompareRow]


class CompareScores(BaseModel):
    """各维度评分（5分制）"""
    budget_score: float = 0
    attraction_score: float = 0
    food_score: float = 0
    transport_score: float = 0
    overall: float = 0


class CompareResponseData(BaseModel):
    table: CompareTable
    recommendation: str
    verdict: str = ""         # 最终结论
    scores: Optional[list[dict]] = None  # [{"destination":"北京","overall":4.5,"details":{...}},...]
    weather: Optional[list[dict]] = None  # [{"city":"北京","weather":"晴","temperature":"15",...},...]


class CompareHistoryItem(BaseModel):
    id: str
    destinations: list[str]
    created_at: str
    summary: str = ""
    chosen: str = ""


class CompareHistoryResponse(BaseModel):
    items: list[CompareHistoryItem]


# ---------- 行程生成 ----------
class ItineraryRequest(BaseModel):
    destination: str
    date: str  # YYYY-MM-DD
    preferences: list[str] = Field(default_factory=list)
    pace: str = "moderate"  # relaxed / moderate / intense
    days: int = Field(default=1, ge=1, le=7)
    with_pet: bool = Field(default=False)  # 是否带宠物
    device_id: str = Field(default="")  # 设备 ID（用于额度管理）


class ItineraryItem(BaseModel):
    model_config = {"coerce_numbers_to_str": True}

    time: str = ""
    name: str = ""
    type: str = "attraction"
    address: str = ""
    duration_minutes: int = 60
    tips: str = ""
    is_local: bool = False
    local_tip: str = ""


class Accommodation(BaseModel):
    name: str
    area: str                   # 所在区域
    price_range: str = ""       # 价位区间
    reason: str = ""            # 推荐理由
    tips: str = ""              # 入住提示


class DayPlan(BaseModel):
    day: int
    date: str
    title: str
    items: list[ItineraryItem] = []
    summary: str = ""
    accommodation: Optional[Accommodation] = None  # 当晚住宿推荐


class ItineraryResponseData(BaseModel):
    destination: str
    date: str
    days: int = 1
    title: str = ""
    items: list[ItineraryItem] = []  # 单日时使用
    day_plans: list[DayPlan] = []    # 多日时使用
    summary: str = ""


# ---------- POI ----------
class PoiItem(BaseModel):
    id: str
    name: str
    address: str
    location: str
    type: str = ""


class PoiSearchResponseData(BaseModel):
    pois: list[PoiItem]


# ---------- 用户缓存 ----------
class CacheSetRequest(BaseModel):
    device_id: str
    key: str
    value: str


class CacheGetResponseData(BaseModel):
    items: dict[str, str]


# ---------- 旅行文案 ----------
class TravelContentItem(BaseModel):
    title: str
    content: str
    source: str
    tags: list[str] = Field(default_factory=list)


class TravelContentResponseData(BaseModel):
    items: list[TravelContentItem]
