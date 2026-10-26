@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found on PATH. Install Flutter and reopen this launcher.
  pause
  exit /b 1
)
if not exist "supabase_config.json" (
  echo Supabase configuration file not found.
  pause
  exit /b 1
)
flutter run -d chrome --web-hostname=localhost --web-port=3000 --dart-define-from-file=supabase_config.json
endlocal
