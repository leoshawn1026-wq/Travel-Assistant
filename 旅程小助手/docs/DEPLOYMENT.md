# 旅程小助手 - 部署与打包指南（Windows 优先）

## 一、环境准备

| 工具 | 版本要求 | 验证命令 |
|------|----------|----------|
| Python | 3.10+ | `python --version` |
| Flutter | 3.16+ | `flutter --version` |
| Android Studio | 2023+ (SDK 34) | Android SDK Manager |
| JDK | 17 | `java -version` |

> **注意**：本文档命令以 **Windows PowerShell / CMD** 为准，不使用 Linux 的 `cp`、`&&`。

---

## 二、后端部署（FastAPI）

### 方式 A：一键启动（推荐）

双击或在 CMD 中运行：

```bat
cd backend
start.bat
```

脚本会自动：创建 venv → 安装依赖 → 复制 `.env` → 启动服务。

### 方式 B：手动步骤

```powershell
# 1. 进入后端目录
cd "C:\Users\27433\Desktop\frist-CC\旅程小助手\backend"

# 2. 创建并激活虚拟环境
python -m venv venv
.\venv\Scripts\Activate.ps1

# 若 PowerShell 禁止脚本执行，先运行：
# Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 3. 安装依赖
pip install -r requirements.txt

# 4. 配置环境变量
copy .env.example .env
# 用记事本编辑 .env，填入 API 密钥
```

`.env` 正确格式：

```env
DEEPSEEK_API_KEY=sk-xxxxxxxx
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-reasoner
AMAP_API_KEY=your-amap-key
HOST=0.0.0.0
PORT=8000
DEBUG=true
DATABASE_PATH=./data/cache.db
```

> **常见错误**：`.env` 中写 `DATABASE_URL` 会导致启动失败。必须使用 `DATABASE_PATH`。

### 5. 启动服务

**必须在 `backend` 目录下执行**，否则找不到 `app` 模块：

```powershell
# 推荐
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 或
python -m app.main
```

### 6. 验证

浏览器访问：http://localhost:8000/health

应返回：

```json
{"status": "ok", "version": "1.0.0-mvp"}
```

API 文档：http://localhost:8000/docs

### 7. 运行爬虫（可选）

```powershell
# 仍在 backend 目录下
python crawler\travel_crawler.py --destination 成都 --source xiaohongshu
```

---

## 三、Flutter 客户端部署

### 前置条件

1. 已安装 Flutter 并加入系统 PATH
2. 后端已启动且 `/health` 可访问

验证 Flutter：

```powershell
flutter doctor
```

### 方式 A：一键初始化（推荐）

```bat
cd mobile
setup.bat
```

### 方式 B：手动步骤

```powershell
cd "C:\Users\27433\Desktop\frist-CC\旅程小助手\mobile"

# 首次必须执行！生成完整 android/ios 工程
flutter create . --org com.travelassistant --project-name travel_assistant

flutter pub get
```

> **常见错误**：跳过 `flutter create` 直接 `flutter run` 会报缺少 `settings.gradle`、`Podfile` 等文件。本项目只包含 `lib/` 业务代码，平台工程需由 Flutter 生成。

### 配置后端地址

编辑 `mobile/lib/core/config/app_config.dart`：

| 场景 | baseUrl |
|------|---------|
| Android 模拟器 | `http://10.0.2.2:8000` |
| iOS 模拟器 | `http://127.0.0.1:8000` |
| Windows 桌面/Web | `http://127.0.0.1:8000` |
| 真机调试 | `http://<电脑局域网IP>:8000` |
| 生产环境 | `https://your-domain.com` |

查看电脑 IP：

```powershell
ipconfig
# 找「无线局域网适配器」下的 IPv4 地址
```

### 运行调试

```powershell
# 查看可用设备
flutter devices

# 运行（指定设备）
flutter run -d <device_id>

# 例如 Android 模拟器
flutter run -d emulator-5554
```

---

## 四、Android AAB 打包

### 1. 生成签名密钥

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias travel-assistant
```

将 `upload-keystore.jks` 放在 `mobile/` 目录下。

### 2. 配置签名

```powershell
cd mobile
copy android\key.properties.example android\key.properties
```

编辑 `android/key.properties`：

```properties
storePassword=你的密码
keyPassword=你的密码
keyAlias=travel-assistant
storeFile=../upload-keystore.jks
```

### 3. 构建 AAB

```powershell
flutter build appbundle --release
```

输出：`build\app\outputs\bundle\release\app-release.aab`

---

## 五、iOS IPA 打包（需 macOS + Xcode）

```bash
cd ios
pod install
open Runner.xcworkspace
```

```bash
flutter build ipa --release
```

---

## 六、故障排查

| 错误现象 | 原因 | 解决方案 |
|----------|------|----------|
| `ValidationError: database_url Extra inputs are not permitted` | `.env` 用了 `DATABASE_URL` | 改为 `DATABASE_PATH=./data/cache.db` |
| `No module named 'app'` | 不在 backend 目录启动 | `cd backend` 后再启动 |
| `flutter 不是内部或外部命令` | Flutter 未装或未加 PATH | 安装 Flutter 并重启终端 |
| `flutter run` 报 Gradle/Pod 错误 | 未执行 `flutter create` | 运行 `mobile\setup.bat` |
| APP 请求失败 / 连接超时 | baseUrl 配置错误 | 模拟器用 `10.0.2.2`，真机用局域网 IP |
| `Activate.ps1 无法加载` | PowerShell 执行策略限制 | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| 防火墙拦截真机连接 | Windows 防火墙 | 允许 Python 通过专用网络，或临时关闭防火墙测试 |
| DeepSeek 超时 | AI 响应慢 | 检查 API Key，或增大客户端 `receiveTimeout` |

### 快速自检清单

```powershell
# 1. 后端是否正常
Invoke-RestMethod http://localhost:8000/health

# 2. Flutter 环境
flutter doctor -v

# 3. 设备是否识别
flutter devices
```

---

## 七、生产部署建议

```bash
pip install gunicorn
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker -b 0.0.0.0:8000
```

- Nginx 反向代理 + HTTPS
- `.env` 通过服务器环境变量注入
- 设置 `DEBUG=false`
- CORS 改为具体域名，不用 `*`
- 移除 `usesCleartextTraffic`（Android）和 `NSAllowsArbitraryLoads`（iOS）
