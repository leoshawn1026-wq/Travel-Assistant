"""API 测试脚本 - 使用 requests 库避免代理问题"""
import requests, json

BASE = 'http://localhost:8002'
NO_PROXY = {'http': '', 'https': ''}
passed = 0
failed = 0

def test(name, method, path, **kwargs):
    global passed, failed
    try:
        kwargs.setdefault('proxies', NO_PROXY)
        kwargs.setdefault('timeout', 30)
        if method == 'GET':
            r = requests.get(f'{BASE}{path}', **kwargs)
        else:
            r = requests.post(f'{BASE}{path}', **kwargs)
        data = r.json()
        ok = data.get('code') == 0 or path == '/health'
        status = 'PASS' if ok else 'FAIL'
        print(f'[{status}] {method} {name}')
        if ok: passed += 1
        else: failed += 1

        if name == '目的地对比':
            print(f'  -> headers: {data["data"]["table"]["headers"]}')
            print(f'  -> rows: {len(data["data"]["table"]["rows"])} dimensions')
        elif name == '行程生成':
            print(f'  -> title: {data["data"]["title"]}')
            print(f'  -> stops: {len(data["data"]["items"])}')
        elif name == 'AI对话':
            print(f'  -> reply: {str(data["data"]["content"])[:80]}')
        elif name == 'POI搜索':
            print(f'  -> pois: {len(data["data"]["pois"])}')
    except Exception as e:
        print(f'[FAIL] {method} {name} -> {e}')
        failed += 1

print('=== 旅程小助手 API 测试 ===\n')

test('健康检查', 'GET', '/health')
test('AI对话', 'POST', '/api/v1/chat', json={
    'messages': [{'role': 'user', 'content': '成都3天怎么玩'}],
    'stream': False
})
test('目的地对比', 'POST', '/api/v1/compare/destinations', json={
    'destinations': ['成都', '重庆', '西安'],
    'travel_days': 3,
    'budget_level': 'medium'
})
test('行程生成', 'POST', '/api/v1/itinerary/generate', json={
    'destination': '成都',
    'date': '2026-06-15',
    'preferences': ['美食', '历史文化'],
    'pace': 'moderate'
})
test('POI搜索', 'GET', '/api/v1/poi/search', params={
    'keywords': '景点', 'city': '成都'
})
test('缓存读取', 'GET', '/api/v1/cache/test-device')

print(f'\n=== 结果: {passed} 通过, {failed} 失败 ===')
