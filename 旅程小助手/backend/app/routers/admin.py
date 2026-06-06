"""管理后台 API — 统计、内容管理、系统状态"""
import os
import time
from fastapi import APIRouter, HTTPException, Query
from app.config import settings
from app.services.cache_db import cache_db
from app.models.schemas import ApiResponse

router = APIRouter(prefix="/admin", tags=["管理后台"])


@router.get("/dashboard", response_model=ApiResponse)
async def admin_dashboard():
    """管理后台首页统计"""
    try:
        # 统计数据 - 从各个表中获取
        stats = {
            "api_status": _check_api_keys(),
            "uptime": _get_uptime(),
            "total_comparisons": 0,
            "total_content": 0,
            "db_size": _get_db_size(),
        }

        # 获取内容数量
        try:
            import aiosqlite
            async with aiosqlite.connect(settings.database_path) as db:
                cursor = await db.execute("SELECT COUNT(*) FROM travel_content")
                row = await cursor.fetchone()
                stats["total_content"] = row[0] if row else 0

                cursor = await db.execute("SELECT COUNT(*) FROM comparison_history")
                row = await cursor.fetchone()
                stats["total_comparisons"] = row[0] if row else 0

                cursor = await db.execute("SELECT COUNT(*) FROM chat_history")
                row = await cursor.fetchone()
                stats["total_chat_messages"] = row[0] if row else 0
        except Exception:
            pass

        return ApiResponse(data=stats)
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))


@router.get("/content", response_model=ApiResponse)
async def admin_content(
    source: str = Query("", description="数据来源"),
    limit: int = Query(default=20, le=100),
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


def _check_api_keys() -> dict:
    return {
        "deepseek": bool(settings.deepseek_api_key),
        "amap": bool(settings.amap_api_key),
    }


_start_time = time.time()


def _get_uptime() -> str:
    elapsed = int(time.time() - _start_time)
    h, r = divmod(elapsed, 3600)
    m, s = divmod(r, 60)
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
