# Install_FolderAudio.ps1 — VLC per-folder audio language from folder name
# Works under any "...\Movies\<Lang>\" tree (e.g. D:\Media\Movies\...).
# eng→English, Kannada→Kannada, Hindi→Hindi, Tamil→Tamil, Telugu→Telugu
# (missing language track → VLC default). Highest quality among matches.
# Close VLC before running.

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcLua = Join-Path $ScriptDir 'folderaudio.lua'
$VlcRoaming = Join-Path $env:APPDATA 'vlc'
$DestDir = Join-Path $VlcRoaming 'lua\intf'
$DestLua = Join-Path $DestDir 'folderaudio.lua'
$Vlcrc = Join-Path $VlcRoaming 'vlcrc'

if (-not (Test-Path $SrcLua)) { throw "Missing $SrcLua" }

$running = Get-Process vlc -ErrorAction SilentlyContinue
if ($running) {
    Write-Host 'Closing VLC...'
    $running | ForEach-Object { $null = $_.CloseMainWindow() }
    Start-Sleep -Seconds 2
    Get-Process vlc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
Copy-Item -Path $SrcLua -Destination $DestLua -Force
Write-Host "Installed: $DestLua"

if (-not (Test-Path $Vlcrc)) { throw "VLC config not found: $Vlcrc" }

$backup = Join-Path $VlcRoaming ("vlcrc.bak-folderaudio-{0:yyyyMMdd-HHmmss}" -f (Get-Date))
Copy-Item $Vlcrc $backup -Force
Write-Host "Backup: $backup"

$text = [System.IO.File]::ReadAllText($Vlcrc)

function Set-VlcrcOption([string]$Content, [string]$Name, [string]$Value) {
    $pattern = "(?m)^#?$([regex]::Escape($Name))=.*$"
    $line = "$Name=$Value"
    if ($Content -match $pattern) {
        return [regex]::Replace($Content, $pattern, $line, 1)
    }
    return $Content.TrimEnd() + "`r`n$line`r`n"
}

# Auto-load folderaudio interface alongside the normal Qt UI
$text = Set-VlcrcOption $text 'extraintf' 'luaintf'
$text = Set-VlcrcOption $text 'lua-intf' 'folderaudio'

# Clear global language lock so folder script can choose (was forcing Kannada everywhere)
$text = Set-VlcrcOption $text 'audio-language' ''

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($Vlcrc, $text, $utf8)

Write-Host ''
Write-Host 'Done. Settings:'
Select-String -Path $Vlcrc -Pattern '^(extraintf|lua-intf|audio-language)=' | ForEach-Object { $_.Line }
Write-Host ''
Write-Host 'Test folders under D:\Media\Movies\ (or any ...\Movies\...):'
Write-Host '  eng, Kannada, Hindi, Tamil, Telugu'
Write-Host 'Audio should follow the folder language when that track exists.'
