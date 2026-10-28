@echo off
chcp 65001 >nul
title Stop Court Form Studio Docker Containers
echo ===========================================================================
echo   กำลังหยุดการทำงานของ Court Smart Form Docker...
echo ===========================================================================
docker compose down
pause
