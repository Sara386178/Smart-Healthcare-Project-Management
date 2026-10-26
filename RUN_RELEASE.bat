@echo off
setlocal
cd /d "%~dp0"
if not exist "supabase_config.json" (
  echo Supabase configuration file not found.
  pause
  exit /b 1
)
flutter build web --release --dart-define-from-file=supabase_config.json
if errorlevel 1 (
  echo Release build failed.
  pause
  exit /b 1
)
start "HealthPM release server" /B dart run tool\serve_release.dart 3000
timeout /t 4 /nobreak >nul
start "" "http://localhost:3000/"
echo HealthPM release build is running at http://localhost:3000/
echo Keep this window open while using the application. Close this window to stop it.
pause
endlocal
