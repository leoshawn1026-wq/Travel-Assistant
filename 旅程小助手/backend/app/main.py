"""旅程小助手 FastAPI 入口 — Web 版（生产就绪）"""
import logging
import time
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from app.config import settings
from app.services.cache_db import cache_db
from app.services.deepseek import deepseek_service
from app.routers import chat, compare, itinerary, poi, cache, content, admin
from app.routers import auth, users, social, travel_query

# ── 结构化日志 ──
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(levelname)-5s │ %(name)s │ %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    force=True,
)
logger = logging.getLogger("wanderwise")

# 抑制 uvicorn 和 sqlalchemy 的冗余日志（生产环境）
if not settings.debug:
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine.Engine").setLevel(logging.WARNING)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 WanderWise 服务启动中...")
    await cache_db.init()
    from app.core.database import init_db
    await init_db()
    await deepseek_service.warmup()
    logger.info("✅ WanderWise 启动完成")
    yield
    await deepseek_service.close()
    logger.info("🛑 WanderWise 服务关闭")


# ── 限流器 ──
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=[f"{settings.rate_limit_per_minute}/minute"],
    enabled=not settings.debug,  # 开发环境不限制，生产环境开启
)

# ── FastAPI 应用 ──
app = FastAPI(
    title="WanderWise API",
    version="2.0.0-web",
    description="AI 旅行规划 - DeepSeek + 高德地图 + 社交系统",
    lifespan=lifespan,
    docs_url="/docs" if settings.openapi_enabled else None,
    redoc_url="/redoc" if settings.openapi_enabled else None,
    openapi_url="/openapi.json" if settings.openapi_enabled else None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── CORS（修复：按环境配置具体来源） ──
origins = [
    o.strip()
    for o in settings.cors_origins.split(",")
    if o.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if not settings.debug else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── 安全响应头中间件 + 请求日志 ──
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    start_time = time.time()
    if request.url.path != "/health":
        logger.info("→ %s %s", request.method, request.url.path)
    response = await call_next(request)
    elapsed_ms = int((time.time() - start_time) * 1000)
    # 安全头
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    if not settings.debug:
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["X-Process-Time-Ms"] = str(elapsed_ms)
    if request.url.path != "/health":
        if elapsed_ms > 1000:
            logger.warning("⚠ %s %s → %s (%dms)", request.method, request.url.path, response.status_code, elapsed_ms)
        else:
            logger.info("← %s %s → %s (%dms)", request.method, request.url.path, response.status_code, elapsed_ms)
    return response


# ── 全局异常处理器 ──
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.exception(f"未捕获异常: {request.method} {request.url.path}")
    return JSONResponse(
        status_code=500,
        content={
            "code": 500,
            "message": "服务器内部错误",
            "detail": str(exc) if settings.debug else "An unexpected error occurred",
        },
    )


@app.exception_handler(500)
async def internal_error_handler(request: Request, exc: Exception):
    logger.error(f"500: {request.method} {request.url.path}")
    return JSONResponse(
        status_code=500,
        content={"code": 500, "message": "服务器内部错误"},
    )


# ── 注册路由 ──
API_PREFIX = "/api/v1"
app.include_router(chat.router, prefix=API_PREFIX)
app.include_router(compare.router, prefix=API_PREFIX)
app.include_router(itinerary.router, prefix=API_PREFIX)
app.include_router(poi.router, prefix=API_PREFIX)
app.include_router(cache.router, prefix=API_PREFIX)
app.include_router(content.router, prefix=API_PREFIX)
app.include_router(admin.router, prefix=API_PREFIX)
app.include_router(auth.router, prefix=API_PREFIX)
app.include_router(users.router, prefix=API_PREFIX)
app.include_router(social.router, prefix=API_PREFIX)
app.include_router(travel_query.router, prefix=API_PREFIX)


@app.get("/health")
async def health():
    return {"status": "ok", "version": "2.0.0-web"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
