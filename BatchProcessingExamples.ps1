# =============================================================================
# OneDrive Path Scanner - Batch Processing Examples
# =============================================================================

# Import the module
Import-Module OneDrivePathScanner

# =============================================================================
# Method 1: Enhanced Batch Processing Function
# =============================================================================

function Invoke-BatchFolderRedirectionScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$UserNames,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        
        [Parameter(Mandatory = $false)]
        [string]$UserRootTemplate = "\\fileserver\users$\{0}",
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = "C:\Reports",
          [Parameter(Mandatory = $false)]
        [switch]$GenerateIndividualReports,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowProgress
    )
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force
    }
    
    $allResults = @()
    $userSummary = @()
    $totalUsers = $UserNames.Count
    $currentUser = 0
    
    Write-Host "Starting batch scan for $totalUsers users..." -ForegroundColor Green
    
    foreach ($userName in $UserNames) {
        $currentUser++
        $rootPath = $UserRootTemplate -f $userName
          if ($ShowProgress -or $PSBoundParameters.ContainsKey('ShowProgress') -eq $false) {
            Write-Progress -Activity "Scanning Users" -Status "Processing $userName ($currentUser of $totalUsers)" -PercentComplete (($currentUser / $totalUsers) * 100)
        }
        
        Write-Host "[$currentUser/$totalUsers] Processing: $userName" -ForegroundColor Cyan
        
        try {
            # Test if the user's folder exists
            if (-not (Test-Path $rootPath)) {
                Write-Warning "  Path not found: $rootPath"
                continue
            }
              # Perform the scan
            $userResults = Test-FolderRedirectionPaths -RootPath $rootPath -TenantName $TenantName -UserName $userName
            $allResults += $userResults
            
            # Calculate user-specific statistics
            $totalItems = $userResults.Count
            $pathIssues = ($userResults | Where-Object { $_.ExceedsLimit }).Count
            $compatIssues = ($userResults | Where-Object { -not $_.IsOneDriveCompatible }).Count
            $requiresAction = ($userResults | Where-Object { $_.RequiresAction }).Count
            
            $userStats = [PSCustomObject]@{
                UserName = $userName
                RootPath = $rootPath
                TotalItems = $totalItems
                PathIssues = $pathIssues
                CompatibilityIssues = $compatIssues
                RequiresAction = $requiresAction
                ReadinessPercentage = if ($totalItems -gt 0) { [math]::Round((($totalItems - $requiresAction) / $totalItems) * 100, 2) } else { 100 }
                ScanDate = Get-Date
                Status = "Completed"
            }
            
            $userSummary += $userStats
            
            Write-Host "  Items: $totalItems | Issues: $requiresAction | Readiness: $($userStats.ReadinessPercentage)%" -ForegroundColor Yellow
            
            # Generate individual report if requested
            if ($GenerateIndividualReports) {
                $individualPath = Join-Path $OutputDirectory "Individual_$userName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
                $userResults | Export-Csv -Path $individualPath -NoTypeInformation
                Write-Host "  Individual report: $individualPath" -ForegroundColor Gray
            }
        }
        catch {
            Write-Error "  Error processing $userName`: $($_.Exception.Message)"
            
            $userStats = [PSCustomObject]@{
                UserName = $userName
                RootPath = $rootPath
                TotalItems = 0
                PathIssues = 0
                CompatibilityIssues = 0
                RequiresAction = 0
                ReadinessPercentage = 0
                ScanDate = Get-Date
                Status = "Error: $($_.Exception.Message)"
            }
            $userSummary += $userStats
        }
    }
      if ($ShowProgress -or $PSBoundParameters.ContainsKey('ShowProgress') -eq $false) {
        Write-Progress -Activity "Scanning Users" -Completed
    }
    
    # Generate combined reports
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    
    # Detailed results
    $detailedPath = Join-Path $OutputDirectory "BatchScan_Detailed_$timestamp.csv"
    $allResults | Export-Csv -Path $detailedPath -NoTypeInformation
    
    # Summary report
    $summaryPath = Join-Path $OutputDirectory "BatchScan_Summary_$timestamp.csv"
    $userSummary | Export-Csv -Path $summaryPath -NoTypeInformation
    
    # Generate executive summary
    $execSummaryPath = Join-Path $OutputDirectory "BatchScan_Executive_Summary_$timestamp.txt"
    $totalUsers = $userSummary.Count
    $successfulScans = ($userSummary | Where-Object { $_.Status -eq "Completed" }).Count
    $avgReadiness = if ($successfulScans -gt 0) { [math]::Round(($userSummary | Where-Object { $_.Status -eq "Completed" } | Measure-Object ReadinessPercentage -Average).Average, 2) } else { 0 }
    $usersReadyForMigration = ($userSummary | Where-Object { $_.ReadinessPercentage -ge 95 }).Count
    $usersNeedingWork = ($userSummary | Where-Object { $_.ReadinessPercentage -lt 80 }).Count
    
    $execSummary = @"
OneDrive Migration Readiness - Executive Summary
Generated: $(Get-Date)
Tenant: $TenantName

=== OVERVIEW ===
Total Users Processed: $totalUsers
Successful Scans: $successfulScans
Failed Scans: $($totalUsers - $successfulScans)

=== READINESS ASSESSMENT ===
Average Readiness: $avgReadiness%
Users Ready for Migration (≥95%): $usersReadyForMigration
Users Needing Significant Work (<80%): $usersNeedingWork

=== DETAILED RESULTS ===
Detailed Results: $detailedPath
User Summary: $summaryPath

=== RECOMMENDATIONS ===
$(if ($avgReadiness -ge 90) { "✓ Organization is well-prepared for migration" } 
  elseif ($avgReadiness -ge 70) { "⚠ Some remediation work needed before migration" }
  else { "⚠ Significant remediation required before migration" })

Focus Areas:
- Users with <80% readiness need immediate attention
- Review detailed reports for specific file/folder issues
- Plan remediation activities for users with compatibility issues
"@
    
    $execSummary | Out-File -FilePath $execSummaryPath -Encoding UTF8
    
    Write-Host "`nBatch scan completed!" -ForegroundColor Green
    Write-Host "Results saved to:" -ForegroundColor Yellow
    Write-Host "  Detailed: $detailedPath" -ForegroundColor Gray
    Write-Host "  Summary: $summaryPath" -ForegroundColor Gray
    Write-Host "  Executive Summary: $execSummaryPath" -ForegroundColor Gray
    
    return [PSCustomObject]@{
        DetailedResults = $allResults
        UserSummary = $userSummary
        DetailedReportPath = $detailedPath
        SummaryReportPath = $summaryPath
        ExecutiveSummaryPath = $execSummaryPath
    }
}

# =============================================================================
# Method 2: Auto-Discovery and Batch Processing
# =============================================================================

function Invoke-AutoDiscoveryBatchScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UsersRootPath,  # e.g., "\\fileserver\users$"
        
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = "C:\Reports",
        
        [Parameter(Mandatory = $false)]
        [int]$MaxUsers = 0,  # 0 = no limit
        
        [Parameter(Mandatory = $false)]
        [string[]]$ExcludeUsers = @(),
        
        [Parameter(Mandatory = $false)]
        [switch]$SortBySize
    )
    
    Write-Host "Auto-discovering users in: $UsersRootPath" -ForegroundColor Green
    
    # Discover user folders
    try {
        $userFolders = Get-ChildItem -Path $UsersRootPath -Directory | Where-Object { 
            $_.Name -notin $ExcludeUsers 
        }
        
        if ($SortBySize) {
            Write-Host "Calculating folder sizes for sorting..." -ForegroundColor Yellow
            $userFolders = $userFolders | ForEach-Object {
                $size = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                $_ | Add-Member -NotePropertyName FolderSize -NotePropertyValue $size -PassThru
            } | Sort-Object FolderSize -Descending
        }
        
        if ($MaxUsers -gt 0 -and $userFolders.Count -gt $MaxUsers) {
            Write-Host "Limiting to first $MaxUsers users (out of $($userFolders.Count) discovered)" -ForegroundColor Yellow
            $userFolders = $userFolders | Select-Object -First $MaxUsers
        }
        
        $userNames = $userFolders | ForEach-Object { $_.Name }
        
        Write-Host "Discovered $($userNames.Count) users to process" -ForegroundColor Green
        
        # Use the batch function
        return Invoke-BatchFolderRedirectionScan -UserNames $userNames -TenantName $TenantName -UserRootTemplate "$UsersRootPath\{0}" -OutputDirectory $OutputDirectory -ShowProgress
    }
    catch {
        Write-Error "Error during auto-discovery: $($_.Exception.Message)"
        return $null
    }
}

# =============================================================================
# Method 3: Parallel Processing (for large environments)
# =============================================================================

function Invoke-ParallelBatchScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$UserNames,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        
        [Parameter(Mandatory = $false)]
        [string]$UserRootTemplate = "\\fileserver\users$\{0}",
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = "C:\Reports",
        
        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit = 5
    )
    
    Write-Host "Starting parallel batch scan for $($UserNames.Count) users (max $ThrottleLimit concurrent)..." -ForegroundColor Green
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force
    }
    
    $jobs = $UserNames | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $userName = $_
        $rootPath = $using:UserRootTemplate -f $userName
        $tenantName = $using:TenantName
        
        try {
            # Import module in the parallel context
            Import-Module OneDrivePathScanner -Force
              if (Test-Path $rootPath) {
                $results = Test-FolderRedirectionPaths -RootPath $rootPath -TenantName $tenantName -UserName $userName
                
                return [PSCustomObject]@{
                    UserName = $userName
                    Status = "Success"
                    Results = $results
                    ItemCount = $results.Count
                    IssueCount = ($results | Where-Object { $_.RequiresAction }).Count
                }
            } else {
                return [PSCustomObject]@{
                    UserName = $userName
                    Status = "PathNotFound"
                    Results = @()
                    ItemCount = 0
                    IssueCount = 0
                }
            }
        }
        catch {
            return [PSCustomObject]@{
                UserName = $userName
                Status = "Error: $($_.Exception.Message)"
                Results = @()
                ItemCount = 0
                IssueCount = 0
            }
        }
    }
    
    # Combine results
    $allResults = @()
    $userSummary = @()
    
    foreach ($job in $jobs) {
        if ($job.Status -eq "Success") {
            $allResults += $job.Results
        }
        
        $userSummary += [PSCustomObject]@{
            UserName = $job.UserName
            Status = $job.Status
            TotalItems = $job.ItemCount
            RequiresAction = $job.IssueCount
            ReadinessPercentage = if ($job.ItemCount -gt 0) { [math]::Round((($job.ItemCount - $job.IssueCount) / $job.ItemCount) * 100, 2) } else { 100 }
            ScanDate = Get-Date
        }
    }
    
    # Export results
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $detailedPath = Join-Path $OutputDirectory "ParallelScan_Detailed_$timestamp.csv"
    $summaryPath = Join-Path $OutputDirectory "ParallelScan_Summary_$timestamp.csv"
    
    $allResults | Export-Csv -Path $detailedPath -NoTypeInformation
    $userSummary | Export-Csv -Path $summaryPath -NoTypeInformation
    
    Write-Host "Parallel scan completed!" -ForegroundColor Green
    Write-Host "Results: $detailedPath" -ForegroundColor Gray
    Write-Host "Summary: $summaryPath" -ForegroundColor Gray
    
    return [PSCustomObject]@{
        DetailedResults = $allResults
        UserSummary = $userSummary
        DetailedReportPath = $detailedPath
        SummaryReportPath = $summaryPath
    }
}

# =============================================================================
# Usage Examples
# =============================================================================

<#
# Example 1: Simple batch processing with specific users
$users = @("john.doe", "jane.smith", "bob.wilson")
$results = Invoke-BatchFolderRedirectionScan -UserNames $users -TenantName "contoso" -GenerateIndividualReports

# Example 2: Auto-discovery of all users
$results = Invoke-AutoDiscoveryBatchScan -UsersRootPath "\\fileserver\users$" -TenantName "contoso" -MaxUsers 50

# Example 3: Parallel processing for large environments
$largeUserList = @("user1", "user2", "user3")  # ... up to hundreds of users
$results = Invoke-ParallelBatchScan -UserNames $largeUserList -TenantName "contoso" -ThrottleLimit 10

# Example 4: Process only users with large folder sizes first
$results = Invoke-AutoDiscoveryBatchScan -UsersRootPath "\\fileserver\users$" -TenantName "contoso" -SortBySize -MaxUsers 20
#>
