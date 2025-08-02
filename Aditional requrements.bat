@echo off
setlocal enabledelayedexpansion

:: Prompt user to choose ComfyUI instance
echo Select the ComfyUI instance to update:
echo [0] ComfyUI_GPU0
echo [1] ComfyUI_GPU1
echo [2] ComfyUI_GPU2
echo [3] ComfyUI_GPU3
set /p instance="Enter number (0-3): "

set instance_folder=ComfyUI_GPU%instance%
set base_path=%~dp0%instance_folder%

:: Check if folder exists
if not exist "%base_path%" (
    echo Error: Instance folder "%base_path%" not found.
    exit /b 1
)

:: Navigate to instance and activate venv
cd /d "%base_path%"
call venv\Scripts\activate

:: --- Install TeaCache core dependencies ---
pip install pymongo httpx diskcache tqdm

:: --- Navigate to TeaCache folder and install its requirements ---
if exist "custom_nodes\ComfyUI-TeaCache\requirements.txt" (
    cd custom_nodes\ComfyUI-TeaCache
    pip install -r requirements.txt
    cd ..\..
) else (
    echo Warning: requirements.txt not found in ComfyUI-TeaCache
)

:: --- Install In-Context-Lora dependencies manually (no requirements.txt present) ---
cd custom_nodes\Comfyui-In-Context-Lora-Utils

:: These are required for Comfyui-In-Context-Lora-Utils to work
pip install scikit-image Pillow numpy torch opencv-python

cd ..\..

:: Done
echo.
echo ✅ All dependencies for TeaCache and In-Context-Lora-Utils installed.
pause
