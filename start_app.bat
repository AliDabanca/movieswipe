@echo off
title MovieSwipe Launcher
color 0A

echo.
echo  ======================================
echo    MovieSwipe - Uygulama Baslatici
echo  ======================================
echo.

:: Backend'i arka planda baslat
echo [1/3] Backend baslatiliyor...
start "MovieSwipe Backend" cmd /k "cd /d %~dp0backend && python -m uvicorn app.presentation.api.main:app --reload --host 0.0.0.0 --port 8000"

:: Backend'in hazir olmasini bekle
echo [2/3] Backend'in hazir olmasi bekleniyor...
:wait_loop
timeout /t 2 /nobreak >nul
curl -s http://127.0.0.1:8000/health >nul 2>&1
if errorlevel 1 (
    echo        Bekleniyor...
    goto wait_loop
)

echo        Backend hazir!
echo.

:: Flutter app'i baslat
echo [3/3] Flutter uygulamasi baslatiliyor...
cd /d %~dp0
flutter run --dart-define=FLAVOR=dev

pause
