# OneDrive Path Scanner - Change Log

## Version 2.1.0 - UserName Parameter Enhancement

### Summary
Added explicit `UserName` parameter to the `Test-FolderRedirectionPaths` function to improve reliability in production environments where username extraction from paths may not be consistent.

### Changes Made

#### Core Module Changes
- **OneDrivePathScanner.psm1**: Added optional `UserName` parameter to `Test-FolderRedirectionPaths` function
  - Parameter is optional and backward compatible
  - Function uses provided username when available, falls back to path extraction when not provided
  - Updated internal logic to use `$resolvedUserName` variable
  - Enhanced function documentation with new parameter and examples

#### Documentation Updates
- **README.md**: 
  - Updated function documentation to include new `UserName` parameter
  - Added examples showing both usage patterns (with and without explicit username)
  - Updated all usage scenarios to demonstrate recommended approach with explicit username
  
- **README-Simple.md**:
  - Updated quick reference examples to include `UserName` parameter
  - Updated batch processing examples
  - Updated focus examples

#### Example Files Updates
- **UpdatedExamples.ps1**:
  - Updated all function calls to include explicit `UserName` parameter
  - Updated `Get-MigrationReadinessReport` function to accept and use `UserName` parameter
  - Enhanced examples to demonstrate best practices

- **BatchProcessingExamples.ps1**:
  - Updated `Invoke-BatchFolderRedirectionScan` to pass username to scan function
  - Updated parallel processing function to include username parameter
  - Maintained compatibility with existing batch processing workflows

### Benefits
1. **Improved Reliability**: Explicit username parameter eliminates dependency on path parsing
2. **Production Ready**: Better suited for environments with non-standard path structures
3. **Backward Compatible**: Existing scripts continue to work without modification
4. **Best Practice**: Encourages explicit parameter usage for more robust code

### Usage Patterns

#### Recommended (Explicit Username)
```powershell
Test-FolderRedirectionPaths -RootPath "\\server\users$\john.doe" -TenantName "contoso" -UserName "john.doe"
```

#### Legacy (Path Extraction)
```powershell
Test-FolderRedirectionPaths -RootPath "\\server\users$\john.doe" -TenantName "contoso"
```

### Testing
- ✅ Module imports successfully with new parameter
- ✅ Function parameters verified (RootPath, TenantName, UserName, ExportPath)
- ✅ Help documentation updated with examples
- ✅ Module manifest validation passes
- ✅ All exported functions remain available
- ✅ Backward compatibility maintained

### Files Modified
- `OneDrivePathScanner.psm1` - Core module with enhanced function
- `README.md` - Comprehensive documentation update
- `README-Simple.md` - Quick reference guide update  
- `UpdatedExamples.ps1` - All examples updated with best practices
- `BatchProcessingExamples.ps1` - Batch processing functions enhanced

### Next Steps
- Users should update their scripts to use the explicit `UserName` parameter for improved reliability
- This enhancement addresses the production reliability concern identified by the user
- The module is now more robust for enterprise deployment scenarios
