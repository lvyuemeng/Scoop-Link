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
  install   <app_id> [--path <install_path>] [scoop_args] - Install an application to a custom path.
  uninstall <app_id>                                      - Uninstall an application.
  move      <app_id> [--path <move_path>]                 - Move an installed application to a new custom path.
  list                                                    - List installed apps with paths.

Common Options:
  -h, --help, /?    Display help for a command.

Examples:
  scoop-ext install 7zip --path D:\MyPortableApps\7Zip
  scoop-ext uninstall 7zip
  scoop-ext list
'@
    install = @'
Usage: scoop-ext install <app_id> [--path/-pa <install_path>] [--force/-f] [scoop_args]

To install an app with path:
	scoop-ext install 7zip, ripgrep --path D:\MyPortableApps

Caveat: 
	There's no need to add app names on your installation path, scoop-ext will create automactically.
	It's necessary to use ',' to separate multiple app names.

Options:
--path/-pa <install_path>   Install app to a custom path.
'@
    uninstall = @"
Usage: scoop-ext uninstall <app_id> [scoop_args]

To uninstall an app:
	scoop-ext uninstall 7zip

Options:
--path/-pa <install_path>   Install app to a custom path.
"@
	move = @"
Usage: scoop-ext move <app_id> [--path/-pa <move_path>]
"@
	list = @"
Usage: scoop-ext list <app_id>
"@
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

	$normal = $commands[$command.ToLower()]
	Write-Debug "[entry]: normal: $canonical"
	if (-Not $normal) {
		# fallback to scoop
		& scoop $command @args
		return
	}

	if ($args | Where-Object { $_ -in $helpCommands }) {
		Show-Help -Context $normal
		return
	}
	
	# conanical is exist
	$handle = "$PSScriptRoot/exec/$normal.ps1"
	Write-Debug "$handle $($args -join ' ')"
	flatten_exec $handle @args
}

Invoke-Entry @args