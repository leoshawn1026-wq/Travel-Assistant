"""FastAPI 依赖注入 — 获取当前用户、数据库会话等 + Token 黑名单"""
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db, async_session_factory
from app.core.security import decode_access_token, token_fingerprint
from app.models.user import User
from app.services.cache_db import cache_db

bearer_scheme = HTTPBearer(auto_error=False)


async def _is_token_blacklisted(token: str) -> bool:
    """检查 Token 是否已被加入黑名单（登出后失效）"""
    fp = token_fingerprint(token)
    data = await cache_db.get_all("__system__")
    return data.get(f"blacklist:{fp}", "") == "1"


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> Optional[User]:
    """获取当前登录用户（可选 — 未登录返回 None）"""
    if not credentials:
        return None
    token = credentials.credentials
    if await _is_token_blacklisted(token):
        return None
    payload = decode_access_token(token)
    if not payload:
        return None
    user_id = payload.get("sub")
    if not user_id:
        return None
    result = await db.execute(select(User).where(User.id == int(user_id)))
    return result.scalar_one_or_none()


async def require_user(
    user: Optional[User] = Depends(get_current_user),
) -> User:
    """要求用户必须登录，否则 401"""
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="请先登录",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user
