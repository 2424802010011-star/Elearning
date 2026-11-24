@echo off
chcp 65001 >nul
title EduBoard - chay thu
cd /d "%~dp0backend"

where node >nul 2>nul
if errorlevel 1 goto nonode
echo Da tim thay Node.js phien ban:
node -v

echo.
echo Dang kiem tra thu vien. Lan dau mat khoang 2-5 phut, cac lan sau chi vai giay...
call npm install --no-audit --no-fund
if errorlevel 1 goto fail

:run
echo.
if not exist "%~dp0tools\livekit-server.exe" goto novideo
tasklist /FI "IMAGENAME eq livekit-server.exe" | find /I "livekit-server.exe" >nul
if not errorlevel 1 goto videook
echo Dang bat may chu video LiveKit. Neu Windows hoi tuong lua, chon Allow.
start "EduBoard - may chu video" /min "%~dp0tools\livekit-server.exe" --dev
goto videook
:novideo
echo Khong thay tools\livekit-server.exe nen phong hoc se khong co video, bang trang van dung duoc.
:videook
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
