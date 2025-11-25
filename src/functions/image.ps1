function UnpackWindowsISO {
	param (
		[string]$Path,
		[string]$Destination
	)
	Write-Host "Preparing directories.."
	New-Item -Path $Destination -ItemType "Directory" -ErrorAction SilentlyContinue | Out-Null
	Write-Host "Mounting a Microsoft Windows ISO.."
	Mount-DiskImage -ImagePath $Path | Out-Null
	$drive = (Get-DiskImage -ImagePath $Path | Get-Volume).DriveLetter
	Write-Host "Copying source files from ISO.."
	Copy-Item -Path "${drive}:\*" -Destination $Destination -Recurse -Force
	Write-Host "Unmounting Microsoft ISO.."
	Dismount-DiskImage -ImagePath $Path | Out-Null
}

function UnpackImageFile {
	param (
		[string]$Path,
		[string]$StoragePath,
		[string]$Destination
	)
	Write-Host "Preparing directories.."
	New-Item -Path $StoragePath -ItemType "Directory" -ErrorAction SilentlyContinue | Out-Null
	$imageFile = "$StoragePath\install.wim"
	$modifiedImageFile = "$StoragePath\modimage.wim"
	Write-Host "Copying Windows Image file.."
	Copy-Item -Path "$Path\sources\install.wim" -Destination $imageFile -ErrorAction SilentlyContinue
	Write-Host "Exporting Pro Edition.."
	Export-WindowsImage -SourceImagePath $imageFile -SourceIndex 6 -DestinationImagePath $modifiedImageFile | Out-Null
	Remove-Item -Path $imageFile -Force -ErrorAction SilentlyContinue
	Write-Host "Preparing directories.."
	New-Item -Path $Destination -ItemType "Directory" -ErrorAction SilentlyContinue | Out-Null
	Write-Host "Mounting Windows Image.."
	Mount-WindowsImage -ImagePath $modifiedImageFile -Index 1 -Path $Destination | Out-Null
}

function MakeImageFile {
	param (
		[string]$Path,
		[string]$UnattendPath,
		$pinsBinPath = (Split-Path $PSSCRIPTROOT -Parent) + "\config\start2.bin",
		$hostsPath = (Split-Path $PSSCRIPTROOT -Parent) + "\config\hosts",
		[string]$Destination
	)
	$startMenuPath = "$Path\Users\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
	Write-Host "Adding Answer file.."
	New-Item -Path "$Path\Windows\panther" -ItemType "Directory" -ErrorAction SilentlyContinue | Out-Null
	Copy-Item -Path $UnattendPath -Destination "$Path\Windows\panther\unattend.xml" -Force
	Write-Host "Adding start2.bin to remove pins from start menu.."
	New-Item $startMenuPath -ItemType Directory -Force | Out-Null
	Copy-Item -Path $pinsBinPath -Destination $startMenuPath -Force
	Write-Host "Adding hosts to remove telemetry endpoints.."
	Copy-Item -Path $hostsPath -Destination "$Path\Windows\System32\drivers\etc" -Force
	Write-Host "Cleaning up the modified image.."
	dism /Image:"$Path" /cleanup-image /startcomponentcleanup /quiet /norestart
	Write-Host "Unmounting modified image.."
	Dismount-WindowsImage -Path $Path -Save | Out-Null
	Write-Host "Optimizing modified image.."
	Export-WindowsImage -SourceImagePath "$Destination\modimage.wim" -SourceIndex 1 -DestinationImagePath "$Destination\install.wim" -ErrorAction continue | Out-Null
	Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
	Remove-Item -Path "$Destination\modimage.wim" -Force -ErrorAction SilentlyContinue
}

function CreateWindowsISO {
	param (
		[string]$ImagePath,
		[string]$SourcePath
	)
	$rootFolder = Split-Path (Split-Path $PSSCRIPTROOT -Parent) -Parent
	Copy-Item -Path $ImagePath -Destination "$SourcePath\sources\install.wim" -Force
	$etfsboot = Join-Path $SourcePath "boot\etfsboot.com"
	$efisys = Join-Path $SourcePath "efi\microsoft\boot\efisys.bin"
	$outputIso = Join-Path $rootFolder "Win11_Custom.iso"
	& oscdimg.exe -m -o -u2 -udfver102 ("-bootdata:2#p0,e,b" + $etfsboot + "#pEF,e,b" + $efisys) -lCCCOMA_X64FRE_EN-US_DV9 $SourcePath $outputIso
}