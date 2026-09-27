@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  DWUT — InstallAndRun.bat
::  One-click install + launch for Darko's Windows Utility Tool
::
::  What this does:
::    1. Requests admin rights (UAC prompt)
::    2. Checks Python 3.10+ is installed
::    3. Upgrades pip and installs all Python dependencies
::    4. Optionally self-updates from GitHub if a newer version
::       is available (checks the releases page)
::    5. Launches DWUT
::
::  Run this bat from the folder where you extracted DWUT.
::  You don't need to open a terminal — just double-click.
:: ============================================================

title DWUT — Launching...

:: ── Step 1: Request admin rights ────────────────────────────────────────────
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [DWUT] Requesting administrator privileges...
    powershell -NoProfile -Command ^
        "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cls
echo.
echo  =====================================================
echo    Darko's Windows Utility Tool  ^|  Launcher
echo  =====================================================
echo.

:: ── Step 2: Python check ────────────────────────────────────────────────────
python --version >nul 2>&1
if %errorLevel% neq 0 (
    echo  [ERROR] Python not found on PATH.
    echo.
    echo  Install Python 3.10 or newer from:
    echo    https://www.python.org/downloads/
    echo.
    echo  IMPORTANT: tick "Add Python to PATH" during install.
    echo.
    pause
    exit /b 1
)

for /f "tokens=2" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
echo  [OK] Python %PY_VER% detected.

:: ── Step 3: pip + dependencies ──────────────────────────────────────────────
echo  [....] Installing / upgrading dependencies...
python -m pip install --upgrade pip --quiet --no-warn-script-location 2>nul
python -m pip install --upgrade ^
    customtkinter ^
    Pillow ^
    psutil ^
    pywin32 ^
    pymem ^
    requests ^
    --quiet --no-warn-script-location 2>nul

if %errorLevel% neq 0 (
    echo  [WARN] Some packages may not have installed cleanly.
    echo         Try running:  pip install -r requirements.txt
) else (
    echo  [OK]   Dependencies ready.
)

:: ── Step 4: Optional self-update check ──────────────────────────────────────
echo  [....] Checking for updates...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$r = try { (Invoke-WebRequest -Uri 'https://api.github.com/repos/supportpantheon-sys/Darkos-Windows-Utility-Tool-DWUT/releases/latest' -UseBasicParsing -TimeoutSec 5).Content | ConvertFrom-Json } catch { $null }; if ($r -and $r.tag_name) { Write-Host $r.tag_name } else { Write-Host 'unknown' }" ^
    > "%TEMP%\dwut_latest_tag.txt" 2>nul

set LATEST_TAG=unknown
if exist "%TEMP%\dwut_latest_tag.txt" (
    set /p LATEST_TAG=<"%TEMP%\dwut_latest_tag.txt"
    del "%TEMP%\dwut_latest_tag.txt" >nul 2>&1
)

if "!LATEST_TAG!" == "unknown" (
    echo  [INFO] Could not reach GitHub — skipping update check.
) else (
    echo  [INFO] Latest release: !LATEST_TAG!
    echo         To update: download the latest zip from
    echo         https://github.com/supportpantheon-sys/Darkos-Windows-Utility-Tool-DWUT/releases
)

:: ── Step 5: OpenHardwareMonitor notice ──────────────────────────────────────
echo.
echo  [INFO] For GPU stats on the Dashboard, run OpenHardwareMonitor first.
echo         Free download: https://openhardwaremonitor.org/
echo         DWUT works fine without it.
echo.

:: ── Step 6: Launch DWUT ─────────────────────────────────────────────────────
echo  [....] Starting DWUT...
echo.
cd /d "%~dp0"

if exist "dmurt\run.py" (
    python dmurt\run.py
) else if exist "run.py" (
    python run.py
) else (
    echo  [ERROR] Cannot find run.py.
    echo          Make sure this .bat is in the DWUT folder next to dmurt\.
    pause
    exit /b 1
)

if %errorLevel% neq 0 (
    echo.
    echo  [ERROR] DWUT exited with an error ^(code %errorLevel%^).
    echo          Check the log file in %%APPDATA%%\DWUT\ for details.
    pause
)
