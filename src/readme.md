# Alt.FluentMigrator.VStudio
### What is Alt.FluentMigrator.VStudio?
[Alt.FluentMigrator.VStudio](https://github.com/crimcol/Alt.FluentMigrator.VStudio) is a set of commands for Package Manager console which makes much easier and faster work with Fluent migrations.

Please create **migrations.json** file in your migration project with following settings.

Example:

```json
{
  "ConnectionProjectName": "ConsoleApp",
  "ConnectionName": "TestDb",
  "FluentMigrationToolPath": ".\\packages\\FluentMigrator.Console.3.2.7\\tools\\net461\\x86\\Migrate.exe",
  "DbProvider": "SqlServer",
  "DbProviderHelpUrl": "https://fluentmigrator.github.io/articles/runners/runner-console.html#--provider---dbtype---dbvalue-required",
  "MigrationFolder": "Migrations",
  "ScriptsFolder":  "Scripts",
  "TimeFormat": "yyyyMMddHHmmss"
}
```

Find more details on [GitHub](https://github.com/crimcol/Alt.FluentMigrator.VStudio#how-to-configurate-migrationsjson).