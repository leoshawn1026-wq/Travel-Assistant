"""应用配置 - 密钥统一从环境变量读取，前端不可见"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # DeepSeek API
    deepseek_api_key: str = ""
    deepseek_base_url: str = "https://api.deepseek.com"
    deepseek_model: str = "deepseek-reasoner"

    # 高德地图 Web 服务
    amap_api_key: str = ""

    # JWT 签名密钥（必须独立于 DeepSeek API Key，生产环境务必修改）
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 10080  # 7 天

    # 服务
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False  # 生产环境必须为 False

    # CORS — 允许的来源，多个用逗号分隔
    cors_origins: str = "http://localhost:3000,http://localhost:3001"

    # 数据库
    database_path: str = "./data/cache.db"

    # 速率限制（每分钟请求数，0=不限制）
    rate_limit_per_minute: int = 10

    # API 文档开关
    openapi_enabled: bool = False  # 生产环境默认关闭


settings = Settings()
