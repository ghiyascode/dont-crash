# ---------------------------------------------------------------------------
# One-command installer for the CARLA 0.9.16 simulation environment (Windows).
#
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Help
#
# Installs CARLA 0.9.16 (+ additional maps), ScenarioRunner v0.9.16, a conda
# environment with the CARLA client and dependencies, PyTorch (CUDA build on
# NVIDIA, CPU build otherwise), and the helper scripts, then runs a smoke test
# that renders one frame. Installs Miniforge if conda is not found.
#
# Safe to re-run: completed steps are skipped and interrupted downloads resume.
# Compatible with Windows PowerShell 5.1 and PowerShell 7.
# ---------------------------------------------------------------------------
param(
    [string]$Dir = (Join-Path $env:USERPROFILE "carla-sim"),
    [string]$EnvName = "carla",
    [switch]$NoMaps,
    [ValidateSet("auto", "cuda", "cpu", "none")]
    [string]$Torch = "auto",
    [switch]$NoTorch,
    [switch]$NoSmokeTest,
    [switch]$RemoveArchives,
    [switch]$ReuseEnv,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$CarlaVersion = "0.9.16"
$SrTag = "v0.9.16"
$PythonVersion = "3.11"
$TorchVersion = "2.8.0"
$TorchvisionVersion = "0.23.0"
$CarlaUrl = "https://downloads.carlasim.com/Windows/CARLA_$CarlaVersion.zip"
$MapsUrl = "https://downloads.carlasim.com/Windows/AdditionalMaps_$CarlaVersion.zip"
$SrRepo = "https://github.com/carla-simulator/scenario_runner.git"
$MiniforgeUrl = "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Windows-x86_64.exe"
$TorchIndex = "https://download.pytorch.org/whl"
# Marker file placed in environments this installer creates. An existing env
# without it belongs to something else and is not modified unless -ReuseEnv.
$EnvMarker = ".carla-sim-installer"

# Sizes in GiB, used for the free-space check (extracted sizes measured on the
# Linux package; the Windows archives are 7.3 and 6.8 GiB).
$Size = @{ CarlaZip = 8; CarlaExtracted = 19; MapsZip = 7; MapsExtracted = 11; PyEnv = 8 }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SetupDir = Join-Path $ScriptDir "setup"

if ($Help) {
    @"
Usage: powershell -ExecutionPolicy Bypass -File .\install.ps1 [options]

Options:
  -Dir PATH          Install location (default: %USERPROFILE%\carla-sim)
  -EnvName NAME      Conda environment name (default: carla)
  -NoMaps            Skip the additional maps (saves ~18 GB)
  -Torch MODE        PyTorch build: auto, cuda, cpu, or none (default: auto;
                     cuda on NVIDIA GPUs, cpu otherwise)
  -NoTorch           Same as -Torch none
  -NoSmokeTest       Skip the final smoke test
  -RemoveArchives    Delete the downloaded archives after extraction
  -ReuseEnv          Allow installing into an existing conda environment that
                     this installer did not create (its packages will change)
  -Help              Show this help
"@
    exit 0
}
if ($NoTorch) { $Torch = "none" }

# --- output helpers --------------------------------------------------------

$script:ServerProc = $null
function Stop-Server {
    if ($script:ServerProc) {
        Invoke-Quiet { taskkill.exe /PID $script:ServerProc.Id /T /F } | Out-Null
        $script:ServerProc = $null
    }
}
function Step($msg) { Write-Host ""; Write-Host "==> $msg" }
function Info($msg) { Write-Host "    $msg" }
function Warn($msg) { Write-Host "warning: $msg" -ForegroundColor Yellow }
function Fail($msg) {
    Write-Host ""
    Write-Host "error: $msg" -ForegroundColor Red
    Stop-Server
    try { Stop-Transcript | Out-Null } catch { }
    exit 1
}
# Run a native command and fail on a non-zero exit code. Native stderr is left
# alone: in Windows PowerShell 5.1, redirecting it turns each stderr line into
# an error, which stops the script under ErrorActionPreference = Stop.
function Invoke-Checked($what, [scriptblock]$cmd) {
    & $cmd
    if ($LASTEXITCODE -ne 0) { Fail "$what failed (exit code $LASTEXITCODE)" }
}
# Run a native command with stderr discarded; $LASTEXITCODE is preserved.
function Invoke-Quiet([scriptblock]$cmd) {
    $eap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & $cmd 2>$null } finally { $ErrorActionPreference = $eap }
}

# --- argument validation ---------------------------------------------------

if ($EnvName -notmatch '^[A-Za-z0-9._-]+$') { Fail "invalid environment name: '$EnvName'" }
# Resolve relative to PowerShell's location (not the .NET working directory).
$Dir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Dir)
$CarlaRoot = Join-Path $Dir "CARLA_$CarlaVersion"
$SrDir = Join-Path $Dir "scenario_runner"
$DlDir = Join-Path $Dir "downloads"
$LogDir = Join-Path $Dir "logs"
New-Item -ItemType Directory -Force -Path $DlDir, $LogDir | Out-Null

$Log = Join-Path $LogDir ("install-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
Start-Transcript -Path $Log -Append | Out-Null
$StartTime = Get-Date

Write-Host "CARLA $CarlaVersion installer - $(Get-Date)"
Write-Host "Install location: $Dir"
Write-Host "Log file:         $Log"

# --- 1. preflight ----------------------------------------------------------

Step "Checking system"

if ($env:OS -ne "Windows_NT") { Fail "this installer is for Windows; on Linux use install.sh" }
if (-not [Environment]::Is64BitOperatingSystem) { Fail "CARLA requires 64-bit Windows" }
foreach ($cmd in @("curl.exe", "tar.exe", "git")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        if ($cmd -eq "git") { Fail "git is required. Install it with: winget install Git.Git" }
        Fail "$cmd is required (included with Windows 10 version 1803 and later)"
    }
}

if (-not (Test-Path (Join-Path $env:WINDIR "System32\vulkan-1.dll"))) {
    Warn "the Vulkan runtime (vulkan-1.dll) was not found; it is installed with current NVIDIA and AMD drivers"
} else {
    Info "Vulkan runtime: found"
}

$Gpu = "unknown"
$gpuNames = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })
if ((Get-Command nvidia-smi -ErrorAction SilentlyContinue) -and ((& nvidia-smi -L) -match "GPU")) {
    $Gpu = "nvidia"
    Info ("GPU: " + (& nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | Select-Object -First 1) + " (NVIDIA driver OK)")
} elseif ($gpuNames -match "NVIDIA") {
    $Gpu = "nvidia"
    Warn "NVIDIA GPU detected but nvidia-smi is not working. Install the NVIDIA driver; CARLA cannot render without it."
} elseif ($gpuNames -match "AMD|Radeon") {
    $Gpu = "amd"
    Info ("GPU: " + (($gpuNames -match "AMD|Radeon") | Select-Object -First 1))
}
if ($Gpu -eq "unknown") { Warn "could not identify a dedicated GPU; CARLA requires an NVIDIA or AMD GPU with Vulkan support" }

if ($Torch -eq "auto") {
    $Torch = if ($Gpu -eq "nvidia") { "cuda" } else { "cpu" }
    Info "PyTorch build: $Torch (auto-selected)"
}

function Test-CarlaExtracted { Test-Path (Join-Path $CarlaRoot "CarlaUE4.exe") }
# The base package already contains Town06's OpenDRIVE/nav data; only the
# additional maps archive contains the map itself.
function Test-MapsExtracted { Test-Path (Join-Path $CarlaRoot "CarlaUE4\Content\Carla\Maps\Town06.umap") }

# --- 2. conda --------------------------------------------------------------

Step "Conda"

$CondaBase = $null
foreach ($d in @("$env:USERPROFILE\miniforge3", "$env:USERPROFILE\miniconda3", "$env:USERPROFILE\anaconda3",
                 "$env:LOCALAPPDATA\miniforge3", "$env:ProgramData\miniforge3")) {
    if (Test-Path (Join-Path $d "Scripts\conda.exe")) { $CondaBase = $d; break }
}
if (-not $CondaBase) {
    $c = Get-Command conda.exe -ErrorAction SilentlyContinue
    if ($c) { $CondaBase = Split-Path -Parent (Split-Path -Parent $c.Source) }
}
$MiniforgeInstalled = $false
if (-not $CondaBase) {
    Info "conda not found; installing Miniforge into $env:USERPROFILE\miniforge3"
    $installer = Join-Path $DlDir "Miniforge3-Windows-x86_64.exe"
    Invoke-Checked "Miniforge download" { curl.exe -fsSL --retry 3 -o $installer $MiniforgeUrl }
    $p = Start-Process -FilePath $installer -Wait -PassThru -ArgumentList @(
        "/InstallationType=JustMe", "/RegisterPython=0", "/AddToPath=0", "/S", "/D=$env:USERPROFILE\miniforge3")
    if ($p.ExitCode -ne 0) { Fail "Miniforge installation failed (exit code $($p.ExitCode))" }
    $CondaBase = "$env:USERPROFILE\miniforge3"
    $MiniforgeInstalled = $true
}
$Conda = Join-Path $CondaBase "Scripts\conda.exe"
Info "Using conda at $CondaBase ($(& $Conda --version))"

# setup_env.ps1 needs conda's PowerShell integration and permission to run
# local scripts.
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Undefined" -or $policy -eq "Restricted") {
    try {
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
        Info "Set the PowerShell execution policy for the current user to RemoteSigned"
    } catch {
        Warn "could not set the execution policy ($($_.Exception.Message)); setup_env.ps1 may be blocked"
    }
}
Invoke-Checked "conda init powershell" { & $Conda init powershell | Out-Null }
Info "conda is enabled for new PowerShell windows"

# Environment paths from conda's JSON output (robust to spaces in paths).
function Get-EnvPath($name) {
    $envs = (& $Conda env list --json | Out-String | ConvertFrom-Json).envs
    foreach ($p in $envs) {
        if ((Split-Path -Leaf $p) -eq $name -and (Split-Path -Leaf (Split-Path -Parent $p)) -eq "envs") { return $p }
    }
    return $null
}
function Test-EnvExists($name) { return [bool](Get-EnvPath $name) }

Step "Disk space"
$need = 0
if (-not (Test-CarlaExtracted)) {
    if (-not (Test-Path (Join-Path $DlDir "CARLA_$CarlaVersion.zip"))) { $need += $Size.CarlaZip }
    $need += $Size.CarlaExtracted
}
if (-not $NoMaps -and -not (Test-MapsExtracted)) {
    if (-not (Test-Path (Join-Path $DlDir "AdditionalMaps_$CarlaVersion.zip"))) { $need += $Size.MapsZip }
    $need += $Size.MapsExtracted
}
if (-not (Test-EnvExists $EnvName)) { $need += $Size.PyEnv }
$driveRoot = [System.IO.Path]::GetPathRoot($Dir)
$free = [math]::Floor((New-Object System.IO.DriveInfo $driveRoot).AvailableFreeSpace / 1GB)
Info "Disk: $free GB free, about $need GB needed"
if ($free -lt $need) { Fail "not enough free disk space on $driveRoot ($free GB free, ~$need GB needed). Use -NoMaps or -Dir to choose another location." }

# --- 3. download -----------------------------------------------------------

function Get-RemoteSize($url) {
    $len = $null
    foreach ($line in (& curl.exe -sIL --max-time 30 $url)) {
        if ($line -match '^content-length:\s*(\d+)') { $len = [int64]$Matches[1] }
    }
    return $len
}
function Get-FileSize($path) {
    if (Test-Path $path) { return (Get-Item $path).Length } else { return [int64]0 }
}
function Get-Archive($url, $dest) {
    $name = Split-Path -Leaf $dest
    $want = Get-RemoteSize $url
    if (-not $want) { Fail "cannot reach $url" }
    $have = Get-FileSize $dest
    if ($have -eq $want) { Info "${name}: already downloaded"; return }
    if ($have -gt $want) { Remove-Item $dest; $have = 0 }
    if ($have -gt 0) {
        Info ("{0}: resuming at {1} of {2} MB" -f $name, [math]::Floor($have / 1MB), [math]::Floor($want / 1MB))
    } else {
        Info ("{0}: downloading {1} MB" -f $name, [math]::Floor($want / 1MB))
    }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        & curl.exe -fL --retry 5 --retry-delay 10 -C - --progress-bar -o $dest $url
        $rc = $LASTEXITCODE
        if ($rc -eq 0) { break }
        if ($rc -eq 33) {
            # The server refused to resume (no byte-range support on this request).
            Warn "the server would not resume $name; restarting it from the beginning"
            Remove-Item -Force $dest
        } else {
            Warn "download interrupted (curl exit $rc, attempt $attempt of 3); resuming"
        }
        Start-Sleep -Seconds 5
    }
    $have = Get-FileSize $dest
    if ($have -ne $want) { Fail "$name is incomplete ($have of $want bytes). Re-run the installer to resume." }
    Info "${name}: complete"
}

Step "Downloading CARLA $CarlaVersion"
if (Test-CarlaExtracted) {
    Info "CARLA already installed in $CarlaRoot"
} else {
    Get-Archive $CarlaUrl (Join-Path $DlDir "CARLA_$CarlaVersion.zip")
}
if (-not $NoMaps) {
    if (Test-MapsExtracted) {
        Info "Additional maps already installed"
    } else {
        Get-Archive $MapsUrl (Join-Path $DlDir "AdditionalMaps_$CarlaVersion.zip")
    }
}

# --- 4. extract ------------------------------------------------------------

Step "Extracting"
New-Item -ItemType Directory -Force -Path $CarlaRoot | Out-Null
if (Test-CarlaExtracted) {
    Info "CARLA: already extracted"
} else {
    Info "CARLA: extracting (several minutes)"
    Invoke-Checked "CARLA extraction" { tar.exe -xf (Join-Path $DlDir "CARLA_$CarlaVersion.zip") -C $CarlaRoot }
    if (-not (Test-CarlaExtracted)) { Fail "extraction finished but CarlaUE4.exe is missing in $CarlaRoot" }
    Info "CARLA: done"
}
if (-not $NoMaps) {
    if (Test-MapsExtracted) {
        Info "Additional maps: already extracted"
    } else {
        Info "Additional maps: extracting (several minutes)"
        Invoke-Checked "map extraction" { tar.exe -xf (Join-Path $DlDir "AdditionalMaps_$CarlaVersion.zip") -C $CarlaRoot }
        if (-not (Test-MapsExtracted)) { Fail "map extraction finished but Town06 is missing" }
        Info "Additional maps: done"
    }
}
if ($RemoveArchives) {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $DlDir "CARLA_$CarlaVersion.zip"), (Join-Path $DlDir "AdditionalMaps_$CarlaVersion.zip")
    Info "Removed downloaded archives"
}

# --- 5. ScenarioRunner -----------------------------------------------------

Step "ScenarioRunner $SrTag"
if (Test-Path (Join-Path $SrDir ".git")) {
    $tag = Invoke-Quiet { git -C $SrDir describe --tags --exact-match }
    if ($tag -eq $SrTag) {
        Info "Already cloned at $SrTag"
    } else {
        Warn "$SrDir exists at '$tag', expected $SrTag; leaving it unchanged"
    }
} else {
    Invoke-Checked "ScenarioRunner clone" { git -c advice.detachedHead=false clone --quiet --depth 1 --branch $SrTag $SrRepo $SrDir }
    Info "Cloned into $SrDir"
}

# --- 6. Python environment -------------------------------------------------

Step "Python environment '$EnvName'"
if (Test-EnvExists $EnvName) {
    $EnvDir = Get-EnvPath $EnvName
    if (Test-Path (Join-Path $EnvDir $EnvMarker)) {
        Info "Environment exists"
    } elseif ($ReuseEnv) {
        New-Item -ItemType File -Force -Path (Join-Path $EnvDir $EnvMarker) | Out-Null
        Info "Using existing environment (-ReuseEnv)"
    } else {
        Fail "a conda environment named '$EnvName' already exists and was not created by this installer. Installing into it would change its packages (for example, numpy would be set to 1.24.4). Use -EnvName <new-name> for a separate environment, or -ReuseEnv to install into it anyway."
    }
} else {
    Invoke-Checked "conda create" { & $Conda create -y -q -n $EnvName "python=$PythonVersion" | Out-Null }
    $EnvDir = Get-EnvPath $EnvName
    if (-not $EnvDir) { Fail "environment '$EnvName' was not found after creation" }
    New-Item -ItemType File -Force -Path (Join-Path $EnvDir $EnvMarker) | Out-Null
    Info "Created with Python $PythonVersion"
}
$Py = Join-Path $EnvDir "python.exe"
if (-not (Test-Path $Py)) { Fail "python.exe not found in environment '$EnvName' ($EnvDir)" }
# Equivalent of activating the environment for this process.
$env:PATH = "$EnvDir;$EnvDir\Library\bin;$EnvDir\Scripts;$env:PATH"

$pyVer = & $Py -c "import sys; print('%d.%d' % sys.version_info[:2])"
if ($pyVer -ne $PythonVersion) { Fail "environment '$EnvName' uses Python $pyVer; Python $PythonVersion is required. Remove it or choose another name with -EnvName." }

Info "Installing CARLA client, example, and ScenarioRunner dependencies"
Invoke-Checked "pip install" {
    & $Py -m pip install --disable-pip-version-check -q "carla==$CarlaVersion" `
        -r (Join-Path $SetupDir "requirements-examples.txt") -r (Join-Path $SrDir "requirements.txt")
}
& $Py -m pip check | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "dependency conflict in '$EnvName' (run: conda activate $EnvName; pip check)" }
Info "Dependencies installed"

# --- 7. PyTorch ------------------------------------------------------------

Step "PyTorch ($Torch)"
$TorchResult = "not installed"
if ($Torch -eq "none") {
    Info "Skipped"
} else {
    $check = "import sys, torch; ok = torch.__version__.startswith('$TorchVersion') and ((torch.version.cuda is not None) == ('$Torch' == 'cuda')); sys.exit(0 if ok else 1)"
    Invoke-Quiet { & $Py -c $check }
    if ($LASTEXITCODE -eq 0) {
        Info "PyTorch $TorchVersion ($Torch) already installed"
    } else {
        # On Windows the CUDA libraries are bundled in the torch wheel, so the
        # pypi.nvidia.com fallback used on Linux is not needed.
        $index = if ($Torch -eq "cuda") { "$TorchIndex/cu128" } else { "$TorchIndex/cpu" }
        Invoke-Checked "PyTorch install" {
            & $Py -m pip install --disable-pip-version-check "torch==$TorchVersion" "torchvision==$TorchvisionVersion" --index-url $index
        }
    }
    $TorchResult = & $Py -c "import torch; print(f'{torch.__version__}, CUDA available: {torch.cuda.is_available()}')"
    Info "PyTorch $TorchResult"
    if ($Torch -eq "cuda" -and $TorchResult -notmatch "CUDA available: True") {
        Warn "PyTorch was installed but cannot see the GPU; check the NVIDIA driver"
    }
}

# --- 8. helper scripts -----------------------------------------------------

Step "Helper scripts"
# Write each file; an existing copy that differs from the new version is kept
# as <name>.bak. The PowerShell helpers are pointed at this install location
# and environment, and saved as UTF-8 with BOM for Windows PowerShell 5.1.
$dirLiteral = $Dir.Replace("'", "''")
$utf8Bom = New-Object System.Text.UTF8Encoding $true
function Install-File($src, $dest) {
    $text = [System.IO.File]::ReadAllText($src)
    if ($dest -like "*.ps1") {
        $text = $text -replace '(?m)^\$DefaultSimDir = .*$', "`$DefaultSimDir = '$dirLiteral'"
        $text = $text -replace '(?m)^\$DefaultCondaEnv = .*$', "`$DefaultCondaEnv = '$EnvName'"
    }
    if (Test-Path $dest) {
        if ([System.IO.File]::ReadAllText($dest) -eq $text) { return }
        Copy-Item $dest "$dest.bak" -Force
        Info "Kept your previous $(Split-Path -Leaf $dest) as $(Split-Path -Leaf $dest).bak"
    }
    $enc = if ($dest -like "*.ps1") { $utf8Bom } else { New-Object System.Text.UTF8Encoding $false }
    [System.IO.File]::WriteAllText($dest, $text, $enc)
}
New-Item -ItemType Directory -Force -Path (Join-Path $Dir "smoketest") | Out-Null
Install-File (Join-Path $SetupDir "windows\setup_env.ps1") (Join-Path $Dir "setup_env.ps1")
Install-File (Join-Path $SetupDir "windows\launch_carla.ps1") (Join-Path $Dir "launch_carla.ps1")
foreach ($f in Get-ChildItem (Join-Path $SetupDir "smoketest") -Filter *.py) {
    Install-File $f.FullName (Join-Path (Join-Path $Dir "smoketest") $f.Name)
}
Info "Installed setup_env.ps1, launch_carla.ps1, and smoketest\ into $Dir"

# --- 9. smoke test ---------------------------------------------------------

function Test-Port2000 {
    $client = New-Object System.Net.Sockets.TcpClient
    try { $client.Connect("127.0.0.1", 2000); return $true } catch { return $false } finally { $client.Close() }
}

$SmokeResult = "skipped"
$SmokeFailed = $false
if (-not $NoSmokeTest) {
    Step "Smoke test"
    if (Test-Port2000) {
        Warn "port 2000 is in use (is CARLA already running?); skipping the smoke test"
        $SmokeResult = "skipped (port 2000 in use)"
    } else {
        Info "Starting CARLA headless (allow up to 3 minutes on first launch)"
        # finally also runs on Ctrl+C, so the server is never left running.
        try {
            $startArgs = @{
                FilePath     = (Join-Path $CarlaRoot "CarlaUE4.exe")
                ArgumentList = @("-carla-rpc-port=2000", "-nosound", "-RenderOffScreen")
                PassThru     = $true
            }
            # -WindowStyle exists only on Windows ($IsLinux is undefined in 5.1).
            if (-not $IsLinux) { $startArgs.WindowStyle = "Hidden" }
            $script:ServerProc = Start-Process @startArgs
            $up = $false
            $deadline = (Get-Date).AddMinutes(3)
            while ((Get-Date) -lt $deadline) {
                if (Test-Port2000) { $up = $true; break }
                if ($script:ServerProc.HasExited) { break }
                Start-Sleep -Seconds 1
            }
            $frame = Join-Path $LogDir "smoketest-frame.png"
            if ($up) {
                & $Py (Join-Path $Dir "smoketest\carla_smoketest.py") --town Town10HD_Opt --out $frame
            }
            if ($up -and $LASTEXITCODE -eq 0) {
                $SmokeResult = "passed (frame saved to $frame)"
            } else {
                if (-not $up) { Warn "the CARLA server did not open port 2000 within 3 minutes" }
                $SmokeResult = "FAILED"
                $SmokeFailed = $true
            }
        } finally {
            Stop-Server
        }
    }
}

# --- summary ---------------------------------------------------------------

$elapsed = (Get-Date) - $StartTime
$mapsNote = if ($NoMaps) { "" } else { " (with additional maps)" }
Write-Host ""
Write-Host "==> Installation summary"
Write-Host "    CARLA:          $CarlaRoot$mapsNote"
Write-Host "    ScenarioRunner: $SrDir"
Write-Host "    Python env:     $EnvName (Python $PythonVersion)"
Write-Host "    PyTorch:        $TorchResult"
Write-Host "    Smoke test:     $SmokeResult"
Write-Host ("    Elapsed:        {0} min {1} s" -f [math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds)
Write-Host ""
Write-Host "Next steps (in a new PowerShell window):"
Write-Host "    cd $Dir"
Write-Host "    . .\setup_env.ps1        # in each new window"
Write-Host "    .\launch_carla.ps1       # start the simulator"
if ($MiniforgeInstalled) { Write-Host "    (Miniforge was installed in $CondaBase.)" }

try { Stop-Transcript | Out-Null } catch { }
if ($SmokeFailed) { exit 1 } else { exit 0 }
