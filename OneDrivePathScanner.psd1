#
# Module manifest for OneDrivePathScanner
#
@{
    RootModule = 'OneDrivePathScanner.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'OneDrive Migration Team'
    CompanyName = 'Organization'
    Copyright = '(c) 2025. All rights reserved.'
    Description = 'PowerShell module for scanning Folder Redirection paths and identifying potential OneDrive Known Folder Move path length issues'
    PowerShellVersion = '5.1'    # Functions to export from this module
    FunctionsToExport = @(
        'Test-FolderRedirectionPaths',
        'Test-OneDrivePathLength',
        'Test-OneDriveCompatibility',
        'Get-UserFolderPaths',
        'Export-PathLengthReport',
        'Get-ADUserFolderRedirection'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = '*'
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('OneDrive', 'Migration', 'FolderRedirection', 'PathLength', 'ActiveDirectory')
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Initial release for OneDrive migration path scanning'
        }
    }
}
