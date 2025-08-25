# Clean Win 11 ISO Maker
It's basically just a click-and-run script that customizes the Windows 11 image by removing pre-installed bloatware, making registry tweaks to disable telemetry, remove intrusive interface elementsand making your image as how you'd like it to be.

<details>
    <summary>Introduction</summary><br/>
    I needed nested VM management (I was using Windows 10 as of August 2025), but when I tried to do this, I realized that Windows 10 only supports nested virtualization on Intel chips, and I use AMD. After investigating further, I learned that Windows 11 is the only version that supports it. I considered using Linux as my main operating system, but I realized that games and Nvidia drivers are not ideal for a Linux machine. I've come up with a idea to make a script that can generate the ISO file I need. Afterwards, I'll install them wherever I want.
</details>

<details>
    <summary>Description</summary><br/>
    
    The script is: 
    - acquires install.wim from Microsoft Windows ISO
    - removes bloatware packages from image
    - creates two WinPE.iso files
    - creates virtual hard disk called "USB"
    - copies image to this drive
    - creates VM
    - mounts WinPE deployment ISO
    - installs it on VHD of VM
    - reboots VM
    - gives you ability to make online modifications
    - copies image from VM
    - creates Win11_Custom.ISO
</details>

<details>
    <summary>Measurements</summary>
    
    Runtime: 16 min 10 sec
    Avg CPU usage: 15%
    Max RAM used: 613MB

    System tested:
    - CPU: Ryzen 3700X
    - RAM: 32GB
    - SSD: SK-Hynix Nvme 1TB
</details>

## Hardware Recommendations
- 64GB of free space
- Quad core CPU with virtualization support and TPM
- 16GB RAM
- Nvme SSD

## Dependencies
- Download and install [Windows ADK and Windows PE add-on](
https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
- Enable virtualization in your BIOS
- Enable [Hyper-V](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/get-started/install-hyper-v?tabs=gui&pivots=windows)
- Download [Windows 11 ISO](https://www.microsoft.com/en-us/software-download/windows11#SoftwareDownload_Edition)/[Mirror](https://msdl.gravesoft.dev/#3113)

## Usage

> [!Warning]
> This script is intended for use by advanced users to streamline their operations. Although it uses safe methods and is partially based on Microsoft documentation, new Microsoft updates can break things, which is why I'm not including uninstallation of Defender and Edge. Use at your own risk!

> [!Tip]
> Only the en-US version is used. You can make your own changes to the code if you want to.

1. Make sure your user has Admin rights.
2. Download and extract zip/clone git repository.
3. Place the downloaded Windows 11 ISO file in the same directory as the Run.bat file.
4. (Optional) Place offline installers of programs that you wanted to have pre-install.
5. Start Run.bat.
6. Wait for '"Online" modifications stage' output.
7. When the virtual machine (VM) is created, the VM window will open. Wait for it to boot, then run Explorer in the VM.
8. Find "USB" drive.
9. (Optional) Install all of your offline installers.
10. After you are done, run sysprep.bat on the USB drive.
11. Wait for your ISO file. It will be placed where you run the script.

## Features

### Removed pre-installed packages
<details>
    <summary>Expand</summary>
    <blockquote>

    Provisioned Apps:
    - Clipchamp.Clipchamp
    - Microsoft.BingNews
    - Microsoft.BingSearch
    - Microsoft.BingWeather
    - Microsoft.Edge.GameAssist
    - Microsoft.GamingApp
    - Microsoft.GetHelp
    - Microsoft.MicrosoftEdge.Stable
    - Microsoft.MicrosoftOfficeHub
    - Microsoft.MicrosoftSolitaireCollection
    - Microsoft.MicrosoftStickyNotes
    - Microsoft.OutlookForWindows
    - Microsoft.Paint
    - Microsoft.PowerAutomateDesktop
    - Microsoft.ScreenSketch
    - Microsoft.SecHealthUI
    - Microsoft.StorePurchaseApp
    - Microsoft.Todos
    - Microsoft.Windows.DevHome
    - Microsoft.Windows.Photos
    - Microsoft.WindowsAlarms
    - Microsoft.WindowsCamera
    - Microsoft.WindowsFeedbackHub
    - Microsoft.WindowsNotepad
    - Microsoft.WindowsSoundRecorder
    - Microsoft.WindowsStore
    - Microsoft.Xbox.TCUI
    - Microsoft.XboxGamingOverlay
    - Microsoft.XboxIdentityProvider
    - Microsoft.XboxSpeechToTextOverlay
    - Microsoft.YourPhone
    - Microsoft.ZuneMusic
    - MicrosoftCorporationII.QuickAssist
    - MicrosoftWindows.Client.WebExperience
    - MicrosoftWindows.CrossDevice
    - MSTeams

    Capabilities:
    - App.StepsRecorder
    - Browser.InternetExplorer
    - Hello.Face.20134
    - MathRecognizer
    - Media.WindowsMediaPlayer
    - OneCoreUAP.OneSync

    * You can prevent packages from being uninstalled by adding their names to the src/dontremoveapps/*.txt file.
</blockquote>
</details>

### Registry tweaks

> [!Note]
> All this changes are stored in src/config/unattend.xml

#### General
- Bypass Microsoft account creation
- Disable DVR
- Disable Enhanced Pointer Precision
- Disable Sticky Keys shortcut
- Removed OneDrive
- Disable automatic windows updates(only notifies)
- Disable Windows Defender Notifications
- Disable Xbox game/screen recording, this also stops gaming overlay popups

#### Telemetry
- Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads
- Disable tips, tricks, suggestions and ads in start, settings, notifications, File Explorer, and on the lockscreen
- Disable ads and the MSN news feed in Microsoft Edge
- Disable the 'Windows Spotlight' desktop background option

#### AI
- Disable & remove Microsoft Copilot
- Disable Windows Recall snapshots
- Disable AI Features in Paint
- Disable AI Features in Notepad

#### File Explorer
- Change the default location that File Explorer opens to "This PC"
- Show hidden files, folders and drives
- Show file extensions for known file types
- Hide the Home or Gallery section from the File Explorer navigation pane

#### Taskbar
- Hide the search icon/box on the taskbar
- Hide the taskview button from the taskbar
- Disable the widgets service & hide icon from the taskbar.
- Hide the chat (meet now) icon from the taskbar
- Enable the 'End Task' option in the taskbar right click menu
- Enable the 'Last Active Click' behavior in the taskbar app area. This allows you to repeatedly click on an application's icon in the taskbar to switch focus between the open windows of that application.

#### Start
- Disable the recommended section in the start menu
- Disable the Phone Link mobile devices integration in the start menu
- Removed all pins

###### Pre-activation with KMS38 Method

## Links

- [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil) - tool that inspired me.
- [Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat) - registry methods I used to debloat windows.
- [schneegans.de/unattend-generator](https://schneegans.de/windows/unattend-generator/) - great answer file generator.
- [MAS](https://github.com/massgravel/Microsoft-Activation-Scripts) - thanks for understanding the activation process.
- [Microsoft guide](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/oem-deployment-of-windows-desktop-editions?view=windows-11) - this probably made it all possible.

#
> [!Note]
> If you encounter any bugs or want to add new features, feel free to fork the repository and make your changes.