@echo off
chcp 65001 >nul
cd /d "%~dp0"

where flutter >nul 2>&1
if errorlevel 1 (
    echo 错误: 未找到 flutter 命令
    echo 请先安装 Flutter SDK 并加入 PATH: https://docs.flutter.dev/get-started/install/windows
    pause
    exit /b 1
)

echo [1/2] 生成 Android/iOS 平台工程（首次必须执行）...
flutter create . --org com.travelassistant --project-name travel_assistant

echo [2/2] 安装依赖...
flutter pub get

echo.
echo 完成！运行调试: flutter run
echo 请确认 lib/core/config/app_config.dart 中 baseUrl 指向你的后端地址
pause
