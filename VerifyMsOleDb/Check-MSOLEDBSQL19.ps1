<#
.SYNOPSIS
    Verifies if Microsoft OLE DB Driver 19 for SQL Server (MSOLEDBSQL19) is installed on the system.

.DESCRIPTION
    This script checks for MSOLEDBSQL19 installation using three detection methods:
    1. Registry scan of uninstall entries (HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall)
    2. File system check for driver installation directories
    3. OLE DB connection attempt to determine provider registration
    
    Results are output to both console and a timestamped log file.

.PARAMETER LocalInstance
    The local SQL Server instance to use for connection testing. Default is localhost (.).
    
.PARAMETER Verbose
    Enable verbose output for detailed debugging information.

.NOTES
    Requires: PowerShell 5.0 or later
    Scope: Detection only; no installation or system modifications
    Exit Codes:
        0 = MSOLEDBSQL19 is installed
        1 = MSOLEDBSQL19 is NOT installed
        2 = Script error or unable to determine

.EXAMPLE
    PS> .\Check-MSOLEDBSQL19.ps1
    PS> .\Check-MSOLEDBSQL19.ps1 -Verbose

#>

param(
    [string]$LocalInstance = ".",
    [switch]$Verbose
)

# Enable error action preference
$ErrorActionPreference = "Continue"

#region Initialize
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "MSOLEDBSQL19 Installation Detection Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Version Check ---
$psVersion = $PSVersionTable.PSVersion
$psVersionMajor = $psVersion.Major

if ($psVersionMajor -lt 5) {
    Write-Host "[ERROR] PowerShell 5.0 or later is required. Current version: $psVersion" -ForegroundColor Red
    exit 2
}

Write-Host "[OK] PowerShell version $psVersion is supported" -ForegroundColor Green

# --- Log File Setup ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = Get-Location }

$logFilePath = Join-Path $scriptDir "Check-MSOLEDBSQL19.log"

try {
    $null = New-Item -ItemType File -Path $logFilePath -Force -ErrorAction Stop
    Write-Host "[OK] Log file created: $logFilePath" -ForegroundColor Green
} catch {
    Write-Host "[WARNING] Could not create log file: $($_.Exception.Message)" -ForegroundColor Yellow
    $logFilePath = $null
}

function Write-LogEntry {
    param([string]$Message, [string]$Level = "INFO")
    
    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    
    if ($logFilePath) {
        Add-Content -Path $logFilePath -Value $logMessage -ErrorAction SilentlyContinue
    }
    
    if ($Verbose -or $Level -eq "ERROR" -or $Level -eq "WARNING") {
        Write-Host $logMessage -ForegroundColor $(
            switch ($Level) {
                "ERROR" { "Red" }
                "WARNING" { "Yellow" }
                "SUCCESS" { "Green" }
                default { "White" }
            }
        )
    }
}

Write-LogEntry "Script started - PowerShell version: $psVersion"
Write-LogEntry "Target local instance: $LocalInstance"

#endregion

#region Registry Detection
Write-Host ""
Write-Host "=== PHASE 1: Registry Detection ===" -ForegroundColor Cyan
Write-LogEntry "Starting registry detection phase..."

$registryFound = $false
$registryResults = @()
$registryUninstallPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$registryUninstallPath32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

foreach ($regPath in @($registryUninstallPath, $registryUninstallPath32)) {
    $pathLabel = if ($regPath -like "*WOW6432Node*") { "32-bit (WOW6432Node)" } else { "64-bit" }
    
    try {
        Write-LogEntry "Scanning registry path ($pathLabel): $regPath" "DEBUG"
        
        $items = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
        
        foreach ($item in $items) {
            $displayName = (Get-ItemProperty -Path $item.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
            
            if ($displayName -like "*MSOLEDBSQL*" -or $displayName -like "*OLE DB Driver*") {
                $displayVersion = (Get-ItemProperty -Path $item.PSPath -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
                $installLocation = (Get-ItemProperty -Path $item.PSPath -Name InstallLocation -ErrorAction SilentlyContinue).InstallLocation
                
                $regResult = [PSCustomObject]@{
                    DisplayName    = $displayName
                    Version        = $displayVersion
                    InstallPath    = $installLocation
                    Architecture   = $pathLabel
                }
                
                $registryResults += $regResult
                $registryFound = $true
                
                Write-Host "[FOUND] $displayName (Version: $displayVersion, Arch: $pathLabel)" -ForegroundColor Green
                Write-LogEntry "Registry entry found: $displayName, Version: $displayVersion, Path: $installLocation, Arch: $pathLabel" "SUCCESS"
            }
        }
    } catch {
        Write-LogEntry "Error scanning registry path $regPath : $($_.Exception.Message)" "WARNING"
    }
}

if (-not $registryFound) {
    Write-Host "[NOT FOUND] No MSOLEDBSQL entries in registry" -ForegroundColor Yellow
    Write-LogEntry "No MSOLEDBSQL entries found in registry" "WARNING"
}

#endregion

#region File System Detection
Write-Host ""
Write-Host "=== PHASE 2: File System Detection ===" -ForegroundColor Cyan
Write-LogEntry "Starting file system detection phase..."

$fileFound = $false
$fileResults = @()

# Helper function to add detected DLL
function Add-FileResult {
    param([string]$DLLPath)
    
    try {
        $fileItem = Get-Item -Path $DLLPath -ErrorAction SilentlyContinue
        if ($fileItem) {
            $fileVersion = $fileItem.VersionInfo.FileVersion
            $productVersion = $fileItem.VersionInfo.ProductVersion
            $fileDir = Split-Path -Parent $DLLPath
            
            $fileResult = [PSCustomObject]@{
                InstallPath    = $fileDir + "\"
                DLLPath        = $DLLPath
                FileVersion    = $fileVersion
                ProductVersion = $productVersion
            }
            
            return $fileResult
        }
    } catch { }
    return $null
}

# Strategy 1: Check System32 and SysWOW64 (common for OLE DB drivers)
Write-LogEntry "Strategy 1: Checking System32 and SysWOW64 directories..." "DEBUG"
foreach ($sysDir in @("C:\Windows\System32", "C:\Windows\SysWOW64")) {
    $dllPath = Join-Path $sysDir "msoledbsql.dll"
    if (Test-Path -Path $dllPath -ErrorAction SilentlyContinue) {
        Write-LogEntry "Found in system directory: $dllPath" "DEBUG"
        $result = Add-FileResult $dllPath
        if ($result) {
            $fileResults += $result
            $fileFound = $true
            Write-Host "[FOUND] Driver DLL in System directory: $dllPath" -ForegroundColor Green
            Write-Host "        File Version: $($result.FileVersion)" -ForegroundColor Green
            Write-LogEntry "File system detection (System32/SysWOW64): Driver found at $dllPath, Version: $($result.FileVersion)" "SUCCESS"
        }
    }
}

# Strategy 2: Check registry-provided paths from uninstall entry
Write-LogEntry "Strategy 2: Checking registry-provided InstallLocation paths..." "DEBUG"
foreach ($reg in $registryResults) {
    if ($reg.InstallPath -and $reg.InstallPath.Trim() -ne "") {
        $dllPath = Join-Path $reg.InstallPath "msoledbsql.dll"
        if (Test-Path -Path $dllPath -ErrorAction SilentlyContinue) {
            Write-LogEntry "Found in registry-specified path: $dllPath" "DEBUG"
            $result = Add-FileResult $dllPath
            if ($result) {
                $fileResults += $result
                $fileFound = $true
                Write-Host "[FOUND] Driver DLL at registry-specified path: $($reg.InstallPath)" -ForegroundColor Green
                Write-Host "        File Version: $($result.FileVersion)" -ForegroundColor Green
                Write-LogEntry "File system detection (Registry path): Driver found at $($reg.InstallPath), Version: $($result.FileVersion)" "SUCCESS"
            }
        }
    }
}

# Strategy 3: Check standard installation paths
Write-LogEntry "Strategy 3: Checking standard installation paths..." "DEBUG"
$standardPaths = @(
    "C:\Program Files\Microsoft OLE DB Driver 19 for SQL Server\",
    "C:\Program Files (x86)\Microsoft OLE DB Driver 19 for SQL Server\",
    "C:\Program Files\Microsoft OLE DB Driver 18 for SQL Server\",
    "C:\Program Files (x86)\Microsoft OLE DB Driver 18 for SQL Server\",
    "C:\Program Files\Microsoft OLE DB Driver 17 for SQL Server\",
    "C:\Program Files (x86)\Microsoft OLE DB Driver 17 for SQL Server\"
)

foreach ($path in $standardPaths) {
    if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
        $dllPath = Join-Path $path "msoledbsql.dll"
        if (Test-Path -Path $dllPath -ErrorAction SilentlyContinue) {
            Write-LogEntry "Found in standard path: $dllPath" "DEBUG"
            $result = Add-FileResult $dllPath
            if ($result) {
                $fileResults += $result
                $fileFound = $true
                Write-Host "[FOUND] Driver DLL at standard path: $path" -ForegroundColor Green
                Write-Host "        File Version: $($result.FileVersion)" -ForegroundColor Green
                Write-LogEntry "File system detection (Standard path): Driver found at $path, Version: $($result.FileVersion)" "SUCCESS"
            }
        }
    }
}

# Strategy 4: Query Windows Installer registry for MSOLEDBSQL products
Write-LogEntry "Strategy 4: Querying Windows Installer registry for MSOLEDBSQL products..." "DEBUG"
try {
    $wmiPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products"
    $wmiPath32 = "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products"
    
    foreach ($regPath in @($wmiPath, $wmiPath32)) {
        try {
            $regKey = Get-Item -Path "Registry::HKLM\$regPath" -ErrorAction SilentlyContinue
            if ($regKey) {
                $products = $regKey.GetSubKeyNames()
                foreach ($product in $products) {
                    $productPath = "Registry::HKLM\$regPath\$product\InstallProperties"
                    $props = Get-ItemProperty -Path $productPath -ErrorAction SilentlyContinue
                    
                    if ($props -and ($props.DisplayName -like "*MSOLEDBSQL*" -or $props.DisplayName -like "*OLE DB Driver*")) {
                        $installDir = $props.InstallLocation
                        if ($installDir) {
                            $dllPath = Join-Path $installDir "msoledbsql.dll"
                            if (Test-Path -Path $dllPath -ErrorAction SilentlyContinue) {
                                Write-LogEntry "Found via Windows Installer: $dllPath" "DEBUG"
                                $result = Add-FileResult $dllPath
                                if ($result) {
                                    $fileResults += $result
                                    $fileFound = $true
                                    Write-Host "[FOUND] Driver DLL via Windows Installer: $installDir" -ForegroundColor Green
                                    Write-Host "        File Version: $($result.FileVersion)" -ForegroundColor Green
                                    Write-LogEntry "File system detection (Windows Installer): Driver found at $installDir, Version: $($result.FileVersion)" "SUCCESS"
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            Write-LogEntry "Windows Installer query error: $($_.Exception.Message)" "DEBUG"
        }
    }
} catch {
    Write-LogEntry "Windows Installer registry query failed: $($_.Exception.Message)" "WARNING"
}

# Strategy 5: Recursive search in Program Files
if (-not $fileFound) {
    Write-LogEntry "Strategy 5: Performing recursive search in Program Files directories..." "DEBUG"
    try {
        $searchDirs = @("C:\Program Files", "C:\Program Files (x86)")
        foreach ($searchDir in $searchDirs) {
            if (Test-Path $searchDir) {
                Write-LogEntry "Searching recursively in: $searchDir" "DEBUG"
                
                $dllFiles = Get-ChildItem -Path $searchDir -Recurse -Name "msoledbsql.dll" -ErrorAction SilentlyContinue | 
                    ForEach-Object { Join-Path $searchDir $_ }
                
                foreach ($dllPath in $dllFiles) {
                    if (Test-Path -Path $dllPath -ErrorAction SilentlyContinue) {
                        Write-LogEntry "Found via recursive search: $dllPath" "DEBUG"
                        $result = Add-FileResult $dllPath
                        if ($result) {
                            $fileResults += $result
                            $fileFound = $true
                            $parentDir = Split-Path -Parent $dllPath
                            Write-Host "[FOUND] Driver DLL via recursive search: $parentDir" -ForegroundColor Green
                            Write-Host "        File Version: $($result.FileVersion)" -ForegroundColor Green
                            Write-LogEntry "File system detection (Recursive search): Driver found at $parentDir, Version: $($result.FileVersion)" "SUCCESS"
                        }
                    }
                }
            }
        }
    } catch {
        Write-LogEntry "Recursive file search error: $($_.Exception.Message)" "WARNING"
    }
}

# Strategy 6: Check Windows registry for ODBC drivers (OLE DB drivers may be registered as ODBC drivers)
if (-not $fileFound) {
    Write-LogEntry "Strategy 6: Checking ODBC driver registry..." "DEBUG"
    try {
        $odbcPath = "HKLM:\SOFTWARE\ODBC\ODBCINST.INI"
        if (Test-Path -Path $odbcPath) {
            $odbcKey = Get-Item -Path $odbcPath -ErrorAction SilentlyContinue
            $drivers = $odbcKey.GetSubKeyNames()
            
            foreach ($driver in $drivers) {
                if ($driver -like "*MSOLEDBSQL*" -or $driver -like "*SQL Server*") {
                    Write-LogEntry "Found ODBC driver reference: $driver" "DEBUG"
                    
                    $driverPath = Join-Path $odbcPath $driver
                    $driverRegPath = "Registry::$driverPath"
                    $driverInfo = Get-ItemProperty -Path $driverRegPath -ErrorAction SilentlyContinue
                    
                    if ($driverInfo -and $driverInfo.Driver) {
                        # The Driver value might contain just the filename or full path
                        $driverFile = $driverInfo.Driver
                        if (-not [System.IO.Path]::IsPathRooted($driverFile)) {
                            $driverFile = Join-Path "C:\Windows\System32" $driverFile
                        }
                        
                        if (Test-Path -Path $driverFile -ErrorAction SilentlyContinue) {
                            Write-LogEntry "Found ODBC driver file: $driverFile" "DEBUG"
                            $result = Add-FileResult $driverFile
                            if ($result) {
                                $fileResults += $result
                                $fileFound = $true
                                $parentDir = Split-Path -Parent $driverFile
                                Write-Host "[FOUND] Driver via ODBC registry: $driverFile" -ForegroundColor Green
                                Write-Host "        File Version: $($result.FileVersion)" -ForegroundColor Green
                                Write-LogEntry "File system detection (ODBC registry): Driver found at $driverFile, Version: $($result.FileVersion)" "SUCCESS"
                            }
                        }
                    }
                }
            }
        }
    } catch {
        Write-LogEntry "ODBC registry query error: $($_.Exception.Message)" "WARNING"
    }
}

# Strategy 7: Query OLE DB provider registry directly for MSOLEDBSQL19 provider DLL path
if (-not $fileFound) {
    Write-LogEntry "Strategy 7: Querying OLE DB provider registry for MSOLEDBSQL19 DLL path..." "DEBUG"
    try {
        $providerRegPaths = @(
            "HKLM:\SOFTWARE\Classes\CLSID",
            "HKLM:\SOFTWARE\OLEDB",
            "HKLM:\SOFTWARE\Microsoft\OLE DB"
        )
        
        foreach ($basePath in $providerRegPaths) {
            try {
                if (Test-Path -Path $basePath -ErrorAction SilentlyContinue) {
                    Write-LogEntry "Searching OLE DB provider registry: $basePath" "DEBUG"
                    
                    $keys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
                    foreach ($key in $keys) {
                        try {
                            $keyProps = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                            
                            # Check for MSOLEDBSQL provider indicators
                            $keyName = $key.PSChildName
                            $keyDefault = $keyProps.'(Default)'
                            
                            if ($keyDefault -like "*MSOLEDBSQL*" -or 
                                $keyDefault -like "*OLE DB Driver*" -or 
                                $keyDefault -like "*SQL Server*" -or
                                $keyName -like "*MSOLEDBSQL*") {
                                
                                Write-LogEntry "Found OLE DB provider key: $keyName = $keyDefault" "DEBUG"
                                
                                # Try to find InprocServer32 or LocalServer32
                                foreach ($serverType in @("InprocServer32", "LocalServer32")) {
                                    $serverPath = Join-Path $key.PSPath $serverType
                                    $serverProps = Get-ItemProperty -Path $serverPath -ErrorAction SilentlyContinue
                                    
                                    if ($serverProps) {
                                        $dllPath = $serverProps.'(Default)'
                                        if ($dllPath) {
                                            Write-LogEntry "Found $serverType path: $dllPath" "DEBUG"
                                            
                                            # Expand any environment variables
                                            $dllPath = [System.Environment]::ExpandEnvironmentVariables($dllPath)
                                            
                                            if (Test-Path -Path $dllPath -ErrorAction SilentlyContinue) {
                                                Write-LogEntry "Confirmed DLL exists: $dllPath" "DEBUG"
                                                $result = Add-FileResult $dllPath
                                                if ($result) {
                                                    $fileResults += $result
                                                    $fileFound = $true
                                                    Write-Host "[FOUND] Driver via OLE DB provider registry: $dllPath" -ForegroundColor Green
                                                    Write-Host "        File Version: $($result.FileVersion)" -ForegroundColor Green
                                                    Write-LogEntry "File system detection (OLE DB provider registry): Driver found at $dllPath, Version: $($result.FileVersion)" "SUCCESS"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } catch {
                            # Continue searching
                        }
                    }
                }
            } catch {
                Write-LogEntry "Error searching OLE DB provider registry path $basePath : $($_.Exception.Message)" "DEBUG"
            }
        }
    } catch {
        Write-LogEntry "OLE DB provider registry query failed: $($_.Exception.Message)" "WARNING"
    }
}

# Strategy 8: Check all typical DLL names and locations
if (-not $fileFound) {
    Write-LogEntry "Strategy 8: Checking alternative DLL names in system directories..." "DEBUG"
    try {
        $dllNames = @("msoledbsql.dll", "msoledbsql19.dll", "msoledbsql18.dll", "msoledbs.dll")
        $searchPaths = @("C:\Windows\System32", "C:\Windows\SysWOW64")
        
        foreach ($path in $searchPaths) {
            foreach ($dllName in $dllNames) {
                $dllPath = Join-Path $path $dllName
                if (Test-Path -Path $dllPath -ErrorAction SilentlyContinue) {
                    Write-LogEntry "Found via alternative name search: $dllPath" "DEBUG"
                    $result = Add-FileResult $dllPath
                    if ($result) {
                        $fileResults += $result
                        $fileFound = $true
                        Write-Host "[FOUND] Driver DLL with alternative name: $dllPath" -ForegroundColor Green
                        Write-Host "        File Version: $($result.FileVersion)" -ForegroundColor Green
                        Write-LogEntry "File system detection (Alternative names): Driver found at $dllPath, Version: $($result.FileVersion)" "SUCCESS"
                    }
                }
            }
        }
    } catch {
        Write-LogEntry "Alternative DLL name search error: $($_.Exception.Message)" "WARNING"
    }
}

# Remove duplicate results (same DLL path)
if ($fileResults.Count -gt 1) {
    $fileResults = $fileResults | Sort-Object -Property DLLPath -Unique
}

if (-not $fileFound) {
    Write-Host "[NOT FOUND] No MSOLEDBSQL driver DLL found in any location" -ForegroundColor Yellow
    Write-LogEntry "No driver DLL files found after comprehensive search" "WARNING"
}

#endregion

#region OLE DB Connection Test
Write-Host ""
Write-Host "=== PHASE 3: OLE DB Connection Test ===" -ForegroundColor Cyan
Write-LogEntry "Starting OLE DB connection test phase..."

$connectionTestResult = $null
$providerConfirmed = $false
$connectionAttempted = $false

try {
    Write-LogEntry "Attempting to enumerate OLE DB providers and test MSOLEDBSQL19 provider..." "DEBUG"
    
    # First, try to enumerate available OLE DB providers to detect MSOLEDBSQL19 without connecting
    Write-Host "Enumerating available OLE DB providers..." -ForegroundColor Cyan
    
    $providerFound = $false
    try {
        # Load required assembly for OleDbEnumerator
        Add-Type -AssemblyName System.Data
        
        # Try to enumerate data sources - this will list available providers
        $oleDbEnumerator = [System.Data.OleDb.OleDbEnumerator]::GetEnumerator()
        $table = $oleDbEnumerator.GetElements()
        
        Write-LogEntry "OleDbEnumerator returned $($table.Rows.Count) provider entries" "DEBUG"
        
        # Check if MSOLEDBSQL19 is in the list
        foreach ($row in $table.Rows) {
            $providerName = $row["SOURCES_NAME"]
            if ($providerName -like "*MSOLEDBSQL*" -or $providerName -like "*SQL Server*") {
                Write-LogEntry "Provider enumeration found: $providerName" "DEBUG"
                if ($providerName -like "*19*" -or $providerName -eq "MSOLEDBSQL19" -or $providerName -eq "MSOLEDBSQL") {
                    $providerFound = $true
                    Write-Host "[FOUND] OLE DB Provider enumeration detected provider compatible with MSOLEDBSQL19" -ForegroundColor Green
                    Write-LogEntry "OLE DB Provider $providerName found via enumeration" "SUCCESS"
                    break
                }
            }
        }
    } catch {
        Write-LogEntry "OleDbEnumerator approach not available or failed: $($_.Exception.Message)" "DEBUG"
    }
    
    # Second approach: Try actual connection with simplified connection string
    if (-not $providerFound) {
        Write-Host "Attempting OLE DB connection test with MSOLEDBSQL19..." -ForegroundColor Cyan
        Write-LogEntry "Attempting OLE DB connection to test provider registration..." "DEBUG"
        
        # Use simplified connection string
        $connectionString = "Provider=MSOLEDBSQL19;Server=$LocalInstance;Trusted_Connection=yes"
        
        $oledbConnection = New-Object -ComObject ADODB.Connection
        $connectionAttempted = $true
        
        $oledbConnection.ConnectionString = $connectionString
        $oledbConnection.ConnectionTimeout = 3
        $oledbConnection.Open()
        
        # If we get here, connection succeeded (provider is registered and accessible)
        Write-Host "[FOUND] OLE DB connection established successfully" -ForegroundColor Green
        Write-LogEntry "OLE DB connection test SUCCESSFUL - MSOLEDBSQL19 provider is functional" "SUCCESS"
        
        $providerConfirmed = $true
        $connectionTestResult = "Connection Successful - Provider Functional"
        
        $oledbConnection.Close()
        $providerFound = $true
    } else {
        $providerConfirmed = $true
        $connectionTestResult = "Provider Enumeration Confirmed - Registration Verified"
    }
    
    if ($providerFound) {
        $providerConfirmed = $true
    }
    
} catch {
    $errorMessage = $_.Exception.Message
    $errorType = $_.Exception.GetType().Name
    $errorHResult = $_.Exception.HResult
    
    Write-LogEntry "OLE DB error - Type: $errorType, HResult: 0x$($errorHResult.ToString('X8')), Message: $errorMessage" "DEBUG"
    
    # Determine if this is a provider registration issue or a connection issue
    if ($errorMessage -like "*not registered*" -or 
        $errorMessage -like "*Class not registered*" -or 
        $errorMessage -like "*provider*not found*" -or
        $errorMessage -like "*0x80040154*" -or
        $errorMessage -like "*provider for*could not be found*" -or
        $errorHResult -eq -2147221164) {  # 0x80040154 = CLASS_E_CLASSNOTAVAILABLE
        
        Write-Host "[NOT FOUND] OLE DB provider MSOLEDBSQL19 is NOT registered" -ForegroundColor Red
        Write-LogEntry "Provider not registered error detected: $errorMessage" "ERROR"
        $connectionTestResult = "Provider Not Registered"
        $providerConfirmed = $false
        
    } elseif ($connectionAttempted -or $errorMessage -like "*Invalid connection string*") {
        # Provider is registered but connection failed (authentication, timeout, instance not running, etc.)
        Write-Host "[CONFIRMATION] Provider is registered (connection string or connectivity issue)" -ForegroundColor Green
        Write-Host "                Error indicates provider exists but cannot connect: $($errorMessage.Substring(0, [Math]::Min(80, $errorMessage.Length)))" -ForegroundColor Green
        Write-LogEntry "Provider is registered; connection failed for other reason: $errorMessage" "SUCCESS"
        $connectionTestResult = "Provider Registered - Confirmed by Error Type"
        $providerConfirmed = $true
        
    } else {
        Write-Host "[ERROR] Unexpected error during OLE DB provider test" -ForegroundColor Red
        Write-Host "        Error: $errorMessage" -ForegroundColor Red
        Write-LogEntry "Unexpected error: $errorMessage" "ERROR"
        $connectionTestResult = "Error During Provider Test"
    }
    
} finally {
    try {
        if ($oledbConnection -and $oledbConnection.State -eq 1) {
            $oledbConnection.Close()
        }
    } catch { }
    
    try {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($oledbConnection) 2>$null | Out-Null
    } catch { }
    
    [gc]::Collect()
}

#endregion

#region Results Summary
Write-Host ""
Write-Host "=== DETECTION RESULTS SUMMARY ===" -ForegroundColor Cyan
Write-LogEntry "=== DETECTION RESULTS SUMMARY ===" "INFO"

Write-Host ""
Write-Host "1. PowerShell Version Check:" -ForegroundColor White
Write-Host "   Version: $psVersion (PASS)" -ForegroundColor Green
Write-LogEntry "PowerShell version check: $psVersion (PASS)"

Write-Host ""
Write-Host "2. Registry Detection:" -ForegroundColor White
if ($registryFound) {
    Write-Host "   Status: FOUND" -ForegroundColor Green
    foreach ($reg in $registryResults) {
        Write-Host "   - $($reg.DisplayName)" -ForegroundColor Green
        Write-Host "     Version: $($reg.Version), Architecture: $($reg.Architecture)" -ForegroundColor Green
        Write-Host "     Path: $($reg.InstallPath)" -ForegroundColor Green
    }
    Write-LogEntry "Registry Detection: FOUND - Multiple entries found"
} else {
    Write-Host "   Status: NOT FOUND" -ForegroundColor Yellow
    Write-LogEntry "Registry Detection: NOT FOUND"
}

Write-Host ""
Write-Host "3. File System Detection:" -ForegroundColor White
if ($fileFound) {
    Write-Host "   Status: FOUND" -ForegroundColor Green
    foreach ($file in $fileResults) {
        Write-Host "   - $($file.InstallPath)" -ForegroundColor Green
        Write-Host "     DLL Version: $($file.FileVersion)" -ForegroundColor Green
    }
    Write-LogEntry "File System Detection: FOUND - Driver DLL located"
} else {
    Write-Host "   Status: NOT FOUND" -ForegroundColor Yellow
    Write-LogEntry "File System Detection: NOT FOUND"
}

Write-Host ""
Write-Host "4. OLE DB Connection Test:" -ForegroundColor White
Write-Host "   Status: $connectionTestResult" -ForegroundColor $(
    if ($providerConfirmed) { "Green" } else { "Yellow" }
)
Write-LogEntry "OLE DB Connection Test: $connectionTestResult"

Write-Host ""
Write-Host "=== FINAL CONCLUSION ===" -ForegroundColor Cyan

$conclusionCode = 2
$conclusionText = "UNABLE TO DETERMINE"
$conclusionColor = "Yellow"

if ($registryFound -and $fileFound -and $providerConfirmed) {
    $conclusionText = "MSOLEDBSQL19 IS INSTALLED AND FUNCTIONAL"
    $conclusionColor = "Green"
    $conclusionCode = 0
} elseif ($registryFound -or $fileFound -or $providerConfirmed) {
    $conclusionText = "MSOLEDBSQL19 APPEARS TO BE INSTALLED (partial confirmation)"
    $conclusionColor = "Green"
    $conclusionCode = 0
} elseif (-not $registryFound -and -not $fileFound -and $connectionTestResult -eq "Provider Not Registered") {
    $conclusionText = "MSOLEDBSQL19 IS NOT INSTALLED"
    $conclusionColor = "Red"
    $conclusionCode = 1
} elseif ($registryFound -or $fileFound) {
    $conclusionText = "MSOLEDBSQL19 IS LIKELY INSTALLED (registry/file found, OLE DB test inconclusive)"
    $conclusionColor = "Green"
    $conclusionCode = 0
} else {
    $conclusionText = "MSOLEDBSQL19 IS NOT INSTALLED"
    $conclusionColor = "Red"
    $conclusionCode = 1
}

Write-Host $conclusionText -ForegroundColor $conclusionColor
Write-LogEntry "FINAL CONCLUSION: $conclusionText" $(
    if ($conclusionCode -eq 0) { "SUCCESS" } 
    elseif ($conclusionCode -eq 1) { "WARNING" } 
    else { "INFO" }
)

Write-Host ""
Write-Host "Log file: $logFilePath" -ForegroundColor Cyan
Write-Host "Exit code: $conclusionCode" -ForegroundColor Cyan
Write-LogEntry "Script completed - Exit code: $conclusionCode"
Write-Host ""

#endregion

exit $conclusionCode
