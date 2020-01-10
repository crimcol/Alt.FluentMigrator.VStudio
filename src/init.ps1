param($installPath, $toolsPath, $package, $project)

$importedModule = Get-Module 'Alt.FluentMigrator.VStudio'
$moduleToImport = Test-ModuleManifest (Join-Path $PSScriptRoot 'Alt.FluentMigrator.VStudio.psd1')
$import = $true

if ($importedModule)
{
    if ($importedModule.Version -le $moduleToImport.Version)
    {
        Remove-Module 'Alt.FluentMigrator.VStudio'
    }
    else
    {
        $import = $false
    }
}

if ($import)
{
    Import-Module $moduleToImport -DisableNameChecking
}