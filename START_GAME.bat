@echo off
chcp 65001 >nul
setlocal
rem PixelArmor launcher - locates project dir and bundled Godot by script location.
set "PROJECT_DIR=%~dp0"
set "GODOT_DIR=%PROJECT_DIR%tools\godot"
set "GODOT_EXE="
if not exist "%GODOT_DIR%" goto no_engine
for /f "delims=" %%F in ('dir /b /a-d "%GODOT_DIR%\Godot_v*.exe" 2^>nul') do (
    echo %%F | findstr /i "console" >nul
    if errorlevel 1 if not defined GODOT_EXE set "GODOT_EXE=%GODOT_DIR%\%%F"
)
if not defined GODOT_EXE for /f "delims=" %%F in ('dir /b /a-d "%GODOT_DIR%\Godot_v*.exe" 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%GODOT_DIR%\%%F"
if not defined GODOT_EXE goto no_engine
echo Engine: %GODOT_EXE%
if not exist "%PROJECT_DIR%.godot" (
    echo First run: importing project resources, please wait ...
    "%GODOT_EXE%" --headless --path "%PROJECT_DIR%." --import
)
"%GODOT_EXE%" --path "%PROJECT_DIR%." %*
set "RC=%errorlevel%"
if not "%RC%"=="0" pause
exit /b %RC%
:no_engine
echo [ERROR] Godot engine not found.
echo Expected folder: %GODOT_DIR%
echo Please extract Godot 4.x stable win64 (normal version, not .NET) there,
echo e.g. Godot_v4.7.2-stable_win64.exe directly inside that folder.
echo [中文] 未找到 Godot 引擎：请将 Godot 4.x 稳定普通版 win64 解压到上述目录后重试。
pause
exit /b 1
