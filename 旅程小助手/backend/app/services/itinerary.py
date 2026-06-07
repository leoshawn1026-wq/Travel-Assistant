"""多日行程生成服务 - 高德 POI + DeepSeek 结构化输出 + 流式支持"""
import json
import re
import asyncio
from datetime import datetime, timedelta
from typing import Optional, AsyncGenerator
from app.services.deepseek import deepseek_service
from app.services.amap import amap_service
from app.models.schemas import ItineraryRequest, ItineraryResponseData, ItineraryItem, DayPlan, Accommodation


def _extract_json(text: str) -> str:
    """从可能包含额外文本的内容中提取 JSON 部分"""
    if not text:
        return ""
    text = text.strip()
    try:
        json.loads(text)
        return text
    except json.JSONDecodeError:
        pass
    m = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', text, re.DOTALL)
    if m:
        candidate = m.group(1).strip()
        try:
            json.loads(candidate)
            return candidate
        except json.JSONDecodeError:
            pass
    start = text.find('{')
    end = text.rfind('}')
    if start != -1 and end > start:
        candidate = text[start:end + 1]
        try:
            json.loads(candidate)
            return candidate
        except json.JSONDecodeError:
            pass
    return text


class ItineraryService:
    async def generate(self, req: ItineraryRequest) -> ItineraryResponseData:
        # 1. 并发获取 POI 参考数据
        attractions_task = amap_service.search_poi(keywords="景点", city=req.destination, limit=5)
        foods_task = amap_service.search_poi(keywords="美食", city=req.destination, limit=5)
        attractions, foods = await asyncio.gather(attractions_task, foods_task)

        poi_context = "景点参考：\n"
        for p in attractions:
            poi_context += f"- {p.name}（{p.address}）\n"
        poi_context += "\n美食参考：\n"
        for p in foods:
            poi_context += f"- {p.name}（{p.address}）\n"

        pace_map = {
            "relaxed": "悠闲，每天3-4个点位",
            "moderate": "适中，每天5-6个点位",
            "intense": "紧凑，每天7-8个点位",
        }

        if req.days > 1:
            return await self._generate_multi_day(req, poi_context, pace_map)
        else:
            return await self._generate_single_day(req, poi_context, pace_map)

    async def generate_stream(
        self, req: ItineraryRequest
    ) -> AsyncGenerator[dict, None]:
        """流式生成行程 — 产出 SSE 事件 dict

        Yields:
            {"type": "status", "text": "..."}
            {"type": "item", "data": {day_plan_dict}}  ← 每新解析出一个 day 就 yield
            {"type": "complete", "data": {完整行程}}     ← 最终完整结果
        """
        yield {"type": "status", "text": "正在搜索景点和美食数据..."}
        await asyncio.sleep(0.1)

        # 1. 并发获取 POI 参考数据
        try:
            attractions_task = amap_service.search_poi(keywords="景点", city=req.destination, limit=5)
            foods_task = amap_service.search_poi(keywords="美食", city=req.destination, limit=5)
            attractions, foods = await asyncio.gather(attractions_task, foods_task)
        except Exception:
            attractions, foods = [], []

        poi_context = "景点参考：\n"
        for p in attractions:
            poi_context += f"- {p.name}（{p.address}）\n"
        poi_context += "\n美食参考：\n"
        for p in foods:
            poi_context += f"- {p.name}（{p.address}）\n"

        yield {"type": "status", "text": f"正在为 {req.destination} 规划行程..."}
        await asyncio.sleep(0.1)

        # 2. 构建 prompt
        pace_map = {
            "relaxed": "悠闲，每天3-4个点位",
            "moderate": "适中，每天5-6个点位",
            "intense": "紧凑，每天7-8个点位",
        }

        pet_hint = ""
        if req.with_pet:
            pet_hint = "【重要】用户会带宠物出行！所有景点、餐厅、活动必须选择宠物允许进入的场所。推荐宠物友好的公园、露天餐厅、宠物乐园等。\n"

        if req.days > 1:
            start_date = datetime.strptime(req.date, "%Y-%m-%d")
            date_range = f"{req.date} 至 {(start_date + timedelta(days=req.days - 1)).strftime('%Y-%m-%d')}"

            system_prompt = f"""你是专业旅行规划师，同时也是一位本地通。
根据POI参考和用户偏好，生成{req.days}天完整行程。
必须严格区分「游客热门」和「本地人私藏」！

必须返回严格JSON格式，按天组织：
{{
  "title": "行程总标题",
  "days": [
    {{
      "day": 1,
      "summary": "当日总结",
      "items": [
        {{
          "time": "09:00",
          "name": "地点名称",
          "type": "attraction|food|transport|rest|local_food|local_spot",
          "address": "地址",
          "duration_minutes": 90,
          "tips": "实用小贴士",
          "is_local": true,
          "local_tip": "本地人才知道的隐藏好店"
        }}
      ],
      "accommodation": {{
        "name": "酒店/民宿名称",
        "area": "所在区域",
        "price_range": "价位区间如200-400元",
        "reason": "为什么推荐住这里",
        "tips": "入住提示"
      }}
    }}
  ],
  "summary": "整个行程的总结，100字以内"
}}

{"\n【重要】用户会带宠物出行！所有推荐必须宠物友好！\n" if req.with_pet else ""}

规则：
- is_local=true 表示本地人推荐（local_food 或 local_spot 类型）
- is_local=false 表示普通游客景点/餐厅
- 每天至少有一顿本地人推荐的餐饮（local_food）
- 住宿推荐要符合当天行程路线，推荐性价比高的区域
- 最后一天不需要 accommodation

请先完整输出JSON中title字段，然后逐天输出days数组的每个元素。"""

            user_prompt = (
                f"目的地：{req.destination}\n"
                f"行程日期：{date_range}\n"
                f"天数：{req.days}天\n"
                f"偏好：{', '.join(req.preferences) if req.preferences else '无特殊偏好'}\n"
                f"节奏：{pace_map.get(req.pace, pace_map['moderate'])}\n"
                f"特别要求：请多推荐本地人爱去的餐厅和地点！\n"
                f"{'【重要】带宠物出行，请推荐宠物友好的景点、餐厅和住宿！' if req.with_pet else ''}\n\n"
                f"{poi_context}"
            )
        else:
            system_prompt = f"""你是专业旅行规划师，同时也是一位本地通。
根据POI参考和用户偏好，生成单日行程。
必须严格区分「游客热门」和「本地人私藏」！

必须返回严格JSON格式：
{{
  "title": "行程标题",
  "items": [
    {{
      "time": "09:00",
      "name": "地点名称",
      "type": "attraction|food|transport|rest|local_food|local_spot",
      "address": "地址",
      "duration_minutes": 90,
      "tips": "实用小贴士",
      "is_local": true,
      "local_tip": "本地人才知道的隐藏好店/小众景点，建议..."
    }}
  ],
  "summary": "行程总结，80字以内"
}}

规则：
- type=local_food：本地人常去的馆子/小吃/苍蝇馆子
- type=local_spot：本地人爱去的小众景点/公园/老街
- type=food：知名餐厅/游客也会去的美食街
- type=attraction：知名景点
- 至少一半的餐饮推荐应该是 local_food（本地人推荐）
- 时间安排合理，包含午餐晚餐，考虑交通衔接
{pet_hint}

请先输出title字段，然后逐条输出items数组。"""

            user_prompt = (
                f"目的地：{req.destination}\n"
                f"日期：{req.date}\n"
                f"偏好：{', '.join(req.preferences) if req.preferences else '无特殊偏好'}\n"
                f"节奏：{pace_map.get(req.pace, pace_map['moderate'])}\n"
                f"特别要求：请多推荐本地人爱去的餐厅和地点！\n"
                f"{'【重要】带宠物出行，请推荐宠物友好场所！' if req.with_pet else ''}\n\n"
                f"{poi_context}"
            )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        yield {"type": "status", "text": "AI 正在生成行程内容..."}
        await asyncio.sleep(0.1)

        # 3. 流式调用 DeepSeek + 增量 JSON 解析
        buffer = ""
        previous_items = 0
        previous_days = 0
        is_multi_day = req.days > 1

        async for token in deepseek_service.chat_stream(messages, temperature=0.6):
            if token == "__DONE__":
                break
            buffer += token

            try:
                data = json.loads(buffer)

                if is_multi_day:
                    days = data.get("days", [])
                    curr = len(days)
                    if curr > previous_days:
                        for i in range(previous_days, curr):
                            day_data = days[i]
                            day_plan = self._parse_day_plan(day_data, req, i + 1)
                            yield {"type": "day", "data": day_plan}
                        previous_days = curr
                else:
                    # 单日：items 逐条显示
                    items = data.get("items", [])
                    curr = len(items)
                    if curr > previous_items:
                        new_items = [self._parse_item(it) for it in items[previous_items:curr]]
                        yield {"type": "items", "data": new_items}
                        previous_items = curr
            except (json.JSONDecodeError, TypeError, ValueError):
                pass

        # 4. 最终完整结果（用 _extract_json 避免 trailing text 导致解析失败）
        try:
            clean = _extract_json(buffer) if buffer else ""
            data = json.loads(clean) if clean else {}
            if is_multi_day:
                day_plans_raw = data.get("days", [])
                day_plans = [self._parse_day_plan(d, req, i + 1) for i, d in enumerate(day_plans_raw)]
                result = ItineraryResponseData(
                    destination=req.destination,
                    date=req.date,
                    days=req.days,
                    title=data.get("title", f"{req.destination}{req.days}日游"),
                    day_plans=day_plans,
                    summary=data.get("summary", ""),
                )
            else:
                items_raw = data.get("items", [])
                items = [self._parse_item(it) for it in items_raw]
                result = ItineraryResponseData(
                    destination=req.destination,
                    date=req.date,
                    days=1,
                    title=data.get("title", f"{req.destination}一日游"),
                    items=items,
                    summary=data.get("summary", ""),
                )
            yield {"type": "complete", "data": result.model_dump()}
        except Exception:
            yield {"type": "complete", "data": self._fallback_itinerary(req).model_dump()}

    def _parse_day_plan(self, day_data: dict, req: ItineraryRequest, day_num: int) -> dict:
        """解析单个 day_plan 为字典"""
        start_date = datetime.strptime(req.date, "%Y-%m-%d")
        day_date = (start_date + timedelta(days=day_num - 1)).strftime("%Y-%m-%d")
        items_raw = day_data.get("items", [])
        items = [self._parse_item(it) for it in items_raw]

        acc_raw = day_data.get("accommodation")
        accommodation = None
        if acc_raw and acc_raw.get("name"):
            accommodation = {
                "name": acc_raw["name"],
                "area": acc_raw.get("area", ""),
                "price_range": acc_raw.get("price_range", ""),
                "reason": acc_raw.get("reason", ""),
                "tips": acc_raw.get("tips", ""),
            }

        return {
            "day": day_num,
            "date": day_date,
            "title": day_data.get("title", f"第{day_num}天"),
            "items": items,
            "summary": day_data.get("summary", ""),
            "accommodation": accommodation,
        }

    def _parse_item(self, item: dict) -> dict:
        def s(v, default=""):
            return v if isinstance(v, str) and v else default
        return {
            "time": s(item.get("time"), "09:00"),
            "name": s(item.get("name")),
            "type": s(item.get("type"), "attraction"),
            "address": s(item.get("address")),
            "duration_minutes": item.get("duration_minutes") or 60,
            "tips": s(item.get("tips")),
            "is_local": bool(item.get("is_local", False)),
            "local_tip": s(item.get("local_tip")),
        }

    async def _generate_single_day(
        self, req: ItineraryRequest, poi_context: str, pace_map: dict
    ) -> ItineraryResponseData:
        pet_hint = ""
        if req.with_pet:
            pet_hint = "【重要】用户会带宠物出行！所有景点、餐厅、活动必须选择宠物允许进入的场所。推荐宠物友好的公园、露天餐厅、宠物乐园等。\n"

        system_prompt = f"""你是专业旅行规划师，同时也是一位本地通。
根据POI参考和用户偏好，生成单日行程。
必须严格区分「游客热门」和「本地人私藏」，推荐一定要包括本地人才知道的好去处！

必须返回严格JSON格式：
{
  "title": "行程标题",
  "items": [
    {
      "time": "09:00",
      "name": "地点名称",
      "type": "attraction|food|transport|rest|local_food|local_spot",
      "address": "地址",
      "duration_minutes": 90,
      "tips": "实用小贴士",
      "is_local": true,
      "local_tip": "本地人才知道的隐藏好店/小众景点，建议..."
    }
  ],
  "summary": "行程总结，80字以内"
}

规则：
- type=local_food：本地人常去的馆子/小吃/苍蝇馆子
- type=local_spot：本地人爱去的小众景点/公园/老街
- type=food：知名餐厅/游客也会去的美食街
- type=attraction：知名景点
- 至少一半的餐饮推荐应该是 local_food（本地人推荐）
- 时间安排合理，包含午餐晚餐，考虑交通衔接
{pet_hint}"""

        user_prompt = (
            f"目的地：{req.destination}\n"
            f"日期：{req.date}\n"
            f"偏好：{', '.join(req.preferences) if req.preferences else '无特殊偏好'}\n"
            f"节奏：{pace_map.get(req.pace, pace_map['moderate'])}\n"
            f"特别要求：请多推荐本地人爱去的餐厅和地点！\n"
            f"{'【重要】带宠物出行，请推荐宠物友好场所！' if req.with_pet else ''}\n\n"
            f"{poi_context}"
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        result = await deepseek_service.chat(messages, temperature=0.6)
        return self._parse_single_day(result["content"], req)

    async def _generate_multi_day(
        self, req: ItineraryRequest, poi_context: str, pace_map: dict
    ) -> ItineraryResponseData:
        start_date = datetime.strptime(req.date, "%Y-%m-%d")
        date_range = f"{req.date} 至 {(start_date + timedelta(days=req.days - 1)).strftime('%Y-%m-%d')}"

        system_prompt = f"""你是专业旅行规划师，同时也是一位本地通。
根据POI参考和用户偏好，生成{req.days}天完整行程。
必须严格区分「游客热门」和「本地人私藏」！

必须返回严格JSON格式，按天组织：
{{
  "title": "行程总标题",
  "days": [
    {{
      "day": 1,
      "summary": "当日总结",
      "items": [
        {{
          "time": "09:00",
          "name": "地点名称",
          "type": "attraction|food|transport|rest|local_food|local_spot",
          "address": "地址",
          "duration_minutes": 90,
          "tips": "实用小贴士",
          "is_local": true,
          "local_tip": "本地人才知道的隐藏好店"
        }}
      ],
      "accommodation": {{
        "name": "酒店/民宿名称",
        "area": "所在区域",
        "price_range": "价位区间如200-400元",
        "reason": "为什么推荐住这里",
        "tips": "入住提示"
      }}
    }}
  ],
  "summary": "整个行程的总结，100字以内"
}}

{"\n【重要】用户会带宠物出行！所有推荐必须宠物友好！\n" if req.with_pet else ""}

规则：
- is_local=true 表示本地人推荐（local_food 或 local_spot 类型）
- is_local=false 表示普通游客景点/餐厅
- 每天至少有一顿本地人推荐的餐饮（local_food）
- 住宿推荐要符合当天行程路线，推荐性价比高的区域
- 最后一天不需要 accommodation"""

        user_prompt = (
            f"目的地：{req.destination}\n"
            f"行程日期：{date_range}\n"
            f"天数：{req.days}天\n"
            f"偏好：{', '.join(req.preferences) if req.preferences else '无特殊偏好'}\n"
            f"节奏：{pace_map.get(req.pace, pace_map['moderate'])}\n"
            f"特别要求：请多推荐本地人爱去的餐厅和地点！\n"
            f"{'【重要】带宠物出行，请推荐宠物友好的景点、餐厅和住宿！' if req.with_pet else ''}\n\n"
            f"{poi_context}"
        )

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]

        result = await deepseek_service.chat(messages, temperature=0.6)
        return self._parse_multi_day(result["content"], req)

    def _parse_single_day(self, content: str, req: ItineraryRequest) -> ItineraryResponseData:
        try:
            clean = _extract_json(content)
            data = json.loads(clean) if clean else {}
            items_raw = data.get("items", [])
            if not items_raw:
                return self._fallback_itinerary(req)
            items = self._parse_items(items_raw)
            if not items:
                return self._fallback_itinerary(req)
            return ItineraryResponseData(
                destination=req.destination,
                date=req.date,
                days=1,
                title=data.get("title", f"{req.destination}一日游"),
                items=items,
                summary=data.get("summary", ""),
            )
        except (json.JSONDecodeError, KeyError):
            return self._fallback_itinerary(req)

    def _parse_multi_day(self, content: str, req: ItineraryRequest) -> ItineraryResponseData:
        try:
            clean = _extract_json(content)
            data = json.loads(clean) if clean else {}
            days_raw = data.get("days", [])
            if not days_raw:
                single_req = req.model_copy(update={"days": 1})
                return self._fallback_itinerary(single_req)

            start_date = datetime.strptime(req.date, "%Y-%m-%d")
            day_plans = []
            for day_data in days_raw:
                day_num = day_data.get("day", 0)
                day_date = (start_date + timedelta(days=day_num - 1)).strftime("%Y-%m-%d")
                items = self._parse_items(day_data.get("items", []))

                # 解析住宿推荐
                acc_raw = day_data.get("accommodation")
                accommodation = None
                if acc_raw and acc_raw.get("name"):
                    accommodation = Accommodation(
                        name=acc_raw["name"],
                        area=acc_raw.get("area", ""),
                        price_range=acc_raw.get("price_range", ""),
                        reason=acc_raw.get("reason", ""),
                        tips=acc_raw.get("tips", ""),
                    )

                if items:
                    day_plans.append(DayPlan(
                        day=day_num,
                        date=day_date,
                        title=day_data.get("title", f"第{day_num}天"),
                        items=items,
                        summary=day_data.get("summary", ""),
                        accommodation=accommodation,
                    ))

            if not day_plans:
                single_req = req.model_copy(update={"days": 1})
                return self._fallback_itinerary(single_req)

            return ItineraryResponseData(
                destination=req.destination,
                date=req.date,
                days=req.days,
                title=data.get("title", f"{req.destination}{req.days}日游"),
                day_plans=day_plans,
                summary=data.get("summary", ""),
            )
        except (json.JSONDecodeError, KeyError):
            single_req = req.model_copy(update={"days": 1})
            return self._fallback_itinerary(single_req)

    def _parse_items(self, items_raw: list) -> list[ItineraryItem]:
        items = []
        for item in items_raw:
            name = item.get("name", "")
            if not name:
                continue
            def s(v, default=""):
                return v if isinstance(v, str) and v else default
            items.append(ItineraryItem(
                time=s(item.get("time"), "09:00"),
                name=name,
                type=s(item.get("type"), "attraction"),
                address=s(item.get("address")),
                duration_minutes=item.get("duration_minutes") or 60,
                tips=s(item.get("tips")),
                is_local=bool(item.get("is_local", False)),
                local_tip=s(item.get("local_tip")),
            ))
        return items

    def _fallback_itinerary(self, req: ItineraryRequest) -> ItineraryResponseData:
        if req.days > 1:
            start = datetime.strptime(req.date, "%Y-%m-%d")
            day_plans = []
            placeholders = ["文化探索", "美食之旅", "自然风光", "休闲购物", "深度体验"]
            for d in range(req.days):
                day_date = (start + timedelta(days=d)).strftime("%Y-%m-%d")
                theme = placeholders[d % len(placeholders)]
                is_last = d == req.days - 1
                day_plans.append(DayPlan(
                    day=d + 1,
                    date=day_date,
                    title=f"第{d+1}天：{theme}",
                    items=[
                        ItineraryItem(time="09:00", name=f"{req.destination}热门景点", type="attraction", tips="建议早点出发"),
                        ItineraryItem(time="12:00", name="本地人推荐小吃店", type="local_food", is_local=True, local_tip="街坊邻居都爱去的老店"),
                        ItineraryItem(time="14:00", name="文化体验", type="attraction", tips="感受当地文化"),
                        ItineraryItem(time="18:00", name="本地特色夜市", type="local_food", is_local=True, local_tip="本地人最爱逛的夜市"),
                    ],
                    summary=f"第{d+1}天{theme}行程",
                    accommodation=None if is_last else Accommodation(
                        name=f"{req.destination}市中心酒店",
                        area="市中心",
                        price_range="200-400元",
                        reason="交通便利，靠近主要景点",
                        tips="建议提前预订",
                    ),
                ))
            return ItineraryResponseData(
                destination=req.destination,
                date=req.date,
                days=req.days,
                title=f"{req.destination}{req.days}日经典游",
                day_plans=day_plans,
                summary=f"{req.destination}{req.days}日行程已生成。",
            )

        return ItineraryResponseData(
            destination=req.destination,
            date=req.date,
            days=1,
            title=f"{req.destination}经典一日游",
            items=[
                ItineraryItem(time="09:00", name=f"{req.destination}市中心", type="attraction", tips="早上人少，适合拍照"),
                ItineraryItem(time="12:00", name="本地人推荐老字号", type="local_food", is_local=True, local_tip="开了30年的老店，本地人从小吃到大"),
                ItineraryItem(time="14:00", name="文化街区", type="attraction", tips="感受当地文化氛围"),
                ItineraryItem(time="18:00", name="本地特色美食街", type="local_food", is_local=True, local_tip="本地人下班后爱去的地方"),
            ],
            summary=f"{req.date}在{req.destination}的经典一日游行程。",
        )


itinerary_service = ItineraryService()
