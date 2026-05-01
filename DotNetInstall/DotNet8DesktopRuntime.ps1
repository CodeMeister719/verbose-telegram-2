[CmdletBinding()]
param()

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$TargetVersion = [Version]"8.0.26"
$TargetMajor = 8
$InstallerFileName = "windowsdesktop-runtime-8.0.26-win-x64.exe"
$InstallerPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "installexe") -ChildPath $InstallerFileName

function Write-Status {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message,

		[ValidateSet("Info", "Success", "Warning", "Error")]
		[string]$Type = "Info"
	)

	$colorMap = @{
		Info = "Cyan"
		Success = "Green"
		Warning = "Yellow"
		Error = "Red"
	}

	$prefixMap = @{
		Info = "[*]"
		Success = "[+]"
		Warning = "[!]"
		Error = "[-]"
	}

	Write-Host ("{0} {1}" -f $prefixMap[$Type], $Message) -ForegroundColor $colorMap[$Type]
}

function Test-IsAdministrator {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($identity)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-InstalledWindowsDesktopRuntimeVersions {
	$versions = New-Object System.Collections.Generic.List[Version]

	try {
		$runtimeLines = & dotnet --list-runtimes 2>$null
		if ($runtimeLines) {
			foreach ($line in $runtimeLines) {
				if ($line -match "^Microsoft\.WindowsDesktop\.App\s+([0-9]+\.[0-9]+\.[0-9]+)") {
					try {
						$parsed = [Version]$Matches[1]
						if (-not $versions.Contains($parsed)) {
							[void]$versions.Add($parsed)
						}
					}
					catch {
						# Ignore malformed version values.
					}
				}
			}
		}
	}
	catch {
		# Ignore and fall back to registry detection.
	}

	if ($versions.Count -eq 0) {
		$regPaths = @(
			"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
			"HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
		)

		foreach ($entry in (Get-ItemProperty -Path $regPaths -ErrorAction SilentlyContinue)) {
			if ($entry.DisplayName -like "Microsoft Windows Desktop Runtime*" -and $entry.DisplayVersion) {
				try {
					$parsed = [Version]$entry.DisplayVersion
					if (-not $versions.Contains($parsed)) {
						[void]$versions.Add($parsed)
					}
				}
				catch {
					# Ignore malformed version values.
				}
			}
		}
	}

	return $versions | Sort-Object
}

function Start-InstallerAndWait {
	param(
		[Parameter(Mandatory = $true)]
		[string]$FilePath,

		[Parameter(Mandatory = $true)]
		[string[]]$ArgumentList,

		[Parameter(Mandatory = $true)]
		[string]$OperationLabel
	)

	$proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -PassThru
	$startTime = Get-Date

	while (-not $proc.HasExited) {
		$elapsed = (Get-Date) - $startTime
		Write-Progress -Activity "Installing .NET 8 Desktop Runtime" -Status ("{0} in progress... ({1}s elapsed)" -f $OperationLabel, [int]$elapsed.TotalSeconds) -PercentComplete -1
		Start-Sleep -Milliseconds 700
	}

	Write-Progress -Activity "Installing .NET 8 Desktop Runtime" -Completed
	return $proc.ExitCode
}

Write-Host ""
Write-Host "===============================================================" -ForegroundColor DarkCyan
Write-Host " .NET 8 Desktop Runtime Installer / Repair" -ForegroundColor DarkCyan
Write-Host "===============================================================" -ForegroundColor DarkCyan
Write-Host ""

try {
	if (-not (Test-Path -Path $InstallerPath -PathType Leaf)) {
		Write-Status -Type Error -Message "Installer not found: $InstallerPath"
		Write-Status -Type Info -Message "Please place $InstallerFileName in the .\installexe folder next to this script."
		exit 1
	}

	if (-not (Test-IsAdministrator)) {
		Write-Status -Type Warning -Message "Administrator permission is required to install or repair .NET Desktop Runtime."
		Write-Status -Type Info -Message "A Windows prompt will appear now. Choose 'Yes' and enter admin credentials if asked."

		$quotedScript = ('"{0}"' -f $PSCommandPath)
		$args = "-NoProfile -ExecutionPolicy Bypass -File $quotedScript"

		try {
			$elevated = Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs -Wait -PassThru
			if ($null -ne $elevated) {
				exit $elevated.ExitCode
			}
			exit 0
		}
		catch {
			Write-Status -Type Error -Message "Elevation was cancelled or failed. Installation cannot continue without admin permission."
			exit 1
		}
	}

	Write-Status -Type Info -Message "Checking existing .NET Desktop Runtime installation..."
	$installedVersions = @(Get-InstalledWindowsDesktopRuntimeVersions)
	$installedV8 = @($installedVersions | Where-Object { $_.Major -eq $TargetMajor })

	$operation = "Install"
	$arguments = @("/install", "/passive", "/norestart")

	if ($installedV8.Count -gt 0) {
		$highestInstalledV8 = $installedV8 | Sort-Object -Descending | Select-Object -First 1
		Write-Status -Type Info -Message ("Detected .NET Desktop Runtime 8.x (highest found: {0})." -f $highestInstalledV8)
		Write-Status -Type Info -Message "Running repair to fix or refresh the installation..."
		$operation = "Repair"
		$arguments = @("/repair", "/passive", "/norestart")
	}
	else {
		Write-Status -Type Info -Message "No .NET Desktop Runtime 8.x found. Starting fresh installation..."
	}

	$exitCode = Start-InstallerAndWait -FilePath $InstallerPath -ArgumentList $arguments -OperationLabel $operation

	switch ($exitCode) {
		0 {
			Write-Status -Type Success -Message "$operation completed successfully."
		}
		1641 {
			Write-Status -Type Success -Message "$operation completed and requested an immediate restart."
		}
		3010 {
			Write-Status -Type Success -Message "$operation completed. A restart is required to finish setup."
		}
		default {
			Write-Status -Type Error -Message "$operation failed (exit code: $exitCode)."
			exit $exitCode
		}
	}

	$finalVersions = @(Get-InstalledWindowsDesktopRuntimeVersions)
	$finalV8 = @($finalVersions | Where-Object { $_.Major -eq $TargetMajor } | Sort-Object)

	if ($finalV8.Count -gt 0) {
		$highest = $finalV8 | Select-Object -Last 1
		Write-Status -Type Success -Message ("Installed .NET Desktop Runtime 8.x detected. Highest version found: {0}" -f $highest)
		if ($highest -lt $TargetVersion) {
			Write-Status -Type Warning -Message ("Expected version {0}, but detected {1}." -f $TargetVersion, $highest)
		}
	}
	else {
		Write-Status -Type Warning -Message "Setup finished, but .NET Desktop Runtime 8.x was not detected afterward."
	}

	Write-Host ""
	Write-Status -Type Info -Message "All done. You can close this window."
	exit 0
}
catch {
	Write-Status -Type Error -Message ("Unexpected error: {0}" -f $_.Exception.Message)
	exit 1
}
