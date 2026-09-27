# Darko's Windows Utility Tool (DWUT)

* UTILITY TOOL DESIGNED FOR WINDOWS 10 AND 11.

* FEATURES DEABLOATING, PRIVACY TWEAKS, DISK CLEANUP, PROXY MANAGMENT, SYSTEM TWEAKS, REGISTRY CLEANUPS, OPTIMIZATION TWEAKS, QUICK ACTION BUTTONS FOR WINDOWS SETTINGS MENUS, ASWELL AS GAME BOOSTERS/FPS UNLOCKERS

## Requirements

- Windows 10 / 11
- Python 3.10+
- Administrator privileges (required for most features)

## Install

```bat
pip install customtkinter pillow psutil pywin32 pymem requests
```

For GPU stats on the Dashboard, install and run [OpenHardwareMonitor](https://openhardwaremonitor.org/) first.

## Launch

```bat
python run.py
```

## Themes (12 total)

| Theme          | Description                          |
|----------------|--------------------------------------|
| Dark           | Default dark palette, blue accent    |
| Midnight       | Deeper blacks than Dark              |
| Carbon         | Warm charcoal                        |
| Slate          | Blue-tinted dark                     |
| Violet         | Dark base, purple accent             |
| Rose           | Dark base, pink/red accent           |
| Amber          | Dark base, warm orange accent        |
| Teal           | Dark base, cyan accent               |
| Nord           | Nordic blue palette                  |
| Dracula        | Classic Dracula colour scheme        |
| Solarized Dark | Solarized dark palette               |
| High Contrast  | Maximum readability                  |

## What's real

| Feature | What actually happens |
|---|---|
| Dashboard | psutil CPU/RAM/Disk every 2s, non-blocking |
| System Health Score | Computed from real metrics |
| Bloatware Removal | `Get-AppxPackage | Remove-AppxPackage -AllUsers` |
| Feature Tweaks | Real registry writes + `sc stop/config` for services |
| Privacy Controls | Real registry writes to HKCU/HKLM policy paths |
| Windows Recall | Registry policy disable + service stop + package removal |
| SFC | `sfc /scannow` — output streams live |
| DISM | `DISM /Online /Cleanup-Image /RestoreHealth` — live output |
| Network Reset | `netsh int ip reset`, `netsh winsock reset`, `ipconfig /flushdns` |
| Windows Update Repair | Stops WU services, clears SoftwareDistribution, restarts |
| System Tools | devmgmt.msc, services.msc, etc. via correct mmc.exe/rundll32 launch |
| Disk Cleanup | Real byte measurement before and after, per-category |
| Registry Cleaner | Real scan of uninstall/startup/file assoc keys, real deletion with .reg backup |
| Startup Manager | Real winreg + schtasks reads, real StartupApproved disable |
| Game Booster | Real SetPriorityClass, real power plan switch, real RAM measurement |
| FPS Unlocker | Real pymem heap scan via VirtualQueryEx, continuous patching |
| Proxy Fetch | Parallel HTTP fetch from 22 real sources |
| Proxy Checker | 9-stage: TCP, protocol, exit IP, geo, anonymity, pool analysis |
| DNS Change | Set-DnsClientServerAddress on all active adapters |
| WinGet Upgrade | `winget upgrade --all` with live output |

## What was fixed vs the original

* SOME PAGE LOADING ISSUES (IM AWARE OF THE TWEAKS PAGE)
* PROXY CHECKER ISSUES AND REGION FILTERS
* TEST CHAIN BUTTON IS IMPLEMENTED BUT BUILT CHAIN HAS ISSUES SOMETIMES
* WINDOWS 10 / 11 DETECTION RESULTING IN WINDOWS 11 SPECIFIC OPTIONS BEING HIDDEN FOR WINDOWS 10 USERS
* DEDICATED GPU PERFORMANCE INTEGRATION (FOR LAPTOPS)
* .BAT FOR FAST SEAMLESS LOADING
* BOOTSRAPPER


## Architecture

```
dwut/
  app/     config, state, permissions, main
  core/    EventBus, ThreadWorker, Logger
  modules/ pure Python — no UI imports
  ui/      CustomTkinter — no business logic
    widgets/ reusable (InfoBadge, attach_tooltip)
    pages/   dashboard, optimizer, debloat, gaming, proxy, tools, settings
```

## Portable mode

If a `settings/` folder exists next to `run.py`, all data is stored there.
Otherwise uses `%APPDATA%\DWUT\`.

## IN PROGRESS

* TWEAKS PAGE LOADING ISSUE FIX
* POPUP PAGE NOT LOADING FIX
* SCROLLWHEEL SLOWNESS FIX
* HIGHSPEED SCROLLING VISUAL BUG FIXES
* OTHER VISUAL BUG FIXES
* PROXY DEFAULT VISUAL BUG FIXES
* REMOVE OLD POORLY PLACED PROXY STUFF FROM SETTINGS
* ADDING CLEANER CATEGORY (BASICALLY LAST RESORT MALWARE REMOVAL TOOLS FOR BOTH WINDOWS 10 AND 11 FOR THOSE WHO GENUINELY DONT WANNA LOSE * THEIR FILES BUT ALSO DONT WANNA RESET THEIR PC (NOT A GUARENTEED REMOVAL) (MASSIVE IMPLEMENTATION)
* OTHER LIGHT QOL CHANGES
* CUSTOMIZABLE FONTS + BETTER DEFAULT FONTS
* CUSTOMIZABLE TEXT COLOR
* MORE THEMES
* LIGHT UI IMPROVEMENTS
