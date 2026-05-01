# MSOLEDBSQL19 Installation Detection Script

A PowerShell script that verifies whether Microsoft OLE DB Driver 19 for SQL Server (MSOLEDBSQL19) is installed on the system using three complementary detection methods.

## Overview

The script performs comprehensive detection using three complementary phases:

1. **Registry Scan** – Searches Windows registry uninstall hives (both 64-bit and 32-bit) for MSOLEDBSQL19 entries
2. **File System Check (8-Strategy)** – Comprehensive multi-method approach to locate driver DLL across all possible installation locations, with OLE DB Provider Registry (Strategy 7) as primary method
3. **OLE DB Connection Test** – Attempts OLE DB provider enumeration and connection to confirm provider registration

Results are output to both console (with color-coded status indicators) and log file `Check-MSOLEDBSQL19.log`.

## Requirements

- **PowerShell:** 5.0 or later (Windows 10/Server 2016+)
- **Permissions:** Standard user (registry read access); Admin recommended for full file system search
- **Platform:** Windows only

## Installation

1. Copy `Check-MSOLEDBSQL19.ps1` to your desired location
2. No additional dependencies or installation required

## Usage

### Basic Usage

```powershell
# Navigate to script directory
cd "d:\REJIS\_devs\verbose-telegram\VerifyMsOleDb"

# Run script with default settings
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Check-MSOLEDBSQL19.ps1"
```

### With Verbose Output

```powershell
# Show detailed DEBUG-level log entries in console
.\Check-MSOLEDBSQL19.ps1 -Verbose
```

### Specify Local Instance

```powershell
# Test connection to a specific named instance (default is "." for local)
.\Check-MSOLEDBSQL19.ps1 -LocalInstance ".\SQLEXPRESS"

# Test with IP address or server name
.\Check-MSOLEDBSQL19.ps1 -LocalInstance "127.0.0.1"
```

### Combine Parameters

```powershell
.\Check-MSOLEDBSQL19.ps1 -LocalInstance ".\SQL2019" -Verbose
```

## Exit Codes

| Code | Meaning | Details |
|------|---------|---------|
| **0** | MSOLEDBSQL19 is installed | Driver detected via registry, file system, or provider registration |
| **1** | MSOLEDBSQL19 is NOT installed | All detection methods returned negative results |
| **2** | Script error or unable to determine | PowerShell version < 5.0 or unexpected error during detection |

### Example: Use in Batch Scripts

```batch
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "Check-MSOLEDBSQL19.ps1"
if %ERRORLEVEL% EQU 0 (
    echo MSOLEDBSQL19 is installed
) else if %ERRORLEVEL% EQU 1 (
    echo MSOLEDBSQL19 is NOT installed
) else (
    echo Error: Could not determine installation status
)
```

## Output Format

### Console Output

**Color-coded indicators:**
- 🟢 **GREEN** – Component passed/found (e.g., "[OK]", "[FOUND]", "[CONFIRMATION]")
- 🔴 **RED** – Component failed/not found (e.g., "[NOT FOUND]", "[ERROR]")
- 🟡 **YELLOW** – Warning/inconclusive (e.g., "[WARNING]", "[INCONCLUSIVE]")
- 🔵 **CYAN** – Section headers and section breaks

### Example Output

```
============================================
MSOLEDBSQL19 Installation Detection Script
============================================

[OK] PowerShell version 5.1.26100.8115 is supported
[OK] Log file created: D:\...\Check-MSOLEDBSQL19.log

=== PHASE 1: Registry Detection ===
[FOUND] Microsoft OLE DB Driver 19 for SQL Server (Version: 19.4.1.0, Arch: 64-bit)

=== PHASE 2: File System Detection ===
[FOUND] Driver via OLE DB provider registry: C:\WINDOWS\system32\msoledbsql19.dll
        File Version: 2019.0194.0001.00

=== PHASE 3: OLE DB Connection Test ===
[CONFIRMATION] Provider is registered (connection string or connectivity issue)
                Error indicates provider exists but cannot connect: Named Pipes Provider: Could not open a connection to SQL Server [2].

=== FINAL CONCLUSION ===
MSOLEDBSQL19 IS INSTALLED AND FUNCTIONAL
Exit code: 0
```

## Log Files

**Location:** Same directory as script
- **Filename:** `Check-MSOLEDBSQL19.log` (named after the PS1 script file)
- **Updates:** New runs overwrite the previous log file with latest detection results
- **Note:** Each execution includes timestamp entries for tracking

**Log Levels:**
- `[INFO]` – Informational messages
- `[DEBUG]` – Detailed diagnostic information (shown in console with `-Verbose` flag)
- `[SUCCESS]` – Successful operation results
- `[WARNING]` – Non-critical issues or inconclusive results
- `[ERROR]` – Error conditions

**Example Log Entry:**
```
[2026-04-29 11:01:15] [DEBUG] Found OLE DB provider key: {EE5DE99A-4453-4C96-861C-F8832A7F59FE} = MSOLEDBSQL19
[2026-04-29 11:01:15] [DEBUG] Found InprocServer32 path: C:\WINDOWS\system32\msoledbsql19.dll
[2026-04-29 11:01:15] [SUCCESS] File system detection (OLE DB provider registry): Driver found at C:\WINDOWS\system32\msoledbsql19.dll, Version: 2019.0194.0001.00
```

## Detection Methods Explained

### 1. Registry Detection (Phase 1)

Searches two registry hives:
- **64-bit:** `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`
- **32-bit:** `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall`

Looks for entries with `DisplayName` matching:
- `*MSOLEDBSQL*`
- `*OLE DB Driver*`

Extracts:
- Display Name
- Version (e.g., 19.4.1.0)
- Architecture (64-bit or 32-bit)
- Installation Path (if available)

### 2. File System Detection (Phase 2)

Comprehensive 8-strategy approach to reliably locate the MSOLEDBSQL19 driver DLL across all possible installation locations:

#### Detection Strategies (in order):

| # | Strategy | Target Location | Purpose |
|---|----------|-----------------|---------|
| **1** | System32/SysWOW64 Check | `C:\Windows\System32` & `C:\Windows\SysWOW64` | Baseline check for system directory installation |
| **2** | Registry-Provided Paths | Paths from uninstall registry entries | Uses InstallLocation values from PHASE 1 results |
| **3** | Standard Installation Paths | Standard OLE DB driver locations | Checks common Microsoft default paths (v17, 18, 19) |
| **4** | Windows Installer Registry | `HKLM:\SOFTWARE\...\Installer\...` | Finds GUID-based installations from MSI installs |
| **5** | Recursive Program Files Search | `C:\Program Files` recursively | Exhaustive directory traversal for non-standard locations |
| **6** | ODBC Driver Registry | `HKLM:\SOFTWARE\ODBC\ODBCINST.INI` | Queries ODBC driver registry references |
| **7** | **OLE DB Provider Registry (Advanced)** | `HKLM:\SOFTWARE\Classes\CLSID` | ⭐ Enumerates OLE DB CLSID entries for provider DLLs (most reliable) |
| **8** | **Alternative DLL Names** | System32/SysWOW64 with variants | Checks `msoledbsql19.dll`, `msoledbsql18.dll`, etc. |

#### What It Checks:

For each discovered path, verifies:
- `msoledbsql.dll` or variant exists
- Extracts **file version** from DLL metadata
- Extracts **product version** from DLL metadata
- Deduplicates results (removes duplicates by DLL path)

#### Key Breakthrough: Strategy 7

The OLE DB Provider Registry query is the most reliable method because it:
1. Directly queries HKLM:\SOFTWARE\Classes\CLSID for MSOLEDBSQL19 provider registrations
2. Reads InprocServer32 or LocalServer32 registry values pointing to actual DLL paths
3. Finds the DLL regardless of custom installation directories
4. Works even when InstallLocation registry values are empty
5. Detects all MSOLEDBSQL19 provider variations (connection pages, advanced pages, etc.)

**Example Discovery Process:**
```
Registry CLSID: {EE5DE99A-4453-4C96-861C-F8832A7F59FE} 
Provider Name: MSOLEDBSQL19
InprocServer32: C:\WINDOWS\system32\msoledbsql19.dll
DLL Version: 2019.0194.0001.00
```

#### Results:

- **ALL methods combined** ensure detection across diverse environments
- **Deduplication** prevents false multiple-found reports
- **Multiple driver versions** detected if present (e.g., v17, 18, 19)
- **Non-standard installations** reliably located via OLE DB provider registry

### 3. OLE DB Connection Test (Phase 3)

**Primary Approach:**
- Attempts to enumerate available OLE DB providers via `System.Data.OleDb.OleDbEnumerator`
- Detects `MSOLEDBSQL19` or `MSOLEDBSQL` in provider list

**Secondary Approach** (if enumeration fails):
- Creates ADODB connection object
- Sets connection string: `Provider=MSOLEDBSQL19;Server=<instance>;Trusted_Connection=yes`
- Attempts connection with 3-second timeout

**Error Analysis:**
- If error mentions "not registered", "class not registered", or HRESULT 0x80040154 → Provider NOT installed
- If error is "Named Pipes Provider: Could not open connection", "Login failed", "Connection timeout" → Provider IS installed but connection failed
- "Invalid connection string attribute" → Provider is registered (error in string format or connection attempt)

## Troubleshooting

### PowerShell 5.0+ Required

**Error:** `[ERROR] PowerShell 5.0 or later is required`

**Solution:** 
- Upgrade to PowerShell 5.0+ or Windows PowerShell 5.1
- Or use PowerShell 7+ (cross-platform edition)

### Script Execution Policy Blocked

**Error:** `File cannot be loaded because running scripts is disabled`

**Solution:**
```powershell
# Option 1: Bypass for single execution
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Check-MSOLEDBSQL19.ps1"

# Option 2: Set permanent policy (requires admin)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Log File Not Created

**Cause:** Script directory not writable

**Solution:**
- Run script from a user-writable directory
- Verify file system permissions on script directory
- Script will still output to console even if log creation fails

### Registry Access Denied

**Cause:** Standard user on restricted system

**Solution:**
- Run as Administrator for full registry access
- Non-admin users can still get registry information from their own registry hive

### File System Detection Still Shows "NOT FOUND" Rarely

**Rare Cause:** Driver is installed in extremely non-standard location not accessible via any detection strategy

**Solution:**
- Enable Verbose mode to see which strategies succeeded: `.\Check-MSOLEDBSQL19.ps1 -Verbose`
- Check log file for detailed strategy execution (Strategy 7 is most reliable)
- If registry and provider registration tests pass, driver is installed
- File system detection is secondary validation; provider registration is primary confirmation

## Architecture & Code Structure

### Main Phases

1. **Initialization & Validation (Lines 1-80)**
   - Check PowerShell version
   - Initialize log file
   - Set up helper functions (`Write-LogEntry`)

2. **Registry Detection (Lines 82-140)**
   - Scan 64-bit and 32-bit uninstall hives
   - Extract and format registry results

3. **File System Detection (Lines 142-440)** ⭐ Expanded Phase
   - Helper function `Add-FileResult` – unified DLL detection and extraction
   - **Strategy 1:** System32/SysWOW64 directory check
   - **Strategy 2:** Registry-provided InstallLocation paths (from Phase 1)
   - **Strategy 3:** Standard installation paths
   - **Strategy 4:** Windows Installer registry query
   - **Strategy 5:** Recursive Program Files search
   - **Strategy 6:** ODBC driver registry query
   - **Strategy 7:** OLE DB Provider Registry CLSID enumeration (primary strategy)
   - **Strategy 8:** Alternative DLL name variants
   - Deduplication of results by DLL path

4. **OLE DB Connection Test (Lines 442-560)**
   - Attempt provider enumeration via `System.Data.OleDb.OleDbEnumerator`
   - Fallback to ADODB connection attempt with error analysis
   - Distinguish provider-not-registered vs. connection-failed errors
   - Properly release COM objects

5. **Results & Reporting (Lines 562-660)**
   - Format summary from all three detection phases
   - Calculate final conclusion logic
   - Output to console with color coding
   - Log all results with timestamps
   - Exit with appropriate exit code (0/1/2)

### Key Functions

- **`Write-LogEntry`** – Unified logging to console and file with level filtering (DEBUG, INFO, SUCCESS, WARNING, ERROR)
- **`Add-FileResult`** – Detects DLL, extracts file/product versions, returns PSCustomObject result
- **Registry extraction** via `Get-ItemProperty` and `Get-ChildItem` with error handling
- **File info** via `Get-Item` and `.VersionInfo` properties for version extraction
- **COM object management** for ADODB connection and provider enumeration with proper cleanup

## Limitations

- **Windows Only:** Script uses Windows registry and ADODB COM objects; not portable to other OS
- **Provider Registration Only:** Detects if provider is installed, not full SQL connectivity
- **No Repair:** Script is detection-only; does not install, upgrade, or repair the driver
- **Admin Recommended:** Some registry paths require elevated permissions
- **Connection Test:** Depends on local instance availability; doesn't reflect actual SQL Server connectivity

## Common Scenarios

### Scenario 1: MSOLEDBSQL19 is Installed & SQL Server Running

**Expected Output:**
```
Registry Detection: FOUND
File System Detection: FOUND (may vary)
OLE DB Connection Test: Connection Successful - Provider Functional
FINAL CONCLUSION: MSOLEDBSQL19 IS INSTALLED AND FUNCTIONAL
Exit code: 0
```

### Scenario 2: MSOLEDBSQL19 is Installed but SQL Server Not Running

**Expected Output:**
```
Registry Detection: FOUND
File System Detection: NOT FOUND (normal)
OLE DB Connection Test: Provider Registered - Confirmed by Error Type
FINAL CONCLUSION: MSOLEDBSQL19 APPEARS TO BE INSTALLED (partial confirmation)
Exit code: 0
```

### Scenario 3: MSOLEDBSQL19 is NOT Installed

**Expected Output:**
```
Registry Detection: NOT FOUND
File System Detection: NOT FOUND
OLE DB Connection Test: Provider Not Registered
FINAL CONCLUSION: MSOLEDBSQL19 IS NOT INSTALLED
Exit code: 1
```

## Examples

### Example 1: Check Installation Status

```powershell
.\Check-MSOLEDBSQL19.ps1
```

### Example 2: Run with Verbose Logging to File

```powershell
.\Check-MSOLEDBSQL19.ps1 -Verbose > output.txt 2>&1
```

### Example 3: Check and Store Result in Variable

```powershell
& ".\Check-MSOLEDBSQL19.ps1" | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Driver is installed" -ForegroundColor Green
} else {
    Write-Host "Driver is NOT installed" -ForegroundColor Red
}
```

### Example 4: Automated Deployment Check

```powershell
# PowerShell script for deployment verification
$scriptPath = ".\Check-MSOLEDBSQL19.ps1"
& $scriptPath -Verbose

if ($LASTEXITCODE -ne 0) {
    Write-Error "MSOLEDBSQL19 not installed on target machine"
    exit 1
}
Write-Host "MSOLEDBSQL19 verified. Proceeding with deployment..." -ForegroundColor Green
```

## Parameters Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-LocalInstance` | string | "." | SQL Server instance for connection testing (e.g., ".\SQLEXPRESS", "localhost", "127.0.0.1") |
| `-Verbose` | switch | False | Enable verbose console output (DEBUG level messages) |

## Version History

- **1.1** (2026-04-29) – Phase 2 Improvements
  - 🔄 Expanded File System Detection from 2 to 8 comprehensive strategies
  - ⭐ Added OLE DB Provider Registry query (Strategy 7) – most reliable method
  - Added alternative DLL name detection (Strategy 8)
  - Added Windows Installer registry detection (Strategy 4)
  - Added ODBC driver registry detection (Strategy 6)
  - Improved duplicate detection and deduplication
  - Better support for non-standard driver installations
  - Single log file naming: `Check-MSOLEDBSQL19.log` (vs. timestamped)
  - Enhanced logging for strategy execution flow

- **1.0** (2026-04-29) – Initial release
  - Registry detection (64-bit and 32-bit)
  - File system detection with DLL version extraction
  - OLE DB provider enumeration and connection test
  - Timestamped log file output
  - Color-coded console output
  - Exit code support (0/1/2)

## License & Support

This script is provided as-is for MSOLEDBSQL19 installation detection on Windows systems.

---

**Last Updated:** 2026-04-29  
**Script Version:** 1.0  
**PowerShell Minimum:** 5.0 (Windows 10/Server 2016+)
