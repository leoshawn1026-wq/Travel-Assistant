"""目的地对比服务 - 带记忆、评分、多维度深度对比 + 流式支持"""
import json
import re
import uuid
import asyncio
from datetime import datetime
from typing import AsyncGenerator
from app.services.deepseek import deepseek_service
from app.services.cache_db import cache_db
from app.models.schemas import (
    CompareRequest, CompareResponseData, CompareTable, CompareRow,
)


def _extract_json(text: str) -> str:
    """从可能包含 markdown 代码块的文本中提取 JSON 部分"""
    if not text:
        return ""
    # 尝试直接解析
    text = text.strip()
    try:
        json.loads(text)
        return text  # 已经是合法 JSON
    except json.JSONDecodeError:
        pass
    # 尝试提取 ```json ... ``` 块
    m = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', text, re.DOTALL)
    if m:
        candidate = m.group(1).strip()
        try:
            json.loads(candidate)
            return candidate
        except json.JSONDecodeError:
            pass
    # 尝试找到第一个 { 到最后一个 } 的部分
    start = text.find('{')
    end = text.rfind('}')
    if start != -1 and end > start:
        candidate = text[start:end + 1]
        try:
            json.loads(candidate)
            return candidate
        except json.JSONDecodeError:
            pass
    return text  # 实在提取不出，返回原文本


PURPOSE_LABELS = {
    "leisure": "休闲度假",
    "culture": "文化历史",
    "food": "美食之旅",
    "adventure": "探险户外",
    "honeymoon": "蜜月浪漫",
    "family": "亲子家庭",
    "shopping": "购物血拼",
}

WITH_WHO_LABELS = {
    "alone": "独自旅行",
    "couple": "情侣/伴侣",
    "family": "带孩子/家人",
    "friends": "和朋友一起",
}

STYLE_LABELS = {
    "free": "自由行",
    "guided": "跟团游",
    "half": "半自由行",
}



class CompareService:
    # ── 共享辅助方法：维度构建（compare 和 compare_stream 共用） ──

    def _build_dimensions(self, req: CompareRequest) -> list[str]:
        """根据用户画像构建对比维度（精简版 ~12 个）"""
        # 始终保留的核心维度
        dims = [
            "预算费用（人均预估）",
            "最佳旅行季节/气候",
            "交通便利度",
        ]

        # 根据旅行目的加 2-3 个重点维度
        purpose_dims = {
            "food": ["特色美食体验", "夜市/小吃丰富度"],
            "honeymoon": ["浪漫氛围", "酒店品质"],
            "family": ["亲子友好度", "安全指数"],
            "culture": ["历史文化底蕴", "博物馆/古迹"],
            "adventure": ["户外活动丰富度", "自然风光"],
            "shopping": ["购物体验", "特色商品"],
            "leisure": ["气候舒适度", "放松指数"],
        }
        dims.extend(purpose_dims.get(req.purpose, ["当地体验深度"]))

        # 根据同行人加 1 个维度
        if req.with_who == "alone":
            dims.append("独自旅行友好度")
        elif req.with_who == "couple":
            dims.append("情侣友好度")
        elif req.with_who == "family":
            dims.append("家庭设施完备度")

        # 补充 3 个实用维度
        dims.extend(["住宿选择", "语言沟通便利度", "景点门票总花费"])

        if req.with_pet:
            dims.append("宠物友好度")

        # 去重
        seen = set()
        return [d for d in dims if not (d in seen or seen.add(d))]

    def _format_dimensions(self, all_dims: list[str]) -> str:
        """将维度列表格式化为 prompt 中的 JSON 模板"""
        NL = chr(10)
        return NL.join(
            f'    {{"dimension": "{d}", "values": ["目的地1的值", "目的地2的值", ...], "detail": "详细分析文字"}}'
            for d in all_dims
        )

    def _build_user_prompt(self, req: CompareRequest, dest_str: str, memory_context: str = "") -> str:
        """构建用户提问 prompt（compare 和 compare_stream 共用）"""
        purpose_label = PURPOSE_LABELS.get(req.purpose, req.purpose)
        who_label = WITH_WHO_LABELS.get(req.with_who, req.with_who)
        style_label = STYLE_LABELS.get(req.travel_style, req.travel_style)
        budget_desc = {"low": "经济省钱", "medium": "适中", "high": "高端舒适"}.get(req.budget_level, req.budget_level)

        NL = chr(10)
        prompt = (
            f"对比以下目的地：{dest_str}{NL}"
            f"计划天数：{req.travel_days}天{NL}"
            f"预算水平：{budget_desc}{NL}"
            f"旅行目的：{purpose_label}{NL}"
            f"和谁去：{who_label}{NL}"
            f"旅行风格：{style_label}{NL}"
        )
        if req.with_pet:
            prompt += "带宠物：是（非常重要，所有推荐必须宠物友好）" + NL
        if req.preferred_season:
            prompt += f"偏好季节：{req.preferred_season}" + NL
        if req.departure_date:
            prompt += f"出发日期：{req.departure_date}" + NL
        if req.special_needs:
            prompt += f"特殊需求：{req.special_needs}" + NL
        if memory_context:
            prompt += NL + memory_context
        return prompt
    async def _build_memory_context(self, req: CompareRequest) -> str:
        """查询历史对比构造记忆上下文"""
        if not req.device_id:
            return ""
        history = await cache_db.get_comparison_history(req.device_id, limit=5)
        if not history:
            return ""
        lines = ["你的历史对比记录："]
        for h in history:
            dests = "、".join(h["destinations"])
            chosen = f"，上次选了「{h['chosen']}」" if h.get("chosen") else ""
            lines.append(f"- 对比：{dests} | 目的：{h.get('purpose','')} | 预算：{h.get('budget_level','')}{chosen}")
        return chr(10).join(lines)
    async def compare(self, req: CompareRequest) -> CompareResponseData:
        dest_str = "、".join(req.destinations)
        purpose_label = PURPOSE_LABELS.get(req.purpose, req.purpose)
        who_label = WITH_WHO_LABELS.get(req.with_who, req.with_who)
        style_label = STYLE_LABELS.get(req.travel_style, req.travel_style)

        # 1. 查询历史对比，构建记忆上下文
        memory_context = ""
        if req.device_id:
            memory_context = await self._build_memory_context(req)

        # 2. 构建 Prompt
        budget_desc = {"low": "经济省钱", "medium": "适中", "high": "高端舒适"}.get(req.budget_level, req.budget_level)

        all_dims = self._build_dimensions(req)
        dims_list = "\n".join(f'    {{"dimension": "{d}", "values": ["目的地1的值", "目的地2的值", ...], "detail": "详细分析文字"}}' for d in all_dims)

        system_prompt = f"""你是旅行规划师，擅长多维度对比分析。

根据用户画像生成 JSON 对比数据，rows 包含以下维度：
{{
  "rows": [
{dims_list}
  ],
  "recommendation": "综合推荐，200字以内，结合用户画像给出理由",
  "verdict": "一句话结论",
  "scores": [每个目的地 overall 评分(5分制) + details]
}}

要求：
- 评分用5分制，values 长度与目的地数量一致
- 每个 row 必须包含 detail 字段，30-80字具体分析
- {"如果用户带宠物，必须包含「宠物友好度」维度\n" if req.with_pet else ""}
- 推荐理由结合用户的具体画像（预算、同行人、目的、是否带宠物）"""


        user_prompt = (
            f"对比以下目的地：{dest_str}\n"
            f"计划天数：{req.travel_days}天\n"
            f"预算水平：{budget_desc}\n"
            f"旅行目的：{purpose_label}\n"
            f"和谁去：{who_label}\n"
            f"旅行风格：{style_label}\n"
        )
        if req.with_pet:
            user_prompt += f"带宠物：是（非常重要，所有推荐必须宠物友好）\n"
        if req.preferred_season:
            user_prompt += f"偏好季节：{req.preferred_season}\n"
        if req.departure_date:
            user_prompt += f"出发日期：{req.departure_date}\n"
        if req.special_needs:
            user_prompt += f"特殊需求：{req.special_needs}\n"
        if memory_context:
            user_prompt += f"\n{memory_context}"

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        result = await deepseek_service.chat(messages, temperature=0.5)
        parsed = self._parse_response(result["content"], req)

        headers = ["维度"] + req.destinations
        table = CompareTable(headers=headers, rows=parsed["rows"])

        # 3. 获取实时天气
        from app.services.amap import amap_service
        try:
            weather_data = await amap_service.get_weather_batch(req.destinations)
            weather_list = []
            for city in req.destinations:
                w = weather_data.get(city, {})
                if w.get("success"):
                    weather_list.append({
                        "city": city,
                        "weather": w.get("weather", ""),
                        "temperature": w.get("temperature", ""),
                        "wind": w.get("wind", ""),
                        "humidity": w.get("humidity", ""),
                    })
        except Exception:
            weather_list = []

        # save history with full result data for detail view
        if req.device_id:
            comp_id = uuid.uuid4().hex[:12]
            # 将 Pydantic 对象转 dict 再序列化
            parsed_for_db = {
                k: v if not isinstance(v, list) else [
                    item.model_dump() if hasattr(item, 'model_dump') else item
                    for item in v
                ]
                for k, v in parsed.items()
            }
            result_data = json.dumps(parsed_for_db, ensure_ascii=False)
            await cache_db.save_comparison(
                device_id=req.device_id,
                comp_id=comp_id,
                destinations=req.destinations,
                purpose=req.purpose,
                with_who=req.with_who,
                budget_level=req.budget_level,
                travel_days=req.travel_days,
                summary=parsed.get("recommendation", "")[:200],
                result_data=result_data,
            )

        return CompareResponseData(
            table=table,
            recommendation=parsed.get("recommendation", ""),
            verdict=parsed.get("verdict", ""),
            scores=parsed.get("scores"),
            weather=weather_list,
        )

    async def compare_stream(
        self, req: CompareRequest
    ) -> AsyncGenerator[dict, None]:
        """流式对比 — 逐维度产出 SSE 事件"""
        dest_str = "、".join(req.destinations)
        purpose_label = PURPOSE_LABELS.get(req.purpose, req.purpose)
        who_label = WITH_WHO_LABELS.get(req.with_who, req.with_who)
        style_label = STYLE_LABELS.get(req.travel_style, req.travel_style)

        yield {"type": "status", "text": "正在分析目的地数据..."}
        await asyncio.sleep(0.1)

        memory_context = ""
        if req.device_id:
            memory_context = await self._build_memory_context(req)

        budget_desc = {"low": "经济省钱", "medium": "适中", "high": "高端舒适"}.get(req.budget_level, req.budget_level)

        all_dims = self._build_dimensions(req)
        dims_list = "\n".join(f'    {{"dimension": "{d}", "values": ["目的地1的值", "目的地2的值", ...], "detail": "详细分析文字"}}' for d in all_dims)

        system_prompt = f"""你是旅行规划师，擅长多维度对比分析。

根据用户画像生成 JSON 对比数据，rows 包含以下所有维度：
{{
  "rows": [
{dims_list}
  ],
  "recommendation": "综合推荐，200字以内，结合用户画像给出理由",
  "verdict": "一句话结论",
  "scores": [每个目的地 overall 评分(5分制) + details]
}}

要求：
- 评分用5分制，values 长度与目的地数量一致
- 每个 row 必须包含 detail 字段，30-80字分析
- {"如果用户带宠物，必须包含「宠物友好度」维度\n" if req.with_pet else ""}
- 推荐理由结合用户的具体画像（预算、同行人、目的、是否带宠物）"""

        user_prompt = (
            f"对比以下目的地：{dest_str}\n"
            f"计划天数：{req.travel_days}天\n"
            f"预算水平：{budget_desc}\n"
            f"旅行目的：{purpose_label}\n"
            f"和谁去：{who_label}\n"
            f"旅行风格：{style_label}\n"
        )
        if req.with_pet:
            user_prompt += f"带宠物：是（非常重要，所有推荐必须宠物友好）\n"
        if req.preferred_season:
            user_prompt += f"偏好季节：{req.preferred_season}\n"
        if req.departure_date:
            user_prompt += f"出发日期：{req.departure_date}\n"
        if req.special_needs:
            user_prompt += f"特殊需求：{req.special_needs}\n"
        if memory_context:
            user_prompt += f"\n{memory_context}"

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        yield {"type": "status", "text": "AI 正在多维度对比分析..."}
        await asyncio.sleep(0.1)

        buffer = ""
        previous_rows = 0
        last_valid_data = {}  # 跟踪最新一次成功解析的完整数据（用于存历史兜底）

        async for token in deepseek_service.chat_stream(messages, temperature=0.5):
            if token == "__DONE__":
                break
            buffer += token
            clean = _extract_json(buffer)
            if clean:
                try:
                    data = json.loads(clean)
                    if data.get("rows"):
                        last_valid_data = data
                    rows = data.get("rows", [])
                    curr = len(rows)
                    if curr > previous_rows:
                        for i in range(previous_rows, curr):
                            row = rows[i]
                            yield {"type": "row", "data": {
                                "dimension": row.get("dimension", ""),
                                "values": row.get("values", []),
                            }}
                        previous_rows = curr
                except (json.JSONDecodeError, TypeError, ValueError):
                    pass

        # 一次性解析 complete 数据，用于发事件和存历史（避免重复解析）
        complete_data = None
        try:
            clean = _extract_json(buffer)
            data = json.loads(clean) if clean else {}
            if data.get("rows"):
                complete_data = {
                    "rows": data.get("rows", []),
                    "recommendation": data.get("recommendation", ""),
                    "verdict": data.get("verdict", ""),
                    "scores": data.get("scores", []),
                }
        except Exception:
            pass

        if not complete_data or not complete_data.get("rows"):
            # buffer 解析失败，用 streaming 途中缓存的数据
            if last_valid_data and last_valid_data.get("rows"):
                complete_data = {
                    "rows": last_valid_data.get("rows", []),
                    "recommendation": last_valid_data.get("recommendation", ""),
                    "verdict": last_valid_data.get("verdict", ""),
                    "scores": last_valid_data.get("scores", []),
                }
            else:
                complete_data = self._fallback_table(req)

        yield {"type": "complete", "data": complete_data}

        # 获取实时天气
        from app.services.amap import amap_service
        try:
            weather_data = await amap_service.get_weather_batch(req.destinations)
            weather_list = []
            for city in req.destinations:
                w = weather_data.get(city, {})
                if w.get("success"):
                    weather_list.append({
                        "city": city,
                        "weather": w.get("weather", ""),
                        "temperature": w.get("temperature", ""),
                        "wind": w.get("wind", ""),
                        "humidity": w.get("humidity", ""),
                    })
            if weather_list:
                yield {"type": "weather", "data": weather_list}
        except Exception:
            pass

        # save history with full result data for detail view（直接复用已解析的 complete_data）
        if req.device_id and complete_data and complete_data.get("rows"):
            comp_id = uuid.uuid4().hex[:12]
            try:
                result_data = json.dumps(complete_data, ensure_ascii=False)
                summary = complete_data.get("recommendation", "")[:200]
            except Exception:
                result_data = ""
                summary = ""
            await cache_db.save_comparison(
                device_id=req.device_id,
                comp_id=comp_id,
                destinations=req.destinations,
                purpose=req.purpose,
                with_who=req.with_who,
                budget_level=req.budget_level,
                travel_days=req.travel_days,
                summary=summary,
                result_data=result_data,
            )

    def _parse_response(self, content: str, req: CompareRequest) -> dict:
        try:
            clean = _extract_json(content)
            data = json.loads(clean) if clean else {}
            rows_raw = data.get("rows", [])
            if not rows_raw:
                fb = self._fallback_table(req)
                return {
                    "rows": [CompareRow(**r) for r in fb["rows"]],
                    "recommendation": fb["recommendation"],
                    "verdict": fb["verdict"],
                    "scores": fb["scores"],
                }
            rows = [
                CompareRow(dimension=r["dimension"], values=r["values"])
                for r in rows_raw
                if "dimension" in r and "values" in r
            ]
            if not rows:
                fb = self._fallback_table(req)
                return {
                    "rows": [CompareRow(**r) for r in fb["rows"]],
                    "recommendation": fb["recommendation"],
                    "verdict": fb["verdict"],
                    "scores": fb["scores"],
                }
            return {
                "rows": rows,
                "recommendation": data.get("recommendation", ""),
                "verdict": data.get("verdict", ""),
                "scores": data.get("scores"),
            }
        except (json.JSONDecodeError, KeyError):
            fb = self._fallback_table(req)
            return {
                "rows": [CompareRow(**r) for r in fb["rows"]],
                "recommendation": fb["recommendation"],
                "verdict": fb["verdict"],
                "scores": fb["scores"],
            }

    def _fallback_table(self, req: CompareRequest) -> dict:
        n = len(req.destinations)
        # 返回纯 dict（不包含 Pydantic 对象），避免 json.dumps 序列化问题
        rows = []
        for key in req.criteria:
            label = {
                "budget": "预算", "weather": "最佳季节/天气",
                "attractions": "必去景点", "transport": "交通便利度",
                "food": "特色美食",
            }.get(key, key)
            if key == "budget":
                values = [f"约{1200 + i * 100}元/{req.travel_days}天" for i in range(n)]
            elif key == "weather":
                values = ["春秋最佳"] * n
            elif key == "attractions":
                values = [f"{d}热门景点" for d in req.destinations]
            elif key == "transport":
                values = ["★★★★☆"] * n
            elif key == "food":
                values = [f"{d}特色美食" for d in req.destinations]
            else:
                values = ["待补充"] * n
            rows.append({"dimension": label, "values": values})

        scores = [
            {"destination": d, "overall": 4.0, "details": {"性价比": 4.0, "景点丰富度": 4.0}}
            for d in req.destinations
        ]

        return {
            "rows": rows,
            "recommendation": f"建议根据个人偏好选择，{req.destinations[0]}和{req.destinations[1]}各有特色。",
            "verdict": f"推荐{req.destinations[0]}或{req.destinations[1]}，具体取决于你的偏好。",
            "scores": scores,
        }


compare_service = CompareService()
