"""DeepSeek API 服务 — 支持流式/非流式 + 连接池 + 消息裁剪 + 响应缓存 + 超时预检"""
import json
import asyncio
import time
import httpx
from httpx import HTTPError
from app.config import settings
from app.services.cache_db import cache_db

# 消息裁剪：最多保留最近 N 轮对话（1 轮 = 1 user + 1 assistant）
MAX_HISTORY_ROUNDS = 6
MAX_MESSAGES = MAX_HISTORY_ROUNDS * 2 + 1

# 流式超时：首 token 超过此秒数则降级非流式
FIRST_TOKEN_TIMEOUT = 8.0


def _trim_messages(messages: list[dict]) -> list[dict]:
    """裁剪消息历史，只保留最近 N 轮 + 第一条 system 消息"""
    if len(messages) <= MAX_MESSAGES:
        return messages
    system_messages = [m for m in messages if m.get("role") == "system"]
    non_system = [m for m in messages if m.get("role") != "system"]
    trimmed = non_system[-(MAX_HISTORY_ROUNDS * 2):]
    return system_messages + trimmed


class DeepSeekService:
    def __init__(self):
        self.api_key = settings.deepseek_api_key
        self.base_url = settings.deepseek_base_url
        self.model = settings.deepseek_model
        self._client = httpx.AsyncClient(
            timeout=httpx.Timeout(60.0, connect=8.0),
            limits=httpx.Limits(max_keepalive_connections=10, max_connections=20),
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
        )
        self._warmed_up = False

    async def warmup(self):
        """启动时预热连接池"""
        if self._warmed_up or not self.api_key:
            return
        self._warmed_up = True
        try:
            await self._client.get(f"{self.base_url}/v1/models", timeout=5.0)
        except Exception:
            pass

    async def chat(self, messages: list[dict], temperature: float = 0.7, max_tokens: int = 4096, skip_cache: bool = False) -> dict:
        """非流式对话 — 先查缓存，未命中再调 API"""
        if not self.api_key:
            return self._mock_response(messages)

        messages = _trim_messages(messages)

        # 1. 查缓存（行程生成跳过缓存，确保每次都重新生成）
        if not skip_cache:
            cached = await cache_db.get_cached_response(messages)
            if cached:
                return {"content": cached, "usage": {"cached": True, "prompt_tokens": 0, "completion_tokens": 0}}

        # 2. 调 API（自动重试 1 次）
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        last_error = None
        for attempt in range(2):
            try:
                resp = await self._client.post(
                    f"{self.base_url}/v1/chat/completions",
                    json=payload,
                )
                resp.raise_for_status()
                data = resp.json()
                choice = data["choices"][0]["message"]["content"]
                usage = data.get("usage", {})
                break  # 成功则跳出循环
            except HTTPError as e:
                last_error = e
                if attempt == 0:
                    await asyncio.sleep(1.5)  # 等待 1.5s 后重试
                else:
                    raise  # 两次都失败，向上抛出

        # 3. 写入缓存
        await cache_db.set_cached_response(messages, choice)

        return {"content": choice, "usage": usage}

    async def chat_stream(self, messages: list[dict], temperature: float = 0.7, max_tokens: int = 4096):
        """流式对话 — 查缓存/调 API + 逐 token 产出 + 首 Token 超时降级

        Yields:
            str: 每个 token 片段
        完成后 yield 终止标记 "__DONE__"
        """
        if not self.api_key:
            yield self._mock_response(messages)["content"]
            yield "__DONE__"
            return

        messages = _trim_messages(messages)

        # 查缓存（缓存只对完整消息列表有效，流式场景较少命中）
        cached = await cache_db.get_cached_response(messages)
        if cached:
            yield cached
            yield "__DONE__"
            return

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
            "stream": True,
        }

        # 首 token 超时降级：如果 8s 内没收到首个 token，回退到非流式
        first_token = True
        fallback_content = ""
        try:
            async with self._client.stream(
                "POST",
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                timeout=FIRST_TOKEN_TIMEOUT if first_token else None,
            ) as resp:
                resp.raise_for_status()
                async for line in resp.aiter_lines():
                    if not line.startswith("data: "):
                        continue
                    chunk = line[6:].strip()
                    if chunk == "[DONE]":
                        break
                    try:
                        data = json.loads(chunk)
                        delta = data.get("choices", [{}])[0].get("delta", {})
                        token = delta.get("content", "")
                        if token:
                            if first_token:
                                first_token = False
                            yield token
                    except json.JSONDecodeError:
                        continue
        except Exception:
            # 流式失败，回退到非流式
            try:
                fallback = await self.chat(messages, temperature)
                yield fallback["content"]
            except Exception:
                yield "抱歉，AI 服务暂时不可用，请稍后重试。"

        yield "__DONE__"

    async def close(self):
        await self._client.aclose()


deepseek_service = DeepSeekService()
