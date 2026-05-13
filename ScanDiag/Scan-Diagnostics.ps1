#Requires -Version 5.0
<#
.SYNOPSIS
    Scan Diagnostics Script
    Executes scanner diagnostics, collects driver information, and generates diagnostic reports.

.DESCRIPTION
    This script performs the following operations:
    1. Cleans up previous diagnostic output files
    2. Executes the REJIS ScannerApp to generate diagnostic PDF
    3. Detects and inventories installed scanner drivers
    4. Generates diagnostic logs and reports
    5. Opens output files for review

.NOTES
    Author: REJIS
    Date: May 2026
    Compatibility: Windows 11, Common PowerShell versions (5.0+)
#>

# ============================================================================
# CONFIGURATION & PATHS
# ============================================================================

$ErrorActionPreference = "Continue"
$WarningPreference = "Continue"

# Parse system environment variables
$TempPath = $env:TEMP
$PublicPath = $env:PUBLIC

# Define output directory and files
$OutputDir = Join-Path $TempPath "REJIS\IMDSPlus"
$OutputPdf = Join-Path $OutputDir "scan-diagnostics.pdf"
$OutputLog = Join-Path $OutputDir "scan-diagnostics.log"
$OutputJson = Join-Path $OutputDir "scan-diagnostics.json"

# Define scanner application path
$ScannerAppPath = Join-Path $PublicPath "AppData\Local\REJIS\IMDSPlus\plus_prod_x64\ScannerApp_x64.exe"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-LogEntry {
    <#
    .SYNOPSIS
        Writes a log entry with timestamp to the log file and console.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    Write-Host $LogMessage
    Add-Content -Path $OutputLog -Value $LogMessage
}

function Test-DirectoryExists {
    <#
    .SYNOPSIS
        Tests if directory exists, creates if missing.
    #>
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-LogEntry "Created directory: $Path" "INFO"
            return $true
        }
        catch {
            Write-LogEntry "Failed to create directory: $Path - $_" "ERROR"
            return $false
        }
    }
    return $true
}

function Test-ApplicationExists {
    <#
    .SYNOPSIS
        Tests if scanner application exists at specified path.
    #>
    param([string]$AppPath)
    
    if (Test-Path $AppPath) {
        Write-LogEntry "Scanner application found: $AppPath" "INFO"
        return $true
    }
    else {
        Write-LogEntry "Scanner application NOT found: $AppPath" "ERROR"
        return $false
    }
}

# ============================================================================
# STEP 1: FILE CLEANUP
# ============================================================================

function Invoke-FileCleanup {
    Write-Host "`n========== STEP 1: FILE CLEANUP ==========" -ForegroundColor Cyan
    Write-LogEntry "=== STEP 1: FILE CLEANUP ===" "INFO"
    
    $SearchPattern = Join-Path $OutputDir "scan-diagnostics.*"
    $FilesToDelete = @(Get-Item -Path $SearchPattern -ErrorAction SilentlyContinue)
    
    if ($FilesToDelete.Count -gt 0) {
        foreach ($File in $FilesToDelete) {
            try {
                Remove-Item -Path $File.FullName -Force
                Write-LogEntry "Deleted: $($File.FullName)" "INFO"
            }
            catch {
                Write-LogEntry "Failed to delete: $($File.FullName) - $_" "WARNING"
            }
        }
        Write-LogEntry "File cleanup completed. $($FilesToDelete.Count) file(s) removed." "SUCCESS"
    }
    else {
        Write-LogEntry "No previous diagnostic files found to cleanup." "INFO"
    }
}

# ============================================================================
# STEP 2: EXECUTE SCANNER APPLICATION
# ============================================================================

function Invoke-ScannerApplication {
    Write-Host "`n========== STEP 2: EXECUTE SCANNER APPLICATION ==========" -ForegroundColor Cyan
    Write-LogEntry "=== STEP 2: EXECUTE SCANNER APPLICATION ===" "INFO"
    
    if (-not (Test-ApplicationExists $ScannerAppPath)) {
        Write-Host "ERROR: Scanner application not found!" -ForegroundColor Red
        return $false
    }
    
    # Get the directory where the scanner application is located
    $ScannerAppDir = Split-Path -Parent $ScannerAppPath
    Write-LogEntry "Scanner application directory: $ScannerAppDir" "INFO"
    
    # Check for fj-scannerlist.txt in the scanner app directory
    $ScannerListFile = Join-Path $ScannerAppDir "fj-scannerlist.txt"
    if (Test-Path $ScannerListFile) {
        Write-LogEntry "Found fj-scannerlist.txt: $ScannerListFile" "INFO"
    }
    else {
        Write-LogEntry "WARNING: fj-scannerlist.txt not found in scanner app directory" "WARNING"
    }
    
    $Arguments = @(
        '--output', "`"$OutputPdf`"",
        '--bitdepth', 'color',
        '--dpi', '300',
        '--pagesize', 'letter',
        '--source', 'duplex'
    )
    
    Write-LogEntry "Launching ScannerApp_x64.exe with parameters:" "INFO"
    Write-LogEntry "  Output PDF: $OutputPdf" "INFO"
    Write-LogEntry "  Bit Depth: color" "INFO"
    Write-LogEntry "  DPI: 300" "INFO"
    Write-LogEntry "  Page Size: letter" "INFO"
    Write-LogEntry "  Source: duplex" "INFO"
    
    try {
        # Save current location and change to scanner app directory
        $OriginalLocation = Get-Location
        Set-Location -Path $ScannerAppDir
        Write-LogEntry "Changed working directory to: $ScannerAppDir" "INFO"
        
        $Process = Start-Process -FilePath $ScannerAppPath -ArgumentList $Arguments -NoNewWindow -PassThru -Wait
        
        # Return to original location
        Set-Location -Path $OriginalLocation
        Write-LogEntry "Returned to original directory: $OriginalLocation" "INFO"
        
        if ($Process.ExitCode -eq 0) {
            Write-LogEntry "ScannerApp_x64.exe completed successfully." "SUCCESS"
            
            # Verify output files were created
            if (Test-Path $OutputPdf) {
                Write-LogEntry "Output PDF created: $OutputPdf" "SUCCESS"
            }
            if (Test-Path $OutputJson) {
                Write-LogEntry "Output JSON created: $OutputJson" "SUCCESS"
            }
            
            return $true
        }
        else {
            Write-LogEntry "ScannerApp_x64.exe completed with exit code: $($Process.ExitCode)" "WARNING"
            return $true  # Continue despite non-zero exit
        }
    }
    catch {
        Write-LogEntry "Failed to execute ScannerApp_x64.exe: $_" "ERROR"
        return $false
    }
}

# ============================================================================
# STEP 3: DETECT SCANNER DRIVERS
# ============================================================================

function Get-ScannerDrivers {
    Write-Host "`n========== STEP 3: SCANNER DRIVER INVENTORY ==========" -ForegroundColor Cyan
    Write-LogEntry "`n=== STEP 3: SCANNER DRIVER INVENTORY ===" "INFO"
    Write-LogEntry "Detecting installed scanner drivers..." "INFO"
    
    $Drivers = @()
    
    # Detect TWAIN 32-bit drivers
    Write-LogEntry "Scanning for TWAIN 32-bit drivers..." "INFO"
    $Twain32Path = "HKLM:\Software\TWAIN_SYSTEM\TWAIN"
    if (Test-Path $Twain32Path) {
        try {
            $Twain32Items = Get-ChildItem -Path $Twain32Path -ErrorAction SilentlyContinue
            if ($Twain32Items) {
                foreach ($Item in $Twain32Items) {
                    $DriverName = $Item.PSChildName
                    $Manufacturer = (Get-ItemProperty -Path $Item.PSPath -Name "Manufacturer" -ErrorAction SilentlyContinue).Manufacturer
                    $DriverVersion = (Get-ItemProperty -Path $Item.PSPath -Name "Version" -ErrorAction SilentlyContinue).Version
                    $ProductName = (Get-ItemProperty -Path $Item.PSPath -Name "ProductName" -ErrorAction SilentlyContinue).ProductName
                    $ProductFamily = (Get-ItemProperty -Path $Item.PSPath -Name "ProductFamily" -ErrorAction SilentlyContinue).ProductFamily
                    
                    $Driver = [PSCustomObject]@{
                        Type = "TWAIN 32-bit"
                        "Driver Name" = $DriverName
                        "Manufacturer" = $Manufacturer
                        "Driver Version" = $DriverVersion
                        "Product Name" = $ProductName
                        "Product Family" = $ProductFamily
                    }
                    $Drivers += $Driver
                    Write-LogEntry "  Found TWAIN 32-bit: $DriverName" "INFO"
                    Write-LogEntry "    Manufacturer: $Manufacturer" "INFO"
                    Write-LogEntry "    Driver Version: $DriverVersion" "INFO"
                    Write-LogEntry "    Product Name: $ProductName" "INFO"
                    Write-LogEntry "    Product Family: $ProductFamily" "INFO"
                }
            }
        }
        catch {
            Write-LogEntry "  Error scanning TWAIN 32-bit registry: $_" "WARNING"
        }
    }
    
    # Detect TWAIN 64-bit drivers
    Write-LogEntry "Scanning for TWAIN 64-bit drivers..." "INFO"
    $Twain64Path = "HKLM:\Software\WOW6432Node\TWAIN_SYSTEM\TWAIN"
    if (Test-Path $Twain64Path) {
        try {
            $Twain64Items = Get-ChildItem -Path $Twain64Path -ErrorAction SilentlyContinue
            if ($Twain64Items) {
                foreach ($Item in $Twain64Items) {
                    $DriverName = $Item.PSChildName
                    $Manufacturer = (Get-ItemProperty -Path $Item.PSPath -Name "Manufacturer" -ErrorAction SilentlyContinue).Manufacturer
                    $DriverVersion = (Get-ItemProperty -Path $Item.PSPath -Name "Version" -ErrorAction SilentlyContinue).Version
                    $ProductName = (Get-ItemProperty -Path $Item.PSPath -Name "ProductName" -ErrorAction SilentlyContinue).ProductName
                    $ProductFamily = (Get-ItemProperty -Path $Item.PSPath -Name "ProductFamily" -ErrorAction SilentlyContinue).ProductFamily
                    
                    $Driver = [PSCustomObject]@{
                        Type = "TWAIN 64-bit"
                        "Driver Name" = $DriverName
                        "Manufacturer" = $Manufacturer
                        "Driver Version" = $DriverVersion
                        "Product Name" = $ProductName
                        "Product Family" = $ProductFamily
                    }
                    $Drivers += $Driver
                    Write-LogEntry "  Found TWAIN 64-bit: $DriverName" "INFO"
                    Write-LogEntry "    Manufacturer: $Manufacturer" "INFO"
                    Write-LogEntry "    Driver Version: $DriverVersion" "INFO"
                    Write-LogEntry "    Product Name: $ProductName" "INFO"
                    Write-LogEntry "    Product Family: $ProductFamily" "INFO"
                }
            }
        }
        catch {
            Write-LogEntry "  Error scanning TWAIN 64-bit registry: $_" "WARNING"
        }
    }
    
    # Detect WIA (Windows Image Acquisition) drivers
    Write-LogEntry "Scanning for WIA drivers..." "INFO"
    $WiaPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\StillImage"
    if (Test-Path $WiaPath) {
        try {
            $WiaItems = Get-ChildItem -Path $WiaPath -ErrorAction SilentlyContinue
            if ($WiaItems) {
                foreach ($Item in $WiaItems) {
                    $DriverName = $Item.PSChildName
                    $Manufacturer = (Get-ItemProperty -Path $Item.PSPath -Name "Manufacturer" -ErrorAction SilentlyContinue).Manufacturer
                    $DriverVersion = (Get-ItemProperty -Path $Item.PSPath -Name "Version" -ErrorAction SilentlyContinue).Version
                    $ProductName = (Get-ItemProperty -Path $Item.PSPath -Name "ProductName" -ErrorAction SilentlyContinue).ProductName
                    $ProductFamily = (Get-ItemProperty -Path $Item.PSPath -Name "ProductFamily" -ErrorAction SilentlyContinue).ProductFamily
                    
                    $Driver = [PSCustomObject]@{
                        Type = "WIA"
                        "Driver Name" = $DriverName
                        "Manufacturer" = $Manufacturer
                        "Driver Version" = $DriverVersion
                        "Product Name" = $ProductName
                        "Product Family" = $ProductFamily
                    }
                    $Drivers += $Driver
                    Write-LogEntry "  Found WIA: $DriverName" "INFO"
                    Write-LogEntry "    Manufacturer: $Manufacturer" "INFO"
                    Write-LogEntry "    Driver Version: $DriverVersion" "INFO"
                    Write-LogEntry "    Product Name: $ProductName" "INFO"
                    Write-LogEntry "    Product Family: $ProductFamily" "INFO"
                }
            }
        }
        catch {
            Write-LogEntry "  Error scanning WIA registry: $_" "WARNING"
        }
    }
    
    # Append driver summary to log
    Write-LogEntry "`n--- DRIVER SUMMARY ---" "INFO"
    Write-LogEntry "Total drivers detected: $($Drivers.Count)" "INFO"
    
    if ($Drivers.Count -gt 0) {
        $DriversByType = $Drivers | Group-Object Type
        foreach ($Group in $DriversByType) {
            Write-LogEntry "`n$($Group.Name): $($Group.Count)" "INFO"
            foreach ($Driver in $Group.Group) {
                Write-LogEntry "  Driver Name: $($Driver.'Driver Name')" "INFO"
                Write-LogEntry "    Manufacturer: $($Driver.Manufacturer)" "INFO"
                Write-LogEntry "    Version: $($Driver.'Driver Version')" "INFO"
                Write-LogEntry "    Product Name: $($Driver.'Product Name')" "INFO"
                Write-LogEntry "    Product Family: $($Driver.'Product Family')" "INFO"
            }
        }
    }
    
    return $Drivers
}

# ============================================================================
# STEP 4: OPEN OUTPUT FILES
# ============================================================================

function Invoke-OpenOutputFiles {
    Write-Host "`n========== STEP 4: OPENING OUTPUT FILES ==========" -ForegroundColor Cyan
    Write-LogEntry "`n=== STEP 4: OPENING OUTPUT FILES ===" "INFO"
    
    # Open log file in default text editor
    if (Test-Path $OutputLog) {
        Write-LogEntry "Opening log file: $OutputLog" "INFO"
        try {
            & notepad $OutputLog
            Write-LogEntry "Log file opened successfully." "SUCCESS"
        }
        catch {
            Write-LogEntry "Failed to open log file: $_" "WARNING"
        }
    }
    else {
        Write-LogEntry "Log file not found: $OutputLog" "WARNING"
    }
    
    # Open JSON file in Notepad
    if (Test-Path $OutputJson) {
        Write-LogEntry "Opening JSON file: $OutputJson" "INFO"
        try {
            & notepad $OutputJson
            Write-LogEntry "JSON file opened successfully." "SUCCESS"
        }
        catch {
            Write-LogEntry "Failed to open JSON file: $_" "WARNING"
        }
    }
    else {
        Write-LogEntry "JSON file not found: $OutputJson" "WARNING"
    }
    
    # Open PDF file with default viewer
    if (Test-Path $OutputPdf) {
        Write-LogEntry "Opening PDF file: $OutputPdf" "INFO"
        try {
            Start-Process $OutputPdf
            Write-LogEntry "PDF file opened successfully." "SUCCESS"
        }
        catch {
            Write-LogEntry "Failed to open PDF file: $_" "WARNING"
        }
    }
    else {
        Write-LogEntry "PDF file not found: $OutputPdf" "WARNING"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  SCAN DIAGNOSTICS SCRIPT" -ForegroundColor Yellow
    Write-Host "  Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    # Initialize log file
    if (-not (Test-DirectoryExists $OutputDir)) {
        Write-Host "ERROR: Cannot create output directory!" -ForegroundColor Red
        return 1
    }
    
    # Create new log file
    $null = New-Item -Path $OutputLog -ItemType File -Force
    Write-LogEntry "Scan Diagnostics Script Started" "INFO"
    Write-LogEntry "Output Directory: $OutputDir" "INFO"
    Write-LogEntry "================================================" "INFO"
    
    # Execute workflow steps
    Invoke-FileCleanup
    Invoke-ScannerApplication
    Get-ScannerDrivers
    Invoke-OpenOutputFiles
    
    Write-LogEntry "================================================" "INFO"
    Write-LogEntry "Scan Diagnostics Script Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "SUCCESS"
    
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "  SCRIPT COMPLETED" -ForegroundColor Yellow
    Write-Host "  Log file: $OutputLog" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    return 0
}

# Execute main function
exit (Main)
