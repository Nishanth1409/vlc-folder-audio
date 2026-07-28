# VLC Folder Audio

VLC helper that picks the soundtrack from the **movie folder name** and prefers higher quality tracks.

| Folder name contains | Prefers |
| :--- | :--- |
| `eng` | English |
| `Kannada` | Kannada |
| `Hindi` | Hindi |

---

## Install from scratch

### Requirements
- [VLC](https://www.videolan.org/) for Windows  
- PowerShell (built-in)

### Steps
1. **Close VLC** completely (tray icon too).  
2. Clone this repo:
   ```bash
   git clone https://github.com/Nishanth1409/vlc-folder-audio.git
   cd vlc-folder-audio
   ```
3. Run the installer from **this folder**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install_FolderAudio.ps1
   ```
4. The script copies `folderaudio.lua` into your VLC user `lua\intf` folder and updates `vlcrc` (a timestamped backup is created first).

### Verify
1. Put a movie inside a folder named e.g. `eng`, `Hindi`, or `Kannada`.  
2. Open that file with VLC.  
3. Audio should follow the folder language when matching tracks exist.

---

## How it works

| File | Role |
| :--- | :--- |
| `folderaudio.lua` | VLC Lua interface logic |
| `Install_FolderAudio.ps1` | Install / patch VLC user config |
| `vlc-help.txt` | Extra notes (optional) |

---

## Pro tips

- Re-run `Install_FolderAudio.ps1` after you update `folderaudio.lua`.  
- If something breaks, restore the `vlcrc.bak-folderaudio-*` backup from your VLC user config folder (`%APPDATA%\vlc`).  
- Adjust the Lua script if you need more language keywords.

## License

Personal / portfolio use. Review before redistributing.
