"""高德 POI 路由"""
from fastapi import APIRouter, HTTPException, Query
from app.models.schemas import ApiResponse, PoiSearchResponseData
from app.services.amap import amap_service

router = APIRouter(prefix="/poi", tags=["POI搜索"])


@router.get("/search", response_model=ApiResponse)
async def search_poi(
    keywords: str = Query(..., description="搜索关键词"),
    city: str = Query("", description="城市限定"),
    types: str = Query("", description="POI类型"),
):
    if not keywords:
        raise HTTPException(status_code=400, detail="keywords 不能为空")

    pois = await amap_service.search_poi(keywords, city, types)
    return ApiResponse(data=PoiSearchResponseData(pois=pois))
