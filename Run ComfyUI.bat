@echo off
setlocal enabledelayedexpansion

echo ============================================
echo      ComfyUI Instance Launcher (up to 4)
echo ============================================
echo.
echo Select which instance of ComfyUI to launch:
echo [0] ComfyUI_GPU0
echo [1] ComfyUI_GPU1
echo [2] ComfyUI_GPU2
echo [3] ComfyUI_GPU3
echo.

set /p instance=Enter instance number (0-3): 

REM Validate input
if "%instance%"=="" goto :invalid
if "%instance%"=="0" goto :valid
if "%instance%"=="1" goto :valid
if "%instance%"=="2" goto :valid
if "%instance%"=="3" goto :valid

:invalid
echo.
echo Invalid selection. Must be a number between 0 and 3.
pause
exit /b

:valid
set "instanceFolder=ComfyUI_GPU%instance%"
set "instancePath=%~dp0%instanceFolder%"

if not exist "%instancePath%" (
    echo.
    echo Folder "%instanceFolder%" not found at path:
    echo %instancePath%
    pause
    exit /b
)

cd /d "%instancePath%"

REM Set CUDA device and port
set "CUDA_VISIBLE_DEVICES=%instance%"
set /a port=8188 + %instance%

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Run ComfyUI
echo.
echo Launching ComfyUI instance %instance% on port %port% with GPU device %CUDA_VISIBLE_DEVICES%
echo.

python main.py --port !port!

endlocal
pause
