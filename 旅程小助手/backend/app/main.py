"""旅程小助手 FastAPI 入口"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.services.cache_db import cache_db
from app.services.deepseek import deepseek_service
from app.routers import chat, compare, itinerary, poi, cache, content, admin


@asynccontextmanager
async def lifespan(app: FastAPI):
    await cache_db.init()
    # 预热 DeepSeek 连接池，避免首次请求慢
    await deepseek_service.warmup()
    yield
    # 优雅关闭连接池
    await deepseek_service.close()


app = FastAPI(
    title="旅程小助手 API",
    version="1.0.0-mvp",
    description="旅行规划后端 - DeepSeek + 高德地图",
    lifespan=lifespan,
)

# CORS - 允许 Flutter 客户端跨域
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
API_PREFIX = "/api/v1"
app.include_router(chat.router, prefix=API_PREFIX)
app.include_router(compare.router, prefix=API_PREFIX)
app.include_router(itinerary.router, prefix=API_PREFIX)
app.include_router(poi.router, prefix=API_PREFIX)
app.include_router(cache.router, prefix=API_PREFIX)
app.include_router(content.router, prefix=API_PREFIX)
app.include_router(admin.router, prefix=API_PREFIX)


@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.0.0-mvp"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
