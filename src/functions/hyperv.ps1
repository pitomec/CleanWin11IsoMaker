$VMName = "Win11Test"
$VMFolderPath = "$PSSCRIPTROOT\VM"
function CreateVM {
	param (
		[Parameter(Mandatory, position=0)]
		[string]$VMName,
		[Parameter(Mandatory, position=1)]
		[string]$VMFolderPath
	)

	$VM = @{
		Name = $VMName
		MemoryStartupBytes = 4294967296
		Generation = 2
		NewVHDPath = "$VMFolderPath\$VMName.vhdx"
		NewVHDSizeBytes = 68719476736
		Path = $VMFolderPath
	}

	New-VM @VM -Force | Out-Null
	Set-VM -Name $VMName -ProcessorCount 2 -CheckpointType Disabled
	Set-VMFirmware $VMName -EnableSecureBoot On
	Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
	Enable-VMTPM -VMName $VMName
	Get-VMIntegrationService -VMName $VMName | Enable-VMIntegrationService
}

function DeleteVM {
	param (
		[Parameter(Mandatory, position=0)]
		[string]$VMName,
		[Parameter(Mandatory, position=1)]
		[string]$VMFolderPath
	)
	Remove-VM -Name $VMName -Force | Out-Null
	Remove-Item -Path "$VMFolderPath\$VMName.vhdx" -Force | Out-Null
}

function MountDVDToVM {
	param (
		[Parameter(Mandatory, position=0)]
		[string]$VMName,
		[Parameter(Mandatory, position=1)]
		[string]$Path
	)
	Add-VMDvdDrive -VMName $VMName -Path $Path -ControllerNumber 0 -ControllerLocation 2
	$VMDvdDrive = Get-VM -Name $VMName | Get-VMDvdDrive -ControllerNumber 0 -ControllerLocation 2
	Set-VMFirmware $VMName -FirstBootDevice $VMDvdDrive
}

function UnmountDVDFromVM {
	param (
		[Parameter(Mandatory, position=0)]
		[string]$VMName
	)
	$VMDvdDrive = Get-VM -Name $VMName | Get-VMDvdDrive -ControllerNumber 0 -ControllerLocation 2
	Remove-VMDvdDrive $VMDvdDrive
}

function CreateUSBVHD {
	param (
		[Parameter(Mandatory, Position=0)]
		[string]$VMFolderPath,
		[Parameter(Mandatory, Position=1)]
		[string]$ImagePath
	)
	$rootFolder = Split-Path (Split-Path $PSSCRIPTROOT -Parent) -Parent
	$userInstalls = "$rootFolder\Install\"
	New-VHD -Path "$VMFolderPath\USB.vhdx" -SizeBytes 17179869184 -Fixed | Mount-VHD -Passthru |Initialize-Disk -Passthru |New-Partition -AssignDriveLetter -UseMaximumSize |Format-Volume -FileSystem NTFS -NewFileSystemLabel "USB-B" -Confirm:$false -Force | Out-Null
	$usbLtr = (Get-Volume | Where-Object { $_.FileSystemLabel -eq 'USB-B' }).DriveLetter
	New-Item -Path "${usbLtr}:\Images" -ItemType "Directory" -ErrorAction SilentlyContinue | Out-Null
	Copy-Item -Path $ImagePath -Destination "${usbLtr}:\Images\install.wim" -Force
	Set-Content -Path "${usbLtr}:\sysprep.bat" -Value "C:\Windows\System32\Sysprep\sysprep /oobe /generalize /shutdown" -Force | Out-Null
	Copy-Item -Path $userInstalls -Destination "${usbLtr}:\Install" -Recurse
	Dismount-VHD -Path "$VMFolderPath\USB.vhdx"
}

function AttachUSBToVM {
	param (
		[Parameter(Mandatory, position=0)]
		[string]$VMName,
		[Parameter(Mandatory, position=1)]
		[string]$VMFolderPath
	)
	Add-VMHardDiskDrive -VMName $VMName -Path "$VMFolderPath\USB.vhdx"
}

function CopyImageFromUSB {
	param (
		[Parameter(Mandatory, Position=0)]
		[string]$VMFolderPath,
		[Parameter(Mandatory, Position=1)]
		[string]$Destination
	)
	$usbLtr = (Mount-VHD -Path "$VMFolderPath\USB.vhdx" -Passthru |Get-Disk |Get-Partition |Get-Volume |Where-Object { $_.FileSystemLabel -eq 'USB-B' }).DriveLetter
	Copy-Item -Path "${usbLtr}:\Images\CleanWinImage_Pro.wim" -Destination "$Destination\install.wim" -Force
	Dismount-VHD -Path "$VMFolderPath\USB.vhdx"
}

function DeleteUSBVHD {
	param (
		[Parameter(Mandatory, position=0)]
		[string]$VMFolderPath
	)
	Remove-Item -Path "$VMFolderPath\USB.vhdx"
}

function StartVM {
	param (
		[Parameter(Mandatory, position=0)]
		[string]$VMName
	)
	Start-VM -Name $VMName
}

function GetVMState {
	param (
		[Parameter(Mandatory, position=0)]
		[string]$VMName
	)
	return (Get-VM -Name $VMName).State
}