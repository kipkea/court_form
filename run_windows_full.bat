@echo off
chcp 65001 >nul
title Court Smart Form Studio (Full Portal Mode)
echo ===========================================================================
echo   เริ่มต้นโปรแกรม Court Smart Form ^& Print Studio (โหมด FULL / เชื่อมต่อระบบ)
echo   เชื่อมต่อกับ Court Central Portal (SSO), ฐานข้อมูลกลาง และระบบ Audit Log
echo ===========================================================================
set EXE_PATH=%~dp0frontend\build\windows\x64\runner\Release\court_form.exe

if not exist "%EXE_PATH%" (
    echo [ERROR] ไม่พบไฟล์โปรแกรม: %EXE_PATH%
    echo กรุณารันคำสั่ง: cd frontend ^&^& flutter build windows --release
    pause
    exit /b 1
)

start "" "%EXE_PATH%"
