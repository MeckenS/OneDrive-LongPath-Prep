# FolderRedirectionPaths

## Description
PowerShell module designed to scan user folders located in a network file share using Folder Redirection. This can assist when migrating user files from Folder Redirection to OneDrive and find any paths that would exceed the 247 path limit imposed on the OneDrive desktop client.

## Getting Started
1. Download the PowerShell module from GitHub
2. Extract the zip folder
3. Open PowerShell and navigate to the location of the module.
4. ```powershell
    Import-Module C:\onedrive-longPath-prep\FolderRedirectionPaths.psm1`
   ```

## Examples

### Show summary of multiple users.
> [!NOTE]
> Remove `-UserName` parameter to scan all users.
> [!WARNING]
> This could take a long time depending on the amount of users.
```powershell
Test-FolderRedirectionPaths -RootPath "\\server\home\" -TenantName "<M365TenantName>" -UserName @("user1", "user2") -ShowProgress -Summary | Format-Table
```

### Scan a single user and export results of paths over the 247 limit to csv
```powershell
Test-FolderRedirectionPaths -RootPath "\\server\home\" -TenantName "<M365TenantName>" -UserName "user1" -ShowProgress | Where-Object {$_.RequiresAction -eq $True} | Export-Csv -NoTypeInformation "results.csv"
```

### Scan multiple users and export results of paths over the 247 limit to csv
```powershell
Test-FolderRedirectionPaths -RootPath "\\server\home\" -TenantName "<M365TenantName>" -UserName @("user1", "user2") -ShowProgress | Where-Object {$_.RequiresAction -eq $True} | Export-Csv -NoTypeInformation "results.csv"
```