@echo off
chcp 65001 >nul
title EduBoard - chay thu
cd /d "%~dp0backend"

where node >nul 2>nul
if errorlevel 1 goto nonode
echo Da tim thay Node.js phien ban:
node -v

if exist node_modules\ goto run
echo.
echo Dang cai thu vien lan dau, mat khoang 2-5 phut. Vui long cho...
call npm install
if errorlevel 1 goto fail

:run
echo.
echo Dang khoi dong may chu. Trinh duyet se tu mo khi san sang.
echo Muon tat may chu thi dong cua so nay.
echo.
start "" /b powershell -NoProfile -WindowStyle Hidden -Command "for($i=0;$i -lt 300;$i++){try{Invoke-WebRequest -UseBasicParsing http://localhost:3000/docs -TimeoutSec 2 | Out-Null; Start-Process 'http://localhost:3000/'; break}catch{Start-Sleep -Seconds 1}}"
call npm run demo
echo.
echo May chu da dung. Neu co chu ERROR o tren, hay chup man hinh gui cho Claude.
goto end

:nonode
echo.
echo ============================================================
echo  MAY CHUA CAI NODE.JS
echo  Trang tai Node.js se duoc mo. Chon ban LTS, cai dat xong
echo  thi TAT cua so nay va bam dup lai file chay-thu.bat
echo ============================================================
start "" https://nodejs.org/
goto end

:fail
echo.
echo Cai thu vien bi loi. Hay chup man hinh cua so nay gui cho Claude.

:end
echo.
pause
