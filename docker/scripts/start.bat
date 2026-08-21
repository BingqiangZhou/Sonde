@echo off
echo ======================================================
echo     Sonde (声读) - Docker Startup Script
echo ======================================================
echo.

echo [1/5] Checking Docker...
docker --version >nul 2>&1
if %errorlevel% NEQ 0 (
    echo ERROR: Docker not found. Please install Docker Desktop
    echo Download from: https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)
echo Docker is installed

docker compose version >nul 2>&1
if %errorlevel% NEQ 0 (
    echo WARNING: Docker compose not found, trying legacy command...
    set COMPOSE_CMD=docker-compose
) else (
    set COMPOSE_CMD=docker compose
)
echo Docker compose is available

echo [2/5] Checking configuration...
if not exist ".env" (
    if exist ".env.example" (
        echo WARNING: docker\.env not found, creating from .env.example...
        copy .env.example .env
        echo Please edit docker\.env and configure:
        echo   - POSTGRES_PASSWORD
        echo   - REDIS_PASSWORD
        echo.
        notepad .env
    ) else (
        echo ERROR: docker\.env.example not found
        pause
        exit /b 1
    )
)
if not exist "..ackend\.env" (
    echo WARNING: backend\.env not found, creating from example...
    copy ..ackend\.env.example ..ackend\.env
    echo Please edit ..ackend\.env before using AI features.
)
echo Configuration check complete

echo [3/5] Building and starting services...
echo This may take several minutes on first run...
echo.

%COMPOSE_CMD% up -d --build

if %errorlevel% NEQ 0 (
    echo ERROR: Startup failed
    echo.
    echo Showing last 20 lines of logs:
    %COMPOSE_CMD% logs --tail=20
    pause
    exit /b 1
)

echo.
echo [4/5] Waiting for services to be ready...
timeout /t 15 /nobreak >nul

echo [5/5] Checking service status...
%COMPOSE_CMD% ps

echo.
echo ======================================================
echo              Deployment Complete!
echo ======================================================
echo.
echo Service URLs:
echo   API Docs: http://localhost:8000/api/v1/docs
echo   Health Check: http://localhost:8000/api/v1/health
echo.
echo Important:
echo   1. First start takes 1-3 minutes (database init + migrations)
echo   2. All services should show "Up" or "Running"
echo   3. If failed, run: docker compose logs backend
echo.
echo Management Commands (run inside docker\):
echo   Stop: docker compose down
echo   Logs: docker compose logs -f backend
echo   Restart: docker compose restart
echo.
echo Press any key to exit...
pause >nul
