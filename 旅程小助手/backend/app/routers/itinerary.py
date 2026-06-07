"""行程生成路由 - MVP 核心 + 流式 SSE + 每日额度"""
import json
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from app.models.schemas import ApiResponse, ItineraryRequest
from app.services.itinerary import itinerary_service
from app.services.quota import quota_service, DAILY_LIMIT

router = APIRouter(prefix="/itinerary", tags=["行程生成"])


@router.post("/generate", response_model=ApiResponse)
async def generate_itinerary(req: ItineraryRequest):
    """非流式行程生成"""
    if not req.destination:
        raise HTTPException(status_code=400, detail="destination 不能为空")

    # 每日额度检查
    if req.device_id:
        allowed, used, limit = await quota_service.check(req.device_id)
        if not allowed:
            raise HTTPException(
                status_code=429,
                detail=f"今日免费额度已用完（{used}/{limit}），明天再来吧",
            )

    try:
        result = await itinerary_service.generate(req)
        if req.device_id:
            await quota_service.increment(req.device_id)
        return ApiResponse(data=result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"行程生成失败: {str(e)}")


@router.post("/generate/stream")
async def generate_itinerary_stream(req: ItineraryRequest):
    """流式行程生成 (SSE) — 逐天/逐项展示"""
    if not req.destination:
        raise HTTPException(status_code=400, detail="destination 不能为空")

    # 每日额度检查
    if req.device_id:
        allowed, used, limit = await quota_service.check(req.device_id)
        if not allowed:
            async def quota_error_gen():
                yield f"data: {json.dumps({'type': 'error', 'text': f'今日免费额度已用完（{used}/{limit}），明天再来吧'}, ensure_ascii=False)}\n\n"
                yield "event: done\ndata: {}\n\n"
            return StreamingResponse(
                quota_error_gen(),
                media_type="text/event-stream",
                headers={"Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no"},
            )

    async def event_generator():
        try:
            async for event in itinerary_service.generate_stream(req):
                yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"
                if event.get("type") == "complete":
                    if req.device_id:
                        await quota_service.increment(req.device_id)
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
