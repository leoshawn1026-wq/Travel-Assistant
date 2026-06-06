"""用户缓存路由"""
from fastapi import APIRouter, HTTPException
from app.models.schemas import ApiResponse, CacheSetRequest, CacheGetResponseData
from app.services.cache_db import cache_db

router = APIRouter(prefix="/cache", tags=["用户缓存"])


@router.get("/{device_id}", response_model=ApiResponse)
async def get_cache(device_id: str):
    items = await cache_db.get_all(device_id)
    return ApiResponse(data=CacheGetResponseData(items=items))


@router.post("", response_model=ApiResponse)
async def set_cache(req: CacheSetRequest):
    await cache_db.set(req.device_id, req.key, req.value)
    return ApiResponse(message="缓存已更新")


@router.delete("/{device_id}/{key}", response_model=ApiResponse)
async def delete_cache(device_id: str, key: str):
    await cache_db.delete(device_id, key)
    return ApiResponse(message="缓存已删除")
