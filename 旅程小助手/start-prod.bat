@echo off
REM ============================================
REM WanderWise Production Startup Script (Windows)
REM ============================================
echo [WanderWise] Starting production services...

:: ===== Backend =====
echo [Backend] Starting API server on port 8002...
cd /d "%~dp0backend"
start /B python -m uvicorn app.main:app --host 0.0.0.0 --port 8002 > ..\logs\backend.log 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [Backend] FAILED to start - check logs\backend.log
    exit /b 1
)
echo [Backend] OK (PID: %ERRORLEVEL%)

:: ===== Frontend =====
echo [Frontend] Starting Next.js production server on port 3000...
cd /d "%~dp0web"
set NEXT_PUBLIC_API_URL=http://localhost:8002/api/v1
start /B node .next/standalone/server.js > ..\logs\frontend.log 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [Frontend] FAILED to start - check logs\frontend.log
    exit /b 1
)
echo [Frontend] OK

:: ===== Verify =====
timeout /t 3 /nobreak >nul
echo.
echo ============================================
echo  WanderWise is running!
echo  Frontend: http://localhost:3000
echo  Backend:  http://localhost:8002/health
echo  Logs:    ./logs/
echo ============================================
echo.
echo Press any key to stop all services...
pause >nul

:: ===== Cleanup =====
echo [WanderWise] Stopping services...
taskkill //F //IM python //IM node 2>nul
echo [WanderWise] Stopped.
