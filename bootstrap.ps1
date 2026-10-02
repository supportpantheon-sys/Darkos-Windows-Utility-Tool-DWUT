<#
.SYNOPSIS
    DWUT bootstrapper (Electron edition) - install / update / launch in one line.
.DESCRIPTION
    Paste into ANY PowerShell window:
        irm https://raw.githubusercontent.com/supportpantheon-sys/Darkos-Windows-Utility-Tool-DWUT/main/bootstrap.ps1 | iex

    Steps
      0. Self-elevates to Administrator (works for  irm | iex  and for a saved .ps1)
      1. Detects Windows 10 / 11 and CPU architecture (x64 / arm64 / x86)
      2. Finds Python 3.10+ - or INSTALLS it (winget, then python.org) if missing
      3. Gets the app: next to this script (offline/dev) OR the latest GitHub release zip
      4. Downloads the portable Electron runtime and verifies its SHA-256
      5. Installs Python packages (one per call, optional ones may fail safely)
      6. Creates a Desktop shortcut and launches DWUT

    Re-running updates to the newest release.  Parameters (saved .ps1 only):
        -Force        re-download everything
        -NoShortcut   skip the desktop shortcut
        -NoLaunch     install only
        -Source PATH  install from a local folder or .zip instead of GitHub
.NOTES
    Requires Windows 10/11 and PowerShell 5.1+. Everything lives in %LOCALAPPDATA%\DWUT.
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$NoShortcut,
    [switch]$NoLaunch,
    [string]$Source = "",
    [string]$ArgsFile = ""
)

# Options travel to the elevated window through a small JSON file, never through the
# command line (a path ending in "\" breaks Windows argument quoting and killed the window).
if ($ArgsFile -and (Test-Path $ArgsFile)) {
    try {
        $o = Get-Content $ArgsFile -Raw | ConvertFrom-Json
        if ($o.Force)      { $Force = $true }
        if ($o.NoShortcut) { $NoShortcut = $true }
        if ($o.NoLaunch)   { $NoLaunch = $true }
        if ($o.Source)     { $Source = [string]$o.Source }
    } catch { }
    Remove-Item $ArgsFile -Force -ErrorAction SilentlyContinue
}
if ($Source) { $Source = $Source.Trim().Trim('"').TrimEnd('\') }

# ---- TLS -------------------------------------------------------------------
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# ---- CONFIG ----------------------------------------------------------------
$OWNER        = "supportpantheon-sys"
$REPO         = "Darkos-Windows-Utility-Tool-DWUT"
$BRAND        = "Darko's Windows Utility Tool (DWUT)"
$ELECTRON_VER = "31.7.7"
$PY_FALLBACK  = "3.12.7"
$INSTALL_DIR  = Join-Path $env:LOCALAPPDATA "DWUT"
$APP_DIR      = Join-Path $INSTALL_DIR "app"
$RUNTIME_DIR  = Join-Path $INSTALL_DIR "electron"
$API_LATEST   = "https://api.github.com/repos/$OWNER/$REPO/releases/latest"
$RAW_BASE     = "https://raw.githubusercontent.com/$OWNER/$REPO/main"
$UA           = "DWUT-Bootstrap"

function Write-Step { param($m) Write-Host "  [....] $m" -ForegroundColor Cyan }
function Write-OK   { param($m) Write-Host "  [ OK ] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "  [ERR ] $m" -ForegroundColor Red }
function Write-Info { param($m) Write-Host "  [INFO] $m" -ForegroundColor Gray }
function Pause-Exit {
    param([string]$msg, [int]$code = 1)
    Write-Err $msg
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit $code
}

# ---- STEP 0: self-elevate ---------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [$BRAND] Requesting administrator privileges..." -ForegroundColor Yellow
    $tmpScript = Join-Path $env:TEMP "dwut_bootstrap_elevated.ps1"
    $selfPath  = $MyInvocation.MyCommand.Path
    if ($selfPath -and (Test-Path $selfPath)) {
        Copy-Item $selfPath $tmpScript -Force                       # saved file: reuse it
    } else {
        try {                                                       # irm | iex: fetch ourselves
            $ProgressPreference = "SilentlyContinue"
            Invoke-WebRequest -Uri "$RAW_BASE/bootstrap.ps1" -OutFile $tmpScript -UseBasicParsing -ErrorAction Stop
        } catch {
            Pause-Exit "Could not obtain the script for elevation. Right-click PowerShell > Run as administrator and try again."
        }
    }
    $argFile = Join-Path $env:TEMP "dwut_bootstrap_args.json"
    $srcFwd = $Source
    if (-not $srcFwd -and $selfPath) {                         # saved .ps1 next to main.js -> remember where
        $selfDir = Split-Path $selfPath -Parent
        if (Test-Path (Join-Path $selfDir "main.js")) { $srcFwd = $selfDir }
    }
    @{ Force = [bool]$Force; NoShortcut = [bool]$NoShortcut; NoLaunch = [bool]$NoLaunch; Source = $srcFwd } |
        ConvertTo-Json | Set-Content -Path $argFile -Encoding UTF8
    try {
        $p = Start-Process powershell -Verb RunAs -PassThru -Wait `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmpScript`" -ArgsFile `"$argFile`""
        Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue
        exit $p.ExitCode
    } catch {
        Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue
        Pause-Exit "Elevation was cancelled. Right-click PowerShell > Run as administrator and try again."
    }
}

# ---- running as Administrator from here -------------------------------------
$LOG_FILE = Join-Path (Join-Path $env:LOCALAPPDATA "DWUT") "bootstrap.log"
New-Item -ItemType Directory -Force -Path (Split-Path $LOG_FILE) | Out-Null
try { Start-Transcript -Path $LOG_FILE -Force | Out-Null } catch { }
try {
$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"      # Invoke-WebRequest is ~50x faster without the progress bar
Add-Type -AssemblyName System.IO.Compression.FileSystem

Write-Host ""
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |       Darko's Windows Utility Tool (DWUT)        |" -ForegroundColor Cyan
Write-Host "  |         Bootstrap Installer - Electron           |" -ForegroundColor Cyan
Write-Host "  +--------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# ---- STEP 1: OS + architecture ----------------------------------------------
$osBuild = [System.Environment]::OSVersion.Version.Build
if ($osBuild -lt 17763) { Pause-Exit "Windows 10 (1809) or newer is required. Detected build $osBuild." }
$osLabel = if ($osBuild -ge 22000) { "Windows 11" } else { "Windows 10" }
$archRaw = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
switch ($archRaw.ToUpper()) {
    "AMD64" { $arch = "x64";   $pyArch = "amd64" }
    "ARM64" { $arch = "arm64"; $pyArch = "arm64" }
    default { $arch = "ia32";  $pyArch = "" }
}
Write-OK "Detected: $osLabel (build $osBuild), $arch"
New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null

function Get-File {
    param([string]$Url, [string]$Dest, [string]$What)
    Write-Step "Downloading $What ..."
    for ($i = 1; $i -le 3; $i++) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -UserAgent $UA -ErrorAction Stop
            if ((Get-Item $Dest).Length -lt 1024) { throw "downloaded file is empty" }
            return
        } catch {
            if ($i -eq 3) { throw "Download of $What failed: $($_.Exception.Message)" }
            Write-Warn "Attempt $i failed ($($_.Exception.Message)) - retrying..."
            Start-Sleep -Seconds (2 * $i)
        }
    }
}

# ---- STEP 2: Python 3.10+ ----------------------------------------------------
function Test-Python {
    param([string]$Exe, [string[]]$PreArgs = @())
    try {
        if ($Exe -match "WindowsApps") { return $null }                  # Microsoft Store stub
        $out = & $Exe @PreArgs -c "import sys;print('%d.%d'%sys.version_info[:2]);print(sys.executable)" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $out) { return $null }
        $lines = @($out)
        if ($lines[0] -match "^(\d+)\.(\d+)$") {
            $maj = [int]$Matches[1]; $min = [int]$Matches[2]
            if ($maj -gt 3 -or ($maj -eq 3 -and $min -ge 10)) { return @{ Exe = $lines[1].Trim(); Ver = "$maj.$min" } }
        }
    } catch { }
    return $null
}
function Find-Python {
    $cands = @()
    if ($env:DWUT_PYTHON) { $cands += ,@($env:DWUT_PYTHON, @()) }
    $cands += ,@("py", @("-3"))
    $cands += ,@("python", @())
    $cands += ,@("python3", @())
    foreach ($root in @("$env:LOCALAPPDATA\Programs\Python", "$env:ProgramFiles", "${env:ProgramFiles(x86)}")) {
        if ($root -and (Test-Path $root)) {
            Get-ChildItem $root -Directory -Filter "Python3*" -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending | ForEach-Object { $cands += ,@((Join-Path $_.FullName "python.exe"), @()) }
        }
    }
    foreach ($c in $cands) {
        $exe = $c[0]
        if ($exe -notmatch "^(py|python|python3)$" -and -not (Test-Path $exe)) { continue }
        $r = Test-Python $exe $c[1]
        if ($r) { return $r }
    }
    return $null
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

Write-Step "Checking Python 3.10+ ..."
$py = Find-Python
if (-not $py) {
    Write-Warn "Python 3.10+ not found - installing it automatically."
    $installed = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            Write-Step "Installing Python 3.12 with winget ..."
            & winget install -e --id Python.Python.3.12 --scope machine --silent --accept-package-agreements --accept-source-agreements | Out-Null
            Refresh-Path; $py = Find-Python; $installed = [bool]$py
        } catch { Write-Warn "winget install failed: $($_.Exception.Message)" }
    }
    if (-not $py -and $pyArch) {
        $pyUrl = "https://www.python.org/ftp/python/$PY_FALLBACK/python-$PY_FALLBACK-$pyArch.exe"
        $pyTmp = Join-Path $env:TEMP "python-$PY_FALLBACK-$pyArch.exe"
        Get-File $pyUrl $pyTmp "Python $PY_FALLBACK (python.org)"
        Write-Step "Installing Python (silent) ..."
        $proc = Start-Process $pyTmp -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_launcher=1" -Wait -PassThru
        Remove-Item $pyTmp -Force -ErrorAction SilentlyContinue
        Refresh-Path; $py = Find-Python
    }
    if (-not $py) { Pause-Exit "Python could not be installed automatically. Install Python 3.10+ from https://www.python.org/downloads/ (tick 'Add to PATH') and run this again." }
}
$pyExe = $py.Exe
Write-OK "Python $($py.Ver) ready: $pyExe"
Set-Content -Path (Join-Path $INSTALL_DIR "python_path.txt") -Value $pyExe -Encoding ASCII
$env:DWUT_PYTHON = $pyExe

# ---- STEP 3: the app ---------------------------------------------------------
function Find-AppRoot {
    param([string]$Dir)
    if ((Test-Path (Join-Path $Dir "main.js")) -and (Test-Path (Join-Path $Dir "backend\server.py"))) { return $Dir }
    foreach ($d in Get-ChildItem $Dir -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue) {
        if ((Test-Path (Join-Path $d.FullName "main.js")) -and (Test-Path (Join-Path $d.FullName "backend\server.py"))) { return $d.FullName }
    }
    return $null
}
function Install-AppFrom {
    param([string]$Root, [string]$VersionLabel)
    # Move a pre-Electron (Tkinter) install out of the way once
    if (Test-Path (Join-Path $INSTALL_DIR "run.py")) {
        $legacy = Join-Path $INSTALL_DIR "_legacy_tk"
        New-Item -ItemType Directory -Force -Path $legacy | Out-Null
        foreach ($n in @("run.py","ui","modules","core","app","data","powershell","requirements.txt","InstallAndRun.bat")) {
            $p = Join-Path $INSTALL_DIR $n
            if (Test-Path $p) { Move-Item $p (Join-Path $legacy $n) -Force -ErrorAction SilentlyContinue }
        }
        Write-Info "Old Tkinter install moved to $legacy"
    }
    if (Test-Path $APP_DIR) { Remove-Item $APP_DIR -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $APP_DIR | Out-Null
    Copy-Item (Join-Path $Root "*") $APP_DIR -Recurse -Force -Exclude "node_modules",".git","__pycache__"
    Set-Content -Path (Join-Path $APP_DIR "version.txt") -Value $VersionLabel -Encoding ASCII
}

$versionFile = Join-Path $APP_DIR "version.txt"
$installedVer = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "" }

$localRoot = $null
if ($Source) {
    if ($Source -match "\.zip$" -and (Test-Path $Source)) {
        $x = Join-Path $env:TEMP "dwut_src"; if (Test-Path $x) { Remove-Item $x -Recurse -Force }
        [IO.Compression.ZipFile]::ExtractToDirectory($Source, $x); $localRoot = Find-AppRoot $x
    } elseif (Test-Path $Source) { $localRoot = Find-AppRoot $Source }
    if (-not $localRoot) { Pause-Exit "-Source '$Source' does not contain main.js and backend\server.py" }
} elseif ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "main.js"))) {
    $localRoot = Find-AppRoot $PSScriptRoot                       # running from the unzipped project
}

if ($localRoot) {
    Write-Step "Installing from local files: $localRoot"
    Install-AppFrom $localRoot ("local-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    Write-OK "App installed to $APP_DIR"
} else {
    Write-Step "Checking GitHub for the latest release ..."
    $tag = $null; $assetUrl = $null
    try {
        $rel = Invoke-RestMethod -Uri $API_LATEST -Headers @{ "User-Agent" = $UA; "Accept" = "application/vnd.github+json" } -ErrorAction Stop
        $tag = $rel.tag_name
        $asset = $rel.assets | Where-Object { $_.name -match "\.zip$" -and $_.name -match "(?i)electron|dwut" } | Select-Object -First 1
        if (-not $asset) { $asset = $rel.assets | Where-Object { $_.name -match "\.zip$" } | Select-Object -First 1 }
        if ($asset) { $assetUrl = $asset.browser_download_url }
    } catch { Write-Warn "GitHub API unavailable: $($_.Exception.Message)" }

    if ($tag -and $installedVer -eq $tag -and -not $Force -and (Test-Path (Join-Path $APP_DIR "main.js"))) {
        Write-OK "Already up to date ($tag)"
    } else {
        if (-not $assetUrl) { $assetUrl = "https://github.com/$OWNER/$REPO/archive/refs/heads/main.zip"; if (-not $tag) { $tag = "main" } }
        $zip = Join-Path $env:TEMP "dwut_app.zip"
        Get-File $assetUrl $zip "DWUT $tag"
        $x = Join-Path $env:TEMP "dwut_extract"; if (Test-Path $x) { Remove-Item $x -Recurse -Force }
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $x)
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        $root = Find-AppRoot $x
        if (-not $root) { Pause-Exit "The downloaded package is not the Electron edition (main.js / backend\server.py missing). Publish the Electron zip as a GitHub release asset, or run this script with -Source <folder-or-zip>." }
        Install-AppFrom $root $tag
        Remove-Item $x -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "App $tag installed to $APP_DIR"
    }
}

# ---- STEP 4: Electron runtime ------------------------------------------------
$exe = Join-Path $RUNTIME_DIR "DWUT.exe"
$runtimeStamp = Join-Path $RUNTIME_DIR "runtime.txt"
$haveRuntime = (Test-Path $exe) -and (Test-Path $runtimeStamp) -and ((Get-Content $runtimeStamp -Raw).Trim() -eq "$ELECTRON_VER-$arch")
if ($haveRuntime -and -not $Force) {
    Write-OK "Electron runtime $ELECTRON_VER present"
} else {
    $name = "electron-v$ELECTRON_VER-win32-$arch.zip"
    $base = "https://github.com/electron/electron/releases/download/v$ELECTRON_VER"
    $zip  = Join-Path $env:TEMP $name
    Get-File "$base/$name" $zip "Electron runtime $ELECTRON_VER ($arch, ~115 MB)"
    try {
        $sums = (Invoke-WebRequest -Uri "$base/SHASUMS256.txt" -UseBasicParsing -UserAgent $UA -ErrorAction Stop).Content
        $line = ($sums -split "`n" | Where-Object { $_ -match [regex]::Escape($name) } | Select-Object -First 1)
        if ($line) {
            $want = ($line.Trim() -split "\s+")[0].ToLower()
            $got  = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
            if ($want -ne $got) { Remove-Item $zip -Force; Pause-Exit "Electron download failed its SHA-256 check - aborting for safety." }
            Write-OK "SHA-256 verified"
        }
    } catch { Write-Warn "Could not fetch checksum list - skipping verification." }
    Write-Step "Extracting runtime ..."
    if (Test-Path $RUNTIME_DIR) { Remove-Item $RUNTIME_DIR -Recurse -Force }
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, $RUNTIME_DIR)
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Move-Item (Join-Path $RUNTIME_DIR "electron.exe") $exe -Force
    Set-Content -Path $runtimeStamp -Value "$ELECTRON_VER-$arch" -Encoding ASCII
    Write-OK "Electron runtime ready"
}

# ---- STEP 5: Python packages (one per call) ----------------------------------
Write-Step "Checking Python packages ..."
$required = @("psutil", "requests", "pywin32")
$optional = @("wmi", "nvidia-ml-py")          # GPU stats - safe to fail
function Test-Pkg {
    param([string]$pkg)
    $mod = @{ "pywin32" = "win32api"; "nvidia-ml-py" = "pynvml"; "psutil" = "psutil"; "requests" = "requests"; "wmi" = "wmi" }[$pkg]
    & $pyExe -c "import $mod" 2>$null
    return ($LASTEXITCODE -eq 0)
}
$ErrorActionPreference = "Continue"
foreach ($pkg in ($required + $optional)) {
    if ((Test-Pkg $pkg) -and -not $Force) { Write-Info "$pkg already installed"; continue }
    Write-Step "Installing $pkg ..."
    & $pyExe -m pip install --upgrade --disable-pip-version-check --no-warn-script-location -q $pkg 2>&1 | Out-Null
    if (Test-Pkg $pkg) { Write-OK "$pkg installed" }
    elseif ($required -contains $pkg) { Pause-Exit "Required package '$pkg' failed to install. Check your internet connection and try again." }
    else { Write-Warn "Optional package '$pkg' not installed (GPU stats may be limited)" }
}
if (Test-Pkg "pywin32") {
    $post = Join-Path (Split-Path $pyExe) "Scripts\pywin32_postinstall.py"
    if (Test-Path $post) { & $pyExe $post -install 2>&1 | Out-Null }
}
$ErrorActionPreference = "Stop"

# ---- STEP 6: shortcut + launch ------------------------------------------------
if (-not $NoShortcut) {
    try {
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "DWUT.lnk"))
        $lnk.TargetPath = $exe
        $lnk.Arguments = "`"$APP_DIR`""
        $lnk.WorkingDirectory = $APP_DIR
        $ico = Join-Path $APP_DIR "renderer\icon.ico"
        if (Test-Path $ico) { $lnk.IconLocation = $ico }
        $lnk.Description = $BRAND
        $lnk.Save()
        Write-OK "Desktop shortcut created"
    } catch { Write-Warn "Could not create shortcut: $($_.Exception.Message)" }
}
Write-Host ""
Write-OK "Installation complete."
if ($NoLaunch) { exit 0 }
Write-Step "Launching DWUT ..."
Start-Process -FilePath $exe -ArgumentList "`"$APP_DIR`"" -WorkingDirectory $APP_DIR
Start-Sleep -Seconds 2
exit 0

} catch {
    Write-Host ""
    Write-Err "Setup failed: $($_.Exception.Message)"
    if ($_.InvocationInfo) { Write-Host ("  at line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line.Trim()) -ForegroundColor DarkGray }
    Write-Host "  Full log: $LOG_FILE" -ForegroundColor Yellow
    try { Stop-Transcript | Out-Null } catch { }
    Write-Host ""
    Read-Host "  Press Enter to close"
    exit 1
}
