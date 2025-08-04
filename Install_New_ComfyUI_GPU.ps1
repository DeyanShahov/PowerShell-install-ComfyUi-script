# =============================================================================
# ComfyUI Multi-Instance Installation Script
# =============================================================================
# Този скрипт автоматизира инсталацията на една или множество инстанции на ComfyUI
# с поддръжка за споделяне на модели, custom nodes и workflows между инстанциите
# =============================================================================


# Функция за намиране на следващата свободна папка за ComfyUI инстанция
# Създава папки с имена ComfyUI_GPU0, ComfyUI_GPU1, ComfyUI_GPU2 и т.н.
function Get-NextFreeComfyFolder {
    $index = 0
    do {
        $folderName = "ComfyUI_GPU$index"
        $fullPath = Join-Path -Path $PSScriptRoot -ChildPath $folderName
        $index++
    } while (Test-Path $fullPath)
    return $fullPath
}

# Функция за получаване на номер на инстанция
function Get-InstanceNumber {
    while ($true) {
        $choice = Read-Host "Автоматично засичане на номера на инстанцията? (Y/N)"
        if ($choice.ToUpper() -eq 'Y') {
            $folderPath = Get-NextFreeComfyFolder
            Write-Host "Автоматично избран номер: $($folderPath | Split-Path -Leaf)" -ForegroundColor Green
            return $folderPath
        }
        if ($choice.ToUpper() -eq 'N') {
            while ($true) {
                $instanceNumber = Read-Host "Въведете номер на инстанцията"
                if ($instanceNumber -notmatch '^\d+$') {
                    Write-Warning "Моля, въведете валиден положителен номер."
                    continue
                }
                $folderName = "ComfyUI_GPU$instanceNumber"
                $fullPath = Join-Path -Path $PSScriptRoot -ChildPath $folderName
                if (Test-Path $fullPath) {
                    Write-Warning "Папката '$folderName' вече съществува. Моля, изберете друг номер."
                    continue
                }
                return $fullPath
            }
        }
        Write-Warning "Невалиден избор. Моля, въведете 'Y' или 'N'."
    }
}


# Функция за създаване на символични връзки (symbolic links) между папки
# Позволява споделяне на модели, custom nodes и workflows между инстанциите
function New-ComfySymbolicLink {
    param(
        [Parameter(Mandatory=$true)]
        [string]$LinkPath,        # Пътят към символичната връзка
        [Parameter(Mandatory=$true)]
        [string]$TargetPath       # Пътят към целевата папка
    )
    # Проверява дали вече съществува връзка или папка и я премахва
    $isReparsePoint = $false
    if (Test-Path $LinkPath -ErrorAction SilentlyContinue) {
        $item = Get-Item $LinkPath -Force -ErrorAction SilentlyContinue
        if ($item -and $item.Attributes.ToString().Contains("ReparsePoint")) {
            $isReparsePoint = $true
        }
    }
    if ($isReparsePoint -or (Test-Path $LinkPath -PathType Container -ErrorAction SilentlyContinue)) {
        Write-Host "Removing existing folder/link at '$LinkPath'..."
        Remove-Item -Recurse -Force $LinkPath
    }
    Write-Host "Creating symbolic link from '$LinkPath' to '$TargetPath'..."
    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath -ErrorAction Stop | Out-Null
        Write-Host "Symbolic link created successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to create symbolic link. Error: $_"
    }
}



# Основна функция за инсталация на ComfyUI ядрото
# Клонира репозиторията, създава виртуална среда и инсталира зависимостите
function Install-ComfyUICore {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallPath      # Път за инсталация на ComfyUI
    )
    $folderName = Split-Path -Leaf $InstallPath
    Write-Host "--- Installing Core ComfyUI into '$folderName' ---" -ForegroundColor Magenta

    Write-Host "Creating directory: $folderName" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $InstallPath | Out-Null
    Write-Host "✓ Directory created successfully" -ForegroundColor Green

    Write-Host "Cloning ComfyUI repository into $folderName..." -ForegroundColor Yellow
    git clone https://github.com/comfyanonymous/ComfyUI.git $InstallPath
    Write-Host "✓ Repository cloned successfully" -ForegroundColor Green

    # Проверка дали клонирането е успешно
    if (-not (Test-Path (Join-Path $InstallPath "main.py"))) {
        Write-Error "Cloning failed. 'main.py' not found in '$InstallPath'."
        throw "Cloning failed."
    }

    Set-Location $InstallPath

    Write-Host "Creating Python virtual environment..." -ForegroundColor Yellow
    python -m venv venv
    $pythonVenvPath = Join-Path $InstallPath "venv\Scripts\python.exe"
    if (-not (Test-Path $pythonVenvPath)) {
        Write-Error "Failed to create virtual environment in '$InstallPath'."
        throw "Venv creation failed."
    }
    Write-Host "✓ Virtual environment created successfully" -ForegroundColor Green

    # --- Обновяване на pip ---
    try {
        Write-Host "`n--- Step 1/3: Upgrading pip ---" -ForegroundColor Magenta
        $pipArgs = @("-m", "pip", "install", "--upgrade", "pip")
        #& ".\venv\Scripts\python.exe" @pipArgs | Out-Null
        & $pythonVenvPath @pipArgs | Out-Null
        Write-Host "✓ Pip upgrade completed successfully" -ForegroundColor Green
        Write-Host "---------------------------------------------" -ForegroundColor Cyan
    } catch {
        Write-Error "Pip upgrade failed: $_" -ForegroundColor Red
        throw
    }

    # --- Инсталация на PyTorch с CUDA поддръжка ---  
    try {
        Write-Host "`n--- Step 2/3: Installing PyTorch with CUDA support ---" -ForegroundColor Magenta
        $torchArgs = @("-m", "pip", "install", "torch", "torchvision", "torchaudio", "--index-url", "https://download.pytorch.org/whl/cu121")
        #& ".\venv\Scripts\python.exe" @torchArgs | Out-Null
        & $pythonVenvPath @torchArgs | Out-Null
        Write-Host "✓ PyTorch installation completed successfully" -ForegroundColor Green
        Write-Host "---------------------------------------------" -ForegroundColor Cyan
    } catch {
        Write-Error "PyTorch installation failed: $_" -Foreground Red
        throw
    }

    # --- Инсталация на ComfyUI зависимости ---   
    try {
        Write-Host "`n--- Step 3/3: Installing ComfyUI requirements ---" -ForegroundColor Magenta
        $reqArgs = @("-m", "pip", "install", "-r", "requirements.txt")
        #& ".\venv\Scripts\python.exe" @reqArgs | Out-Null
        & $pythonVenvPath @reqArgs | Out-Null
        Write-Host "✓ Requirements installation completed successfully" -ForegroundColor Green
        Write-Host "---------------------------------------------" -ForegroundColor Cyan
    } catch {
        Write-Error "Requirements installation failed: $_" -ForegroundColor Red
        throw
    }
    
    Write-Host "`n✓ Core installation of ComfyUI is complete in folder: $folderName" -ForegroundColor Green
    return $pythonVenvPath
}




# Функция за изтегляне на модели за конкретни workflows
# Позволява избор на готови пакети модели за различни задачи
function Invoke-ModelDownloader {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallPath
    )

    $modelsBasePath = Join-Path -Path $InstallPath -ChildPath "models"

    # Дефиниране на пакети модели с техните зависимости
    # Всеки пакет съдържа списък от модели, необходими за конкретен workflow
    $modelPacks = @(
        [PSCustomObject]@{
            WorkflowName = "2-in-1 Clothes Swapper Workflow"
           Models = @(
                [PSCustomObject]@{
                    Name = "T5-XXL FP8 Text Encoder"
                    URL = "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors"
                    Size = "5 GB"
                    Destination = "clip"
                    FileName = "t5xxl_fp8_e4m3fn.safetensors"
                },
                [PSCustomObject]@{
                    Name = "Clip l Text Encoder"
                    URL = "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
                    Size = "246 MB"
                    Destination = "clip"
                    FileName = "clip_l.safetensors"
                },
                [PSCustomObject]@{
                    Name = "Sigclip vision 384"
                    URL = "https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors"
                    Size = "857 MB"
                    Destination = "clip_vision"
                    FileName = "sigclip_vision_patch14_384.safetensors"
                },
                [PSCustomObject]@{
                    Name = "FLUX.1-Redux-dev"
                    URL = "https://huggingface.co/second-state/FLUX.1-Redux-dev-GGUF/resolve/c7e36ea59a409eaa553b9744b53aa350099d5d51/flux1-redux-dev.safetensors"
                    Size = "129 MB"
                    Destination = "style_models"
                    FileName = "flux1-redux-dev.safetensors"
                },
                [PSCustomObject]@{
                    Name = "FLUX.1-Turbo-Alpha"
                    URL = "https://huggingface.co/alimama-creative/FLUX.1-Turbo-Alpha/resolve/main/diffusion_pytorch_model.safetensors"
                    Size = "694 MB"
                    Destination = "loras"
                    FileName = "FLUX.1-Turbo-Alpha.safetensors"
                },
                [PSCustomObject]@{
                    Name = "Flux fill FP8 Turbo"
                    URL = "https://huggingface.co/jackzheng/flux-fill-FP8/resolve/0416994c3318316e8be23f259d10d4a320b0fcbd/fluxFillFP8_v10.safetensors"
                    Size = "12 GB"
                    Destination = "diffusion_models"
                    FileName = "fluxfillV1FP8Turbo_v10.safetensors"
                },
                [PSCustomObject]@{
                    Name = "F_1D_Detailed Skin&Textures"
                    #URL = "https://civitai.com/api/download/models/1770362?type=Model&format=SafeTensor"
                    URL = "https://huggingface.co/TheImposterImposters/RealisticSkinTexturestyleXLDetailedSkinSD1.5Flux1D-SkintextureF1Dv1.5/resolve/main/detailed%20photorealism%20style%20v3.safetensors"
                    #Size = "1.14 GB"
                    Size = "1.14 GB"
                    Destination = "loras"
                    FileName = "F_1D_Detailed Skin&Textures_(dsv4).safetensors"
                },
                [PSCustomObject]@{
                    Name = "F_1D_Migration_Lora_cloth"
                    URL = "https://huggingface.co/TTPlanet/Migration_Lora_flux/resolve/main/Migration_Lora_cloth.safetensors"
                    Size = "164 MB"
                    Destination = "loras"
                    FileName = "F_1D_Migration_Lora_cloth_(cloth-on).safetensors"
                },
                [PSCustomObject]@{
                    Name = "4x-Ultrasharp"
                    URL = "https://huggingface.co/lokCX/4x-Ultrasharp/resolve/main/4x-UltraSharp.pth"
                    Size = "67 MB"
                    Destination = "upscale_models"
                    FileName = "4x-Ultrasharp.pth"
                },   
                [PSCustomObject]@{
                    Name = "ae.sft"
                    URL = "https://huggingface.co/Madespace/vae/resolve/3b34e1aca3511e7f382ff8bb2dab0731c4f4b6cf/ae.sft"
                    Size = "335 MB"
                    Destination = "vae"
                    FileName = "ae.sft"
                }                                     
                # Add other models for this workflow here in the future
            )
        }
        # Тук могат да се добавят други пакети модели
    )

    Write-Host "`n--- Model Pack Downloader ---"
    Write-Host "Select a model pack to download:"

    # Интерактивен избор на пакет модели
    $validChoice = $false
    while (-not $validChoice) {
        # Показване на наличните опции
        for ($i = 0; $i -lt $modelPacks.Count; $i++) {
            Write-Host "  [$($i+1)] $($modelPacks[$i].WorkflowName)"
        }
        Write-Host "  [Q] Quit downloader and skip"

        $packChoice = Read-Host "Your choice"

        # Проверка за изход
        if ($packChoice.ToUpper() -eq 'Q') {
            Write-Host "Skipping model downloads."
            return
        }

        # Проверка за валиден числов избор
        if ($packChoice -match "^\d+$") {
            $chosenIndex = [int]$packChoice - 1
            if ($chosenIndex -ge 0 -and $chosenIndex -lt $modelPacks.Count) {
                $validChoice = $true
                $chosenPack = $modelPacks[$chosenIndex]
                $modelsToDownload = $chosenPack.Models

                Write-Host "`nYou selected '$($chosenPack.WorkflowName)'."
                $downloadAll = Read-Host "Download all required models for this pack? (Y/N)"

                # Изтегляне на избраните модели
                foreach ($model in $modelsToDownload) {
                    $doDownload = $false
                    if ($downloadAll -in @('Y', 'y')) {
                        $doDownload = $true
                    } else {
                        $individualChoice = Read-Host "Download '$($model.Name)' ($($model.Size))? (Y/N)"
                        if ($individualChoice -in @('Y', 'y')) {
                            $doDownload = $true
                        }
                    }

                    if ($doDownload) {
                        $destinationFolder = Join-Path -Path $modelsBasePath -ChildPath $model.Destination
                        $destinationFile = Join-Path -Path $destinationFolder -ChildPath $model.FileName

                        # Създаване на папката ако не съществува
                        if (-not (Test-Path $destinationFolder)) {
                            Write-Host "Creating directory: $destinationFolder" -ForegroundColor Yellow
                            New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
                        }

                        # Проверка дали файлът вече съществува
                        if (Test-Path $destinationFile) {
                            Write-Host "File '$($model.FileName)' already exists. Skipping download." 
                        } else {
                            Write-Host "Downloading '$($model.Name)' ($($model.Size)) to '$($model.Destination)'..." -ForegroundColor Yellow
                            try {                             
                                Invoke-WebRequest -Uri $model.URL -OutFile $destinationFile
                                Write-Host "Download complete for '$($model.FileName)'." -ForegroundColor Green
                            } catch {
                                Write-Error "Failed to download '$($model.Name)'. Error: $_" -ForegroundColor Red
                            }
                        }
                    }
                }
            } else {
                Write-Host "Invalid selection. Please enter a number between 1 and $($modelPacks.Count)." 
            }
        } else {
            Write-Host "Invalid input. Please enter a valid number or 'Q' to quit." 
        }
    }
}

# Функция за настройка на споделени папки (models, workflows)
# Позволява избор между връзка към съществуваща папка, изтегляне или пропускане
function Setup-SharedFolderLink {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallPath,
        [Parameter(Mandatory=$true)]
        [string]$FolderName
    )

    Write-Host "`n--- Settings for '$FolderName' folder ---"
    Write-Host "Please choose an option for the '$FolderName' folder:"
    Write-Host "  [L] Link to an existing folder."
    if ($FolderName -eq 'models') {
        Write-Host "  [D] Download recommended model packs."
    }
    Write-Host "  [S] Skip - the default empty folder will be used."

    $validChoices = "L", "S"
    if ($FolderName -eq 'models') {
        $validChoices += "D"
    }
    
    $choice = ""
    while ($choice.ToUpper() -notin $validChoices) {
        $choice = Read-Host "Your choice ($($validChoices -join '/'))"
    }

    switch ($choice.ToUpper()) {
        "L" {
            # Създаване на символична връзка към съществуваща папка
            $sourcePath = Read-Host "Enter the full path to the existing '$FolderName' folder"

            if (Test-Path $sourcePath -PathType Container) {
                Write-Host "Folder found: $sourcePath"
                $linkPath = Join-Path -Path $InstallPath -ChildPath $FolderName
                New-ComfySymbolicLink -LinkPath $linkPath -TargetPath $sourcePath
            } else {
                Write-Warning "The specified path '$sourcePath' does not exist or is not a folder. No symbolic link was created for '$FolderName'."
            }
        }
        "D" {
            # Изтегляне на модели (само за models папката)
            Invoke-ModelDownloader -InstallPath $InstallPath
        }
        "S" {
            Write-Host "The default local folder '$FolderName' will be used. Skipping."
        }
    }
}

# Функция за изтегляне на custom nodes (стара версия - използва се в автоматизирания режим)
function Invoke-CustomNodeDownloader {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallPath,
        [Parameter(Mandatory=$true)]
        [string]$PythonVenvPath
    )
    $customNodesInstallPath = Join-Path -Path $InstallPath -ChildPath "custom_nodes"
    if (-not (Test-Path $customNodesInstallPath)) {
        New-Item -Path $customNodesInstallPath -ItemType Directory -Force | Out-Null
    }

    Write-Host "Downloading recommended custom nodes..."
    # Списък с препоръчителни custom nodes репозитории
    $nodeRepos = @(
        "https://github.com/welltop-cn/ComfyUI-TeaCache.git", "https://github.com/Acly/comfyui-inpaint-nodes.git",
        "https://github.com/kaibioinfo/ComfyUI_AdvancedRefluxControl.git", "https://github.com/lrzjason/Comfyui-In-Context-Lora-Utils.git",
        "https://github.com/jags111/efficiency-nodes-comfyui.git", "https://github.com/cubiq/ComfyUI_essentials.git",
        "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git", "https://github.com/jamesWalker55/comfyui-various.git"
    )

    $originalLocation = Get-Location
    Set-Location $customNodesInstallPath

    # Клониране на всеки custom node репозиторий
    foreach ($repoUrl in $nodeRepos) {
        $repoName = ($repoUrl.Split('/')[-1]).Replace(".git", "")
        $repoPath = Join-Path -Path (Get-Location) -ChildPath $repoName
        if (Test-Path $repoPath) { Write-Host "Custom node '$repoName' already exists. Skipping clone."; continue }
        Write-Host "Cloning '$repoName'..."; git clone $repoUrl
        # Инсталиране на зависимости ако има requirements.txt
        $requirementsPath = Join-Path -Path $repoPath -ChildPath "requirements.txt"
        if (Test-Path $requirementsPath) { Write-Host "Found requirements.txt for $repoName. Installing..."; & $PythonVenvPath -m pip install -r $requirementsPath }
    }
    Set-Location $originalLocation
    Write-Host "`nAll custom nodes have been downloaded and their dependencies installed." -ForegroundColor Green
}

# Функция за настройка на custom nodes (нова версия - използва се в ръчния режим)
function Setup-CustomNodes {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallPath
    )

    $customNodesInstallPath = Join-Path -Path $InstallPath -ChildPath "custom_nodes"

    Write-Host "`n--- Settings for 'custom_nodes' folder ---"
    Write-Host "Please choose an option for 'custom_nodes':"
    Write-Host "  [L] Link to an existing folder."
    Write-Host "  [D] Download a recommended list of custom nodes."
    Write-Host "  [S] Skip - the default empty folder will be used."

    $validChoices = "L", "D", "S"
    $choice = ""
    while ($choice.ToUpper() -notin $validChoices) {
        $choice = Read-Host "Your choice ($($validChoices -join '/'))"
    }

    switch ($choice.ToUpper()) {
        "L" {
            # Създаване на символична връзка към съществуваща custom_nodes папка
            $sourcePath = Read-Host "Enter the full path to the existing 'custom_nodes' folder"
            if (Test-Path $sourcePath -PathType Container) {
                Write-Host "Creating symbolic link for 'custom_nodes'..."
                New-Item -ItemType SymbolicLink -Path $customNodesInstallPath -Target $sourcePath | Out-Null
                Write-Host "Symbolic link from '$customNodesInstallPath' to '$sourcePath' created successfully."
            } else {
                Write-Warning "The specified path '$sourcePath' does not exist or is not a folder. No symbolic link was created."
            }
        }
        "D" {
            # Изтегляне на препоръчителни custom nodes
            Write-Host "Download option selected for recommended custom nodes."
            $nodeRepos = @(
                "https://github.com/welltop-cn/ComfyUI-TeaCache.git",
                "https://github.com/Acly/comfyui-inpaint-nodes.git",
                "https://github.com/kaibioinfo/ComfyUI_AdvancedRefluxControl.git",
                "https://github.com/lrzjason/Comfyui-In-Context-Lora-Utils.git",
                "https://github.com/jags111/efficiency-nodes-comfyui.git",
                "https://github.com/cubiq/ComfyUI_essentials.git",
                "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git",
                "https://github.com/jamesWalker55/comfyui-various.git"
            )

            $pythonVenvPath = Join-Path -Path $InstallPath -ChildPath "venv\Scripts\python.exe"
            $originalLocation = Get-Location
            Set-Location $customNodesInstallPath

            # Клониране и инсталиране на зависимости
            foreach ($repoUrl in $nodeRepos) {
                $repoName = ($repoUrl.Split('/')[-1]).Replace(".git", "")
                Write-Host "Cloning '$repoName'..."
                git clone $repoUrl

                $repoPath = Join-Path -Path (Get-Location) -ChildPath $repoName
                $requirementsPath = Join-Path -Path $repoPath -ChildPath "requirements.txt"
                
                if (Test-Path $requirementsPath) {
                    Write-Host "Found requirements.txt for $repoName. Installing dependencies..."
                    & $pythonVenvPath -m pip install -r $requirementsPath
                }
            }
            Set-Location $originalLocation
            Write-Host "`nAll custom nodes have been downloaded and their dependencies installed."
        }
        "S" {
            Write-Host "The default local 'custom_nodes' folder will be used. Skipping."
        }
    }
}

# Функция за проверка на необходимите програми (git, python)
# Автоматично инсталира липсващите програми чрез winget ако е възможно
function Check-Prerequisites {
    Write-Host "--- Checking required programs (git, python) ---" -ForegroundColor Yellow

    $gitFound = $false
    $pythonFound = $false

    # Проверка за git
    Write-Host "Checking for git..."
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] git is installed." -ForegroundColor Green
        $gitFound = $true
    } else {
        Write-Warning "  [MISSING] git not found."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Attempting to install git via winget..."
            try {
                winget install --id Git.Git -e --source winget
                Write-Host "Git installation may require restarting the terminal to update PATH." -ForegroundColor Yellow
                Write-Host "Please restart the script in a new terminal if it fails after this step." -ForegroundColor Yellow
                if (Get-Command git -ErrorAction SilentlyContinue) {
                    Write-Host "  [OK] git installed successfully." -ForegroundColor Green
                    $gitFound = $true
                } else {
                    Write-Error "Git installation failed or PATH not updated. Please install git manually and ensure it's in your PATH, then restart the script."
                    exit 1
                }
            } catch {
                Write-Error "Failed to install git via winget. Please install it manually and ensure it's in your PATH."
                exit 1
            }
        } else {
            Write-Error "winget not found. Please install git manually (from https://git-scm.com/downloads) and ensure it's in your PATH."
            exit 1
        }
    }

    # Проверка за Python
    Write-Host "Checking for Python..."
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] Python is installed." -ForegroundColor Green
        $pythonFound = $true
    } else {
        Write-Warning "  [MISSING] Python not found."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Attempting to install Python 3.10 via winget..."
            try {
                winget install --id Python.Python.3.10 -e --source winget
                Write-Host "Python installation may require restarting the terminal to update PATH." -ForegroundColor Yellow
                Write-Host "Please restart the script in a new terminal if it fails after this step." -ForegroundColor Yellow
                if (Get-Command python -ErrorAction SilentlyContinue) {
                    Write-Host "  [OK] Python installed successfully." -ForegroundColor Green
                    $pythonFound = $true
                } else {
                    Write-Error "Python installation failed or PATH not updated. Please install Python manually and ensure it's in your PATH, then restart the script."
                    exit 1
                }
            } catch {
                Write-Error "Failed to install Python via winget. Please install it manually (from https://www.python.org/downloads/) and ensure it's in your PATH."
                exit 1
            }
        } else {
            Write-Error "winget not found. Please install Python manually (from https://www.python.org/downloads/) and ensure it's in your PATH."
            exit 1
        }
    }

    if ($gitFound -and $pythonFound) {
        Write-Host "`nAll required programs are available. Starting ComfyUI installation..." -ForegroundColor Green
    } else {
        Write-Error "One or more required programs are missing. Please install them and restart the script."
        exit 1
    }
}

# =============================================================================
# ОСНОВЕН БЛОК ЗА ИЗПЪЛНЕНИЕ
# =============================================================================

# Проверка на предварителните изисквания
Check-Prerequisites

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host " ComfyUI Multi-Instance Installation System" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Фаза 1: Избор на режим на инсталация
Write-Host "`n--- Phase 1: Select Installation Mode ---" -ForegroundColor Magenta
$installMode = ""
while ($installMode.ToUpper() -notin @('A', 'M')) {
    Write-Host "Choose an installation mode:"
    Write-Host "  [A] Automated: Configure once, install multiple identical instances."
    Write-Host "  [M] Manual: Configure each instance individually (old behavior)."
    $installMode = Read-Host "Your choice (A/M)"
}

# Въвеждане на броя инстанции
$instanceCount = 0
while ($instanceCount -le 0) {
    $inputCount = Read-Host "`nHow many ComfyUI instances do you want to install?"
    if ($inputCount -match "^\d+$" -and [int]$inputCount -gt 0) {
        $instanceCount = [int]$inputCount
    } else {
        Write-Warning "Please enter a valid positive number."
    }
}

# Фаза 2: Изпълнение според избрания режим
if ($installMode.ToUpper() -eq 'A') {
    # =============================================================================
    # АВТОМАТИЗИРАН РЕЖИМ
    # =============================================================================
    # Конфигурира се веднъж за всички инстанции, след което се инсталират идентични копия
    Write-Host "`n--- Phase 2: Automated Installation for $instanceCount instance(s) ---"
    
    # Предварителна конфигурация за всички инстанции
    $modelsSourcePath = $null
    $customNodesSourcePath = $null
    $modelsAction = ''
    $nodesAction = ''

    # Конфигуриране на Models папката за всички инстанции
    while ($modelsAction.ToUpper() -notin @('L', 'D', 'S')) {
        $modelsAction = Read-Host "`nConfigure 'models' folder for ALL instances: [L]ink to existing, [D]ownload new, [S]kip"
    }
    if ($modelsAction.ToUpper() -eq 'L') {
        $modelsSourcePath = Read-Host "Enter the full path to the GLOBAL 'models' folder"
        if (-not (Test-Path $modelsSourcePath -PathType Container)) {
            Write-Warning "Path not found. Will default to downloading in the first instance."
            $modelsAction = 'D'
        }
    }

    # Конфигуриране на Custom Nodes папката за всички инстанции
    while ($nodesAction.ToUpper() -notin @('L', 'D', 'S')) {
        $nodesAction = Read-Host "`nConfigure 'custom_nodes' folder for ALL instances: [L]ink to existing, [D]ownload new, [S]kip"
    }
    if ($nodesAction.ToUpper() -eq 'L') {
        $customNodesSourcePath = Read-Host "Enter the full path to the GLOBAL 'custom_nodes' folder"
        if (-not (Test-Path $customNodesSourcePath -PathType Container)) {
            Write-Warning "Path not found. Will default to downloading in the first instance."
            $nodesAction = 'D'
        }
    }

    # Цикъл за инсталация на всички инстанции
    for ($i = 0; $i -lt $instanceCount; $i++) {
        $comfyPath = Get-NextFreeComfyFolder
        Write-Host "`n`n=========================================================" -ForegroundColor Cyan
        Write-Host "Starting installation for instance $($i+1)/$instanceCount in '$comfyPath'" -ForegroundColor Cyan
        Write-Host "=========================================================" -ForegroundColor Cyan

        try {
            # Инсталация на ComfyUI ядрото
            $pythonVenvPath = Install-ComfyUICore -InstallPath $comfyPath           

            # Обработка на Models папката
            if ($modelsAction.ToUpper() -eq 'L') {
                # Създаване на символична връзка към глобалната models папка
                New-ComfySymbolicLink -LinkPath (Join-Path $comfyPath "models") -TargetPath $modelsSourcePath
            } elseif ($modelsAction.ToUpper() -eq 'D') {
                if ($i -eq 0) { # Изтегляне само за първата инстанция
                    Invoke-ModelDownloader -InstallPath $comfyPath
                    $modelsSourcePath = Join-Path $comfyPath "models" # Това става източникът на истината
                } else { # Връзка на следващите инстанции към първата
                    New-ComfySymbolicLink -LinkPath (Join-Path $comfyPath "models") -TargetPath $modelsSourcePath
                }
            } # 'S' (Skip) не прави нищо, използва локалната папка

            # Обработка на Custom Nodes папката
            if ($nodesAction.ToUpper() -eq 'L') {
                # Създаване на символична връзка към глобалната custom_nodes папка
                New-ComfySymbolicLink -LinkPath (Join-Path $comfyPath "custom_nodes") -TargetPath $customNodesSourcePath
            } elseif ($nodesAction.ToUpper() -eq 'D') {
                if ($i -eq 0) { # Изтегляне само за първата инстанция
                    Invoke-CustomNodeDownloader -InstallPath $comfyPath -PythonVenvPath $pythonVenvPath
                    $customNodesSourcePath = Join-Path $comfyPath "custom_nodes" # Това става източникът на истината
                } else { # Връзка на следващите инстанции към първата
                    New-ComfySymbolicLink -LinkPath (Join-Path $comfyPath "custom_nodes") -TargetPath $customNodesSourcePath
                }
            } # 'S' (Skip) не прави нищо, използва локалната папка

            # Връзка на workflows към първата инстанция ако има повече от една
            if ($i -gt 0) {
                $firstInstancePath = Join-Path -Path $PSScriptRoot -ChildPath "ComfyUI_GPU0"
                $workflowsSourcePath = Join-Path $firstInstancePath "workflows"
                if (Test-Path $workflowsSourcePath) {
                    New-ComfySymbolicLink -LinkPath (Join-Path $comfyPath "workflows") -TargetPath $workflowsSourcePath
                }
            }

        } catch {
            Write-Error "A critical error occurred during installation of instance $($i+1). Stopping script. Error: $_"
            break
        }
    }

} else {
    # =============================================================================
    # РЪЧЕН РЕЖИМ
    # =============================================================================
    # Всяка инстанция се конфигурира индивидуално
    Write-Host "`n--- Phase 2: Manual Installation for $instanceCount instance(s) ---"
    for ($i = 0; $i -lt $instanceCount; $i++) {
        $comfyPath = Get-InstanceNumber
        Write-Host "`n`n========================================================="
        Write-Host "Starting installation for instance $($i+1)/$instanceCount in '$comfyPath'"
        Write-Host "========================================================="

        try {
            # Инсталация на ComfyUI ядрото
            Install-ComfyUICore -InstallPath $comfyPath

            Write-Host "`n--- Configuring Shared Folders for $comfyPath ---"
            # Индивидуална конфигурация на споделените папки
            Setup-SharedFolderLink -InstallPath $comfyPath -FolderName "models"
            Setup-SharedFolderLink -InstallPath $comfyPath -FolderName "workflows"

            Write-Host "`n--- Configuring Custom Nodes for $comfyPath ---"
            # Индивидуална конфигурация на custom nodes
            Setup-CustomNodes -InstallPath $comfyPath

        } catch {
            Write-Error "A critical error occurred during installation of instance $($i+1). Stopping script. Error: $_"
            break
        }
    }
}

Write-Host "`n`nAll installation tasks are complete." -ForegroundColor Green