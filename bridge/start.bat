@echo off
setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo ERROR: Node.js was not found.
  echo Please install the current Node.js LTS release and run this file again.
  echo https://nodejs.org/
  echo.
  pause
  exit /b 1
)

if not exist "node_modules\playwright" (
  echo Installing Playwright...
  call npm install
  if errorlevel 1 goto :error
)

echo Installing/checking Chromium for Playwright...
call npx playwright install chromium
if errorlevel 1 goto :error

echo.
echo ============================================
echo   DunkOrSlam Birthday Card Quest - Bridge
echo ============================================
echo.
echo Keep this window open while playing Noita.
echo The Recocards board is imported once at launch.
echo Keep this window open so Birthday Book links can open.
echo.
call npm start
exit /b %errorlevel%

:error
echo.
echo Setup failed. Please check the error messages above.
pause
exit /b 1
