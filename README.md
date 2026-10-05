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
irm https://raw.githubusercontent.com/supportpantheon-sys/Darkos-Windows-Utility-Tool-DWUT/main/bootstrap.ps1 | iex
```
OR

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

* PROXY STUFF
* ADDED MOSTLY FUNCTIONAL VPN (ASIDE FROM REGION SELECTION)
* UPDATED CLEANER CATEGORY
* ADDED USB FLASHER CATEGORY
* ADDED VM BUILDER CATEGORY VMWARE OR VIRTUALBOX OPTIONS
* VPN IS SEPERATE FROM PROXY TOOLS
* FIXED OTHER MINOR BUGS
* UPDATED GAME BOOSTER
* ADDED WAYS TO REMOVE ACTIVATE NOW POPUPS IN THE POPUPS TAB
* VM AND USB CATEGORIES WORK
* VPN THAT ALSO USES THE WHOLE PROXY SETUP INSTEAD FOR STACKED EFFORTS (WIP)
* ADDED AUTO STARTUP STUFF
* ADDEDCUSTOM TASK MANAGER TO THE DASHBOARD
* ADDED THE SAME TASK MANAGER AS A REPLACEMENT TO THE TASK MANAGER BUTTON IN CONFIG TOOLS
* ADDED A NETWORK MONITORING TAB THAT GIVES USERS POPUP NOTIFICATIONS (AVOIDING FALSE POSITIVES) (WIP)
  



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
* MORE THEMES IN SETTINGS
* UPDATING PROXY TAB VPN THAT ALSO USES THE WHOLE PROXY SETUP INSTEAD FOR STACKED EFFORTS (WIP) (PROXIES ARE DEAD RN)



