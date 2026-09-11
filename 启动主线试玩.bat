@echo off
setlocal
set "MAINLINE_LAUNCHER=%~dp0START_GAME.bat"
if not exist "%MAINLINE_LAUNCHER%" (
    echo [ERROR] Mainline project not found: "%MAINLINE_LAUNCHER%"
    pause
    exit /b 1
)
call "%MAINLINE_LAUNCHER%" %*
exit /b %errorlevel%
