@echo off
chcp 65001 >nul
cd /d "%~dp0"

if not exist "venv\Scripts\python.exe" (
    echo [1/3] 创建虚拟环境...
    python -m venv venv
    if errorlevel 1 (
        echo 错误: 未找到 python，请先安装 Python 3.10+
        pause
        exit /b 1
    )
)

echo [2/3] 安装依赖...
venv\Scripts\pip install -r requirements.txt -q

if not exist ".env" (
    echo [提示] 未找到 .env，正在从 .env.example 复制...
    copy .env.example .env >nul
)

echo [3/3] 启动服务 http://localhost:8000 ...
venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
pause
