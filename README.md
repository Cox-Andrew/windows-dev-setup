# Windows Development Setup Tips

This is my ([@cox-andrew](https://github.com/cox-andrew)) assortment of tips (**not a complete guide**) for consideration when setting up Windows for a range of development activities. Enjoy the nerd shit :)

---

You will probably need to relog or `refreshenv` after installing these tools to get them to show on `PATH` correctly.

---

## Chocolatey

- Package manager for Windows - alternatively look into [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [Install](https://chocolatey.org/install)

## PowerShell Core

- Improved cross-platform PowerShell
- `choco install powershell-core`

## Windows Terminal

- Best Windows terminal emulator imo
- `choco install microsoft-windows-terminal`
- Customise start-up script `$PROFILE`

<!-- TODO: add reference to file and update file -->
```powershell
# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

$ESC = [char]27

# Custom prompt
function prompt {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  $admin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  "$ESC$($admin ? '[91m' : '[92m')$env:USERNAME$ESC[96m@$env:COMPUTERNAME $ESC[92m$(if ($pwd.ToString() -eq $HOME) {"~"} else {Split-Path -Path $pwd -Leaf})$ESC[0m$('>' * ($nestedPromptLevel + 1)) "  
}

# Register ssh autocomplete
Register-ArgumentCompleter -Native -CommandName ssh,scp,sftp -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)
  $hosts = Select-String -Path ${Env:USERPROFILE}\.ssh\config -Pattern "(?<=^Host ).*" -AllMatches `
  | ForEach-Object { $_.Matches } `
  | ForEach-Object { $_.Value }

  $hosts `
  | Where-Object { $_ -like "${wordToComplete}*" } `
  | ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, [System.Management.Automation.CompletionResultType]::ParameterValue, $_) }
}

# Exit shortcut
Set-PSReadlineKeyHandler -Chord Ctrl+d -Function DeleteCharOrExit

# Copy working directory to clipboard alias
Function Copy-Path {
  $path = Get-Location
  $path | Set-Clipboard
  Write-Host "Copied $ESC[92m$path$ESC[0m to clipboard"
}
Set-Alias -Name cwd -Value Copy-Path -Description "Copy working directory to clipboard"
```

- [Add Git Bash](https://stackoverflow.com/questions/56839307/adding-git-bash-to-the-new-windows-terminal)

## AutoHotKey

- `choco install autohotkey`
- Used for useful key binds such as launching Windows Terminal
- Place scripts in `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` to run on login

<!-- TODO: add reference to file and update file -->
```autohotkey
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance Force

pinned := false

; Suspend/resume process utils
ProcessSuspend(pid) {
    handle := DllCall("OpenProcess", "uInt", 0x1F0FFF, "Int", 0, "Int", pid)
    If !handle   
        Return -1
    DllCall("ntdll.dll\NtSuspendProcess", "Int", handle)
    DllCall("CloseHandle", "Int", handle)
}

ProcessResume(pid) {
    handle := DllCall("OpenProcess", "uInt", 0x1F0FFF, "Int", 0, "Int", pid)
    If !handle   
        Return -1
    DllCall("ntdll.dll\NtResumeProcess", "Int", handle)
    DllCall("CloseHandle", "Int", handle)
}

ProcessSuspended(pid) {
    For thread in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Thread WHERE ProcessHandle = " pid)
        If (thread.ThreadWaitReason != 5)
            Return False
    Return True
}

; ================================= hot keys ==================================

; Media keys
<^>!j:: Send,  {Media_Prev}
<^>!k:: Send,  {Media_Play_Pause}
<^>!l:: Send,  {Media_Next}
<^>!,:: Send,  {Volume_Down}
<^>!.:: Send,  {Volume_Up}
<^>!m:: Send,  {Volume_Mute}

; ============================= disabled in game ==============================
#IfWinNotActive ahk_class Tiger D3D Window

; Terminal
^!t::   Run,   wt
^!+t::  Run,   schtasks /Run /TN "\UAC\wt",, hide

; Sleep PC
^!+s:: DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0)

; Wake desktop
^!+p::  Run, wol.bat, , Hide

; Pin windows
; ^!SPACE::
;     Winset,    Alwaysontop, , A
;     pinned := !pinned
;     TrayTip,   % "Window " . (pinned ? "" : "un") . "pinned", Press ctrl+alt+space to toggle, , 0x11
; Return

; Dark/Light Mode Toggle
^!+l::
    ; Get the current light mode status 
    RegRead, isLightmode, HKCU, SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize, SystemUsesLightTheme
    If isLightmode {
        ; Switch to dark theme
        RegWrite, Reg_Dword, HKCU, SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize, SystemUsesLightTheme, 0
        RegWrite, Reg_Dword, HKCU, SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize, AppsUseLightTheme, 0
    } Else {
        ; Switch to light theme
        RegWrite, Reg_Dword, HKCU, SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize, SystemUsesLightTheme, 1
        RegWrite, Reg_Dword, HKCU, SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize, AppsUseLightTheme, 1
    }
    ; Refresh the user settings
    Run, RUNDLL32.EXE USER32.DLL`, UpdatePerUserSystemParameters `,2 `,True
Return

; Remote Desktop middle mouse fix
<#F22::MButton  ; Left Win + F22
<#<^F22::MButton  ; Left Win + Left Ctrl + F22

; Suspend/Resume Cemu
^!+o::
    Process, Exist, Cemu.exe
    pid := Errorlevel
    If ProcessSuspended(pid) {
        ProcessResume(pid)
    } Else {
        ProcessSuspend(pid)
    }
Return

#IfWinNotActive ; ahk_class Tiger D3D Window
```

- To make the Windows Terminal shortcut work we need to create a scheduled task
  - Fill in `MACHINE\USERNAME` with yours in `wt.xml`
  - import `wt.xml` into Task Scheduler
  - correct the user account to run task with
  - this should have path /UAC/wt

## VSCode

- `choco install vscode`
- It's basically an IDE at this point.
- Here are a list of essential/great extensions (excludes language specific):
  - [ms-vscode-remote.remote-ssh](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)
  - [ms-vscode-remote.remote-ssh-edit](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh-edit)
  - [ms-vscode-remote.remote-wsl](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl)
  - [ms-vscode.remote-explorer](https://marketplace.visualstudio.com/items?itemName=ms-vscode.remote-explorer)
  - [ms-azuretools.vscode-docker](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-docker)
  - [esbenp.prettier-vscode](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
  - [eamodio.gitlens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens)
  - [Tyriar.sort-lines](https://marketplace.visualstudio.com/items?itemName=Tyriar.sort-lines)
  - [tomoki1207.pdf](https://marketplace.visualstudio.com/items?itemName=tomoki1207.pdf)
- Personally recommend the theme One Dark Pro (zhuangtongfa.material-theme)

## Setup OpenSSH

- [Install](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse?tabs=powershell)
- [Generate private/public keys](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement)
- Configure `~\.ssh\ssh_config`
- Comment out / remove the `adminstrator_authorized_keys` from `%PROGRAMDATA%\ssh\sshd_config`
- Set Powershell/bash as default ssh shell
  - `New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value <shell path> -PropertyType String -Force`
  - `C:\Program Files\PowerShell\7\pwsh.exe`
  - `C:\WINDOWS\system32\bash.exe`

## ~~Setup GPG~~ Wouldn't recommend anymore

- `choco install gpg4win`
- Generate GPG key
  - `gpg --full-generate-key --expert`
  - select EDDSA and Curve 25519 (default)
  - make sure to add a passphrase
- View key
  - `gpg --list-secret-keys --keyid-format short`
- Generate signing sub-key
  - `gpg --edit-key <key id> --expert`
  - `addkey`
  - Select ECC (sign only) and Curve 25519 (default)
  - `save`
- Upload public key to GitHub
  - `gpg --armor --export <key id> | clip`
  - paste into GitHub GPG key settings
- Configure git to use GPG
  - `git config --global commit.gpgsign true`
  - `git config --global gpg.program <gpg.exe path>`
- For ease of use increase the GPG key cache timeout
  - `gpgconf --list-options gpg-agent`
  - `gpgconf --change-options gpg-agent max-cache-ttl=<lifetime in seconds>`
  - `gpgconf --reload gpg-agent`

## Git

- `choco install git`
- Setup git to use OpenSSH
  - `git config --global core.sshCommand "C:\Windows\System32\OpenSSH\ssh.exe"`
- Somebody (hey not saying it's you) commit and push credentials? Scrub them from the repo using [BFG Repo-Cleaner](https://rtyley.github.io/bfg-repo-cleaner/)
- Ensure git uses wincred keyring for credentials
  - `git config --global credential.helper wincred`

## WSL2

- [Install](https://learn.microsoft.com/en-us/windows/wsl/install)

## PowerToys

- `choco install powertoys`
- I honestly find this an essential extension to Windows (curtesy of and personally used by the Windows team)
  - **PowerToys Run:** MacOS like run pop-up `Alt+Space`
  - **FancyZones:** custom window snapping - especially useful to improve the awful Windows vertical monitor snapping

## Language Specifics

### Python

- Personally I find it easiest to manage Python versions using `pyenv`
- `choco install pyenv-win`
- `pyenv update`
- View available versions with `pyenv install -l`
  - Then `pyenv install <version>`
  - Set as global version with `pyenv global <version>`
- If VSCode doesn't detect `pyenv` interpreters you can add the following to your `settings.json`
  - "python.venvPath": "~/.pyenv/pyenv-win/versions"
- **Caution:** for some god-forsaken reason by default, Windows adds Windows store `python` to your path even if it's not installed
  - Remove this from `%LOCALAPPDATA%\Microsoft\WindowsApps\`

### NodeJS

- I manage NodeJS versions (as god they change so often) using `nvm`
- `choco install nvm`
- `nvm install <latest/lts/version>`
