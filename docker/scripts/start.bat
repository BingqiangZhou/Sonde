@echo off
echo ======================================================
echo     Sonde - Docker Startup Script
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
if not exist "..\backend\.env" (
    echo WARNING: .env file not found, creating default...
    copy ..\backend\.env.example ..\backend\.env
    echo Please edit ..\backend\.env and configure:
    echo   - ENVIRONMENT=production
    echo   - OPENAI_API_KEY (if using AI features)
    echo.
    notepad ..\backend\.env
)
echo Configuration check complete

echo [3/5] Starting services...
echo This may take several minutes on first run...
echo.

%COMPOSE_CMD% -f docker-compose.podcast.yml up -d --build

if %errorlevel% NEQ 0 (
    echo ERROR: Startup failed
    echo.
    echo Showing last 20 lines of logs:
    %COMPOSE_CMD% -f docker-compose.podcast.yml logs --tail=20
    pause
    exit /b 1
)

echo.
echo [4/5] Waiting for services to be ready...
timeout /t 10 /nobreak >nul

echo [5/5] Checking service status...
%COMPOSE_CMD% -f docker-compose.podcast.yml ps

echo.
echo ======================================================
echo              Deployment Complete!
echo ======================================================
echo.
echo Service URLs:
echo   API Docs: http://localhost:8000/docs
echo   Health Check: http://localhost:8000/health
echo.
echo Important:
echo   1. First start takes 1-3 minutes (database init)
echo   2. All services should show "Up" or "Running"
echo   3. If failed, run: docker compose -f docker/docker-compose.podcast.yml logs backend
echo.
echo Management Commands:
echo   Stop: docker compose -f docker/docker-compose.podcast.yml down
echo   Logs: docker compose -f docker/docker-compose.podcast.yml logs -f backend
echo   Restart: docker compose -f docker/docker-compose.podcast.yml restart
echo.
echo Press any key to exit...
pause >nul