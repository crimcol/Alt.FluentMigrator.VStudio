## Import PowerShell module directly for troubleshooting
```
Import-Module ..\..\src\Alt.FluentMigrator.VStudio.psm1 -Force
```



## Install/Uninstall package
```
Find-Package Alt.FluentMigrator.VStudio
Uninstall-Package Alt.FluentMigrator.VStudio -verbose
Install-Package Alt.FluentMigrator.VStudio -verbose
Install-Package Alt.FluentMigrator.VStudio -Source LocalSource -Version 1.3.2 -verbose
```


## Test cases
```
Add-FluentMigration -MigrationName M1 -AddScript
Add-FluentMigration -MigrationName M2
Add-FluentMigration M3
Add-FluentMigration M4 -AddScript
```
For the following commands please update -ProjectName parameter.

```
Add-FluentMigration -MigrationName M5 -AddScript  -ProjectName DbMigrationsNetFramework48
Add-FluentMigration -MigrationName M6             -ProjectName DbMigrationsNetFramework48
Add-FluentMigration M7                            -ProjectName DbMigrationsNetFramework48
Add-FluentMigration M8 -AddScript                 -ProjectName DbMigrationsNetFramework48
```
```
Update-FluentDatabase
Rollback-FluentDatabase 0
```