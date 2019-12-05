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
	$p = If (!$projectName) { Get-Project } Else { Get-Project $projectName }

	$fullPath = $p.Properties.Item("FullPath").Value
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
		param (
			[parameter(Position = 0,
				Mandatory = $true)]
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

function GetConfigFilePath($projProps)
{
	return $projProps.OutputFileFullPath + ".config"
}

Export-ModuleMember @('FluentUpdateDatabase')
Export-ModuleMember @('FluentRollbackDatabase')