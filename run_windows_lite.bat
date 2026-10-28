@echo off
chcp 65001 >nul
title Court Smart Form Studio (Lite / Standalone Mode)
echo ===========================================================================
echo   เริ่มต้นโปรแกรม Court Smart Form ^& Print Studio (โหมด LITE / STANDALONE)
echo   พารามิเตอร์: --lite (ใช้งานอิสระ ไม่ต้องล็อกอิน และไม่เชื่อมต่อฐานข้อมูลเซิร์ฟเวอร์)
echo ===========================================================================
set EXE_PATH=%~dp0frontend\build\windows\x64\runner\Release\court_form.exe

if not exist "%EXE_PATH%" (
    echo [ERROR] ไม่พบไฟล์โปรแกรม: %EXE_PATH%
    echo กรุณารันคำสั่ง: cd frontend ^&^& flutter build windows --release
    pause
    exit /b 1
)

start "" "%EXE_PATH%" --lite
