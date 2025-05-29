#Requires -Version 5.1

# Global variables
$script:MaxPathLength = 247
$script:OneDriveBasePath = "C:\Users\{0}\OneDrive - {1}"  # {0} = username, {1} = tenant name

# Known folder mappings for OneDrive
$script:OneDriveFolderMappings = @{
    'My Documents' = 'Documents'
    'Documents' = 'Documents'  # Include both variations
    'My Pictures' = 'Pictures'
    'My Music' = 'Music'
    'My Video' = 'Videos'
    'Desktop' = 'Desktop'  # These don't change but included for completeness
}

# OneDrive incompatible characters and file names
$script:InvalidChars = @('<', '>', ':', '"', '|', '?', '*', '\')
$script:InvalidNames = @(
    'CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9', '_vti_', 'desktop.ini'
)

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
        'Info' { Write-Verbose $logMessage }
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

function Test-FolderRedirectionPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
          [Parameter(Mandatory = $false)]
        [string[]]$UserName,
        
        [Parameter()]
        [switch]$Summary,
        
        [Parameter()]
        [switch]$CheckCompatibility,
        
        [Parameter()]
        [switch]$EnableLogging,
        
        [Parameter()]
        [switch]$ShowProgress
    )
    
    begin {
        # Helper function to conditionally write log messages
        function Write-OptionalLog {
            param([string]$Message, [string]$Level = 'Info')
            if ($EnableLogging) {
                Write-LogMessage -Message $Message -Level $Level
            }
        }
        
        function Write-OptionalProgress {
            param(
                [int]$Id,
                [string]$Activity,
                [string]$Status,
                [int]$PercentComplete,
                [string]$CurrentOperation
            )
            if ($ShowProgress) {
                Write-Progress -Id $Id -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $CurrentOperation
            }
        }
        
        Write-OptionalLog "Starting folder redirection path scan for root path: $RootPath"
        $results = @()
        $userSummary = @{}
        $folderItemCounts = @{}
    }
    
    process {
        try {
            # Validate root path exists
            if (-not (Test-Path $RootPath)) {
                throw "Root path does not exist: $RootPath"
            }
            
            # Initialize data structures
            $results = @()
            $userSummary = @{}
            $folderItemCounts = @{}
              # Use provided usernames or scan for user folders
            if ($UserName) {
                $userFolders = @()
                foreach ($name in $UserName) {
                    $userPath = Join-Path $RootPath $name
                    if (-not (Test-Path $userPath)) {
                        Write-Warning "User folder does not exist and will be skipped: $userPath"
                        continue
                    }
                    $userFolders += [PSCustomObject]@{
                        Name = $name
                        FullName = $userPath
                        LocalUsername = $name
                    }
                }
                if ($userFolders.Count -eq 0) {
                    throw "None of the specified user folders exist in $RootPath"
                }
            } else {
                $userFolders = Get-ChildItem -Path $RootPath -Directory | ForEach-Object {
                    $localUsername = $_.Name
                    if ($localUsername -match '^[^\\]+\\(.+)$') {
                        $localUsername = $matches[1]
                    }
                    [PSCustomObject]@{
                        Name = $_.Name
                        FullName = $_.FullName
                        LocalUsername = $localUsername
                    }
                }
            }

            $userCount = $userFolders.Count
            $currentUserIndex = 0
            
            foreach ($userFolder in $userFolders) {
                $currentUsername = $userFolder.Name
                $currentUserIndex++
                
                # Show overall progress for users
                $userPercentComplete = ($currentUserIndex / $userCount) * 100
                Write-OptionalProgress -Id 0 -Activity "Scanning User Folders" -Status "Processing user $currentUserIndex of $userCount" `
                    -PercentComplete $userPercentComplete -CurrentOperation "Current User: $currentUsername"
                
                Write-OptionalLog "Processing user folder: $currentUsername"
                $userSummary[$currentUsername] = @{
                }
                
                $oneDriveBasePath = $script:OneDriveBasePath -f $userFolder.LocalUsername, $TenantName
                Write-OptionalLog "OneDrive base path will be: $oneDriveBasePath"
                
                $userPath = $userFolder.FullName
                $topLevelFolders = Get-ChildItem -Path $userPath -Directory -ErrorAction SilentlyContinue
                
                foreach ($folder in $topLevelFolders) {
                    Write-OptionalLog "Processing folder: $($folder.Name)"
                    $userSummary[$currentUsername][$folder.Name] = 0
                    
                    $folderKey = "$currentUsername`_$($folder.Name)"
                    $folderItemCounts[$folderKey] = 0
                      # Map folder name to OneDrive equivalent using predefined mappings
                    $oneDriveFolderName = if ($script:OneDriveFolderMappings.ContainsKey($folder.Name)) {
                        $script:OneDriveFolderMappings[$folder.Name]
                    } else {
                        $folder.Name
                    }
                    $oneDriveFolderPath = Join-Path $oneDriveBasePath $oneDriveFolderName
                    $allItems = Get-ChildItem -Path $folder.FullName -Recurse -ErrorAction SilentlyContinue
                    $totalItems = if ($allItems) { $allItems.Count } else { 0 }
                    $folderItemCounts[$folderKey] = $totalItems
                    
                    # Initialize item counter for progress
                    $currentItemIndex = 0
                    
                    foreach ($item in $allItems) {
                        $currentItemIndex++
                        # Show progress for current folder scan
                        if ($totalItems -gt 0) {
                            $itemPercentComplete = ($currentItemIndex / $totalItems) * 100
                            Write-OptionalProgress -Id 1 -Activity "Scanning Items in $($folder.Name)" `
                                -Status "Processing item $currentItemIndex of $totalItems" `
                                -PercentComplete $itemPercentComplete `
                                -CurrentOperation $item.Name
                        }
                        
                        $relativePath = $item.FullName.Substring($folder.FullName.Length).TrimStart('\')
                        $oneDriveItemPath = Join-Path $oneDriveFolderPath $relativePath
                        
                        $pathLength = $oneDriveItemPath.Length
                        $exceedsLimit = $pathLength -gt $script:MaxPathLength
                        $charactersOver = if ($exceedsLimit) { $pathLength - $script:MaxPathLength } else { 0 }
                        
                        # Only check compatibility if the switch is provided
                        $compatibilityResult = if ($CheckCompatibility) {
                            Test-OneDriveCompatibility -Path $item.FullName
                        } else {
                            [PSCustomObject]@{
                                Path = $item.FullName
                                FileName = Split-Path $item.FullName -Leaf
                                IsCompatible = $true
                                Issues = @()
                            }
                        }
                        
                        $result = [PSCustomObject]@{
                            UserName = $currentUsername
                            FolderName = $folder.Name
                            Path = $item.FullName
                            OneDrivePath = $oneDriveItemPath
                            PathLength = $pathLength
                            ExceedsLimit = $exceedsLimit
                            CharactersOverLimit = $charactersOver
                            IsCompatible = $compatibilityResult.IsCompatible
                            Issues = ($compatibilityResult.Issues -join '; ')
                            RequiresAction = $exceedsLimit -or (-not $compatibilityResult.IsCompatible)
                        }
                        
                        $results += $result
                        
                        if ($exceedsLimit) {
                            Write-OptionalLog "Path exceeds limit: $oneDriveItemPath (Length: $pathLength, Over by: $charactersOver)" -Level Warning
                            $userSummary[$currentUsername][$folder.Name]++
                        }
                        if ($CheckCompatibility -and -not $compatibilityResult.IsCompatible) {
                            Write-OptionalLog "Compatibility issue: $($item.FullName) - $($compatibilityResult.Issues -join ', ')" -Level Warning
                        }
                    }
                }
            }
            
            # Clear both progress bars
            if ($ShowProgress) {
                Write-Progress -Id 1 -Activity "Scanning Items" -Completed
                Write-Progress -Id 0 -Activity "Scanning User Folders" -Completed
            }
            
            $totalItems = $results.Count
            $itemsWithIssues = ($results | Where-Object { $_.RequiresAction }).Count
            Write-OptionalLog "Scan completed. Found $itemsWithIssues issues in $totalItems items."
            
            if ($Summary) {
                if ($EnableLogging) {
                    Write-Verbose "`nPer-User Path Length Summary:"
                    Write-Verbose "-----------------------------"
                }
                $summaryObjects = @()
                
                foreach ($user in $userSummary.Keys | Sort-Object) {
                    Write-OptionalLog "`nUser: $user"
                    foreach ($folder in $userSummary[$user].Keys | Sort-Object) {
                        $count = $userSummary[$user][$folder]
                        $folderKey = "$user`_$folder"
                        $totalItemsInFolder = $folderItemCounts[$folderKey]
                        
                        if ($count -gt 0) {
                            Write-OptionalLog "  $folder : $count paths over limit" -Level Warning
                        } else {
                            Write-OptionalLog "  $folder : No issues"
                        }
                        
                        $summaryObjects += [PSCustomObject]@{
                            UserName = $user
                            Folder = $folder
                            PathsOverLimit = $count
                            HasIssues = $count -gt 0
                            TotalItems = $totalItemsInFolder
                        }
                    }
                }
                return $summaryObjects
            } else {
                return $results
            }
        }
        catch {
            Write-Error "Error during folder redirection scan: $($_.Exception.Message)"
            throw
        }
    }
}

# Export only the main function
Export-ModuleMember -Function 'Test-FolderRedirectionPaths'