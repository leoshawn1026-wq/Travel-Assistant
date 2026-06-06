@echo off
chcp 65001 >nul
echo 正在将 Flutter 添加到系统环境变量...

:: 添加 Flutter 到系统 PATH
setx PATH "%PATH%;D:\flutter\bin" /M >nul 2>&1

:: 添加国内镜像（加速 pub 依赖下载）
setx PUB_HOSTED_URL "https://pub.npmmirror.com" /M >nul 2>&1
setx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn" /M >nul 2>&1

echo [OK] 环境变量已配置！
echo 请关闭并重新打开终端，然后运行 flutter doctor
pause
