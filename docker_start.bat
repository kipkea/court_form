@echo off
chcp 65001 >nul
title Start Court Form Studio with Docker
echo ===========================================================================
echo   กำลังเริ่มต้นระบบ Court Smart Form ^& Print Studio ด้วย Docker...
echo ===========================================================================
docker compose up -d --build
echo.
echo ระบบพร้อมใช้งานแล้วที่: http://localhost:8007
echo ดู log การทำงานได้ด้วยคำสั่ง: docker compose logs -f
pause
