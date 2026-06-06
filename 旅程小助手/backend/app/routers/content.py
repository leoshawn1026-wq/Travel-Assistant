"""旅行文案查询路由（爬虫入库后）"""
from fastapi import APIRouter, Query
from app.models.schemas import ApiResponse, TravelContentResponseData, TravelContentItem
from app.services.cache_db import cache_db

router = APIRouter(prefix="/content", tags=["旅行文案"])


@router.get("/travel", response_model=ApiResponse)
async def get_travel_content(
    destination: str = Query(..., description="目的地"),
    source: str = Query("", description="来源: xiaohongshu/douyin"),
    limit: int = Query(10, ge=1, le=50),
):
    items_raw = await cache_db.get_travel_content(destination, source, limit)
    items = [TravelContentItem(**item) for item in items_raw]
    return ApiResponse(data=TravelContentResponseData(items=items))
