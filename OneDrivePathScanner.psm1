#Requires -Version 5.1
# ActiveDirectory module will be loaded dynamically if available

<#
.SYNOPSIS
OneDrive Path Scanner Module for Folder Redirection Migration Analysis

.DESCRIPTION
This module provides functions to scan user folders with Folder Redirection
and identify potential path length issues when migrating to OneDrive Known Folder Move.
The module calculates path lengths considering the Microsoft tenant name addition
and identifies OneDrive compatibility issues.

.NOTES
Author: OneDrive Migration Team
Version: 2.0.0
#>

# Import required modules
if (Get-Module -Name ActiveDirectory -ListAvailable) {
    try {
        Import-Module ActiveDirectory -ErrorAction SilentlyContinue
        Write-Verbose "ActiveDirectory module loaded successfully"
    }
    catch {
        Write-Warning "ActiveDirectory module is available but could not be loaded: $($_.Exception.Message)"
    }
}
else {
    Write-Warning "ActiveDirectory module is not available. AD-related functions will not work."
}

# Global variables
$script:MaxPathLength = 247
$script:OneDriveBasePath = "C:\Users\{0}\OneDrive - {1}"

# OneDrive incompatible characters and file names
$script:InvalidChars = @('<', '>', ':', '"', '|', '?', '*', '\')
$script:InvalidNames = @(
    'CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9', '_vti_', 'desktop.ini'
)
$script:InvalidFileExtensions = @('.tmp', '.temp')
$script:InvalidPatterns = @('~$*', '.lock', 'Thumbs.db', '.DS_Store')

#region Helper Functions

function Write-LogMessage {
    [CmdletBinding()]
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'Info' { Write-Host $logMessage -ForegroundColor Green }
        'Warning' { Write-Warning $logMessage }
        'Error' { Write-Error $logMessage }
    }
}

function Test-OneDriveCompatibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $issues = @()
    $fileName = Split-Path $Path -Leaf
    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $extension = [System.IO.Path]::GetExtension($fileName)
    
    # Check for invalid characters
    foreach ($char in $script:InvalidChars) {
        if ($fileName.Contains($char)) {
            $issues += "Contains invalid character: '$char'"
        }
    }
    
    # Check for invalid file names
    if ($script:InvalidNames -contains $fileNameWithoutExtension.ToUpper()) {
        $issues += "Reserved file name: '$fileNameWithoutExtension'"
    }
    
    # Check for invalid file extensions
    if ($script:InvalidFileExtensions -contains $extension.ToLower()) {
        $issues += "Invalid file extension: '$extension'"
    }
    
    # Check for invalid patterns
    foreach ($pattern in $script:InvalidPatterns) {
        if ($fileName -like $pattern) {
            $issues += "Matches invalid pattern: '$pattern'"
        }
    }
    
    # Check for files starting or ending with periods or spaces
    if ($fileName.StartsWith('.') -and $fileName.Length -gt 1) {
        $issues += "File name starts with period"
    }
    if ($fileName.EndsWith('.') -or $fileName.EndsWith(' ')) {
        $issues += "File name ends with period or space"
    }
    
    # Check file name length (255 character limit for file names)
    if ($fileName.Length -gt 255) {
        $issues += "File name too long (>255 characters)"
    }
      return [PSCustomObject]@{
        Path = $Path
        FileName = $fileName
        IsCompatible = $issues.Count -eq 0
        Issues = $issues
    }
}

function Get-FolderSize {
    [CmdletBinding()]
    param(
        [string]$Path
    )
    
    try {
        if (Test-Path $Path) {
            $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum).Sum
            return [math]::Round($size / 1MB, 2)
        }
        return 0
    }
    catch {
        Write-LogMessage "Error calculating folder size for $Path`: $($_.Exception.Message)" -Level Error
        return 0
    }
}

function Get-UsernameFromPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )
    
    try {
        # Extract username from folder redirection path
        # Assuming format like \\server\share\username or C:\FolderRedirect\username
        $pathParts = $RootPath -split '[\\/]'
        $username = $pathParts[-1]  # Last part should be username
        
        # Clean up any trailing slashes or special characters
        $username = $username.Trim('\/', ' ')
        
        return $username
    }
    catch {
        Write-LogMessage "Error extracting username from path $RootPath`: $($_.Exception.Message)" -Level Error
        return "unknown"
    }
}

function Get-FolderSize {
    [CmdletBinding()]
    param(
        [string]$Path
    )
    
    try {
        if (Test-Path $Path) {
            $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum).Sum
            return [math]::Round($size / 1MB, 2)
        }
        return 0
    }
    catch {
        Write-LogMessage "Error calculating folder size for $Path`: $($_.Exception.Message)" -Level Error
        return 0
    }
}

#endregion

#region Main Functions

<#
.SYNOPSIS
Tests if a path will exceed OneDrive path length limits

.PARAMETER Path
The current folder redirection path to test

.PARAMETER UserName
The username for the folder

.PARAMETER TenantName
The Microsoft tenant name that will be added to the OneDrive path

.EXAMPLE
Test-OneDrivePathLength -Path "\\server\redirect\john.doe\Documents\Project Files" -UserName "john.doe" -TenantName "contoso"
#>
function Test-OneDrivePathLength {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantName
    )
    
    begin {
        Write-LogMessage "Testing OneDrive path length for user: $UserName"
    }
    
    process {
        try {
            # Calculate the new OneDrive path
            $oneDriveBasePath = $script:OneDriveBasePath -f $UserName, $TenantName
            
            # Extract the relative path from the folder redirection path
            # Assuming format like \\server\share\username\foldername\...
            $pathParts = $Path -split '\\'
            $userIndex = -1
            
            for ($i = 0; $i -lt $pathParts.Length; $i++) {
                if ($pathParts[$i] -eq $UserName) {
                    $userIndex = $i
                    break
                }
            }
            
            if ($userIndex -ge 0 -and $userIndex -lt $pathParts.Length - 1) {
                $relativePath = ($pathParts[($userIndex + 1)..($pathParts.Length - 1)] -join '\')
                $newOneDrivePath = Join-Path $oneDriveBasePath $relativePath
            }
            else {
                # Fallback: use the last part of the path
                $folderName = Split-Path $Path -Leaf
                $newOneDrivePath = Join-Path $oneDriveBasePath $folderName
            }
            
            $pathLength = $newOneDrivePath.Length
            $exceedsLimit = $pathLength -gt $script:MaxPathLength
            
            $result = [PSCustomObject]@{
                OriginalPath = $Path
                NewOneDrivePath = $newOneDrivePath
                PathLength = $pathLength
                ExceedsLimit = $exceedsLimit
                MaxLength = $script:MaxPathLength
                UserName = $UserName
                TenantName = $TenantName
            }
            
            if ($exceedsLimit) {
                Write-LogMessage "Path exceeds limit: $newOneDrivePath (Length: $pathLength)" -Level Warning
            }
            
            return $result
        }
        catch {
            Write-LogMessage "Error testing path length: $($_.Exception.Message)" -Level Error
            throw
        }
    }
}

<#
.SYNOPSIS
Gets folder redirection paths for AD users

.PARAMETER UserName
Specific username to query (optional)

.PARAMETER SearchBase
AD search base (optional)

.EXAMPLE
Get-ADUserFolderRedirection -UserName "john.doe"
Get-ADUserFolderRedirection -SearchBase "OU=Users,DC=contoso,DC=com"
#>
function Get-ADUserFolderRedirection {
    [CmdletBinding()]
    param(
        [string]$UserName,
        [string]$SearchBase,
        [int]$MaxUsers = 1000
    )
    
    begin {
        Write-LogMessage "Retrieving AD user folder redirection information"
        
        if (-not (Get-Module -Name ActiveDirectory)) {
            try {
                Import-Module ActiveDirectory -ErrorAction Stop
            }
            catch {
                throw "ActiveDirectory module is required but cannot be loaded: $($_.Exception.Message)"
            }
        }
    }
    
    process {
        try {
            $searchParams = @{
                Filter = "Enabled -eq 'True'"
                Properties = @('SamAccountName', 'DisplayName', 'HomeDirectory', 'ProfilePath')
            }
            
            if ($UserName) {
                $searchParams.Filter = "SamAccountName -eq '$UserName' -and Enabled -eq 'True'"
            }
            
            if ($SearchBase) {
                $searchParams.SearchBase = $SearchBase
            }
            
            $users = Get-ADUser @searchParams | Select-Object -First $MaxUsers
            
            foreach ($user in $users) {
                # Get common folder redirection paths from registry/group policy
                $userFolders = @()
                
                # Common redirected folders
                $redirectedFolders = @(
                    'Desktop',
                    'Documents', 
                    'Downloads',
                    'Pictures',
                    'Videos',
                    'Music'
                )
                
                foreach ($folder in $redirectedFolders) {
                    # Construct typical folder redirection paths
                    $possiblePaths = @(
                        "\\fileserver\users$\$($user.SamAccountName)\$folder",
                        "\\fileserver\home$\$($user.SamAccountName)\$folder",
                        "\\fileserver\redirect$\$($user.SamAccountName)\$folder"
                    )
                    
                    foreach ($path in $possiblePaths) {
                        if (Test-Path $path) {
                            $userFolders += [PSCustomObject]@{
                                UserName = $user.SamAccountName
                                DisplayName = $user.DisplayName
                                FolderType = $folder
                                Path = $path
                                Exists = $true
                                SizeMB = Get-FolderSize -Path $path
                            }
                            break
                        }
                    }
                }
                
                if ($userFolders.Count -eq 0) {
                    # Add entry even if no folders found
                    $userFolders += [PSCustomObject]@{
                        UserName = $user.SamAccountName
                        DisplayName = $user.DisplayName
                        FolderType = 'None'
                        Path = 'No redirected folders found'
                        Exists = $false
                        SizeMB = 0
                    }
                }
                
                Write-Output $userFolders
            }
        }
        catch {
            Write-LogMessage "Error retrieving AD users: $($_.Exception.Message)" -Level Error
            throw
        }
    }
}

<#
.SYNOPSIS
Tests folder redirection root path and identifies OneDrive migration issues

.PARAMETER RootPath
The root path of the user's folder redirection (e.g., \\server\share\username)

.PARAMETER TenantName
The Microsoft 365 tenant name for OneDrive

.PARAMETER UserName
The username for the folders being scanned (optional - will be extracted from RootPath if not provided)

.PARAMETER ExportPath
Path to save the CSV report (optional)

.EXAMPLE
Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso" -UserName "john.doe" -ExportPath "C:\Reports\OneDriveScan.csv"

.EXAMPLE
Test-FolderRedirectionPaths -RootPath "\\fileserver\users$\john.doe" -TenantName "contoso"
#>
function Test-FolderRedirectionPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        
        [Parameter(Mandatory = $false)]
        [string]$UserName,
        
        [string]$ExportPath
    )
    
    begin {
        Write-LogMessage "Starting folder redirection path scan for root path: $RootPath"
        $results = @()
        $compatibilityIssues = @()
    }
    
    process {
        try {            # Validate root path exists
            if (-not (Test-Path $RootPath)) {
                throw "Root path does not exist: $RootPath"
            }
            
            # Use provided username or extract from root path
            if ($UserName) {
                $resolvedUserName = $UserName
                Write-LogMessage "Using provided username: $resolvedUserName"
            } else {
                $resolvedUserName = Get-UsernameFromPath -RootPath $RootPath
                Write-LogMessage "Extracted username: $resolvedUserName from path: $RootPath"
            }
            
            # Get OneDrive base path
            $oneDriveBasePath = $script:OneDriveBasePath -f $resolvedUserName, $TenantName
            Write-LogMessage "OneDrive base path will be: $oneDriveBasePath"
            
            # Enumerate all folders in the root path (Desktop, Documents, Pictures, etc.)
            $topLevelFolders = Get-ChildItem -Path $RootPath -Directory -ErrorAction SilentlyContinue
            
            foreach ($folder in $topLevelFolders) {
                Write-LogMessage "Processing folder: $($folder.Name)"
                
                # Calculate OneDrive path for this folder
                $oneDriveFolderPath = Join-Path $oneDriveBasePath $folder.Name
                
                # Get all files and subfolders recursively
                $allItems = Get-ChildItem -Path $folder.FullName -Recurse -ErrorAction SilentlyContinue
                
                foreach ($item in $allItems) {
                    # Calculate relative path from the folder root
                    $relativePath = $item.FullName.Substring($folder.FullName.Length).TrimStart('\')
                    $oneDriveItemPath = Join-Path $oneDriveFolderPath $relativePath
                    
                    $pathLength = $oneDriveItemPath.Length
                    $exceedsLimit = $pathLength -gt $script:MaxPathLength
                    $charactersOver = if ($exceedsLimit) { $pathLength - $script:MaxPathLength } else { 0 }
                    
                    # Check OneDrive compatibility
                    $compatibilityResult = Test-OneDriveCompatibility -Path $item.FullName
                      $result = [PSCustomObject]@{
                        UserName = $resolvedUserName
                        FolderType = $folder.Name
                        ItemType = if ($item.PSIsContainer) { "Folder" } else { "File" }
                        CurrentPath = $item.FullName
                        OneDrivePath = $oneDriveItemPath
                        CurrentPathLength = $item.FullName.Length
                        OneDrivePathLength = $pathLength
                        ExceedsLimit = $exceedsLimit
                        CharactersOverLimit = $charactersOver
                        MaxPathLength = $script:MaxPathLength
                        IsOneDriveCompatible = $compatibilityResult.IsCompatible
                        CompatibilityIssues = ($compatibilityResult.Issues -join '; ')
                        RequiresAction = $exceedsLimit -or (-not $compatibilityResult.IsCompatible)
                        ItemName = $item.Name
                        LastModified = $item.LastWriteTime
                        SizeBytes = if (-not $item.PSIsContainer) { $item.Length } else { 0 }
                        ScanDate = Get-Date
                    }
                    
                    $results += $result
                    
                    # Track compatibility issues separately
                    if (-not $compatibilityResult.IsCompatible) {
                        $compatibilityIssues += $result
                    }
                    
                    # Log long paths and compatibility issues
                    if ($exceedsLimit) {
                        Write-LogMessage "Path exceeds limit: $oneDriveItemPath (Length: $pathLength, Over by: $charactersOver)" -Level Warning
                    }
                    if (-not $compatibilityResult.IsCompatible) {
                        Write-LogMessage "Compatibility issue: $($item.FullName) - $($compatibilityResult.Issues -join ', ')" -Level Warning
                    }
                }
                
                # Also check the folder itself (without files)
                $folderPathLength = $oneDriveFolderPath.Length
                $folderExceedsLimit = $folderPathLength -gt $script:MaxPathLength
                $folderCharactersOver = if ($folderExceedsLimit) { $folderPathLength - $script:MaxPathLength } else { 0 }
                
                $folderCompatibility = Test-OneDriveCompatibility -Path $folder.FullName
                  $folderResult = [PSCustomObject]@{
                    UserName = $resolvedUserName
                    FolderType = $folder.Name
                    ItemType = "Folder"
                    CurrentPath = $folder.FullName
                    OneDrivePath = $oneDriveFolderPath
                    CurrentPathLength = $folder.FullName.Length
                    OneDrivePathLength = $folderPathLength
                    ExceedsLimit = $folderExceedsLimit
                    CharactersOverLimit = $folderCharactersOver
                    MaxPathLength = $script:MaxPathLength
                    IsOneDriveCompatible = $folderCompatibility.IsCompatible
                    CompatibilityIssues = ($folderCompatibility.Issues -join '; ')
                    RequiresAction = $folderExceedsLimit -or (-not $folderCompatibility.IsCompatible)
                    ItemName = $folder.Name
                    LastModified = $folder.LastWriteTime
                    SizeBytes = 0
                    ScanDate = Get-Date
                }
                
                $results += $folderResult
            }
            
            # Generate summary statistics
            $totalItems = $results.Count
            $itemsExceedingLimit = ($results | Where-Object { $_.ExceedsLimit }).Count
            $itemsWithCompatibilityIssues = ($results | Where-Object { -not $_.IsOneDriveCompatible }).Count
            $itemsRequiringAction = ($results | Where-Object { $_.RequiresAction }).Count
              Write-LogMessage "Scan completed for user: $resolvedUserName"
            Write-LogMessage "Total items: $totalItems"
            Write-LogMessage "Items exceeding path limit: $itemsExceedingLimit"
            Write-LogMessage "Items with compatibility issues: $itemsWithCompatibilityIssues"
            Write-LogMessage "Items requiring action: $itemsRequiringAction"
            
            # Export to CSV if requested
            if ($ExportPath) {
                Export-PathLengthReport -Results $results -OutputPath $ExportPath
            }
            
            return $results
        }
        catch {
            Write-LogMessage "Error during folder redirection scan: $($_.Exception.Message)" -Level Error
            throw
        }
    }
}

<#
.SYNOPSIS
Exports the path length analysis results to various formats

.PARAMETER Results
The results from Test-FolderRedirectionPaths

.PARAMETER OutputPath
Output file path (supports .csv, .xlsx, .json)

.EXAMPLE
Export-PathLengthReport -Results $scanResults -OutputPath "C:\Reports\OneDriveAnalysis.csv"
#>
function Export-PathLengthReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    begin {
        Write-LogMessage "Exporting path length report to: $OutputPath"
    }
    
    process {
        try {
            $extension = [System.IO.Path]::GetExtension($OutputPath).ToLower()
            
            # Ensure output directory exists
            $outputDir = Split-Path $OutputPath -Parent
            if (-not (Test-Path $outputDir)) {
                New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            }
            
            switch ($extension) {
                '.csv' {
                    $Results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
                '.json' {
                    $Results | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding UTF8
                }
                '.xlsx' {
                    if (Get-Module -Name ImportExcel -ListAvailable) {
                        Import-Module ImportExcel
                        $Results | Export-Excel -Path $OutputPath -AutoSize -FreezeTopRow -TableStyle Medium2
                    }
                    else {
                        Write-LogMessage "ImportExcel module not available. Exporting as CSV instead." -Level Warning
                        $csvPath = $OutputPath -replace '\.xlsx$', '.csv'
                        $Results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                    }
                }
                default {
                    Write-LogMessage "Unsupported file format. Exporting as CSV." -Level Warning
                    $csvPath = $OutputPath -replace '\.[^.]+$', '.csv'
                    $Results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                }
            }
              # Create summary report
            $summaryPath = $OutputPath -replace '\.[^.]+$', '_Summary.txt'
            $summary = @"
OneDrive Migration Path Analysis Summary
Generated: $(Get-Date)

Total Items Analyzed: $($Results.Count)
Items Exceeding Path Limit (247 chars): $(($Results | Where-Object { $_.ExceedsLimit }).Count)
Items with OneDrive Compatibility Issues: $(($Results | Where-Object { -not $_.IsOneDriveCompatible }).Count)
Items Requiring Action: $(($Results | Where-Object { $_.RequiresAction }).Count)
Percentage Requiring Action: $([math]::Round((($Results | Where-Object { $_.RequiresAction }).Count / $Results.Count) * 100, 2))%

Files vs Folders:
Files: $(($Results | Where-Object { $_.ItemType -eq 'File' }).Count)
Folders: $(($Results | Where-Object { $_.ItemType -eq 'Folder' }).Count)

Average Current Path Length: $([math]::Round(($Results | Measure-Object -Property CurrentPathLength -Average).Average, 2))
Average OneDrive Path Length: $([math]::Round(($Results | Measure-Object -Property OneDrivePathLength -Average).Average, 2))
Maximum Path Length Found: $(($Results | Measure-Object -Property OneDrivePathLength -Maximum).Maximum)

Top Folder Types with Path Issues:
$(($Results | Where-Object { $_.ExceedsLimit } | Group-Object FolderType | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object { "$($_.Name): $($_.Count) items" }) -join "`n")

Common Compatibility Issues:
$(($Results | Where-Object { -not $_.IsOneDriveCompatible } | ForEach-Object { $_.CompatibilityIssues } | Group-Object | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object { "$($_.Name): $($_.Count) occurrences" }) -join "`n")

Longest Paths (Top 5):
$(($Results | Sort-Object OneDrivePathLength -Descending | Select-Object -First 5 | ForEach-Object { "$($_.OneDrivePathLength) chars: $($_.OneDrivePath)" }) -join "`n")
"@
            
            $summary | Out-File -FilePath $summaryPath -Encoding UTF8
            
            Write-LogMessage "Report exported successfully. Summary saved to: $summaryPath"
        }
        catch {
            Write-LogMessage "Error exporting report: $($_.Exception.Message)" -Level Error
            throw
        }
    }
}

<#
.SYNOPSIS
Gets user folder paths with detailed information

.PARAMETER UserName
Specific username to query

.PARAMETER IncludeSize
Include folder size calculation

.EXAMPLE
Get-UserFolderPaths -UserName "john.doe" -IncludeSize
#>
function Get-UserFolderPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        
        [switch]$IncludeSize
    )
    
    begin {
        Write-LogMessage "Getting folder paths for user: $UserName"
    }
    
    process {
        try {
            $userFolders = Get-ADUserFolderRedirection -UserName $UserName
            
            if ($IncludeSize) {
                foreach ($folder in $userFolders) {
                    if ($folder.Exists) {
                        $folder.SizeMB = Get-FolderSize -Path $folder.Path
                    }
                }
            }
            
            return $userFolders
        }
        catch {
            Write-LogMessage "Error getting user folder paths: $($_.Exception.Message)" -Level Error
            throw
        }
    }
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Test-FolderRedirectionPaths',
    'Test-OneDrivePathLength',
    'Test-OneDriveCompatibility', 
    'Get-UserFolderPaths',
    'Export-PathLengthReport',
    'Get-ADUserFolderRedirection'
)
