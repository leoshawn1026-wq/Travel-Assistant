"""管理后台 API — 统计看板 + Token 监控 + 系统状态"""
import os
import time
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.config import settings
from app.services.cache_db import cache_db
from app.models.schemas import ApiResponse
from app.core.database import get_db
from app.models.user import User

router = APIRouter(prefix="/admin", tags=["管理后台"])

_start_time = time.time()

AVG_TOKENS_PER_CALL = 350  # 每次 AI 调用平均消耗 token 数（含输入+输出）


@router.get("/dashboard", response_model=ApiResponse)
async def admin_dashboard(db: AsyncSession = Depends(get_db)):
    """管理后台首页统计"""
    try:
        # 1. 用户统计
        result = await db.execute(select(func.count(User.id)))
        total_users = result.scalar() or 0

        # 2. API 调用统计（从 cache_db 的现有表统计）
        async with aiosqlite.connect(settings.database_path) as cdb:
            # 对比调用量
            cursor = await cdb.execute("SELECT COUNT(*) FROM comparison_history")
            total_comparisons = (await cursor.fetchone())[0] or 0

            cursor = await cdb.execute("SELECT COUNT(*) FROM chat_history WHERE role='assistant'")
            total_chat_calls = (await cursor.fetchone())[0] or 0

            # 今日数据
            today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
            cursor = await cdb.execute(
                "SELECT COUNT(*) FROM comparison_history WHERE created_at >= ?", (today,)
            )
            today_comparisons = (await cursor.fetchone())[0] or 0

            cursor = await cdb.execute(
                "SELECT COUNT(*) FROM chat_history WHERE role='assistant' AND created_at >= ?", (today,)
            )
            today_chat_calls = (await cursor.fetchone())[0] or 0

            # 近 7 天趋势
            daily_stats = []
            for i in range(6, -1, -1):
                day = (datetime.now(timezone.utc) - timedelta(days=i)).strftime("%Y-%m-%d")
                next_day = (datetime.now(timezone.utc) - timedelta(days=i - 1)).strftime("%Y-%m-%d") if i > 0 else "9999-12-31"

                cursor = await cdb.execute(
                    "SELECT COUNT(*) FROM comparison_history WHERE created_at >= ? AND created_at < ?",
                    (day, next_day),
                )
                comps = (await cursor.fetchone())[0] or 0

                cursor = await cdb.execute(
                    "SELECT COUNT(*) FROM chat_history WHERE role='assistant' AND created_at >= ? AND created_at < ?",
                    (day, next_day),
                )
                chats = (await cursor.fetchone())[0] or 0

                total_calls = comps + chats
                daily_stats.append({
                    "date": day,
                    "comparisons": comps,
                    "chat_calls": chats,
                    "total_calls": total_calls,
                    "estimated_tokens": total_calls * AVG_TOKENS_PER_CALL,
                })

            # 10 分钟内活跃数
            ten_min_ago = (datetime.now(timezone.utc) - timedelta(minutes=10)).isoformat()
            cursor = await cdb.execute(
                "SELECT COUNT(DISTINCT device_id) FROM chat_history WHERE created_at >= ?",
                (ten_min_ago,),
            )
            active_users_10m = (await cursor.fetchone())[0] or 0

            cursor = await cdb.execute(
                "SELECT COUNT(DISTINCT device_id) FROM comparison_history WHERE created_at >= ?",
                (ten_min_ago,),
            )
            active_compare_10m = (await cursor.fetchone())[0] or 0

        # 总调用量
        total_calls = total_comparisons + total_chat_calls
        today_calls = today_comparisons + today_chat_calls
        total_tokens = total_calls * AVG_TOKENS_PER_CALL
        today_tokens = today_calls * AVG_TOKENS_PER_CALL

        # 估算费用（DeepSeek v4 flash 约 ¥0.5/1M tokens）
        estimated_cost = total_tokens / 1_000_000 * 0.5

        return ApiResponse(data={
            # 用户
            "total_users": total_users,
            "new_users_today": 0,  # 需要注册时间字段才能统计
            # 调用量
            "total_calls": total_calls,
            "today_calls": today_calls,
            "total_comparisons": total_comparisons,
            "total_chat_calls": total_chat_calls,
            "today_comparisons": today_comparisons,
            "today_chat_calls": today_chat_calls,
            # Token
            "total_tokens": total_tokens,
            "today_tokens": today_tokens,
            "estimated_cost": round(estimated_cost, 4),
            # 实时
            "active_users_10m": max(active_users_10m, active_compare_10m),
            "daily_trend": daily_stats,
            # 系统
            "api_status": {
                "deepseek": bool(settings.deepseek_api_key),
                "amap": bool(settings.amap_api_key),
            },
            "uptime": _get_uptime(),
            "db_size": _get_db_size(),
        })
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))


@router.get("/content", response_model=ApiResponse)
async def admin_content(
    source: str = "",
    limit: int = 20,
):
    """查看旅行内容缓存"""
    try:
        async with aiosqlite.connect(settings.database_path) as db:
            if source:
                cursor = await db.execute(
                    """SELECT id, destination, title, content, source, tags, created_at
                       FROM travel_content WHERE source = ? ORDER BY created_at DESC LIMIT ?""",
                    (source, limit),
                )
            else:
                cursor = await db.execute(
                    """SELECT id, destination, title, content, source, tags, created_at
                       FROM travel_content ORDER BY created_at DESC LIMIT ?""",
                    (limit,),
                )
            rows = await cursor.fetchall()

        items = []
        for r in rows:
            items.append({
                "id": r[0],
                "destination": r[1],
                "title": r[2],
                "content": r[3][:200] + ("…" if len(r[3]) > 200 else ""),
                "source": r[4],
                "tags": r[5].split(",") if r[5] else [],
                "created_at": r[6],
            })
        return ApiResponse(data={"items": items, "total": len(items)})
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))


@router.get("/config", response_model=ApiResponse)
async def admin_config():
    """查看系统配置（隐藏完整密钥）"""
    return ApiResponse(data={
        "deepseek_model": settings.deepseek_model,
        "deepseek_api_key": _mask_key(settings.deepseek_api_key),
        "amap_api_key": _mask_key(settings.amap_api_key),
        "database_path": settings.database_path,
        "host": settings.host,
        "port": settings.port,
        "debug": settings.debug,
    })


def _get_uptime() -> str:
    elapsed = int(time.time() - _start_time)
    d, r = divmod(elapsed, 86400)
    h, r = divmod(r, 3600)
    m, s = divmod(r, 60)
    if d > 0:
        return f"{d}d {h:02d}:{m:02d}:{s:02d}"
    return f"{h:02d}:{m:02d}:{s:02d}"


def _get_db_size() -> str:
    try:
        size = os.path.getsize(settings.database_path)
        if size < 1024:
            return f"{size} B"
        elif size < 1024 * 1024:
            return f"{size / 1024:.1f} KB"
        else:
            return f"{size / 1024 / 1024:.1f} MB"
    except Exception:
        return "N/A"


def _mask_key(key: str) -> str:
    if not key:
        return ""
    if len(key) <= 8:
        return key[:2] + "***"
    return key[:6] + "****" + key[-4:]


# Lazy import to avoid circular imports
import aiosqlite
