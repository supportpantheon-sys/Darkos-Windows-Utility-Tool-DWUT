<#
.SYNOPSIS
    DWUT one-line IRM bootstrapper.

.DESCRIPTION
    Paste this single line into an elevated PowerShell window to download,
    install, and launch Darko's Windows Utility Tool in one shot:

        irm https://raw.githubusercontent.com/supportpantheon-sys/Darkos-Windows-Utility-Tool-DWUT/main/bootstrap.ps1 | iex

    What it does:
      1. Self-elevates to Administrator if needed
      2. Detects your Windows version (10 or 11)
      3. Checks Python 3.10+ is installed (explains how to install if not)
      4. Downloads the LATEST release zip from GitHub Releases
         (always gets the newest version automatically)
      5. Extracts to %LOCALAPPDATA%\DWUT\ (persists between runs)
      6. Installs / upgrades all Python dependencies
      7. Launches DWUT

    Re-running the command later will auto-update to the newest release.

.NOTES
    Requires: Windows 10 / 11, PowerShell 5.1+, Python 3.10+
    Python download: https://www.python.org/downloads/
    Repo:  https://github.com/supportpantheon-sys/Darkos-Windows-Utility-Tool-DWUT
#>

#Requires -Version 5.1

# Enforce TLS 1.2 / TLS 1.3 for secure GitHub downloads
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# ── CONFIG ────────────────────────────────────────────────────────────────────
$OWNER     = "supportpantheon-sys"
$REPO      = "Darkos-Windows-Utility-Tool-DWUT"
$BRAND     = "Darko's Windows Utility Tool (DWUT)"
$INSTALL_DIR = Join-Path $env:LOCALAPPDATA "DWUT"
$API_LATEST  = "https://api.github.com/repos/$OWNER/$REPO/releases/latest"
$FALLBACK_ZIP = "https://github.com/$OWNER/$REPO/archive/refs/heads/main.zip"
# ─────────────────────────────────────────────────────────────────────────────

# ── HELPERS ───────────────────────────────────────────────────────────────────
function Write-Step  { param($msg) Write-Host "  [....] $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "  [ OK ] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "  [ERR ] $msg" -ForegroundColor Red }
function Write-Info  { param($msg) Write-Host "  [INFO] $msg" -ForegroundColor Gray }

function Pause-Exit {
    param([string]$msg, [int]$code = 1)
    Write-Err $msg
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit $code
}

# ── STEP 0: Self-elevate if not admin ─────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [DWUT] Requesting administrator privileges..." -ForegroundColor Yellow
    # Re-run the downloaded script content as admin
    $scriptContent = $MyInvocation.MyCommand.ScriptContents
    if (-not $scriptContent) {
        # Running via irm | iex — re-download as a file first
        $tmpScript = Join-Path $env:TEMP "dwut_bootstrap_tmp.ps1"
        $iex_url = "https://raw.githubusercontent.com/$OWNER/$REPO/main/bootstrap.ps1"
        Invoke-WebRequest -Uri $iex_url -OutFile $tmpScript -UseBasicParsing
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmpScript`""
    } else {
        $tmpScript = Join-Path $env:TEMP "dwut_bootstrap_tmp.ps1"
        $scriptContent | Set-Content $tmpScript -Encoding UTF8
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmpScript`""
    }
    exit
}

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ── BANNER ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     $BRAND     ║" -ForegroundColor Cyan
Write-Host "  ║              Bootstrap Installer                 ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── STEP 1: Detect Windows version ────────────────────────────────────────────
$osBuild = [System.Environment]::OSVersion.Version.Build
if ($osBuild -ge 22000) {
    $osLabel = "Windows 11 (build $osBuild)"
} else {
    $osLabel = "Windows 10 (build $osBuild)"
}
Write-OK "Detected OS: $osLabel"

# ── STEP 2: Python check ──────────────────────────────────────────────────────
Write-Step "Checking Python..."
$pyExe = $null
foreach ($candidate in @("python", "python3", "py")) {
    try {
        $ver = & $candidate --version 2>&1
        if ($ver -match "Python (\d+)\.(\d+)") {
            $maj = [int]$Matches[1]; $min = [int]$Matches[2]
            if ($maj -gt 3 -or ($maj -eq 3 -and $min -ge 10)) {
                $pyExe = $candidate
                Write-OK "Python $($Matches[0]) found ('$candidate')"
                break
            } else {
                Write-Warn "Found Python $maj.$min but need 3.10+. Checking for another install..."
            }
        }
    } catch { }
}

if (-not $pyExe) {
    Write-Host ""
    Write-Err "Python 3.10 or newer is required but not found."
    Write-Host "  Download it from: https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "  IMPORTANT: tick 'Add Python to PATH' during installation." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  After installing Python, re-run this command:" -ForegroundColor Gray
    Write-Host "  irm https://raw.githubusercontent.com/$OWNER/$REPO/main/bootstrap.ps1 | iex" -ForegroundColor White
    Write-Host ""
    Read-Host "  Press Enter to open the Python download page then exit"
    Start-Process "https://www.python.org/downloads/"
    exit 1
}

# ── STEP 3: Get latest release from GitHub ────────────────────────────────────
Write-Step "Fetching latest release info from GitHub..."
$latestTag  = $null
$downloadUrl = $null

try {
    $release = Invoke-RestMethod -Uri $API_LATEST -Headers @{Accept="application/vnd.github+json"} -TimeoutSec 10
    $latestTag = $release.tag_name

    # Prefer a .zip release asset; fall back to source zip
    $asset = $release.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
    if ($asset) {
        $downloadUrl = $asset.browser_download_url
    } else {
        $downloadUrl = $release.zipball_url
    }
    Write-OK "Latest release: $latestTag"
} catch {
    Write-Warn "Could not reach GitHub releases — using main branch zip instead."
    $downloadUrl = $FALLBACK_ZIP
    $latestTag   = "main"
}

# ── STEP 4: Check if already installed and up to date ────────────────────────
$versionFile = Join-Path $INSTALL_DIR "installed_version.txt"
$alreadyInstalled = $false

if (Test-Path $versionFile) {
    $installedTag = (Get-Content $versionFile -Raw).Trim()
    if ($installedTag -eq $latestTag -and $latestTag -ne "main") {
        Write-OK "DWUT $latestTag is already installed and up to date."
        $alreadyInstalled = $true
    } else {
        Write-Info "Installed: $installedTag  →  Updating to: $latestTag"
    }
}

# ── STEP 5: Download & extract ───────────────────────────────────────────────
if (-not $alreadyInstalled) {
    $zipPath    = Join-Path $env:TEMP "DWUT_download.zip"
    $extractTmp = Join-Path $env:TEMP "DWUT_extract_tmp"

    Write-Step "Downloading DWUT $latestTag..."
    try {
        # Use BITS if available (more reliable for large files), fall back to WebRequest
        try {
            Import-Module BitsTransfer -ErrorAction Stop
            Start-BitsTransfer -Source $downloadUrl -Destination $zipPath -DisplayName "DWUT Download"
        } catch {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        }
        Write-OK "Download complete ($([math]::Round((Get-Item $zipPath).Length / 1KB)) KB)"
    } catch {
        Pause-Exit "Download failed: $_`nCheck your internet connection and try again."
    }

    Write-Step "Extracting..."
    if (Test-Path $extractTmp) { Remove-Item $extractTmp -Recurse -Force }
    try {
        Expand-Archive -Path $zipPath -DestinationPath $extractTmp -Force
    } catch {
        Pause-Exit "Extraction failed: $_"
    }

    # GitHub source zips have a single top-level folder; flatten it
    $inner = Get-ChildItem $extractTmp -Directory | Select-Object -First 1
    $sourceRoot = if ($inner) { $inner.FullName } else { $extractTmp }

    # Copy into install dir
    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }

    Write-Step "Installing to $INSTALL_DIR..."
    # Copy everything, overwriting existing files
    Get-ChildItem $sourceRoot -Recurse | ForEach-Object {
        $dest = $_.FullName.Replace($sourceRoot, $INSTALL_DIR)
        if ($_.PSIsContainer) {
            if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
        } else {
            Copy-Item $_.FullName -Destination $dest -Force
        }
    }

    # Record installed version
    $latestTag | Set-Content $versionFile -Encoding UTF8

    # Cleanup temp files
    Remove-Item $zipPath    -Force -ErrorAction SilentlyContinue
    Remove-Item $extractTmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Installed successfully."
}

# ── STEP 6: Install / upgrade Python dependencies ────────────────────────────
Write-Step "Installing Python dependencies..."

& $pyExe -m pip install --upgrade pip --quiet --no-warn-script-location 2>&1 | Out-Null

$deps = @("customtkinter>=5.2.0", "Pillow>=10.0.0", "psutil>=5.9.0", "pywin32>=306", "pymem>=1.12.0", "requests>=2.31.0")

# Use requirements.txt if present
$reqFile = Join-Path $INSTALL_DIR "requirements.txt"
if (Test-Path $reqFile) {
    & $pyExe -m pip install --upgrade -r $reqFile --quiet --no-warn-script-location 2>&1 | Out-Null
} else {
    & $pyExe -m pip install --upgrade ($deps -join " ") --quiet --no-warn-script-location 2>&1 | Out-Null
}

if ($LASTEXITCODE -ne 0) {
    Write-Warn "Some packages may not have installed cleanly."
    Write-Warn "Try running manually:  pip install $($deps -join ' ')"
} else {
    Write-OK "All dependencies installed."
}

# ── STEP 7: OpenHardwareMonitor hint ─────────────────────────────────────────
Write-Host ""
Write-Info "For GPU temperature / load on the Dashboard:"
Write-Info "  Install OpenHardwareMonitor from https://openhardwaremonitor.org/"
Write-Info "  Run it before launching DWUT. (Optional — DWUT works without it.)"
Write-Host ""

# ── STEP 8: Launch DWUT ──────────────────────────────────────────────────────
# Find run.py — handle both flat and nested layouts
$runScript = $null
foreach ($candidate in @(
    (Join-Path $INSTALL_DIR "dmurt\run.py"),
    (Join-Path $INSTALL_DIR "run.py"),
    # GitHub source zip extracts with the repo name as top folder
    (Join-Path $INSTALL_DIR "$REPO-main\dmurt\run.py"),
    (Join-Path $INSTALL_DIR "$REPO-main\run.py")
)) {
    if (Test-Path $candidate) { $runScript = $candidate; break }
}

if (-not $runScript) {
    # Last resort: search recursively
    $found = Get-ChildItem $INSTALL_DIR -Filter "run.py" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $runScript = $found.FullName }
}

if (-not $runScript) {
    Pause-Exit "Could not find run.py in $INSTALL_DIR. The download may have failed or the repo structure changed."
}

$appDir = Split-Path $runScript -Parent
Write-Step "Launching DWUT from $appDir..."
Set-Location $appDir
Write-Host ""

& $pyExe $runScript

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Err "DWUT exited with an error (code $LASTEXITCODE)."
    Write-Info "Check the log file in $env:APPDATA\DWUT\ for details."
    Read-Host "Press Enter to exit"
}
