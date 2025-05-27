# OneDrive Path Scanner

A PowerShell module for scanning Folder Redirection paths before migrating to OneDrive Known Folder Move.

## Overview
This module helps identify potential path length issues and OneDrive compatibility problems when migrating from on-premises Folder Redirection to OneDrive Known Folder Move. It scans user folder structures and calculates the new OneDrive path lengths, identifies files with incompatible characters, and generates detailed reports for migration planning.

## Quick Start

### Prerequisites
- PowerShell 5.1 or later
- Read access to Folder Redirection file shares
- Optional: ActiveDirectory PowerShell module (for enhanced AD integration)

### Import and Use
```powershell
# Import the module
Import-Module .\OneDrivePathScanner.psm1

# Basic scan of a user's folder redirection
$results = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso" -UserName "john.doe"

# Scan with CSV export
Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\jane.smith" -TenantName "contoso" -UserName "jane.smith" -ExportPath "C:\Reports\migration_scan.csv"
```

## Core Functions

### Test-FolderRedirectionPaths
**Primary function** - Tests a user's folder redirection root path and identifies all OneDrive migration issues.

**Parameters:**
- `RootPath` (Required): Root path of user's folder redirection (e.g., "\\server\users$\username")
- `TenantName` (Required): Microsoft 365 tenant name for OneDrive path calculation
- `UserName` (Optional): Username for the folders being scanned (if not provided, will be extracted from RootPath)
- `ExportPath` (Optional): Path to save detailed CSV report

**Examples:**
```powershell
# Basic scan (username extracted from path)
Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso"

# Scan with explicit username (more reliable)
Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso" -UserName "john.doe"

# Scan with detailed reporting
Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso" -UserName "john.doe" -ExportPath "C:\Reports\john_doe_scan.csv"
```

### Test-OneDriveCompatibility
Tests individual files/folders for OneDrive compatibility issues.

**Parameters:**
- `Path` (Required): File or folder path to test

**Example:**
```powershell
Test-OneDriveCompatibility -Path "C:\Users\test\Documents\File<invalid>.txt"
```

### Test-OneDrivePathLength
Calculates and validates OneDrive path lengths for specific paths.

**Parameters:**
- `Path` (Required): Current folder redirection path
- `UserName` (Required): Username for path calculation
- `TenantName` (Required): Microsoft 365 tenant name

**Example:**
```powershell
Test-OneDrivePathLength -Path "\\server\users$\john.doe\Documents\Very Long Project Name" -UserName "john.doe" -TenantName "contoso"
```

### Export-PathLengthReport
Exports scan results with summary statistics.

**Parameters:**
- `Results` (Required): Results from Test-FolderRedirectionPaths
- `OutputPath` (Required): Export file path (.csv, .json, .xlsx)

### Get-UserFolderPaths
Gets detailed folder information for a specific user (requires AD module).

**Parameters:**
- `UserName` (Required): Username to query
- `IncludeSize` (Optional): Include folder size calculations

### Get-ADUserFolderRedirection
Retrieves folder redirection info from Active Directory (requires AD module).

**Parameters:**
- `UserName` (Optional): Specific user to query
- `SearchBase` (Optional): AD organizational unit
- `MaxUsers` (Optional): Maximum users to return (default: 1000)

## Usage Scenarios

### 1. Single User Assessment
Quickly assess a specific user's folder redirection for migration readiness:

```powershell
# Import the module
Import-Module .\OneDrivePathScanner.psm1

# Scan a specific user's folder redirection
$results = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso" -UserName "john.doe"

# Show summary
$pathIssues = $results | Where-Object { $_.ExceedsLimit }
$compatIssues = $results | Where-Object { -not $_.IsOneDriveCompatible }
Write-Host "Path length issues: $($pathIssues.Count)"
Write-Host "Compatibility issues: $($compatIssues.Count)"
```

### 2. Batch User Processing
Process multiple users systematically:

```powershell
$users = @("alice.cooper", "bob.dylan", "charlie.brown")
$allResults = @()

foreach ($user in $users) {
    Write-Host "Processing user: $user"
    try {
        $userResults = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\$user" -TenantName "contoso" -UserName $user
        $allResults += $userResults
        
        $userIssues = $userResults | Where-Object { $_.RequiresAction }
        Write-Host "  $user has $($userIssues.Count) items requiring attention"
    }
    catch {
        Write-Warning "Error processing $user`: $($_.Exception.Message)"
    }
}

# Export combined results
$allResults | Export-Csv -Path "C:\Reports\All_Users_Analysis.csv" -NoTypeInformation
```

### 3. Migration Readiness Assessment
Generate comprehensive migration readiness reports:

```powershell
# Scan with detailed reporting
Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\jane.smith" -TenantName "contoso" -ExportPath "C:\Reports\jane_smith_analysis.csv"

# The module automatically creates both CSV and summary reports
```

### 4. Remediation Planning
Identify specific issues that need addressing:

```powershell
$results = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso"

# Find worst path length offenders
$worstPaths = $results | Where-Object { $_.ExceedsLimit } | 
    Sort-Object CharactersOverLimit -Descending |
    Select-Object -First 10 |
    Select-Object ItemType, ItemName, OneDrivePathLength, CharactersOverLimit, OneDrivePath

Write-Host "Top 10 longest paths requiring attention:"
$worstPaths | Format-Table -AutoSize

# Identify compatibility issues
$compatIssues = $results | Where-Object { -not $_.IsOneDriveCompatible } |
    Group-Object CompatibilityIssues |
    Sort-Object Count -Descending

Write-Host "Common compatibility issues:"
$compatIssues | ForEach-Object { Write-Host "  $($_.Name): $($_.Count) occurrences" }
```

## What the Module Detects

### Path Length Issues
- **Character Limit**: OneDrive paths exceeding 247 characters
- **Path Calculation**: Converts `\\server\users$\username\folder` to `C:\Users\username\OneDrive - tenantname\folder`
- **Overage Reporting**: Exact number of characters over the limit

### OneDrive Compatibility Issues  
- **Invalid Characters**: `< > : " | ? * \`
- **Reserved Names**: CON, PRN, AUX, NUL, COM1-9, LPT1-9, etc.
- **Invalid Extensions**: .tmp, .temp
- **Problem Patterns**: ~$*, .lock, Thumbs.db, .DS_Store
- **Naming Rules**: Files starting/ending with periods or spaces

### Detailed Reporting
- **File-Level Analysis**: Every file and folder checked individually
- **CSV Export**: Detailed spreadsheet with all findings
- **Summary Statistics**: Overview of issues found
- **Actionable Data**: Prioritized list of items requiring attention

## Output Format

The scan results include these key fields:

- **RequiresAction**: Boolean indicating if remediation is needed
- **ExceedsLimit**: Boolean for 247-character path limit violations
- **CharactersOverLimit**: Exact number of characters over the limit
- **IsOneDriveCompatible**: Boolean for OneDrive compatibility
- **CompatibilityIssues**: Detailed description of compatibility problems
- **OneDrivePath**: Calculated OneDrive path after migration
- **OneDrivePathLength**: Length of the OneDrive path
- **ItemType**: File or Folder
- **FolderType**: Desktop, Documents, Pictures, etc.

## Installation Options

### Method 1: Direct Import (Recommended for Testing)
```powershell
# Navigate to the module directory
cd "C:\OneDriveMigration"

# Import directly
Import-Module .\OneDrivePathScanner.psm1 -Force

# Verify import
Get-Command -Module OneDrivePathScanner
```

### Method 2: Install to Module Path (Production Use)
```powershell
# Check available module paths
$env:PSModulePath -split ';'

# Copy to user module path
$userModulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\OneDrivePathScanner"
New-Item -Path $userModulePath -ItemType Directory -Force
Copy-Item -Path ".\OneDrivePathScanner.psm1" -Destination $userModulePath
Copy-Item -Path ".\OneDrivePathScanner.psd1" -Destination $userModulePath

# Import from module path
Import-Module OneDrivePathScanner
```

## Troubleshooting

### Common Issues

**"ActiveDirectory module not found"**
- The module works without AD module for basic scanning
- Install RSAT tools for enhanced AD features:
  ```powershell
  Get-WindowsCapability -Name RSAT.ActiveDirectory* -Online | Add-WindowsCapability -Online
  ```

**"Access denied to file shares"**
- Ensure read permissions to folder redirection shares
- Run PowerShell as appropriate service account
- Test access: `Test-Path "\\fileserver\users$\username"`

**"No items found" or empty results**
- Verify the RootPath exists and contains folders
- Check folder redirection is actually configured
- Ensure the path format matches your environment

**Performance with large datasets**
- Process users in smaller batches
- Run scans during off-peak hours
- Consider excluding test/service accounts

## Best Practices

1. **Start Small**: Test with a few users before scanning entire organization
2. **Document Issues**: Export detailed reports for remediation planning  
3. **Address Path Lengths**: Focus on longest paths first (highest impact)
4. **Fix Compatibility**: Rename files with invalid characters before migration
5. **Validate Results**: Re-scan after remediation to confirm fixes
6. **Plan Migration**: Use scan results to prioritize and sequence migrations

## Migration Planning Workflow

1. **Discovery**: Scan current folder redirection structure
2. **Assessment**: Analyze path lengths and compatibility issues
3. **Prioritization**: Identify users/departments with most issues
4. **Remediation**: Address path lengths and file naming problems
5. **Validation**: Re-scan to confirm issues are resolved
6. **Migration**: Proceed with OneDrive Known Folder Move

## Support and Examples

- See `UpdatedExamples.ps1` for comprehensive usage examples
- See `README-Simple.md` for quick reference guide
- Use `Get-Help <FunctionName>` for detailed parameter information

For additional examples including batch processing, monitoring, and advanced scenarios, refer to the included example files.
