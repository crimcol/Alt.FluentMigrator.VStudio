## Import PowerShell module directly for troubleshooting
```
Import-Module .\DbMigrations\Alt.FluentMigrator.VStudio.psm1 -Force
```



## Install/Uninstall package
```
Uninstall-Package Alt.FluentMigrator.VStudio -verbose
Install-Package Alt.FluentMigrator.VStudio -verbose
```


## Test cases
```
Add-FluentMigration -MigrationName M1 -AddScript
Add-FluentMigration -MigrationName M2
Add-FluentMigration M3
Add-FluentMigration M4 -AddScript

Add-FluentMigration -MigrationName M5 -AddScript  -ProjectName DbMigrations
Add-FluentMigration -MigrationName M6             -ProjectName DbMigrations
Add-FluentMigration M7                            -ProjectName DbMigrations
Add-FluentMigration M8 -AddScript                 -ProjectName DbMigrations

Update-FluentDatabase
Rollback-FluentDatabase 0
```