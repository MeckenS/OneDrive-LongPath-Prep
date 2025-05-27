# Updated OneDrive Path ScaTest-FolderRedirectionPaths -RootPath "\\fileserver\users$\jane.smith" -TenantName "fabrikam" -ExportPath "C:\Reports\jane_smith_analysis.csv"ner Examples

# =============================================================================
# New Enhanced Usage Examples
# =============================================================================

# =============================================================================
# Example 1: Basic Folder Redirection Scan
# =============================================================================

# Import the module
Import-Module OneDrivePathScanner

# Scan a user's folder redirection root path
$results = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso" -UserName "john.doe"

# Show summary
$pathIssues = $results | Where-Object { $_.ExceedsLimit }
$compatibilityIssues = $results | Where-Object { -not $_.IsOneDriveCompatible }
Write-Host "Found $($pathIssues.Count) items with path length issues"
Write-Host "Found $($compatibilityIssues.Count) items with OneDrive compatibility issues"

# =============================================================================
# Example 2: Scan with CSV Export
# =============================================================================

# Comprehensive scan with CSV export
Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\jane.smith" -TenantName "fabrikam" -UserName "jane.smith" -ExportPath "C:\Reports\jane_smith_analysis.csv"

# The module will create both the detailed CSV and a summary text file

# =============================================================================
# Example 3: Analyzing Results for Remediation
# =============================================================================

# Perform scan
$scanResults = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\bob.wilson" -TenantName "contoso" -UserName "bob.wilson"

# Show items that exceed path length limits
$pathProblems = $scanResults | Where-Object { $_.ExceedsLimit } | 
    Select-Object ItemType, FolderType, OneDrivePathLength, CharactersOverLimit, OneDrivePath |
    Sort-Object OneDrivePathLength -Descending

Write-Host "Items exceeding 247 character limit:"
$pathProblems | Format-Table -AutoSize

# Show OneDrive compatibility issues
$compatibilityProblems = $scanResults | Where-Object { -not $_.IsOneDriveCompatible } |
    Select-Object ItemType, ItemName, CompatibilityIssues, CurrentPath

Write-Host "Items with OneDrive compatibility issues:"
$compatibilityProblems | Format-Table -AutoSize

# =============================================================================
# Example 4: Testing Individual Files/Folders
# =============================================================================

# Test OneDrive compatibility for a specific file
$compatResult = Test-OneDriveCompatibility -Path "C:\Users\test\Documents\File<Name>.txt"
if (-not $compatResult.IsCompatible) {
    Write-Host "Compatibility issues found:"
    $compatResult.Issues | ForEach-Object { Write-Host "  - $_" }
}

# Test path length for a specific path
$pathResult = Test-OneDrivePathLength -Path "\\server\share\user\Documents\Very Long Folder Name" -UserName "user" -TenantName "contoso"
if ($pathResult.ExceedsLimit) {
    Write-Host "Path exceeds limit: $($pathResult.OneDrivePathLength) characters"
    Write-Host "Over by: $($pathResult.CharactersOverLimit) characters"
}

# =============================================================================
# Advanced Scenarios
# =============================================================================

# =============================================================================
# Example 5: Batch Processing Multiple Users
# =============================================================================

# Process multiple users' folder redirection paths
$users = @("alice.cooper", "bob.dylan", "charlie.brown")
$allResults = @()

foreach ($user in $users) {
    Write-Host "Processing user: $user"
    try {
        $userResults = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\$user" -TenantName "contoso" -UserName $user
        $allResults += $userResults
        
        # Show quick summary for this user
        $userIssues = $userResults | Where-Object { $_.RequiresAction }
        Write-Host "  $user has $($userIssues.Count) items requiring attention"
    }
    catch {
        Write-Warning "Error processing $user`: $($_.Exception.Message)"
    }
}

# Export combined results
$allResults | Export-Csv -Path "C:\Reports\All_Users_Analysis.csv" -NoTypeInformation

# =============================================================================
# Example 6: Focused Analysis by Folder Type
# =============================================================================

# Scan and analyze by folder type
$results = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso" -UserName "john.doe"

# Group results by folder type
$folderAnalysis = $results | Group-Object FolderType | ForEach-Object {
    $issues = $_.Group | Where-Object { $_.RequiresAction }
    [PSCustomObject]@{
        FolderType = $_.Name
        TotalItems = $_.Count
        ItemsWithIssues = $issues.Count
        PercentageWithIssues = [math]::Round(($issues.Count / $_.Count) * 100, 2)
        MaxPathLength = ($_.Group | Measure-Object OneDrivePathLength -Maximum).Maximum
    }
}

$folderAnalysis | Sort-Object PercentageWithIssues -Descending | Format-Table -AutoSize

# =============================================================================
# Example 7: Migration Readiness Report
# =============================================================================

function Get-MigrationReadinessReport {
    param(
        [string]$RootPath,
        [string]$TenantName,
        [string]$UserName,
        [string]$OutputPath
    )
    
    $results = Test-FolderRedirectionPaths -RootPath $RootPath -TenantName $TenantName -UserName $UserName
    
    # Calculate statistics
    $totalItems = $results.Count
    $pathIssues = ($results | Where-Object { $_.ExceedsLimit }).Count
    $compatIssues = ($results | Where-Object { -not $_.IsOneDriveCompatible }).Count
    $readyItems = $totalItems - ($results | Where-Object { $_.RequiresAction }).Count
    
    $readinessPercentage = if ($totalItems -gt 0) { [math]::Round(($readyItems / $totalItems) * 100, 2) } else { 0 }
    
    # Generate report
    $report = [PSCustomObject]@{
        UserName = Split-Path $RootPath -Leaf
        TotalItems = $totalItems
        ReadyItems = $readyItems
        PathIssues = $pathIssues
        CompatibilityIssues = $compatIssues
        ReadinessPercentage = $readinessPercentage
        RecommendedAction = switch ($readinessPercentage) {
            { $_ -ge 95 } { "Ready for migration" }
            { $_ -ge 80 } { "Minor cleanup required" }
            { $_ -ge 60 } { "Moderate remediation needed" }
            default { "Significant remediation required" }
        }
        ScanDate = Get-Date
    }
    
    if ($OutputPath) {
        $report | Export-Csv -Path $OutputPath -NoTypeInformation
    }
    
    return $report
}

# Use the function
$readinessReport = Get-MigrationReadinessReport -RootPath "\\fileserver\users$\jane.doe" -TenantName "contoso" -UserName "jane.doe" -OutputPath "C:\Reports\jane_doe_readiness.csv"
Write-Host "$($readinessReport.UserName) is $($readinessReport.ReadinessPercentage)% ready for migration"

# =============================================================================
# Example 8: Filtering and Remediation Planning
# =============================================================================

# Get detailed analysis for remediation planning
$results = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso" -UserName "john.doe"

# Identify the worst path length offenders
$worstPaths = $results | Where-Object { $_.ExceedsLimit } | 
    Sort-Object CharactersOverLimit -Descending |
    Select-Object -First 10 |
    Select-Object ItemType, ItemName, OneDrivePathLength, CharactersOverLimit, OneDrivePath

Write-Host "Top 10 longest paths requiring attention:"
$worstPaths | Format-Table -AutoSize

# Identify common compatibility issues
$compatIssues = $results | Where-Object { -not $_.IsOneDriveCompatible } |
    Group-Object CompatibilityIssues |
    Sort-Object Count -Descending |
    Select-Object Name, Count

Write-Host "Common compatibility issues:"
$compatIssues | ForEach-Object { Write-Host "  $($_.Name): $($_.Count) occurrences" }

# Find files with invalid characters (most common issue)
$invalidCharFiles = $results | Where-Object { $_.CompatibilityIssues -like "*invalid character*" } |
    Select-Object ItemName, CurrentPath, CompatibilityIssues

Write-Host "Files with invalid characters:"
$invalidCharFiles | Format-Table -AutoSize

# =============================================================================
# Specialized Use Cases
# =============================================================================

# =============================================================================
# Example 9: Large File Identification
# =============================================================================
# Identify large files that might impact migration
$results = Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso" -UserName "john.doe"

$largeFiles = $results | Where-Object { $_.ItemType -eq "File" -and $_.SizeBytes -gt 100MB } |
    Select-Object ItemName, @{Name="SizeMB";Expression={[math]::Round($_.SizeBytes/1MB,2)}}, CurrentPath |
    Sort-Object SizeMB -Descending

Write-Host "Large files (>100MB) that may impact migration:"
$largeFiles | Format-Table -AutoSize

# =============================================================================
# Example 10: Real-time Monitoring Function
# =============================================================================
function Start-FolderRedirectionMonitoring {
    param(
        [string[]]$RootPaths,
        [string]$TenantName,
        [int]$IntervalMinutes = 60
    )
    
    while ($true) {
        Write-Host "$(Get-Date): Starting monitoring cycle..."
        
        foreach ($rootPath in $RootPaths) {
            try {
                $results = Test-FolderRedirectionPaths -RootPath $rootPath -TenantName $TenantName
                $issues = $results | Where-Object { $_.RequiresAction }
                
                if ($issues.Count -gt 0) {
                    Write-Warning "User $(Split-Path $rootPath -Leaf) has $($issues.Count) items requiring attention"
                    
                    # Export issues for this user
                    $userName = Split-Path $rootPath -Leaf
                    $issuesPath = "C:\Reports\Issues_$userName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                    $issues | Export-Csv -Path $issuesPath -NoTypeInformation
                    Write-Host "Issues exported to: $issuesPath"
                }
            }
            catch {
                Write-Error "Error monitoring $rootPath`: $($_.Exception.Message)"
            }
        }
        
        Write-Host "Monitoring cycle complete. Waiting $IntervalMinutes minutes..."
        Start-Sleep -Seconds ($IntervalMinutes * 60)
    }
}

# Start monitoring multiple users
# Start-FolderRedirectionMonitoring -RootPaths @("\\server\users$\user1", "\\server\users$\user2") -TenantName "contoso" -IntervalMinutes 30

# =============================================================================
# Key Features Demonstrated
# =============================================================================

# 1. Root Path Scanning: Directly specify user's folder redirection root path
# 2. Comprehensive Path Analysis: Every file and folder is checked for OneDrive compatibility  
# 3. Character Limit Detection: Identifies paths exceeding 247 characters with exact overage
# 4. Compatibility Checking: Detects invalid characters, reserved names, and other OneDrive restrictions
# 5. Detailed Reporting: Provides file-level detail with CSV export capability
# 6. Flexible Analysis: Filter by file type, folder type, issue type, etc.

# =============================================================================
# Migration Planning Workflow
# =============================================================================

# 1. Discovery: Use Test-FolderRedirectionPaths to analyze current state
# 2. Assessment: Review both path length and compatibility issues
# 3. Prioritization: Focus on users/folders with highest issue counts
# 4. Remediation: Address path lengths and file naming issues
# 5. Validation: Re-scan to confirm issues are resolved
# 6. Migration: Proceed with OneDrive Known Folder Move
