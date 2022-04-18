Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

function GetMigrationSettings($projectName)
{
	$p = GetProjectProperties $projectName

	$migrationSettingsFullPath = [IO.Path]::Combine($p.FullPath, 'migrations.json')
	$migrationSettings = Get-Content -Raw -Path $migrationSettingsFullPath | ConvertFrom-Json

	$migrationSettings | Add-Member -MemberType NoteProperty -Name SettingsFullPath -Value $migrationSettingsFullPath
	$migrationSettings.FluentMigrationToolPath = $migrationSettings.FluentMigrationToolPath.replace("%USERPROFILE%", $env:USERPROFILE)

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

function Update-FluentDatabase([String]$ProjectName, [Int] $Timeout = 30)
{
	$migrationProject = GetProjectProperties $ProjectName
	FluentBuild $migrationProject.Project

	$migrationSettings = GetMigrationSettings $migrationProject.Name
	$connectionProject = GetProjectProperties $migrationSettings.ConnectionProjectName

	$params = @(
		"-t:migrate", 
		"-db $($migrationSettings.DbProvider)",
		"-configPath ""$($connectionProject.ConfigFilePath)""",
		"-c ""$($migrationSettings.ConnectionName)""",
		"-a ""$($migrationProject.OutputFileFullPath)""",
		"-wd ""$($migrationProject.OutputFullPath)""",
		"-timeout $($Timeout)",
		"-verbose ""TRUE""")
	$command = "$($migrationSettings.FluentMigrationToolPath) $params"
	
	Write-Host $command
	Invoke-Expression -Command $command
}

function Rollback-FluentDatabase
{
	[CmdletBinding(DefaultParameterSetName = 'MigrationNumber')]
		param ([parameter(Position = 0, Mandatory = $true)]
			[string] $MigrationNumber,
			[String] $ProjectName, 
			[Int] $Timeout = 30)

	$migrationProject = GetProjectProperties $ProjectName
	FluentBuild $migrationProject.Project

	$migrationSettings = GetMigrationSettings $migrationProject.Name
	$connectionProject = GetProjectProperties $migrationSettings.ConnectionProjectName

	$params = @(
		"-t rollback:toversion", 
		"-version $MigrationNumber",
		"-db $($migrationSettings.DbProvider)",
		"-configPath ""$($connectionProject.ConfigFilePath)""",
		"-c ""$($migrationSettings.ConnectionName)""",
		"-a ""$($migrationProject.OutputFileFullPath)""",
		"-wd ""$($migrationProject.OutputFullPath)""",
		"-timeout $($Timeout)")
	
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

function Add-FluentMigration
{
	[CmdletBinding(PositionalBinding = $false, DefaultParameterSetName = 'MigrationName')]
    param (
	[parameter(Position = 0, Mandatory = $true, ParameterSetName='MigrationName')]
	[string] $MigrationName,
	[Parameter(Position = 1, Mandatory = $false)]
    [Switch]$AddScript = $false,
	[Parameter(Position = 2, Mandatory = $false)]
	[string] $ProjectName)
	
	$migrationSettings = GetMigrationSettings $ProjectName
	$projectSettings = GetProjectProperties $ProjectName
	$p = $projectSettings.Project

	FluentBuild $p

	$timestamp = Get-Date -Format $migrationSettings.TimeFormat
	$migrationsFolderName = $migrationSettings.MigrationFolder;
	$namespace = $p.Properties.Item("DefaultNamespace").Value.ToString()
	$migrationsPath = Join-Path $projectSettings.FullPath $migrationsFolderName
	$className = $migrationName -replace "([\s-])", "_"
	$fileName = $timestamp + "_$migrationName.cs"
	$filePath = Join-Path $migrationsPath $fileName	
	$codeScriptUpPath = "";
	$codeScriptDownPath = "";

	if ($AddScript) {
		$scriptsFolderName = $migrationSettings.ScriptsFolder;
		$scriptsFolderPath = Join-Path $projectSettings.FullPath $scriptsFolderName
		$scriptFileName = $timestamp + "_$migrationName.sql"
		$scriptFilePath = Join-Path $scriptsFolderPath $scriptFileName
		$scriptDownFileName = $timestamp + "_$($migrationName)_Down.sql"
		$scriptDownFilePath = Join-Path $scriptsFolderPath $scriptDownFileName

		CreateFolderIfNotExist $scriptsFolderPath
		
		New-Item -Path $scriptsFolderPath -Name $scriptFileName -ItemType "file" -Value "--SQL script here." > $null
		$scriptItem = $p.ProjectItems.AddFromFile($scriptFilePath)
		$scriptItem.Properties.Item("CopyToOutputDirectory").Value = [uint32]2;		#Copy if newer

		New-Item -Path $scriptsFolderPath -Name $scriptDownFileName -ItemType "file" -Value "--SQL script here." > $null
		$scriptItem = $p.ProjectItems.AddFromFile($scriptDownFilePath)
		$scriptItem.Properties.Item("CopyToOutputDirectory").Value = [uint32]2;		#Copy if newer

		$codeScriptUpPath = $scriptFilePath.Replace("$($projectSettings.FullPath)\", "")
		$codeScriptDownPath = $scriptDownFilePath.Replace("$($projectSettings.FullPath)\", "")
	}

	$fileContent = GetMigrationContent $namespace $timestamp $className $codeScriptUpPath $codeScriptDownPath

	CreateFolderIfNotExist $migrationsPath
	Write-Output "CreateFolderIfNotExist $migrationsPath"
	New-Item -Path $migrationsPath -Name $fileName -ItemType "file" -Value $fileContent > $null
	Write-Output "New-Item -Path $migrationsPath"
	$p.ProjectItems.AddFromFile($filePath) > $null
	Write-Output "New migration in file: $fileName"
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
		[System.IO.Directory]::CreateDirectory($path) > $null
	}
}

function GetMigrationContent($namespace, $timestamp, $className, $scriptPathUp, $scriptPathDown)
{
	$executeScriptUp = If ([string]::IsNullOrEmpty($scriptPathUp)) {""} Else {"Execute.Script(@""$scriptPathUp"");"}
	$executeScriptDown = If ([string]::IsNullOrEmpty($scriptPathDown)) {""} Else {"Execute.Script(@""$scriptPathDown"");"};
	$fileContent = @"
using FluentMigrator;

namespace $namespace
{
	[Migration($timestamp)]
	public class $className : Migration
	{
		public override void Up()
		{
			$executeScriptUp
		}

		public override void Down()
		{
			$executeScriptDown
		}
	}
}  
"@
	return $fileContent
}


Export-ModuleMember @('Update-FluentDatabase')
Export-ModuleMember @('Rollback-FluentDatabase')
Export-ModuleMember @('Add-FluentMigration')

# TODO commands alias