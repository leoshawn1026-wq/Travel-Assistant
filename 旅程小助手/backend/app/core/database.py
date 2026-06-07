"""SQLAlchemy 异步引擎与会话管理"""
import os
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

# SQLite for dev; 生产环境只需改 DATABASE_URL 为 postgresql+asyncpg://...
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    f"sqlite+aiosqlite:///{os.path.join(os.path.dirname(settings.database_path), 'travel_web.db')}"
)

engine = create_async_engine(DATABASE_URL, echo=settings.debug)
async_session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db():
    """FastAPI dependency — 每次请求获取一个新 session"""
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    """启动时创建所有表"""
    # 延迟导入避免循环依赖
    from app.models.user import User
    from app.models.social import SavedItinerary, Follow, ItineraryLike, ItineraryComment, Friend
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
