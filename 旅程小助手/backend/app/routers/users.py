"""用户资料与公开信息路由"""
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.core.database import get_db
from app.core.deps import get_current_user, require_user
from app.models.user import User
from app.models.social import Follow, SavedItinerary
from app.models.schemas import ApiResponse

router = APIRouter(prefix="/users", tags=["用户资料"])


@router.get("/{username}", response_model=ApiResponse)
async def get_user_profile(
    username: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """查看用户公开资料"""
    result = await db.execute(select(User).where(User.username == username))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    # 统计
    itinerary_count_result = await db.execute(
        select(func.count(SavedItinerary.id))
        .where(SavedItinerary.user_id == user.id, SavedItinerary.is_public == True)
    )
    itinerary_count = itinerary_count_result.scalar() or 0

    follower_count_result = await db.execute(
        select(func.count(Follow.follower_id))
        .where(Follow.following_id == user.id)
    )
    follower_count = follower_count_result.scalar() or 0

    following_count_result = await db.execute(
        select(func.count(Follow.following_id))
        .where(Follow.follower_id == user.id)
    )
    following_count = following_count_result.scalar() or 0

    # 当前用户是否已关注
    is_following = False
    if current_user:
        follow_result = await db.execute(
            select(Follow).where(
                Follow.follower_id == current_user.id,
                Follow.following_id == user.id,
            )
        )
        is_following = follow_result.scalar_one_or_none() is not None

    profile = {
        **user.to_dict(),
        "itinerary_count": itinerary_count,
        "follower_count": follower_count,
        "following_count": following_count,
        "is_following": is_following,
    }

    return ApiResponse(data=profile)


@router.get("/{username}/itineraries", response_model=ApiResponse)
async def get_user_itineraries(
    username: str,
    db: AsyncSession = Depends(get_db),
):
    """获取用户的公开行程列表"""
    result = await db.execute(select(User).where(User.username == username))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    result = await db.execute(
        select(SavedItinerary)
        .where(SavedItinerary.user_id == user.id, SavedItinerary.is_public == True)
        .order_by(SavedItinerary.created_at.desc())
    )
    itineraries = result.scalars().all()

    return ApiResponse(data=[{
        "id": it.id,
        "title": it.title,
        "destination": it.destination,
        "like_count": it.like_count,
        "created_at": it.created_at.isoformat() if it.created_at else "",
    } for it in itineraries])
