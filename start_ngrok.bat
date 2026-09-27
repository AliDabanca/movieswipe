@echo off
title MovieSwipe - Sunucu Baslatici
color 0B

echo.
echo  ================================================
echo    MovieSwipe - Backend ve Ngrok (Telefon Icin)
echo  ================================================
echo.

:: Backend'i baslat
echo [1/2] Backend baslatiliyor...
start "MovieSwipe Backend" cmd /k "cd /d %~dp0 && call .venv\Scripts\activate.bat && cd backend && python -m uvicorn app.presentation.api.main:app --reload --host 0.0.0.0 --port 8000"

:: Ngrok'u baslat
echo [2/2] Ngrok baslatiliyor...
start "Ngrok Tunnel" cmd /k "C:\Users\alida\Downloads\ngrok-v3-stable-windows-amd64\ngrok.exe http 8000"

echo.
echo Islem tamamlandi! Sunucu ve Ngrok arka planda calisiyor.
echo Bilgisayara hicbir kablo baglamadan, dogrudan telefonunuzdan
echo uygulamayi kullanmaya baslayabilirsiniz! 😎
echo.
pause
