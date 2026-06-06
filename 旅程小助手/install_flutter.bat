@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Flutter Installer

echo ========================================
echo     Flutter Installer for Windows
echo ========================================
echo.

set FLUTTER_DIR=D:\flutter
set BIN_PATH=%FLUTTER_DIR%\bin
set ZIP_PATH=%TEMP%\flutter.zip

REM Check if already installed
if exist "%BIN_PATH%\flutter.bat" (
    echo [OK] Flutter already installed at %FLUTTER_DIR%
    echo.
    echo Running flutter doctor...
    "%BIN_PATH%\flutter.bat" doctor
    echo.
    pause
    exit /b 0
)

REM Download
echo [1/3] Downloading Flutter SDK from npm mirror (China)...
echo   URL: https://npmmirror.com/mirrors/flutter/flutter_windows_3.29.2-stable.zip
echo.
echo   This may take a few minutes (1GB file)...

powershell -Command "$wc = New-Object System.Net.WebClient; Write-Host 'Downloading...'; $wc.DownloadFile('https://npmmirror.com/mirrors/flutter/flutter_windows_3.29.2-stable.zip', '%ZIP_PATH%'); Write-Host 'Download complete!'"

if not exist "%ZIP_PATH%" (
    echo [FAIL] Download failed!
    echo.
    echo Please manually download from:
    echo   https://npmmirror.com/mirrors/flutter/
    echo.
    echo Download flutter_windows_3.29.2-stable.zip
    echo Extract to D:\flutter
    echo Add D:\flutter\bin to system PATH
    echo Re-run this script
    pause
    exit /b 1
)

echo [OK] Download complete!
echo.

REM Extract
echo [2/3] Extracting to %FLUTTER_DIR% ...
if exist "%FLUTTER_DIR%" rmdir /s /q "%FLUTTER_DIR%" >nul 2>&1

powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%ZIP_PATH%', 'D:\'); $d = Get-ChildItem 'D:\' -Directory | Where-Object { $_.Name -like 'flutter*' } | Select-Object -First 1; if ($d.FullName -ne '%FLUTTER_DIR%') { Rename-Item $d.FullName '%FLUTTER_DIR%' }"

if not exist "%BIN_PATH%\flutter.bat" (
    echo [FAIL] Extraction failed!
    echo Please manually extract %ZIP_PATH% to D:\flutter
    pause
    exit /b 1
)

echo [OK] Extraction complete!
echo.

REM Add PATH
echo [3/3] Adding to system PATH...
setx PATH "%PATH%;%BIN_PATH%" /M >nul 2>&1
echo [OK] PATH updated. Please restart terminal after install.
echo.

REM Run doctor
echo ========================================
echo  Running flutter doctor (first run downloads Dart SDK)
echo ========================================
echo.

set PUB_HOSTED_URL=https://pub.npmmirror.com
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

"%BIN_PATH%\flutter.bat" doctor

echo.
echo ========================================
echo     Installation complete!
echo ========================================
echo.
echo Next steps:
echo   1. Close and reopen terminal
echo   2. cd mobile
echo   3. setup.bat (first time only)
echo   4. flutter run
echo.
pause
