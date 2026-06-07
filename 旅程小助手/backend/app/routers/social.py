"""社交功能路由 — 关注/粉丝、点赞、评论、好友、行程分享"""
import uuid
from fastapi import APIRouter, HTTPException, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, and_
from pydantic import BaseModel, Field
from app.core.database import get_db
from app.core.deps import get_current_user, require_user
from app.models.user import User
from app.models.social import (
    SavedItinerary, Follow, ItineraryLike, ItineraryComment, Friend, FriendStatus,
)
from app.models.schemas import ApiResponse

router = APIRouter(prefix="/social", tags=["社交功能"])


# ── 关注/取关 ──

@router.post("/follow/{user_id}", response_model=ApiResponse)
async def follow_user(
    user_id: int,
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """关注用户"""
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="不能关注自己")

    # 检查被关注用户是否存在
    result = await db.execute(select(User).where(User.id == user_id))
    target = result.scalar_one_or_none()
    if not target:
        raise HTTPException(status_code=404, detail="用户不存在")

    # 检查是否已关注
    result = await db.execute(
        select(Follow).where(
            Follow.follower_id == current_user.id,
            Follow.following_id == user_id,
        )
    )
    if result.scalar_one_or_none():
        return ApiResponse(message="已关注")

    db.add(Follow(follower_id=current_user.id, following_id=user_id))
    await db.flush()
    return ApiResponse(message="关注成功")


@router.delete("/follow/{user_id}", response_model=ApiResponse)
async def unfollow_user(
    user_id: int,
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """取消关注"""
    result = await db.execute(
        select(Follow).where(
            Follow.follower_id == current_user.id,
            Follow.following_id == user_id,
        )
    )
    follow = result.scalar_one_or_none()
    if not follow:
        raise HTTPException(status_code=404, detail="未关注该用户")

    await db.delete(follow)
    await db.flush()
    return ApiResponse(message="已取消关注")


@router.get("/followers/{user_id}", response_model=ApiResponse)
async def get_followers(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    limit: int = Query(default=20, le=100),
):
    """获取粉丝列表"""
    result = await db.execute(
        select(Follow).where(Follow.following_id == user_id).limit(limit)
    )
    follows = result.scalars().all()
    user_ids = [f.follower_id for f in follows]

    if not user_ids:
        return ApiResponse(data={"users": [], "total": 0})

    result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users = result.scalars().all()
    return ApiResponse(data={
        "users": [u.to_dict() for u in users],
        "total": len(users),
    })


@router.get("/following/{user_id}", response_model=ApiResponse)
async def get_following(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    limit: int = Query(default=20, le=100),
):
    """获取关注列表"""
    result = await db.execute(
        select(Follow).where(Follow.follower_id == user_id).limit(limit)
    )
    follows = result.scalars().all()
    user_ids = [f.following_id for f in follows]

    if not user_ids:
        return ApiResponse(data={"users": [], "total": 0})

    result = await db.execute(select(User).where(User.id.in_(user_ids)))
    users = result.scalars().all()
    return ApiResponse(data={
        "users": [u.to_dict() for u in users],
        "total": len(users),
    })


# ── 行程分享（保存/公开） ──

class SaveItineraryRequest(BaseModel):
    title: str = ""
    destination: str = ""
    itinerary_data: dict
    is_public: bool = True


@router.post("/itineraries", response_model=ApiResponse)
async def save_itinerary(
    req: SaveItineraryRequest,
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """保存/分享行程"""
    share_token = uuid.uuid4().hex[:16]

    itinerary = SavedItinerary(
        user_id=current_user.id,
        title=req.title or f"{req.destination}行程",
        destination=req.destination,
        itinerary_data=req.itinerary_data,
        is_public=req.is_public,
        share_token=share_token,
    )
    db.add(itinerary)
    await db.flush()
    await db.refresh(itinerary)

    return ApiResponse(data={
        "id": itinerary.id,
        "share_token": share_token,
        "share_url": f"/share/{share_token}",
        "created_at": itinerary.created_at.isoformat() if itinerary.created_at else "",
    })


@router.get("/itineraries", response_model=ApiResponse)
async def list_itineraries(
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, le=50),
):
    """获取当前用户的行程列表"""
    offset = (page - 1) * page_size
    result = await db.execute(
        select(SavedItinerary)
        .where(SavedItinerary.user_id == current_user.id)
        .order_by(SavedItinerary.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    items = result.scalars().all()

    total_result = await db.execute(
        select(func.count(SavedItinerary.id))
        .where(SavedItinerary.user_id == current_user.id)
    )
    total = total_result.scalar() or 0

    return ApiResponse(data={
        "items": [{
            "id": it.id,
            "title": it.title,
            "destination": it.destination,
            "is_public": it.is_public,
            "like_count": it.like_count,
            "created_at": it.created_at.isoformat() if it.created_at else "",
        } for it in items],
        "total": total,
        "page": page,
    })


@router.delete("/itineraries/{itinerary_id}", response_model=ApiResponse)
async def delete_itinerary(
    itinerary_id: int,
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """删除自己的行程"""
    result = await db.execute(
        select(SavedItinerary).where(
            SavedItinerary.id == itinerary_id,
            SavedItinerary.user_id == current_user.id,
        )
    )
    itinerary = result.scalar_one_or_none()
    if not itinerary:
        raise HTTPException(status_code=404, detail="行程不存在或无权删除")

    await db.delete(itinerary)
    await db.flush()
    return ApiResponse(message="已删除")


# ── 公开行程 Feed ──

@router.get("/feed", response_model=ApiResponse)
async def get_feed(
    db: AsyncSession = Depends(get_db),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, le=50),
    destination: str = Query(default="", description="按目的地筛选"),
):
    """获取公开行程 Feed（首页灵感流）"""
    offset = (page - 1) * page_size

    query = select(SavedItinerary).where(SavedItinerary.is_public == True)
    count_query = select(func.count(SavedItinerary.id)).where(SavedItinerary.is_public == True)

    if destination:
        query = query.where(SavedItinerary.destination.ilike(f"%{destination}%"))
        count_query = count_query.where(SavedItinerary.destination.ilike(f"%{destination}%"))

    query = query.order_by(SavedItinerary.like_count.desc(), SavedItinerary.created_at.desc())
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    items = result.scalars().all()

    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    feed_items = []
    for it in items:
        feed_items.append({
            "id": it.id,
            "title": it.title,
            "destination": it.destination,
            "like_count": it.like_count,
            "created_at": it.created_at.isoformat() if it.created_at else "",
            "user": it.user.to_dict() if it.user else {},
            "summary": it.itinerary_data.get("summary", "") if isinstance(it.itinerary_data, dict) else "",
        })

    return ApiResponse(data={
        "items": feed_items,
        "total": total,
        "page": page,
    })


# ── 分享链接访问（无需登录） ──

@router.get("/share/{share_token}", response_model=ApiResponse)
async def get_shared_itinerary(
    share_token: str,
    db: AsyncSession = Depends(get_db),
):
    """通过分享链接获取行程（无需登录）"""
    result = await db.execute(
        select(SavedItinerary).where(SavedItinerary.share_token == share_token)
    )
    itinerary = result.scalar_one_or_none()
    if not itinerary or not itinerary.is_public:
        raise HTTPException(status_code=404, detail="行程不存在或已删除")

    # 评论数
    comment_count_result = await db.execute(
        select(func.count(ItineraryComment.id))
        .where(ItineraryComment.itinerary_id == itinerary.id)
    )
    comment_count = comment_count_result.scalar() or 0

    return ApiResponse(data={
        "id": itinerary.id,
        "title": itinerary.title,
        "destination": itinerary.destination,
        "itinerary_data": itinerary.itinerary_data,
        "like_count": itinerary.like_count,
        "comment_count": comment_count,
        "user": itinerary.user.to_dict() if itinerary.user else {},
        "created_at": itinerary.created_at.isoformat() if itinerary.created_at else "",
    })


# ── 点赞/取消点赞 ──

@router.post("/itineraries/{itinerary_id}/like", response_model=ApiResponse)
async def like_itinerary(
    itinerary_id: int,
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """点赞行程"""
    # 检查行程是否存在且公开
    result = await db.execute(
        select(SavedItinerary).where(
            SavedItinerary.id == itinerary_id,
            SavedItinerary.is_public == True,
        )
    )
    itinerary = result.scalar_one_or_none()
    if not itinerary:
        raise HTTPException(status_code=404, detail="行程不存在")

    # 检查是否已点赞
    result = await db.execute(
        select(ItineraryLike).where(
            ItineraryLike.user_id == current_user.id,
            ItineraryLike.itinerary_id == itinerary_id,
        )
    )
    if result.scalar_one_or_none():
        return ApiResponse(message="已点赞")

    db.add(ItineraryLike(user_id=current_user.id, itinerary_id=itinerary_id))
    itinerary.like_count += 1
    await db.flush()
    return ApiResponse(data={"like_count": itinerary.like_count}, message="点赞成功")


@router.delete("/itineraries/{itinerary_id}/like", response_model=ApiResponse)
async def unlike_itinerary(
    itinerary_id: int,
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """取消点赞"""
    result = await db.execute(
        select(ItineraryLike).where(
            ItineraryLike.user_id == current_user.id,
            ItineraryLike.itinerary_id == itinerary_id,
        )
    )
    like = result.scalar_one_or_none()
    if not like:
        raise HTTPException(status_code=404, detail="未点赞")

    await db.delete(like)

    result = await db.execute(
        select(SavedItinerary).where(SavedItinerary.id == itinerary_id)
    )
    itinerary = result.scalar_one_or_none()
    if itinerary and itinerary.like_count > 0:
        itinerary.like_count -= 1

    await db.flush()
    return ApiResponse(message="已取消点赞")


# ── 评论 ──

class CommentRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)


@router.post("/itineraries/{itinerary_id}/comments", response_model=ApiResponse)
async def add_comment(
    itinerary_id: int,
    req: CommentRequest,
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """添加评论"""
    result = await db.execute(
        select(SavedItinerary).where(
            SavedItinerary.id == itinerary_id,
            SavedItinerary.is_public == True,
        )
    )
    itinerary = result.scalar_one_or_none()
    if not itinerary:
        raise HTTPException(status_code=404, detail="行程不存在")

    comment = ItineraryComment(
        user_id=current_user.id,
        itinerary_id=itinerary_id,
        content=req.content,
    )
    db.add(comment)
    await db.flush()
    await db.refresh(comment)

    return ApiResponse(data={
        "id": comment.id,
        "content": comment.content,
        "user": current_user.to_dict(),
        "created_at": comment.created_at.isoformat() if comment.created_at else "",
    }, message="评论成功")


@router.get("/itineraries/{itinerary_id}/comments", response_model=ApiResponse)
async def get_comments(
    itinerary_id: int,
    db: AsyncSession = Depends(get_db),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, le=50),
):
    """获取评论列表"""
    offset = (page - 1) * page_size
    result = await db.execute(
        select(ItineraryComment)
        .where(ItineraryComment.itinerary_id == itinerary_id)
        .order_by(ItineraryComment.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    comments = result.scalars().all()

    return ApiResponse(data={
        "items": [{
            "id": c.id,
            "content": c.content,
            "user": c.user.to_dict() if c.user else {},
            "created_at": c.created_at.isoformat() if c.created_at else "",
        } for c in comments],
    })


# ── 好友系统 ──

@router.post("/friend-request/{user_id}", response_model=ApiResponse)
async def send_friend_request(
    user_id: int,
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """发送好友请求"""
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="不能添加自己为好友")

    # 检查对方是否存在
    result = await db.execute(select(User).where(User.id == user_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="用户不存在")

    # 检查是否已是好友
    result = await db.execute(
        select(Friend).where(
            or_(
                and_(Friend.user_id == current_user.id, Friend.friend_id == user_id),
                and_(Friend.user_id == user_id, Friend.friend_id == current_user.id),
            )
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        if existing.status == FriendStatus.ACCEPTED:
            return ApiResponse(message="已是好友")
        return ApiResponse(message="已发送过好友请求")

    db.add(Friend(user_id=current_user.id, friend_id=user_id, status=FriendStatus.PENDING))
    await db.flush()
    return ApiResponse(message="好友请求已发送")


@router.post("/friend-request/{user_id}/accept", response_model=ApiResponse)
async def accept_friend_request(
    user_id: int,
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """接受好友请求"""
    result = await db.execute(
        select(Friend).where(
            Friend.user_id == user_id,
            Friend.friend_id == current_user.id,
            Friend.status == FriendStatus.PENDING,
        )
    )
    friendship = result.scalar_one_or_none()
    if not friendship:
        raise HTTPException(status_code=404, detail="好友请求不存在")

    friendship.status = FriendStatus.ACCEPTED
    await db.flush()
    return ApiResponse(message="已接受好友请求")


@router.get("/friends", response_model=ApiResponse)
async def get_friends(
    current_user: User = Depends(require_user),
    db: AsyncSession = Depends(get_db),
):
    """获取好友列表"""
    result = await db.execute(
        select(Friend).where(
            or_(
                and_(Friend.user_id == current_user.id, Friend.status == FriendStatus.ACCEPTED),
                and_(Friend.friend_id == current_user.id, Friend.status == FriendStatus.ACCEPTED),
            )
        )
    )
    friendships = result.scalars().all()

    friend_ids = set()
    for f in friendships:
        if f.user_id == current_user.id:
            friend_ids.add(f.friend_id)
        else:
            friend_ids.add(f.user_id)

    if not friend_ids:
        return ApiResponse(data={"users": []})

    result = await db.execute(select(User).where(User.id.in_(friend_ids)))
    users = result.scalars().all()
    return ApiResponse(data={"users": [u.to_dict() for u in users]})
