# 以管理员身份运行
# 设置 Flutter 环境变量（持久化）

$FLUTTER_BIN = "D:\flutter\bin"

# 检查 Flutter 是否存在
if (-not (Test-Path "$FLUTTER_BIN\flutter.bat")) {
    Write-Host "[FAIL] 未找到 D:\flutter\bin\flutter.bat，请先安装 Flutter" -ForegroundColor Red
    pause
    exit 1
}

# 添加到系统 PATH
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($machinePath -notlike "*$FLUTTER_BIN*") {
    [Environment]::SetEnvironmentVariable("Path", "$machinePath;$FLUTTER_BIN", "Machine")
    Write-Host "[OK] Flutter 已添加到系统 PATH" -ForegroundColor Green
} else {
    Write-Host "[OK] Flutter 已在 PATH 中" -ForegroundColor Green
}

# 配置国内镜像
[Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.npmmirror.com", "Machine")
[Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "Machine")
Write-Host "[OK] 国内镜像已配置" -ForegroundColor Green

Write-Host ""
Write-Host "=== 环境配置完成！===" -ForegroundColor Cyan
Write-Host "请关闭并重新打开终端让环境变量生效"
Write-Host ""
Write-Host "后续步骤："
Write-Host "  1. 重新打开终端"
Write-Host "  2. cd 到本项目目录"
Write-Host "  3. cd mobile"
Write-Host "  4. setup.bat（首次初始化）"
Write-Host "  5. flutter pub get"
Write-Host "  6. flutter run -d chrome（浏览器预览）"
Write-Host ""
Write-Host "如需开发 Android 应用，请安装 Android Studio："
Write-Host "  https://developer.android.com/studio"
pause
