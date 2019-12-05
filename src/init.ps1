param($installPath, $toolsPath, $package, $project)

$importedModule = Get-Module 'FluentMigrator.VStudio'
$moduleToImport = Test-ModuleManifest (Join-Path $PSScriptRoot 'FluentMigrator.VStudio.psd1')
$import = $true

if ($importedModule)
{
    if ($importedModule.Version -le $moduleToImport.Version)
    {
        Remove-Module 'FluentMigrator.VStudio'
    }
    else
    {
        $import = $false
    }
}

if ($import)
{
    Import-Module $moduleToImport
}