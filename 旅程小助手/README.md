# 旅程小助手

基于 Flutter + FastAPI 的 AI 旅行规划 APP，对接 DeepSeek-R1 和高德地图。

## 功能

- **AI 对话**：旅行问答与建议
- **目的地对比**：多城市表格对比（预算/景点/美食等）
- **单日行程生成**：AI + POI 结构化行程
- **收藏行程**：SharedPreferences 本地持久化

## 快速开始（Windows）

### 后端（一键启动）

```bat
cd backend
start.bat
```

或手动：

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env    # 填入 API 密钥，注意用 DATABASE_PATH 而非 DATABASE_URL
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

验证：http://localhost:8000/health

### 客户端

```bat
cd mobile
setup.bat
flutter run
```

> 首次必须先执行 `setup.bat`（内部调用 `flutter create`）生成完整平台工程。

## 文档

- [架构说明](docs/ARCHITECTURE.md)
- [接口文档](docs/API.md)
- [部署与打包](docs/DEPLOYMENT.md)

## 技术栈

| 端 | 技术 |
|----|------|
| 移动端 | Flutter, Dio, SharedPreferences |
| 后端 | FastAPI, DeepSeek-R1, 高德 Web API |
| 爬虫 | Python requests + BeautifulSoup |

## 许可证

仅供学习研究使用。爬虫请遵守目标网站 robots.txt 和相关法律法规。
