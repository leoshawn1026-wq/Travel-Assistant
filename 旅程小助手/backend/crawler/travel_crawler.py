"""
旅行文案简易爬虫 - 仅抓取公开页面，去广告，结构化入库
用法: python travel_crawler.py --destination 成都 --source xiaohongshu
注意: 遵守 robots.txt，不做登录态爬取，仅供学习研究
"""
import argparse
import re
import sys
import os
import sqlite3
import requests
from bs4 import BeautifulSoup

# 将 backend 目录加入路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from app.config import settings  # noqa: E402

DB_PATH = settings.database_path

# 广告关键词过滤
AD_KEYWORDS = [
    "点击购买", "优惠券", "加微信", "私信", "关注我",
    "广告", "赞助", "推广", "限时优惠", "扫码",
]

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )
}


def clean_content(text: str) -> str:
    """去除广告文案和多余空白"""
    for kw in AD_KEYWORDS:
        text = text.replace(kw, "")
    text = re.sub(r"http[s]?://\S+", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_tags(text: str) -> str:
    """从文案中提取 #标签"""
    tags = re.findall(r"#(\w+)", text)
    return ",".join(tags[:10])


def init_db():
    os.makedirs(os.path.dirname(DB_PATH) or ".", exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
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
    conn.commit()
    return conn


def crawl_public_search(destination: str, source: str) -> list[dict]:
    """
    模拟公开搜索页抓取（MVP 使用示例数据 + 可选真实 URL）
    生产环境应替换为合规的数据源 API
    """
    items = []

    # MVP 示例数据（演示清洗入库流程）
    sample_data = {
        "xiaohongshu": [
            {
                "title": f"{destination}三日游超全攻略",
                "content": (
                    f"Day1: 到达{destination}，入住酒店，晚上逛夜市品尝当地小吃。"
                    f"Day2: 上午游览热门景点，下午体验文化街区。"
                    f"Day3: 购物返程。推荐美食：本地火锅、特色小吃。"
                    f"#旅行攻略 #{destination}旅游 #美食"
                ),
            },
            {
                "title": f"{destination}必打卡景点合集",
                "content": (
                    f"整理了{destination}最值得去的5个景点，"
                    f"包含交通方式和游玩时长建议，避开人流高峰时段。"
                    f"#景点推荐 #{destination}"
                ),
            },
        ],
        "douyin": [
            {
                "title": f"【{destination}】一日精华路线",
                "content": (
                    f"早上8点出发，打卡3个核心景点，"
                    f"中午吃当地特色午餐，下午逛文创街区，晚上看夜景。"
                    f"全程步行+地铁，人均花费约200元。"
                ),
            },
        ],
    }

    for item in sample_data.get(source, []):
        cleaned = clean_content(item["content"])
        tags = extract_tags(item["content"])
        items.append({
            "title": item["title"],
            "content": cleaned,
            "tags": tags,
        })

    return items


def save_to_db(conn, destination: str, source: str, items: list[dict]):
    for item in items:
        conn.execute(
            """
            INSERT INTO travel_content (destination, title, content, source, tags)
            VALUES (?, ?, ?, ?, ?)
            """,
            (destination, item["title"], item["content"], source, item["tags"]),
        )
    conn.commit()
    print(f"已入库 {len(items)} 条 {source} 文案（目的地: {destination}）")


def main():
    parser = argparse.ArgumentParser(description="旅行文案爬虫")
    parser.add_argument("--destination", required=True, help="目的地城市")
    parser.add_argument(
        "--source",
        default="xiaohongshu",
        choices=["xiaohongshu", "douyin"],
        help="数据来源",
    )
    args = parser.parse_args()

    conn = init_db()
    items = crawl_public_search(args.destination, args.source)

    if not items:
        print("未抓取到数据")
        return

    save_to_db(conn, args.destination, args.source, items)
    conn.close()
    print("爬虫任务完成")


if __name__ == "__main__":
    main()
