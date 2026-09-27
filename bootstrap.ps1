<#
.SYNOPSIS
    DWUT one-line bootstrap (IRM).

.DESCRIPTION
    irm https://github.com/supportpantheon-sys/Darkos-Windows-Utility-Tool-DWUT/main/bootstrap.ps1 | iex

    Downloads, installs dependencies, and launches DWUT.
    Requires Windows 10/11 with Python 3.10+ and internet access.
    Runs from a temp directory — nothing is permanently installed unless
    you move the folder yourself.

.NOTES
    Must be run as Administrator for full functionality.
    Self-elevates if needed.
#>

#Requires -Version 5.1

# ── Self-elevate if not admin ──────────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[DWUT] Not running as Administrator — requesting elevation..." -ForegroundColor Yellow
    $cmd = "& { $($MyInvocation.MyCommand.ScriptContents) }"
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $cmd"
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Config ─────────────────────────────────────────────────────────────────────
$REPO_URL   = "https://github.com/YourUser/DWUT/archive/refs/heads/main.zip"
$DEST_DIR   = "$env:TEMP\DWUT_bootstrap"
$ZIP_PATH   = "$DEST_DIR\dwut.zip"
$EXTRACT_TO = "$DEST_DIR\extracted"

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "   Darko's Windows Utility Tool — Bootstrap  " -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

# ── Python check ───────────────────────────────────────────────────────────────
try {
    $pyVer = (python --version 2>&1).ToString().Trim()
    Write-Host "[OK] $pyVer found." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Python not found. Install Python 3.10+ from https://python.org" -ForegroundColor Red
    Write-Host "        Tick 'Add Python to PATH' during installation." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# ── Detect OS ─────────────────────────────────────────────────────────────────
$build = [System.Environment]::OSVersion.Version.Build
if ($build -ge 22000) {
    $osName = "Windows 11 (build $build)"
} else {
    $osName = "Windows 10 (build $build)"
}
Write-Host "[INFO] Detected: $osName" -ForegroundColor Cyan

# ── Download ───────────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $DEST_DIR | Out-Null
Write-Host "[....] Downloading DWUT..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $REPO_URL -OutFile $ZIP_PATH -UseBasicParsing
    Write-Host "[OK] Download complete." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host "        Check your internet connection or download manually." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# ── Extract ────────────────────────────────────────────────────────────────────
Write-Host "[....] Extracting..." -ForegroundColor Yellow
if (Test-Path $EXTRACT_TO) { Remove-Item $EXTRACT_TO -Recurse -Force }
Expand-Archive -Path $ZIP_PATH -DestinationPath $EXTRACT_TO
$appDir = (Get-ChildItem $EXTRACT_TO -Directory | Select-Object -First 1).FullName
Write-Host "[OK] Extracted to: $appDir" -ForegroundColor Green

# ── Dependencies ───────────────────────────────────────────────────────────────
Write-Host "[....] Installing dependencies (pip)..." -ForegroundColor Yellow
python -m pip install --upgrade pip --quiet
pip install --upgrade customtkinter pillow psutil pywin32 pymem requests --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Some packages may not have installed cleanly." -ForegroundColor Yellow
}
Write-Host "[OK] Dependencies ready." -ForegroundColor Green

# ── Launch ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[....] Launching DWUT..." -ForegroundColor Green
Set-Location $appDir
python dmurt\run.py
