"""每日免费额度管理 — 防止 AI 接口被滥用刷费"""
from datetime import datetime, timezone
from app.services.cache_db import cache_db

# 每个设备每天免费 AI 调用次数
DAILY_LIMIT = 10


class QuotaService:
    """基于 device_id 的每日额度管理，存于现有 user_cache 表"""

    @staticmethod
    def _quota_key() -> str:
        return f"quota:{datetime.now(timezone.utc).strftime('%Y-%m-%d')}"

    async def get_usage(self, device_id: str) -> int:
        """查询今日已用次数"""
        if not device_id:
            return 0
        data = await cache_db.get_all(device_id)
        return int(data.get(self._quota_key(), 0))

    async def get_remaining(self, device_id: str) -> int:
        """今日剩余次数"""
        return max(0, DAILY_LIMIT - await self.get_usage(device_id))

    async def increment(self, device_id: str) -> int:
        """消耗一次额度，返回累计已用次数"""
        if not device_id:
            return 0
        key = self._quota_key()
        current = await self.get_usage(device_id) + 1
        await cache_db.set(device_id, key, str(current))
        return current

    async def check(self, device_id: str) -> tuple[bool, int, int]:
        """
        检查是否还有额度
        返回 (是否允许, 已用次数, 总限额)
        """
        used = await self.get_usage(device_id)
        return (used < DAILY_LIMIT, used, DAILY_LIMIT)

    async def consume(self, device_id: str) -> tuple[bool, int, int]:
        """
        尝试消耗一次额度
        返回 (是否成功, 已用次数, 总限额)
        """
        allowed, used, limit = await self.check(device_id)
        if not allowed:
            return (False, used, limit)
        await self.increment(device_id)
        return (True, used + 1, limit)


quota_service = QuotaService()
