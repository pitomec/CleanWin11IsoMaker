function GetKitsInstallPath {
	$KitsRootRegValueName = "KitsRoot10"
	$wow64RegKeyPathFound = if (Get-ItemProperty -Path "HKLM:\Software\Wow6432Node\Microsoft\Windows Kits\Installed Roots" -Name $KitsRootRegValueName -ErrorAction SilentlyContinue) {1} else {0}
	$regKeyPathFound = if (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows Kits\Installed Roots" -Name $KitsRootRegValueName -ErrorAction SilentlyContinue) {1} else {0}
	
	if ($wow64RegKeyPathFound -eq 0) {
		if ($regKeyPathFound -eq 0) {
			Write-Host "KitsRoot not found, can't set common path for Deployment Tools" -ForegroundColor red
			exit 1
		} else {
			$regKeyPath = "HKLM:\Software\Microsoft\Windows Kits\Installed Roots"
		}
	} else {
		$regKeyPath = "HKLM:\Software\Wow6432Node\Microsoft\Windows Kits\Installed Roots"
	}
	$KitsRoot = (Get-ItemProperty -Path $regKeyPath -Name $KitsRootRegValueName -ErrorAction Stop).$KitsRootRegValueName
	return $KitsRoot
}

function SetPathForADKTools {
	$KitsRoot = GetKitsInstallPath
	$WinPERoot = "$KitsRoot" + "Assessment and Deployment Kit\Windows Preinstallation Environment"
	$DandIRoot = "$KitsRoot" + "Assessment and Deployment Kit\Deployment Tools\amd64"
	$DISMRoot = "$DandIRoot" + "\DISM"
	$OSCDImgRoot = "$DandIRoot" + "\Oscdimg"
	$env:Path = "$DISMRoot;$OSCDImgRoot;$WinPERoot;$env:Path"
	$env:WinPERoot = $WinPERoot
	$env:DISMRoot = $DISMRoot
	$env:OSCDimgRoot = $OSCDImgRoot
}

function CreateWinPEImage {
	param (
		[string]$Type,
		[string]$WinPEPath
	)
	$rootFolder = Split-Path $PSSCRIPTROOT -Parent
	$WinPERoot = $env:WinPERoot
	$WinPEOC = "$WinPERoot" + "\amd64\WinPE_OCs\"
	$WinPEISOName = "WinPE.iso"
	$logPath = "$rootFolder\log.txt"
	$packageList = @(
		"WinPE-WMI"
		"WinPE-WDS-Tools"
		"WinPE-SecureStartup"
		"WinPE-Scripting"
		"WinPE-EnhancedStorage"
	)
	$enUs = $packageList | ForEach-Object { "en-us\" + $_ + "_en-us" }
	$packageList += $enUs
	$packageList = $packageList | ForEach-Object { $_ + ".cab" }
	$mountPath = "$WinPEPath\mount"
	
	if (Get-WindowsImage -Mounted | Where-Object { $_.Path -eq $mountPath }) {
		Dismount-WindowsImage -Path $mountPath -Discard | Out-Null
	} else {
		dism /cleanup-wim /quiet
	}
	if (Test-Path $WinPEPath) {
		Remove-Item $WinPEPath -Force -Recurse -ErrorAction SilentlyContinue | Out-Null
	}
	Write-Host "Preparing directories.."
	copype amd64 $WinPEPath | ForEach-Object {
		"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))][Copype] $_" | Add-Content $logPath
	}
	if ($LASTEXITCODE -ne 0){
		Write-Host "Copype process failed, please check log.txt" -ForegroundColor red
	}
	Write-Host "Mounting winpe image.."
	Mount-WindowsImage -ImagePath "$WinPEPath\media\sources\boot.wim" -Index 1 -Path $mountPath 2>>$logPath | Out-Null
	
	$counter = 0
	Write-Host "Adding important packages.."
	foreach ($pkg in $packageList) {
		$percent = ($counter++/$packageList.Count*100)
		Write-Progress -Activity "Adding Packages" -Status "${percent}%" -PercentComplete $percent
		dism /Add-Package /image:"$WinPEPath\mount" /PackagePath:"$WinPEOC\$pkg" /quiet /norestart
		
	}
	Write-Progress -Activity "Adding Packages" -Status "Ready" -Completed
	
	Write-Host "Preparing boot files.."
	Remove-Item -Path "$WinPEPath\bootbins\etfsboot.com" -Force
	Remove-Item -Path "$WinPEPath\bootbins\efisys.bin" -Force
	Rename-Item -Path "$WinPEPath\bootbins\efisys_noprompt.bin" -NewName "efisys.bin" -Force
	Add-Content -Path "$WinPEPath\mount\windows\system32\startnet.cmd" -Value "powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
	Write-Host "Adding startup scripts.."
	New-Item -Path "$WinPEPath\mount\" -Name "scripts" -ItemType "Directory" -ErrorAction SilentlyContinue | Out-Null
	if ($Type -eq "Deployment") {
		Copy-Item -Path "$rootFolder\winpe\deployment\*" -Destination "$WinPEPath\mount\scripts" -Recurse -ErrorAction SilentlyContinue
		Add-Content -Path "$WinPEPath\mount\windows\system32\startnet.cmd" -Value "X:\scripts\install.cmd"
		$WinPEISOName = "WinPE_D.iso"
	} elseif ($Type -eq "Capture") {
		Copy-Item -Path "$rootFolder\winpe\capture\*" -Destination "$WinPEPath\mount\scripts" -Recurse -ErrorAction SilentlyContinue
		Add-Content -Path "$WinPEPath\mount\windows\system32\startnet.cmd" -Value "X:\scripts\capture.cmd"
		$WinPEISOName = "WinPE_C.iso"
	} else {
	}
	
	Write-Host "Cleaning up winpe image.."
	dism /image:"$WinPEPath\mount" /Cleanup-image /StartComponentCleanup /quiet /norestart
	Write-Host "Unmounting winpe image.."
	Dismount-WindowsImage -Path $mountPath -Save -ErrorAction Continue 2>>$logPath | Out-Null
	Write-Host "Optimizing winpe image.."
	Export-WindowsImage -SourceImagePath "$WinPEPath\media\sources\boot.wim" -SourceIndex 1 -DestinationImagePath "$WinPEPath\mount\boot2.wim" -ErrorAction Continue 2>>$logPath | Out-Null
	Remove-Item -Path "$WinPEPath\media\sources\boot.wim" -Force -ErrorAction SilentlyContinue
	Copy-Item -Path "$WinPEPath\mount\boot2.wim" -Destination "$WinPEPath\media\sources\boot.wim"
	Write-Host "Creating WinPE iso.."
	MakeWinPEMedia /ISO /f $WinPEPath "$rootFolder\tmp\$WinPEISOName" | ForEach-Object {
		"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))][ISO] $_" | Add-Content $logPath
	}
	Remove-Item -Path $WinPEPath -Recurse -Force -ErrorAction SilentlyContinue
}