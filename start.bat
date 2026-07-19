@echo off
setlocal

for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "(Get-Content -Raw '%~dp0package.json' | ConvertFrom-Json).version"`) do set "APP_VERSION=%%V"

set "APP_EXE=%~dp0dist\video-hok-Portable-%APP_VERSION%.exe"
set "APP_DIR=%~dp0dist"

if not exist "%APP_EXE%" (
  echo Portable EXE was not found.
  echo Run: npm run release:windows
  pause
  exit /b 1
)

start "" /D "%APP_DIR%" "%APP_EXE%"
