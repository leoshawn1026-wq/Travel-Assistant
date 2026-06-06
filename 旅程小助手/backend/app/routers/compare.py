"""目的地对比路由 - 带记忆功能 + 流式 SSE"""
import json
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from app.models.schemas import ApiResponse, CompareRequest, CompareHistoryResponse, CompareHistoryItem
from app.services.compare import compare_service
from app.services.cache_db import cache_db

router = APIRouter(prefix="/compare", tags=["目的地对比"])


@router.post("/destinations", response_model=ApiResponse)
async def compare_destinations(req: CompareRequest):
    if len(req.destinations) < 2:
        raise HTTPException(status_code=400, detail="至少需要 2 个目的地")

    try:
        result = await compare_service.compare(req)
        return ApiResponse(data=result)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"对比生成失败: {str(e)}")


@router.post("/destinations/stream")
async def compare_destinations_stream(req: CompareRequest):
    """流式对比 (SSE) — 逐维度展示"""
    if len(req.destinations) < 2:
        raise HTTPException(status_code=400, detail="至少需要 2 个目的地")

    async def event_generator():
        try:
            async for event in compare_service.compare_stream(req):
                yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"
                if event.get("type") == "complete":
                    yield "event: done\ndata: {}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'type': 'error', 'text': str(e)}, ensure_ascii=False)}\n\n"
            yield "event: done\ndata: {}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/history", response_model=ApiResponse)
async def get_history(device_id: str = Query(""), limit: int = Query(default=10, le=50)):
    if not device_id:
        return ApiResponse(data=CompareHistoryResponse(items=[]))
    try:
        items_data = await cache_db.get_comparison_history(device_id, limit)
        items = [
            CompareHistoryItem(
                id=item["id"],
                destinations=item["destinations"],
                created_at=item["created_at"],
                summary=item["summary"],
                chosen=item.get("chosen", ""),
            )
            for item in items_data
        ]
        return ApiResponse(data=CompareHistoryResponse(items=items))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"获取历史失败: {str(e)}")


@router.get("/history/{comp_id}", response_model=ApiResponse)
async def get_history_detail(comp_id: str):
    """获取单条对比历史明细（完整对比结果）"""
    try:
        item = await cache_db.get_comparison_by_id(comp_id)
        if not item:
            raise HTTPException(status_code=404, detail="对比记录不存在")
        result_data_raw = item.get("result_data", "")
        result_data = json.loads(result_data_raw) if result_data_raw else {}
        return ApiResponse(data={
            "id": item["id"],
            "destinations": item["destinations"],
            "created_at": item["created_at"],
            "result": result_data,
        })
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"获取对比明细失败: {str(e)}")


@router.delete("/history/{comp_id}", response_model=ApiResponse)
async def delete_history(comp_id: str):
    """删除单条对比历史"""
    try:
        item = await cache_db.get_comparison_by_id(comp_id)
        if not item:
            raise HTTPException(status_code=404, detail="对比记录不存在")
        await cache_db.delete_comparison(comp_id)
        return ApiResponse(data={"deleted": True})
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"删除失败: {str(e)}")
