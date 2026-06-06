"""用户本地缓存 - SQLite 持久化"""
import json
import os
import hashlib
from typing import Optional
import aiosqlite
from app.config import settings


class CacheDB:
    def __init__(self, db_path: str):
        self.db_path = db_path

    async def init(self):
        os.makedirs(os.path.dirname(self.db_path) or ".", exist_ok=True)
        async with aiosqlite.connect(self.db_path) as db:
            # 迁移：为已有表补加新字段（SQLite 不支持 ALTER ADD COLUMN IF NOT EXISTS）
            try:
                await db.execute("ALTER TABLE comparison_history ADD COLUMN result_data TEXT DEFAULT ''")
            except aiosqlite.OperationalError:
                pass  # 列已存在，忽略
            await db.execute(
                """
                CREATE TABLE IF NOT EXISTS user_cache (
                    device_id TEXT NOT NULL,
                    key TEXT NOT NULL,
                    value TEXT NOT NULL,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (device_id, key)
                )
                """
            )
            await db.execute(
                """
                CREATE TABLE IF NOT EXISTS comparison_history (
                    id TEXT PRIMARY KEY,
                    device_id TEXT NOT NULL,
                    destinations TEXT NOT NULL,
                    purpose TEXT DEFAULT '',
                    with_who TEXT DEFAULT '',
                    budget_level TEXT DEFAULT '',
                    travel_days INTEGER DEFAULT 3,
                    chosen TEXT DEFAULT '',
                    summary TEXT DEFAULT '',
                    result_data TEXT DEFAULT '',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            await db.execute(
                """
                CREATE TABLE IF NOT EXISTS chat_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    device_id TEXT NOT NULL,
                    conversation_id TEXT DEFAULT '',
                    role TEXT NOT NULL,
                    content TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            await db.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_chat_history_device
                ON chat_history (device_id, created_at)
                """
            )
            await db.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_chat_conv
                ON chat_history (device_id, conversation_id)
                """
            )
            await db.execute(
                """
                CREATE TABLE IF NOT EXISTS response_cache (
                    cache_key TEXT PRIMARY KEY,
                    messages_hash TEXT NOT NULL,
                    response TEXT NOT NULL,
                    endpoint TEXT DEFAULT 'chat',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            await db.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_response_cache_hash
                ON response_cache (messages_hash)
                """
            )
            await db.execute(
                """
                CREATE TABLE IF NOT EXISTS conversations (
                    id TEXT PRIMARY KEY,
                    device_id TEXT NOT NULL,
                    title TEXT DEFAULT '',
                    message_count INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            await db.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_conv_device
                ON conversations (device_id, updated_at)
                """
            )
            await db.execute(
                """
                CREATE TABLE IF NOT EXISTS travel_content (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    destination TEXT NOT NULL,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    source TEXT NOT NULL,
                    tags TEXT DEFAULT '',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            await db.commit()

    async def get_all(self, device_id: str) -> dict[str, str]:
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute(
                "SELECT key, value FROM user_cache WHERE device_id = ?",
                (device_id,),
            )
            rows = await cursor.fetchall()
        return {row[0]: row[1] for row in rows}

    async def set(self, device_id: str, key: str, value: str):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                """
                INSERT INTO user_cache (device_id, key, value)
                VALUES (?, ?, ?)
                ON CONFLICT(device_id, key) DO UPDATE SET
                    value = excluded.value,
                    updated_at = CURRENT_TIMESTAMP
                """,
                (device_id, key, value),
            )
            await db.commit()

    async def delete(self, device_id: str, key: str):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "DELETE FROM user_cache WHERE device_id = ? AND key = ?",
                (device_id, key),
            )
            await db.commit()

    async def get_travel_content(
        self, destination: str, source: str = "", limit: int = 10
    ) -> list[dict]:
        async with aiosqlite.connect(self.db_path) as db:
            if source:
                cursor = await db.execute(
                    """
                    SELECT title, content, source, tags FROM travel_content
                    WHERE destination LIKE ? AND source = ?
                    ORDER BY created_at DESC LIMIT ?
                    """,
                    (f"%{destination}%", source, limit),
                )
            else:
                cursor = await db.execute(
                    """
                    SELECT title, content, source, tags FROM travel_content
                    WHERE destination LIKE ?
                    ORDER BY created_at DESC LIMIT ?
                    """,
                    (f"%{destination}%", limit),
                )
            rows = await cursor.fetchall()
        return [
            {
                "title": r[0],
                "content": r[1],
                "source": r[2],
                "tags": r[3].split(",") if r[3] else [],
            }
            for r in rows
        ]

    async def insert_travel_content(
        self, destination: str, title: str, content: str, source: str, tags: str = ""
    ):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                """
                INSERT INTO travel_content (destination, title, content, source, tags)
                VALUES (?, ?, ?, ?, ?)
                """,
                (destination, title, content, source, tags),
            )
            await db.commit()

    # ── 对比记忆 ──

    async def save_comparison(
        self, device_id: str, comp_id: str, destinations: list[str],
        purpose: str = "", with_who: str = "", budget_level: str = "",
        travel_days: int = 3, chosen: str = "", summary: str = "",
        result_data: str = ""
    ):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                """
                INSERT INTO comparison_history (id, device_id, destinations, purpose, with_who, budget_level, travel_days, chosen, summary, result_data)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    chosen = excluded.chosen,
                    summary = excluded.summary,
                    result_data = excluded.result_data
                """,
                (comp_id, device_id, json.dumps(destinations), purpose, with_who, budget_level, travel_days, chosen, summary, result_data),
            )
            await db.commit()

    async def get_comparison_history(self, device_id: str, limit: int = 10) -> list[dict]:
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute(
                """
                SELECT id, destinations, purpose, with_who, budget_level, travel_days, chosen, summary, created_at
                FROM comparison_history
                WHERE device_id = ?
                ORDER BY created_at DESC LIMIT ?
                """,
                (device_id, limit),
            )
            rows = await cursor.fetchall()
        return [
            {
                "id": r[0],
                "destinations": json.loads(r[1]) if r[1] else [],
                "purpose": r[2] or "",
                "with_who": r[3] or "",
                "budget_level": r[4] or "",
                "travel_days": r[5] or 3,
                "chosen": r[6] or "",
                "summary": r[7] or "",
                "created_at": r[8] or "",
            }
            for r in rows
        ]

    async def delete_comparison(self, comp_id: str):
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "DELETE FROM comparison_history WHERE id = ?",
                (comp_id,),
            )
            await db.commit()

    async def get_comparison_by_id(self, comp_id: str) -> Optional[dict]:
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute(
                """
                SELECT id, destinations, purpose, with_who, budget_level, travel_days, chosen, summary, result_data, created_at
                FROM comparison_history WHERE id = ?
                """,
                (comp_id,),
            )
            r = await cursor.fetchone()
        if not r:
            return None
        return {
            "id": r[0],
            "destinations": json.loads(r[1]) if r[1] else [],
            "purpose": r[2] or "",
            "with_who": r[3] or "",
            "budget_level": r[4] or "",
            "travel_days": r[5] or 3,
            "chosen": r[6] or "",
            "summary": r[7] or "",
            "result_data": r[8] or "",
            "created_at": r[9] or "",
        }


    # ── 聊天历史（多对话支持） ──

    async def save_chat_conversation(
        self, device_id: str, conversation_id: str, messages: list[dict]
    ):
        """保存整条对话（先清空该对话旧记录，再写入最新）"""
        async with aiosqlite.connect(self.db_path) as db:
            # 清空该对话旧记录
            await db.execute(
                "DELETE FROM chat_history WHERE device_id = ? AND conversation_id = ?",
                (device_id, conversation_id),
            )
            # 批量写入
            for msg in messages:
                await db.execute(
                    """INSERT INTO chat_history (device_id, conversation_id, role, content)
                       VALUES (?, ?, ?, ?)""",
                    (device_id, conversation_id, msg.get("role", ""), msg.get("content", "")),
                )
            # 更新 conversations 表
            title = ""
            for msg in messages:
                if msg.get("role") == "user" and msg.get("content"):
                    title = msg["content"][:30]
                    break
            await db.execute(
                """INSERT OR REPLACE INTO conversations (id, device_id, title, message_count, updated_at)
                   VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)""",
                (conversation_id, device_id, title, len(messages)),
            )
            await db.commit()

    async def get_conversations(self, device_id: str, limit: int = 20) -> list[dict]:
        """读取该设备的所有对话列表"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute(
                """SELECT id, title, message_count, created_at, updated_at
                   FROM conversations WHERE device_id = ?
                   ORDER BY updated_at DESC LIMIT ?""",
                (device_id, limit),
            )
            rows = await cursor.fetchall()
        return [
            {"id": r[0], "title": r[1], "message_count": r[2], "created_at": r[3], "updated_at": r[4]}
            for r in rows
        ]

    async def get_conversation_messages(self, conversation_id: str) -> list[dict]:
        """读取某条对话的全部消息"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute(
                """SELECT role, content, created_at
                   FROM chat_history WHERE conversation_id = ?
                   ORDER BY created_at ASC""",
                (conversation_id,),
            )
            rows = await cursor.fetchall()
        return [{"role": r[0], "content": r[1], "created_at": r[2]} for r in rows]

    async def delete_conversation(self, conversation_id: str):
        """删除对话及其所有消息"""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("DELETE FROM chat_history WHERE conversation_id = ?", (conversation_id,))
            await db.execute("DELETE FROM conversations WHERE id = ?", (conversation_id,))
            await db.commit()

    async def get_all_conversations_count(self) -> int:
        """全局对话数（用于管理后台）"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute("SELECT COUNT(*) FROM conversations")
            row = await cursor.fetchone()
            return row[0] if row else 0

    # ── 旧的单对话方法（兼容，已废弃） ──

    async def save_chat_batch(self, device_id: str, messages: list[dict]):
        """批量保存聊天记录（先清空该设备旧记录，再写入最新）"""
        async with aiosqlite.connect(self.db_path) as db:
            # 清空旧记录
            await db.execute(
                "DELETE FROM chat_history WHERE device_id = ?",
                (device_id,),
            )
            # 批量写入
            for msg in messages:
                await db.execute(
                    """
                    INSERT INTO chat_history (device_id, role, content)
                    VALUES (?, ?, ?)
                    """,
                    (device_id, msg.get("role", ""), msg.get("content", "")),
                )
            await db.commit()

    async def get_chat_history(self, device_id: str) -> list[dict]:
        """读取该设备的全部聊天记录"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute(
                """
                SELECT role, content, created_at
                FROM chat_history
                WHERE device_id = ?
                ORDER BY created_at ASC
                """,
                (device_id,),
            )
            rows = await cursor.fetchall()
        return [
            {"role": r[0], "content": r[1], "created_at": r[2]}
            for r in rows
        ]

    async def delete_chat_history(self, device_id: str):
        """删除该设备的聊天记录"""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "DELETE FROM chat_history WHERE device_id = ?",
                (device_id,),
            )
            await db.commit()

    async def get_chat_history_count(self) -> int:
        """全局聊天记录数（用于管理后台统计）"""
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute("SELECT COUNT(*) FROM chat_history")
            row = await cursor.fetchone()
            return row[0] if row else 0

    # ── 响应缓存（相同问题加速） ──

    @staticmethod
    def _hash_messages(messages: list[dict]) -> str:
        """对消息列表取 MD5 哈希作为缓存键"""
        raw = json.dumps(messages, sort_keys=True, ensure_ascii=False)
        return hashlib.md5(raw.encode("utf-8")).hexdigest()

    async def get_cached_response(self, messages: list[dict]) -> Optional[str]:
        """查缓存，命中返回缓存的响应文本"""
        h = self._hash_messages(messages)
        async with aiosqlite.connect(self.db_path) as db:
            cursor = await db.execute(
                """SELECT response FROM response_cache
                   WHERE messages_hash = ? ORDER BY created_at DESC LIMIT 1""",
                (h,),
            )
            row = await cursor.fetchone()
        return row[0] if row else None

    async def set_cached_response(
        self, messages: list[dict], response: str, endpoint: str = "chat"
    ):
        """写入缓存"""
        h = self._hash_messages(messages)
        key = f"{endpoint}:{h}"
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                """INSERT OR REPLACE INTO response_cache (cache_key, messages_hash, response, endpoint)
                   VALUES (?, ?, ?, ?)""",
                (key, h, response, endpoint),
            )
            await db.commit()

    async def clear_expired_cache(self, max_age_hours: int = 24):
        """清理过期缓存（默认保留 24 小时）"""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                """DELETE FROM response_cache
                   WHERE created_at < datetime('now', ?)""",
                (f"-{max_age_hours} hours",),
            )
            await db.commit()


cache_db = CacheDB(settings.database_path)
