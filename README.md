# FluentMigrator.VStudio
[FluentMigrator](https://github.com/schambers/fluentmigrator) is a SQL migration framework designed to help version an application's database. This package allows a developer to create a new migration, update or rollback database within Visual Studio's Package Manager console.

### What is FluentMigrator.VStudio?
[FluentMigrator.VStudio](https://github.com/crimcol/FluentMigrator.VStudio) is a set of commands for Package Manager console which makes much easier and faster work with Fluent migrations.

It contains settings file:

* migrations.json

and following commands:

* FluentAddMigration
* FluentUpdateDatabase
* FluentRollbackDatabase

### How to install?
Please install [FluentMigrator](https://github.com/schambers/fluentmigrator) first.

Select Default project in Package Manager console and then install [FluentMigrator.VStudio](https://github.com/crimcol/FluentMigrator.VStudio) by command:

```console
PM > Install-Package FluentMigrator.VStudio
```
It will create **migrations.json** file which contains settings. Please update it.

### How to configurate migrations.json?

Example:

```json
{
  "ConnectionProjectName": "ConsoleApp",
  "ConnectionName": "TestDb",
  "FluentMigrationToolPath": ".\\packages\\FluentMigrator.Console.3.2.1\\net461\\x86\\Migrate.exe",
  "DbProvider": "SqlServer",
  "DbProviderHelpUrl": "https://fluentmigrator.github.io/articles/runners/runner-console.html#--provider---dbtype---dbvalue-required",
  "MigrationFolder": "Migrations",
  "TimeFormat": "yyyyMMddHHmmss"
}
```
* **ConnectionProjectName** - name of the project in your solution which contains Web.config or App.config file with connection string.
* **ConnectionName** - specify connection name what you want to use.
* **FluentMigrationToolPath** - relative path to FluentMigrator tool.
* **DbProvider** - database provider. It is a parameter for FluentMigrator: [--provider, --dbtype, --db=VALUE](https://fluentmigrator.github.io/articles/runners/runner-console.html#--provider---dbtype---dbvalue-required)
* **DbProviderHelpUrl** - url on documentation.
* **MigrationFolder** - folder name in your project where all migrations will be created. it also supports subfolders. 'Migrations' by default.
* **TimeFormat** - time format is a number which will be used for migration number and part of the file name. Time format *"yyMMddHHmm"* also applicable but contains less characters.


### FluentAddMigration
This command generates a new empty migration with migration number based on curent time and specified time format in **migrations.json**.

It will create migration folder if it does not exist.

```console
PM > FluentAddMigration InitialMigration
```

The migration file will look like this:

```csharp
using FluentMigrator;

namespace DbMigrations.Migrations
{
	[Migration(20191207222856)]
	public class InitialMigration : Migration
	{
		public override void Up()
		{
		}

		public override void Down()
		{
		}
	}
}  
```

### FluentUpdateDatabase

This command will apply all recently created migrations.

```console
PM > FluentUpdateDatabase
```

### FluentRollbackDatabase

This command will revert all migrations to specified version (migration number).

```console
PM > FluentRollbackDatabase 20191207220215
```
