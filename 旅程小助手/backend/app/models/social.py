"""社交/行程相关模型"""
import datetime
from sqlalchemy import String, Text, JSON, Integer, Boolean, DateTime, ForeignKey, func, Enum as SAEnum, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
import enum
from app.core.database import Base


class FriendStatus(str, enum.Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"


class SavedItinerary(Base):
    """用户保存的行程"""
    __tablename__ = "saved_itineraries"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), default="")
    destination: Mapped[str] = mapped_column(String(100), default="")
    # 完整行程数据（JSON，与 ItineraryResponseData 结构一致）
    itinerary_data: Mapped[dict] = mapped_column(JSON, nullable=False)
    is_public: Mapped[bool] = mapped_column(Boolean, default=True)
    like_count: Mapped[int] = mapped_column(Integer, default=0)
    share_token: Mapped[str] = mapped_column(String(64), default="", index=True)

    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", lazy="selectin")
    comments = relationship("ItineraryComment", back_populates="itinerary", lazy="selectin", cascade="all, delete-orphan")


class Follow(Base):
    """用户关注"""
    __tablename__ = "follows"

    follower_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), primary_key=True)
    following_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), primary_key=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())


class ItineraryLike(Base):
    """行程点赞"""
    __tablename__ = "itinerary_likes"
    __table_args__ = (
        UniqueConstraint("user_id", "itinerary_id", name="uq_user_itinerary_like"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    itinerary_id: Mapped[int] = mapped_column(Integer, ForeignKey("saved_itineraries.id"), nullable=False, index=True)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())


class ItineraryComment(Base):
    """行程评论"""
    __tablename__ = "itinerary_comments"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    itinerary_id: Mapped[int] = mapped_column(Integer, ForeignKey("saved_itineraries.id"), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())

    user = relationship("User", lazy="selectin")
    itinerary = relationship("SavedItinerary", back_populates="comments", lazy="selectin")


class Friend(Base):
    """好友关系"""
    __tablename__ = "friends"

    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), primary_key=True)
    friend_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), primary_key=True)
    status: Mapped[FriendStatus] = mapped_column(SAEnum(FriendStatus), default=FriendStatus.PENDING)
    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())
