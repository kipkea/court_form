@echo off
chcp 65001 >nul
title Court Form Studio Docker Logs
docker compose logs -f
