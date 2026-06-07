"""用户认证路由 — 注册 / 登录 / 退出（Token 黑名单）"""
from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, Field
from app.core.database import get_db
from app.core.security import hash_password, verify_password, create_access_token, token_fingerprint
from app.core.deps import get_current_user, require_user
from app.models.user import User
from app.models.schemas import ApiResponse
from app.services.cache_db import cache_db

router = APIRouter(prefix="/auth", tags=["用户认证"])

class RegisterRequest(BaseModel):
    username: str = Field(..., min_length=2, max_length=50, description="用户名")
    email: str = Field(..., description="邮箱")
    password: str = Field(..., min_length=6, max_length=100, description="密码")


class LoginRequest(BaseModel):
    username: str = Field(..., description="用户名或邮箱")
    password: str = Field(..., description="密码")


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: dict


# ── 路由 ──

@router.post("/register", response_model=ApiResponse)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """用户注册"""
    # 检查用户名是否已存在
    result = await db.execute(select(User).where(User.username == req.username))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="用户名已被使用")

    # 检查邮箱是否已存在
    result = await db.execute(select(User).where(User.email == req.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="邮箱已被注册")

    user = User(
        username=req.username,
        email=req.email,
        hashed_password=hash_password(req.password),
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)

    token = create_access_token({"sub": str(user.id)})
    return ApiResponse(data=AuthResponse(
        access_token=token,
        user=user.to_dict(include_email=True),
    ))


@router.post("/login", response_model=ApiResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    """用户登录（支持用户名或邮箱）"""
    result = await db.execute(
        select(User).where(
            (User.username == req.username) | (User.email == req.username)
        )
    )
    user = result.scalar_one_or_none()
    if not user or not verify_password(req.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="用户名或密码错误")

    token = create_access_token({"sub": str(user.id)})
    return ApiResponse(data=AuthResponse(
        access_token=token,
        user=user.to_dict(include_email=True),
    ))


@router.get("/me", response_model=ApiResponse)
async def get_me(user: User = Depends(require_user)):
    """获取当前登录用户信息"""
    return ApiResponse(data=user.to_dict(include_email=True))


@router.put("/me", response_model=ApiResponse)
async def update_me(
    req: dict,
    user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """更新个人信息（avatar, bio, travel_preferences）"""
    allowed_fields = {"avatar", "bio", "travel_preferences", "username", "email"}
    for key, value in req.items():
        if key in allowed_fields and value is not None:
            setattr(user, key, value)

    db.add(user)
    await db.flush()
    await db.refresh(user)
    return ApiResponse(data=user.to_dict(include_email=True))


@router.post("/logout", response_model=ApiResponse)
async def logout(request: Request, user: User = Depends(require_user)):
    """退出登录 — 将当前 Token 加入黑名单"""
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.replace("Bearer ", "").strip()
    if token:
        fp = token_fingerprint(token)
        await cache_db.set("__system__", f"blacklist:{fp}", "1")
    return ApiResponse(message="已退出登录")


# ── 请求/响应模型 ──
