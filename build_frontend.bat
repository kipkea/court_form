@echo off
title Build Flutter Web - Court Smart Form Studio
echo ================================================================
echo    Building Flutter Web for Court Smart Form Studio
echo ================================================================
echo.

cd /d "%~dp0frontend"
flutter build web --release --no-tree-shake-icons
echo.
echo Build completed! Output: frontend\build\web
echo.
if exist "d:\keaapp\fenv\Scripts\activate.bat" (
    call "d:\keaapp\fenv\Scripts\activate.bat"
)
cd /d "%~dp0backend"
python manage.py collectstatic --noinput
echo.
echo All Done!
pause
