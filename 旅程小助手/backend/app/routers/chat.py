"""AI 对话路由 — 非流式 + 流式(SSE) + 多对话持久化 + 每日额度"""
import json
import uuid
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from app.models.schemas import ApiResponse, ChatRequest, ChatResponseData, ChatMessage
from app.services.deepseek import deepseek_service
from app.services.cache_db import cache_db
from app.services.quota import quota_service

router = APIRouter(prefix="/chat", tags=["AI对话"])


@router.post("", response_model=ApiResponse)
async def chat(req: ChatRequest):
    """非流式对话 — 返回完整回复"""
    if not req.messages:
        raise HTTPException(status_code=400, detail="messages 不能为空")

    # 每日额度检查
    device_id = req.device_id
    if device_id:
        allowed, used, limit = await quota_service.check(device_id)
        if not allowed:
            raise HTTPException(
                status_code=429,
                detail=f"今日免费额度已用完（{used}/{limit}），明天再来吧",
            )

    messages = [{"role": m.role, "content": m.content} for m in req.messages]
    try:
        result = await deepseek_service.chat(messages)
        if device_id:
            await quota_service.increment(device_id)
        content = result["content"]
        # 尝试解析 JSON（兼容模拟数据）
        try:
            parsed = json.loads(content)
            if "reply" in parsed:
                content = parsed["reply"]
            elif "mock" in parsed:
                content = parsed.get("reply", content)
        except (json.JSONDecodeError, TypeError):
            pass

        return ApiResponse(
            data=ChatResponseData(content=content, usage=result.get("usage"))
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"DeepSeek 调用失败: {str(e)}")


@router.post("/stream")
async def chat_stream(req: ChatRequest):
    """流式对话 (SSE) — 逐 token 返回，前端逐字展示 + 每日额度"""
    if not req.messages:
        raise HTTPException(status_code=400, detail="messages 不能为空")

    # 每日额度检查
    device_id = req.device_id
    if device_id:
        allowed, used, limit = await quota_service.check(device_id)
        if not allowed:
            async def quota_error_gen():
                yield f"data: {json.dumps({'e': f'今日免费额度已用完（{used}/{limit}），明天再来吧'}, ensure_ascii=False)}\n\n"
                yield "event: done\ndata: {}\n\n"
            return StreamingResponse(
                quota_error_gen(),
                media_type="text/event-stream",
                headers={"Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no"},
            )

    messages = [{"role": m.role, "content": m.content} for m in req.messages]

    async def event_generator():
        try:
            async for token in deepseek_service.chat_stream(messages):
                if token == "__DONE__":
                    if device_id:
                        await quota_service.increment(device_id)
                    yield "event: done\ndata: {}\n\n"
                else:
                    yield f"data: {json.dumps({'t': token}, ensure_ascii=False)}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'e': str(e)}, ensure_ascii=False)}\n\n"
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


# ── 聊天历史持久化 ──


class ChatHistorySaveRequest(BaseModel):
    device_id: str
    messages: list[ChatMessage]


class ChatHistoryResponse(BaseModel):
    messages: list[ChatMessage]


@router.get("/history", response_model=ApiResponse)
async def get_chat_history(device_id: str = Query("", description="设备 ID")):
    """读取该设备的聊天历史"""
    if not device_id:
        return ApiResponse(data=ChatHistoryResponse(messages=[]))
    try:
        rows = await cache_db.get_chat_history(device_id)
        messages = [ChatMessage(role=r["role"], content=r["content"]) for r in rows]
        return ApiResponse(data=ChatHistoryResponse(messages=messages))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"读取历史失败: {str(e)}")


@router.post("/history", response_model=ApiResponse)
async def save_chat_history(req: ChatHistorySaveRequest):
    """保存聊天历史（全量替换）"""
    if not req.device_id:
        raise HTTPException(status_code=400, detail="device_id 必填")
    try:
        messages = [{"role": m.role, "content": m.content} for m in req.messages]
        await cache_db.save_chat_batch(req.device_id, messages)
        return ApiResponse(message="历史已保存")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"保存历史失败: {str(e)}")


@router.delete("/history", response_model=ApiResponse)
async def delete_chat_history(device_id: str = Query("", description="设备 ID")):
    """清空该设备的聊天历史"""
    if not device_id:
        raise HTTPException(status_code=400, detail="device_id 必填")
    try:
        await cache_db.delete_chat_history(device_id)
        return ApiResponse(message="历史已清空")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"清空失败: {str(e)}")


# ── 多对话管理 ──


class ConversationListItem(BaseModel):
    id: str
    title: str = ""
    message_count: int = 0
    created_at: str = ""
    updated_at: str = ""


class ConversationListResponse(BaseModel):
    conversations: list[ConversationListItem]


class ConversationSaveRequest(BaseModel):
    device_id: str
    conversation_id: str = ""
    messages: list[ChatMessage]


@router.get("/conversations", response_model=ApiResponse)
async def list_conversations(device_id: str = Query("", description="设备 ID")):
    """获取对话列表"""
    if not device_id:
        return ApiResponse(data=ConversationListResponse(conversations=[]))
    try:
        items = await cache_db.get_conversations(device_id)
        convs = [ConversationListItem(**i) for i in items]
        return ApiResponse(data=ConversationListResponse(conversations=convs))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"获取列表失败: {str(e)}")


@router.post("/conversations", response_model=ApiResponse)
async def save_conversation(req: ConversationSaveRequest):
    """保存对话（新建或覆盖）"""
    if not req.device_id:
        raise HTTPException(status_code=400, detail="device_id 必填")
    conv_id = req.conversation_id or uuid.uuid4().hex[:12]
    try:
        messages = [{"role": m.role, "content": m.content} for m in req.messages]
        await cache_db.save_chat_conversation(req.device_id, conv_id, messages)
        return ApiResponse(data={"conversation_id": conv_id})
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"保存失败: {str(e)}")


@router.get("/conversations/{conv_id}", response_model=ApiResponse)
async def get_conversation(conv_id: str):
    """获取某条对话的完整消息"""
    try:
        rows = await cache_db.get_conversation_messages(conv_id)
        messages = [ChatMessage(role=r["role"], content=r["content"]) for r in rows]
        return ApiResponse(data=ChatHistoryResponse(messages=messages))
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"读取失败: {str(e)}")


@router.delete("/conversations/{conv_id}", response_model=ApiResponse)
async def delete_conversation(conv_id: str):
    """删除某条对话"""
    try:
        await cache_db.delete_conversation(conv_id)
        return ApiResponse(message="已删除")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"删除失败: {str(e)}")
