@echo off
:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Run the PowerShell installer script in the same folder
echo.
echo Launching ComfyUI installation script...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install_New_ComfyUI_GPU.ps1"
pause
