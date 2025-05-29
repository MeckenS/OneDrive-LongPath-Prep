@{
    RootModule = 'FolderRedirectionPaths.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'  # You might want to generate a new GUID
    Author = 'MeckenS'
    Description = 'PowerShell module designed to scan user folders located in a network file share using Folder Redirection and identify potential path length issues for migrations.'
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Test-FolderRedirectionPaths'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            Tags = @('FolderRedirection', 'Migration', 'OneDrive', 'Path')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Initial release'
        }
    }
}
