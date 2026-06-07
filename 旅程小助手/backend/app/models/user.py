"""User 模型"""
import datetime
from sqlalchemy import String, Text, JSON, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    avatar: Mapped[str] = mapped_column(String(500), default="")
    bio: Mapped[str] = mapped_column(Text, default="")
    # 旅行偏好（JSON）：{purpose, budget_level, travel_style, with_who, preferred_season, with_pet}
    travel_preferences: Mapped[dict] = mapped_column(JSON, default=dict)

    created_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now())
    updated_at: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=func.now(), onupdate=func.now())

    @property
    def is_authenticated(self) -> bool:
        return True

    def to_dict(self, include_email: bool = False) -> dict:
        data = {
            "id": self.id,
            "username": self.username,
            "avatar": self.avatar,
            "bio": self.bio,
            "travel_preferences": self.travel_preferences or {},
            "created_at": self.created_at.isoformat() if self.created_at else "",
        }
        if include_email:
            data["email"] = self.email
        return data
