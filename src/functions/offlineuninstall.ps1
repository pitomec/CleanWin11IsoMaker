$mountPath = "C:\mount\windows"
function GetListFromFile {
	param (
		[string]$FileName
	)
	$rootFolder = Split-Path $PSSCRIPTROOT -Parent
	return Get-Content -Path "$rootFolder\dontremoveapps\$FileName.txt"
}

function RemoveProvisionedPackages {
	param (
		[string]$Path
	)
	$appsList = GetListFromFile "ProvisionedPackages"
	$appxProvisionedPackages = Get-AppxProvisionedPackage -Path $Path | Where-Object {
		$packageName = $_.PackageName
		-not ($appsList | Where-Object { $packageName -like "*$_*"})
	}
	$counter = 0
	foreach ($appx in $appxProvisionedPackages) {
		$status = "Removing $($appx.PackageName)"
		Write-Progress -Activity "Removing Provisioned Apps" -Status $status -PercentComplete ($counter++/$appxProvisionedPackages.Count*100)
		try {
			Remove-AppxProvisionedPackage -Path $Path -PackageName $appx.PackageName -ErrorAction SilentlyContinue | Out-Null
		} catch {
			Write-Host "Application $($appx.PackageName) could not be removed"
			continue
		}
	}
	Write-Progress -Activity "Removing Provisioned Apps" -Status "Ready" -Completed
}

function RemoveCapabilities {
	param (
		[string]$Path
	)
	$capabilitiesList = GetListFromFile "Capabilities"

	$capabilities = @()
	$currentCapability = $null

	foreach ($line in (dism /Image:$Path /Get-Capabilities)) {
		if ($line -match "Capability Identity\s*:\s*(.+)") {
			$currentCapability = $matches[1]
		}
		elseif ($line -match "State\s*:\s*(.+)" -and $currentCapability) {
			$state = $matches[1].Trim()
			$capabilities += [PSCustomObject]@{
				Identity = $currentCapability
				State      = $state
			}
			$currentCapability = $null
		}
	}

	# Filter and display only 'Installed' ones
	$capabilities = $capabilities | Where-Object { 
		$capabilityName = $_.Identity
		$_.State -eq 'Installed' -and
		-not ($capabilitiesList | Where-Object { $capabilityName -like "*$_*"})
	}
	
	$counter = 0
	foreach ($capability in $capabilities) {
		$status = "Removing $($capability.Identity)"
		Write-Progress -Activity "Removing Capabilities" -Status $status -PercentComplete ($counter++/$capabilities.Count*100)
		dism /image:$Path /remove-capability /CapabilityName:$($capability.Identity) /quiet /norestart | Out-Null
		if ($? -eq $false) {
			Write-Host "Package $($capability.Identity) could not be removed."
		}
	}
	Write-Progress -Activity "Removing Capabilities" -Status "Ready" -Completed
}

function RemovePackages {
	param (
		[string]$Path
	)
	$pkgList = GetListFromFile "Packages"
	$fodPackages = dism /Image:$Path /Get-Packages | Select-String -Pattern "Package Identity : " -CaseSensitive -SimpleMatch
	if ($?) {
		$fodPackages = $fodPackages -split "Package Identity : " | Where-Object {$_}
		$fodPackages = $fodPackages | Where-Object {
			$packageName = $_
			-not ($pkgList | Where-Object { $packageName -like "*$_*" })
		}
	}
	
	$counter = 0
	foreach ($package in $fodPackages) {
		$status = "Removing $package"
		Write-Progress -Activity "Removing Packages" -Status $status -PercentComplete ($counter++/$fodPackages.Count*100)
		dism /image:$Path /remove-package /PackageName:$package /quiet /norestart | Out-Null
		if ($? -eq $false) {
			Write-Host "Package $package could not be removed."
		}
	}
	Write-Progress -Activity "Removing Packages" -Status "Ready" -Completed
}