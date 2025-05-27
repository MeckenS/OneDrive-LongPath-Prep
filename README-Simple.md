# OneDrive Path Scanner - Quick Reference

A PowerShell module for scanning Folder Redirection paths before OneDrive migration.

## What It Does

- **Path Length Detection**: Identifies files/folders exceeding OneDrive's 247-character limit
- **Compatibility Checking**: Finds files with invalid characters or reserved names
- **Migration Planning**: Generates detailed reports for remediation before OneDrive Known Folder Move

## Quick Start

```powershell
# 1. Import the module
Import-Module .\OneDrivePathScanner.psm1

# 2. Scan a user's folder redirection
$results = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "yourcompany" -UserName "john.doe"

# 3. Show summary
$pathIssues = $results | Where-Object { $_.ExceedsLimit }
$compatIssues = $results | Where-Object { -not $_.IsOneDriveCompatible }
Write-Host "Path length issues: $($pathIssues.Count)"
Write-Host "Compatibility issues: $($compatIssues.Count)"
```

## Main Functions

### Test-FolderRedirectionPaths
**Primary function** - scans user's folder redirection root path
```powershell
# Basic scan
Test-FolderRedirectionPaths -RootPath "\\server\users$\username" -TenantName "contoso" -UserName "username"

# With CSV export
Test-FolderRedirectionPaths -RootPath "\\server\users$\username" -TenantName "contoso" -UserName "username" -ExportPath "C:\Reports\scan.csv"
```

### Test-OneDriveCompatibility
Check individual files/folders for OneDrive issues
```powershell
Test-OneDriveCompatibility -Path "C:\Users\test\Documents\File<invalid>.txt"
```

### Test-OneDrivePathLength
Validate specific path lengths
```powershell
Test-OneDrivePathLength -Path "\\server\path" -UserName "user" -TenantName "tenant"
```

## Path Calculation

OneDrive paths are calculated as:
```
\\server\users$\username\Documents → C:\Users\username\OneDrive - tenantname\Documents
```

The 247-character limit ensures OneDrive sync compatibility.

## Common Usage

### Batch Processing Multiple Users
```powershell
$users = @("user1", "user2", "user3")
foreach ($user in $users) {
    $results = Test-FolderRedirectionPaths -RootPath "\\server\users$\$user" -TenantName "contoso" -UserName $user
    $issues = $results | Where-Object { $_.RequiresAction }
    Write-Host "$user`: $($issues.Count) items need attention"
}
```

### Focus on Problems
```powershell
$results = Test-FolderRedirectionPaths -RootPath "\\server\users$\john.doe" -TenantName "contoso" -UserName "john.doe"

# Show worst path length offenders
$results | Where-Object { $_.ExceedsLimit } | 
    Sort-Object CharactersOverLimit -Descending | 
    Select-Object -First 5 ItemName, OneDrivePathLength, CharactersOverLimit

# Show compatibility issues
$results | Where-Object { -not $_.IsOneDriveCompatible } | 
    Select-Object ItemName, CompatibilityIssues
```

## Key Output Fields

- **RequiresAction**: True if item needs remediation
- **ExceedsLimit**: True if path > 247 characters  
- **CharactersOverLimit**: How many characters over the limit
- **IsOneDriveCompatible**: True if compatible with OneDrive
- **CompatibilityIssues**: Description of compatibility problems
- **OneDrivePath**: Calculated OneDrive path after migration

## Requirements

- PowerShell 5.1+
- Read permissions to Folder Redirection paths
- Optional: ActiveDirectory module for enhanced features

## Migration Workflow

1. **Scan**: Use `Test-FolderRedirectionPaths` to analyze current state
2. **Assess**: Review path length and compatibility issues  
3. **Remediate**: Fix long paths and rename problematic files
4. **Validate**: Re-scan to confirm issues resolved
5. **Migrate**: Proceed with OneDrive Known Folder Move

See `UpdatedExamples.ps1` for comprehensive usage examples and `README.md` for detailed documentation.
