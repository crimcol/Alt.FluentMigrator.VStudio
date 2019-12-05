param($installPath, $toolsPath, $package, $project)

$p = Get-Project
$fullPath = Split-Path -Path $p.FullName
$fileName = "migrations.json"
$configPath = "$fullPath\$fileName"

if ($project.ProjectItems | Where-Object { $_.Name -eq $fileName })
{
    return
}

$configContent = @"
{
    "ConnectionProjectName": "MigrationTest",
    "ConnectionName": "TestDb",
    "FluentMigrationToolPath": ".\\packages\\FluentMigrator.Console.3.2.1\\net461\\x86\\Migrate.exe",
    "DbProvider": "SqlServer",
    "DbProviderHelpUrl": "https://fluentmigrator.github.io/articles/runners/runner-console.html#--provider---dbtype---dbvalue-required"
}  
"@

New-Item -Path $fullPath -Name $fileName -ItemType "file" -Value $configContent
$p.ProjectItems.AddFromFile($configPath)