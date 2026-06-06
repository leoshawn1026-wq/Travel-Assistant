"""高德地图 Web 服务封装 - POI 搜索、天气、地理编码"""
import asyncio
import httpx
from app.config import settings
from app.models.schemas import PoiItem


class AmapService:
    BASE = "https://restapi.amap.com/v3"

    def __init__(self):
        self.api_key = settings.amap_api_key

    async def search_poi(
        self, keywords: str, city: str = "", types: str = "", limit: int = 10
    ) -> list[PoiItem]:
        """POI 关键词搜索"""
        if not self.api_key:
            return self._mock_pois(keywords, city)

        params = {
            "key": self.api_key,
            "keywords": keywords,
            "offset": limit,
            "page": 1,
            "extensions": "base",
        }
        if city:
            params["city"] = city
        if types:
            params["types"] = types

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(f"{self.BASE}/place/text", params=params)
                resp.raise_for_status()
                data = resp.json()
            if data.get("status") != "1":
                return []
            pois = []
            for p in data.get("pois", []):
                pois.append(PoiItem(
                    id=p.get("id", ""),
                    name=p.get("name", ""),
                    address=p.get("address", "") or p.get("pname", ""),
                    location=p.get("location", ""),
                    type=p.get("type", ""),
                ))
            return pois
        except Exception:
            return []

    async def get_weather(self, city: str) -> dict:
        """获取实时天气

        Args:
            city: 城市名（如 "北京"）或 adcode（如 "110000"）

        Returns:
            {"weather": "...", "temperature": "...", "wind": "...", "humidity": "...", "success": bool}
        """
        if not self.api_key:
            return {"success": False, "weather": "", "temperature": ""}

        params = {
            "key": self.api_key,
            "city": city,
            "extensions": "base",
            "output": "json",
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(f"{self.BASE}/weather/weatherInfo", params=params)
                resp.raise_for_status()
                data = resp.json()
            if data.get("status") != "1" or not data.get("lives"):
                return {"success": False, "weather": "", "temperature": ""}

            live = data["lives"][0]
            return {
                "success": True,
                "city": live.get("city", city),
                "weather": live.get("weather", ""),
                "temperature": live.get("temperature", ""),
                "wind": f"{live.get('winddirection', '')}风 {live.get('windpower', '')}级",
                "humidity": live.get("humidity", ""),
                "report_time": live.get("reporttime", ""),
            }
        except Exception:
            return {"success": False, "weather": "", "temperature": ""}

    async def get_weather_batch(self, cities: list[str]) -> dict[str, dict]:
        """批量获取多个城市的天气（并行查询）"""
        tasks = [self.get_weather(city) for city in cities]
        results = await asyncio.gather(*tasks)
        return dict(zip(cities, results))

    def _mock_pois(self, keywords: str, city: str) -> list[PoiItem]:
        return [
            PoiItem(id="mock_001", name=f"{city}{keywords}热门景点", address=f"{city}市中心", location="104.06,30.67", type="风景名胜"),
            PoiItem(id="mock_002", name=f"{city}特色餐厅", address=f"{city}美食街", location="104.07,30.66", type="餐饮服务"),
        ]


amap_service = AmapService()
