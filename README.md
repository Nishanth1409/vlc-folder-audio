# VLC Folder Audio

Small VLC helper: pick soundtrack language from the movie folder name  
(`eng` → English, `Kannada` → Kannada, `Hindi` → Hindi) and prefer highest quality.

**Not part of System Maintenance** (desktop right-click toolkit). This is a separate media tool.

## Files

| File | Purpose |
| :--- | :--- |
| `folderaudio.lua` | VLC Lua interface script |
| `Install_FolderAudio.ps1` | Installs script into `%APPDATA%\vlc\lua\intf` and patches `vlcrc` |

## Install

1. Close VLC.
2. Run PowerShell:

```powershell
cd D:\Projects\tools\vlc-folder-audio
powershell -ExecutionPolicy Bypass -File .\Install_FolderAudio.ps1
```

3. Open a movie from a folder named like `eng`, `Hindi`, or `Kannada`.

## Paths

- Local: `D:\Projects\tools\vlc-folder-audio`
- VLC config: `%APPDATA%\vlc\`
