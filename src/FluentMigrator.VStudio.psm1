Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

function GetMigrationSettings($projectName)
{
	$p = GetProjectProperties $projectName

	$migrationSettingsFullPath = [IO.Path]::Combine($p.FullPath, 'migrations.json')
	$migrationSettings = Get-Content -Raw -Path $migrationSettingsFullPath | ConvertFrom-Json

	$migrationSettings | Add-Member -MemberType NoteProperty -Name SettingsFullPath -Value $migrationSettingsFullPath

	return $migrationSettings
}

function GetProjectProperties($projectName)
{
	$p = GetProject $projectName

	$fullPath = Split-Path -Path $p.FullName
	$outputPath = $p.ConfigurationManager.ActiveConfiguration.Properties.Item("OutputPath").Value
	$outputFileName = $p.Properties.Item("OutputFileName").Value
	$outputFullPath = [IO.Path]::Combine($fullPath, $outputPath)
	$outputFileFullPath = [IO.Path]::Combine($outputFullPath, $outputFileName)
	$configFilePath = $outputFileFullPath + ".config"

	$properties = @{
		Name = $p.Name
		Project = $p
		FullPath = $fullPath
		OutputPath = $outputPath
		OutputFileName = $outputFileName
		OutputFullPath = $outputFullPath
		OutputFileFullPath = $outputFileFullPath
		ConfigFilePath = $configFilePath
	}

	$o = New-Object psobject -Property $properties

	return $o
}

function FluentUpdateDatabase($projectName)
{
	$migrationProject = GetProjectProperties $projectName
	FluentBuild $($migrationProject.Project)

	$migrationSettings = GetMigrationSettings $migrationProject.Name
	$connectionProject = GetProjectProperties $migrationSettings.ConnectionProjectName

	$params = @(
		"-t:migrate", 
		"-db $($migrationSettings.DbProvider)",
		"-configPath ""$($connectionProject.ConfigFilePath)""",
		"-c ""$($migrationSettings.ConnectionName)""",
		"-a ""$($migrationProject.OutputFileFullPath)""",
		"-wd ""$($migrationProject.OutputFullPath)""")
		#"-verbose ""FALSE""")
	$command = "$($migrationSettings.FluentMigrationToolPath) $params"
	
	Write-Host $command
	Invoke-Expression -Command $command
}

function FluentRollbackDatabase
{
	[CmdletBinding(DefaultParameterSetName = 'MigrationNumber')]
		param ([parameter(Position = 0, Mandatory = $true)]
			[string] $MigrationNumber,
			$projectName)

	$migrationProject = GetProjectProperties $projectName
	FluentBuild $($migrationProject.Project)

	$migrationSettings = GetMigrationSettings $migrationProject.Name
	$connectionProject = GetProjectProperties $migrationSettings.ConnectionProjectName

	$params = @(
		"-t rollback:toversion", 
		"-version $MigrationNumber",
		"-db $($migrationSettings.DbProvider)",
		"-configPath ""$($connectionProject.ConfigFilePath)""",
		"-c ""$($migrationSettings.ConnectionName)""",
		"-a ""$($migrationProject.OutputFileFullPath)""",
		"-wd ""$($migrationProject.OutputFullPath)""")
		#"-verbose ""FALSE""")
	$command = "$($migrationSettings.FluentMigrationToolPath) $params"

	Write-Host $command
	Invoke-Expression -Command $command
}

function FluentBuild
{
	[CmdletBinding(DefaultParameterSetName = '$project')]
	param ([parameter(Position = 0, Mandatory = $true)] $project)
	
	$solutionBuild = $DTE.Solution.SolutionBuild
    $solutionBuild.BuildProject(
        $solutionBuild.ActiveConfiguration.Name,
        $project.UniqueName,
        <# WaitForBuildToFinish #> $true)

    if ($solutionBuild.LastBuildInfo)
    {
        throw "The project '$($project.ProjectName)' failed to build."
    }
	
	Write-Output "'$($project.ProjectName)' project build success."
}

function FluentAddMigration
{
	[CmdletBinding(DefaultParameterSetName = 'MigrationName')]
    param (
		[parameter(Position = 0, Mandatory = $true, ParameterSetName='MigrationName')]
		[string] $MigrationName,
		[Parameter(Position = 1, Mandatory = $false, ParameterSetName='ProjectName')]
		[string] $ProjectName)
	
	$projectSettings = GetProjectProperties $ProjectName
	$p = $projectSettings.Project

	$timestamp = Get-Date -Format yyyyMMddHHmmss
	$migrationsFolderName = "Migrations";
	$namespace = $p.Properties.Item("DefaultNamespace").Value.ToString() + ".$migrationsFolderName"
	$migrationsPath = Join-Path $projectSettings.FullPath $migrationsFolderName
	$className = $migrationName -replace "([\s-])", "_"
	$fileName = $timestamp + "_$migrationName.cs"
	$filePath = Join-Path $migrationsPath $fileName
	$fileContent = GetMigrationContent $namespace $timestamp $className

	CreateFolderIfNotExist $migrationsPath
	New-Item -Path $migrationsPath -Name $fileName -ItemType "file" -Value $fileContent
	$p.ProjectItems.AddFromFile($filePath)
}

function GetConfigFilePath($projProps)
{
	return $projProps.OutputFileFullPath + ".config"
}

function GetProject($projectName)
{
	$p = If (!$projectName) { Get-Project } Else { Get-Project $projectName }
	return $p
}

function CreateFolderIfNotExist($path)
{
	if (-not (Test-Path $path))
	{
		return [System.IO.Directory]::CreateDirectory($migrationsPath)
	}
}

function GetMigrationContent($namespace, $timestamp, $className)
{
	$fileContent = @"
using FluentMigrator;

namespace $namespace
{
	[Migration($timestamp)]
	public class $className : Migration
	{
		public override void Up()
		{
		}

		public override void Down()
		{
		}
	}
}  
"@
	return $fileContent
}


Export-ModuleMember @('FluentUpdateDatabase')
Export-ModuleMember @('FluentRollbackDatabase')
Export-ModuleMember @('FluentAddMigration')

# TODO
# - Build project before adding migration
# - Check if new migration already exists
# - Add Migration folder to config
# - Add Time format to config