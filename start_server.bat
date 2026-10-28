@echo off
title "Court Smart Form & Print Studio - Server (Port 8007)"
echo ================================================================
echo    Court Smart Form ^& Print Studio (Port 8007)
echo    Chiang Dao Kwaeng Court - Connected to Central Portal
echo ================================================================
echo.

cd /d "%~dp0"

if exist "d:\keaapp\fenv\Scripts\activate.bat" (
    echo Activating virtual environment (fenv)...
    call "d:\keaapp\fenv\Scripts\activate.bat"
)

cd backend
python serve_production.py
pause
