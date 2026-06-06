"""应用配置 - 密钥统一从环境变量读取，前端不可见"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",  # 忽略 .env 中未声明的字段，避免启动失败
    )

    # DeepSeek API
    deepseek_api_key: str = ""
    deepseek_base_url: str = "https://api.deepseek.com"
    deepseek_model: str = "deepseek-reasoner"

    # 高德地图 Web 服务
    amap_api_key: str = ""

    # 服务
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = True

    # 数据库（对应 .env 中 DATABASE_PATH）
    database_path: str = "./data/cache.db"


settings = Settings()
