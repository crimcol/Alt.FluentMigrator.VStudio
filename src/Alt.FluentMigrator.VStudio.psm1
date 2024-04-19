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

function ReadConnectionString
{
	[CmdletBinding()]
		param($connectionStringPath, $connectionName)
		
	if ([string]::IsNullOrEmpty($connectionProject.ConfigFilePath))
	{
		Write-Error -Message "Config file path is empty." -ErrorAction Stop 
	}
	
	$connectionString = ""
	try {
		$connectionString = ReadConnectionStringFromJsonConfig $connectionStringPath $connectionName
	}
	catch {
		Write-Verbose "probably it is not a json file"
		Write-Verbose $_
	}

	if ([string]::IsNullOrEmpty($connectionString))
	{
		$connectionString = ReadConnectionStringFromXmlConfig $connectionStringPath $connectionName
	}
	else
	{
		return $connectionString
	}

	if ([string]::IsNullOrEmpty($connectionString))
	{
		Write-Error -Message "ConnectionString '$($connectionName)' not found in file '$($connectionStringPath)'." -ErrorAction Stop 
	}

	return $connectionString
}

function ReadConnectionStringFromJsonConfig
{
	[CmdletBinding()]
		param($connectionStringPath, $connectionName)
		
	Write-Verbose "Read connection string from JSON config: $connectionStringPath"
	$json = Get-Content -Path $connectionStringPath | ConvertFrom-Json
	$connectionStrings = $json.ConnectionStrings
	
	foreach($item in $connectionStrings.PSObject.Properties){
		if($item.Name -match $connectionName){
			return $item.Value
		}else{
			Write-Verbose "Skip connection string $($item.Name) : $($item.Value)"
		}
	}
}

function ReadConnectionStringFromXmlConfig
{
	[CmdletBinding()]
		param($connectionStringPath, $connectionName)
		
	Write-Verbose "Read connection string from XML config: $connectionStringPath"
	$cfg = [xml](Get-Content -Path $connectionStringPath)
	$connectionStrings = $cfg.SelectNodes("//connectionStrings/add")
	foreach($cs in $connectionStrings){
		if($cs.name -match $connectionName){
			return $cs.connectionString
		}else{
			Write-Verbose "Skip connection string $($cs.name) : $($cs.connectionString)"
		}
	}
}

function GetProjectProperties
{
	[CmdletBinding()]
		param($projectName)
	$p = GetProject $projectName

	$fullPath = Split-Path -Path $p.FullName
	$outputPath = $p.ConfigurationManager.ActiveConfiguration.Properties.Item("OutputPath").Value.TrimEnd("\")
	$outputFileName = $p.Properties.Item("OutputFileName").Value
	$outputFullPath = [IO.Path]::Combine($fullPath, $outputPath)
	$outputFileFullPath = [IO.Path]::Combine($outputFullPath, $outputFileName)
	$configFilePath = $outputFileFullPath + ".config"
	
	if (-not(Test-Path $configFilePath))
	{
		$prevConfigPath = $configFilePath
		$configFilePath = [IO.Path]::Combine($outputFullPath, "appsettings.json")
		if (-not(Test-Path $configFilePath))
		{
			Write-Verbose -Message "Config file was not found:`r`n$($prevConfigPath)`r`n$($configFilePath)"
			$configFilePath = ""
		}
	}

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

function Update-FluentDatabase
{
	[CmdletBinding()]
		param ([String]$ProjectName, [Int] $Timeout = 30)

	$migrationProject = GetProjectProperties $ProjectName
	FluentBuild $migrationProject.Project

	$migrationSettings = GetMigrationSettings $migrationProject.Name
	$connectionProject = GetProjectProperties $migrationSettings.ConnectionProjectName
	$connectionString = ReadConnectionString $connectionProject.ConfigFilePath $migrationSettings.ConnectionName

	$params = @(
		"-t:migrate", 
		"-db $($migrationSettings.DbProvider)",
		#"-configPath ""$($connectionProject.ConfigFilePath)""",
		"-c ""$($connectionString)""",
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
	$connectionString = ReadConnectionString $connectionProject.ConfigFilePath $migrationSettings.ConnectionName

	$params = @(
		"-t rollback:toversion", 
		"-version $MigrationNumber",
		"-db $($migrationSettings.DbProvider)",
		#"-configPath ""$($connectionProject.ConfigFilePath)""",
		"-c ""$($connectionString)""",
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