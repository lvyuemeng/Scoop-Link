param (
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/context.ps1"
. "$PSScriptRoot/lib/parse.ps1"

$helpCommands = "-h", "--help", "/?"
$commands = @{
	"install"   = "install"
	"add"       = "install"
	"uninstall" = "uninstall"
	"remove"    = "uninstall"
	"rm"        = "uninstall"
	"move"		= "move"
	"mv" 		= "move"
	"list"      = "list"
	"ls"        = "list"
}

$helpContext = @{
    main = @'
Usage: scoop-ext <command> [options/arguments]
Commands:
  install   <app_id> [--path <install_path>] [scoop_args]   - Install an application to a custom path.
  uninstall <app_id>                                        - Uninstall an application.
  move      <app_id> [--path <move_path]                    - Move an installed application to a new custom path.
  list                                                      - List scoop-ext managed applications.
Common Options:
  -h, --help, /? Display help for a command.
Examples:
  scoop-ext install 7zip --path D:\MyPortableApps\7Zip
  scoop-ext uninstall 7zip
  scoop-ext list
'@
    install = "Usage: scoop-ext install <app_id> [--path <install_path>] [scoop_args]"
    uninstall = "Usage: scoop-ext uninstall <app_id> [scoop_args]"
	move = "Usuage: scoop-ext move <app_id> [--path <move_path>] [--global/-g]"
}

function Show-Help {
	param (
		[string]$Context = "main"
	)
	$help = $helpContext[$Context]
	if (-Not $help) {
		Write-Error "No help found for '$Context'."
		Write-Host $helpContext["main"]
	}
	Write-Host $help
}

# entry
function Invoke-Entry {
	param (
		[string]$command,
		[Parameter(ValueFromRemainingArguments = $true)]
		$args
	)
	Write-Debug "[entry]: command: $command"
	Write-Debug "[entry]: args: $args"
	
	if (-Not $command -or $command -in $helpCommands) {
		Show-Help
		return
	}

	$canonical = $commands[$command.ToLower()]
	Write-Debug "[entry]: canonical: $canonical"
	if (-Not $canonical) {
		Write-Error "Unknown command: '$command'."
		Show-Help
		return
	}

	if ($args.Count -eq 0 -or ($args | Where-Object { $_ -in $helpCommands })) {
		Show-Help -Context $canonical
		return
	}
	
	# conanical is exist
	$handle = "$PSScriptRoot/exec/$canonical.ps1"
	Write-Debug "$handle $($args -join ' ')"
	flatten_exec $handle @args
}

Invoke-Entry @args