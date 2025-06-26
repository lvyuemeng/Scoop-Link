. "$PSScriptRoot/context.ps1"

$helpCommands = "-h", "--help", "/?"
$commands = "install", "uninstall"

$mainHelp = @'
Usage: scoop-ext <command> [options/arguments]

Commands:
  install   <app_id> [--path <install_path>] [scoop_args]   - Install an application to a custom path.
  uninstall <app_id>                                        - Uninstall an application.
  move      <app_id> --to <new_path>                        - Move an installed application to a new custom path.
  list                                                      - List scoop-ext managed applications.
  info      <app_id>                                        - Show details about a scoop-ext managed application.

Common Options:
  -h, --help, /? Display help for a command.

Examples:
  scoop-ext install 7zip --path D:\MyPortableApps\7Zip
  scoop-ext uninstall 7zip
  scoop-ext list
'@

$installHelp = @'
Usage: scoop-ext install <app_id> [--path <install_path>] [scoop_args]
'@

$uninstallHelp = @'
Usage: scoop-ext uninstall <app_id> 
'@

function Show-Help {
	param (
		[string]$Context = "main"
	)
	
	switch ($Context.ToLower()) {
		"main" {
			Write-Host $mainHelp
		}
		"install" {
			Write-Host $installHelp
		}
		default {
			Write-Host "No help found for '$Context'."
			Write-Host $mainHelp
		}
	}
}

function Get-Handler {
	param (
		[string]$command
	)
	$path = "$PSScriptRoot/exec/$command.ps1"
	if (-Not (Test-Path $path)) {
		Write-Error "Unknown command: '$command'. Use 'scoop-ext help' for help." -ErrorAction Stop
	}
	return $path
}

# entry
function Invoke-ScoopExt {
	param (
		[string]$command,
		[Parameter(ValueFromRemainingArguments = $true)]
		$args
	)
	$command = $command.ToLower()
	if ((-Not $command) -or $command -in $helpCommands) {
		Show-Help
		return
	}

	if (($args | Where-Object { $_ -in $helpCommands }) -or $args.Count -eq 0) {
		Show-Help -Context $command
		return
	}

	Write-Debug "[entry]: command: $command"
	Write-Debug "[entry]: args: $args"

	$handle = Get-Handler $command
	Invoke-Expression "$handle $($args -join ' ')"
}
