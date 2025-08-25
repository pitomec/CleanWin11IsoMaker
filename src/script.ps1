#Requires -RunAsAdministrator
#Requires -Modules Dism, Hyper-V

. "$PSSCRIPTROOT\functions\image.ps1"
. "$PSSCRIPTROOT\functions\winpe.ps1"
. "$PSSCRIPTROOT\functions\offlineuninstall.ps1"
. "$PSSCRIPTROOT\functions\hyperv.ps1"


# TODO:
# - Add uninstalling Microsoft Edge
# - Disable Defender?

function Main {
	$tempDir = "$PSSCRIPTROOT\tmp"
	$isoDir = "$tempDir\ISO"
	$imagesDir = "$tempDir\images"
	$vmDir = "$tempDir\VM"
	$winMountedPath = "$tempDir\mount\windows"
	$WinPEDir = "$tempDir\winpe_amd64"
	$rootDir = Split-Path $PSSCRIPTROOT -Parent
	$configDir = "$PSSCRIPTROOT\config"
	$vmName = "Custom_Win11_08463"
	$winPEDeploy = "$tempDir\WinPE_D.iso"
	$winPECapture = "$tempDir\WinPE_C.iso"

	$cP = $ConfirmPreference
	$ConfirmPreference = 'None'

	$autoplay = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay"

	if ($autoplay -eq 0) {
		Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay" -Value 1
	}

	$microsoftIso = Get-Item -Path "$rootDir\*.iso"
	if ($microsoftIso -ne $null) {
		if ($microsoftIso -is [array]) {
			Write-Host "You have more than one .iso image. Please only leave one!" -ForegroundColor red -NoNewLine
			AwaitKeyToExit
		}
	} else {
		Write-Host "No Windows .iso was found!" -ForegroundColor red -NoNewLine
		AwaitKeyToExit
	}
	$microsoftIsoPath = "$rootDir\$($microsoftIso.Name)"
	
	# Checking VM and deleting if exists
	if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
		if ((GetVMState $vmName) -ne "Off") {
			Stop-VM -Name $vmName -TurnOff -Force
		}
		Start-Sleep -Seconds 5
		DeleteVM $vmName $vmDir
	}
	
	if (Get-WindowsImage -Mounted | Where-Object { $_.Path -eq $winMountedPath }) {
		Dismount-WindowsImage -Path $winMountedPath -Discard | Out-Null
	} else {
		dism /cleanup-wim /quiet
	}

	# Cleanup before running scripts
	$tempDirList = @($tempDir,$WinPEDir,$isoDir,$winMountedPath,$imagesDir,$vmDir)
	foreach ($dir in $tempDirList) {
		$exist = CheckItemExist $dir
		if ($exist -eq $true) {
			Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
	

	Write-Host "Creating temporary directory.."
	New-Item -Path $tempDir -ItemType "Directory" -ErrorAction SilentlyContinue | Out-Null
	
	Write-Host "===================[Windows wim file]==================="
	Write-Host "       *Acquiring source files*"
	UnpackWindowsISO -Path $microsoftIsoPath -Destination $isoDir
	UnpackImageFile -Path $isoDir -StoragePath $imagesDir -Destination $winMountedPath
	Write-Host "       *Removing bloatware packages*"
	RemoveProvisionedPackages -Path $winMountedPath
	RemoveCapabilities -Path $winMountedPath
	RemovePackages -Path $winMountedPath
	Write-Host "       *Creating modified wim file*"
	MakeImageFile -Path $winMountedPath -UnattendPath "$configDir\unattend.xml" -Destination $imagesDir
	
	Write-Host "=========================[WinPE]========================="
	SetPathForADKTools
	Write-Host "       *Creating WinPE.iso for deployment stage*"
	CreateWinPEImage -Type "Deployment" -WinPEPath $WinPEDir
	Write-Host "       *Creating WinPE.iso for capturing stage*"
	CreateWinPEImage -Type "Capture" -WinPEPath $WinPEDir
	
	Write-Host "========================[Hyper-V]========================"
	CreateVM $vmName $vmDir
	Write-Host "VM for testing has been created"
	CreateUSBVHD $vmDir "$imagesDir\install.wim"
	Write-Host "Virtual ""USB"" has been created"
	Write-Host "Adding ""USB"" to a VM"
	AttachUSBToVM $vmName $vmDir
	Write-Host "       *Starting deployment stage*"
	MountDVDToVM $vmName $winPEDeploy
	Start-Sleep -Seconds 5
	Write-Host "Starting VM.."
	StartVM $vmName
	do {
		$vm = GetVMState $vmName
		Write-Host "Waiting for VM to shut down..."
		Start-Sleep -Seconds 5
	} while ($vm -ne "Off")
	Write-Host "       *""Online"" modifications*"
	UnmountDVDFromVM $vmName
	Write-Host "Starting VM.."
	StartVM $vmName
	Start-Sleep -Seconds 3
	Start-Process "vmconnect.exe" -ArgumentList "localhost", "$vmName"
	do {
		$vm = GetVMState $vmName
		Write-Host "Waiting for VM to shut down..."
		Start-Sleep -Seconds 5
	} while ($vm -ne "Off")
	Write-Host "       *Starting capturing stage*"
	MountDVDToVM $vmName $winPECapture
	Stop-Process -Name "vmconnect" -Force
	Write-Host "Starting VM.."
	StartVM $vmName
	do {
		$vm = GetVMState $vmName
		Write-Host "Waiting for VM to shut down..."
		Start-Sleep -Seconds 5
	} while ($vm -ne "Off")
	Write-Host "Removing VM.."
	DeleteVM $vmName $vmDir
	
	Write-Host "Copying image from USB.."
	CopyImageFromUSB $vmDir $imagesDir
	DeleteUSBVHD $vmDir

	Write-Host "==========================[ISO]=========================="
	Write-Host "Adding Answer file.."
	Copy-Item -Path "$configDir\autounattend.xml" -Destination "$isoDir\autounattend.xml" -Force
	IncludeActivation -Path "$isoDir\sources"

	Write-Host "       *Making Custom Windows ISO*"
	CreateWindowsISO -ImagePath "$imagesDir\install.wim" -SourcePath $isoDir

	Write-Host "Cleaning up.."
	foreach ($dir in $tempDirList) {
		$exist = CheckItemExist $dir
		if ($exist -eq $true) {
			Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
	$ConfirmPreference = $cP
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" -Name "DisableAutoplay" -Value $autoplay
	AwaitKeyToExit
}

function AwaitKeyToExit {
    Write-Host "`nPress any key to exit..."
    [void][System.Console]::ReadKey($true)
	Exit
}

function CheckItemExist {
	param (
		[string]$Path
	)
	try {
		Get-Item -Path $Path -ErrorAction Stop | Out-Null
		return $true
	} catch {
		return $false
	}
}

function IncludeActivation {
	param (
		[string]$Path
	)
	$oemPath = "`$OEM`$\`$$`\Setup\Scripts"
	$fullPath = "$Path\$oemPath"
$setupCmd = @'
@echo off
fltmc >nul || exit /b
call "%~dp0Activation.cmd"
cd \
(goto) 2>nul & (if /I "%~dp0"=="%SystemRoot%\Setup\Scripts\" rd /s /q "%~dp0")
'@

$activationCmd = @'
@echo off
:: Install generic key for your edition first:
cscript /Nologo %windir%\system32\slmgr.vbs /ipk W269N-WFGWX-YVC9B-4J6C9-T83GX
::  Generate KMS38.xml and apply
set "signature=C52iGEoH+1VqzI6kEAqOhUyrWuEObnivzaVjyef8WqItVYd/xGDTZZ3bkxAI9hTpobPFNJyJx6a3uriXq3HVd7mlXfSUK9ydeoUdG4eqMeLwkxeb6jQWJzLOz41rFVSMtBL0e+ycCATebTaXS4uvFYaDHDdPw2lKY8ADj3MLgsA="
set "sessionId=TwBTAE0AYQBqAG8AcgBWAGUAcgBzAGkAbwBuAD0ANQA7AE8AUwBNAGkAbgBvAHIAVgBlAHIAcwBpAG8AbgA9ADEAOwBPAFMAUABsAGEAdABmAG8AcgBtAEkAZAA9ADIAOwBQAFAAPQAwADsARwBWAEwASwBFAHgAcAA9ADIAMAAzADgALQAwADEALQAxADkAVAAwADMAOgAxADQAOgAwADcAWgA7AEQAbwB3AG4AbABlAHYAZQBsAEcAZQBuAHUAaQBuAGUAUwB0AGEAdABlAD0AMQA7AAAA"
<nul set /p "=<?xml version="1.0" encoding="utf-8"?><genuineAuthorization xmlns="http://www.microsoft.com/DRM/SL/GenuineAuthorization/1.0"><version>1.0</version><genuineProperties origin="sppclient"><properties>OA3xOriginalProductId=;OA3xOriginalProductKey=;SessionId=%sessionId%;TimeStampClient=2022-10-11T12:00:00Z</properties><signatures><signature name="clientLockboxKey" method="rsa-sha256">%signature%</signature></signatures></genuineProperties></genuineAuthorization>" >"%SystemDrive%\KMS38.xml"
:: Install ticket using clipup
clipup.exe -v -o -altto C:\
:: Restart licensing service
net stop sppsvc
net start sppsvc
<nul set /p "=<?xml version="1.0" encoding="utf-8"?><genuineAuthorization xmlns="http://www.microsoft.com/DRM/SL/GenuineAuthorization/1.0"><version>1.0</version><genuineProperties origin="sppclient"><properties>OA3xOriginalProductId=;OA3xOriginalProductKey=;SessionId=%sessionId%;TimeStampClient=2022-10-11T12:00:00Z</properties><signatures><signature name="clientLockboxKey" method="rsa-sha256">%signature%</signature></signatures></genuineProperties></genuineAuthorization>" >"%SystemDrive%\KMS38.xml"
:: Install ticket using clipup
clipup.exe -v -o -altto C:\
:: Restart licensing service
net stop sppsvc
net start sppsvc
if exist "%SystemDrive%\*.xml" del /f /q "%SystemDrive%\*.xml" %nul%
exit /b
'@
	Write-Host "Creating OEM directory in setup.."
	New-Item -ItemType "Directory" -Path $fullPath -Force | Out-Null
	Write-Host "Inserting scripts.."
	Set-Content -Path "$fullPath\SetupComplete.cmd" -Value $setupCmd -Force | Out-Null
	Set-Content -Path "$fullPath\Activation.cmd" -Value $activationCmd -Force | Out-Null
}

Main