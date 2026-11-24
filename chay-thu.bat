@echo off
chcp 65001 >nul
cd /d "%~dp0backend"
where node >nul 2>nul || (echo Chua cai Node.js. Tai tai https://nodejs.org (ban LTS) roi chay lai file nay. & pause & exit /b 1)
if not exist node_modules (echo Dang cai thu vien lan dau, mat vai phut... & call npm install || (pause & exit /b 1))
start "" http://localhost:3000/docs
call npm run demo
pause
