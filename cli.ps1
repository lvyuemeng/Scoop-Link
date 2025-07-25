param (
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/context.ps1"
. "$PSScriptRoot/lib/parse.ps1"

$helpCommands = "-h", "--help", "/?"
$commands = @{
	"move" = "move"
	"mv"   = "move"
	"sync" = "sync"
	"list" = "list"
	"ls"   = "list"
}

$helpContext = @{
	main = @'
Usage: scoop-ext <command> [options/arguments]

Commands:
  move      <[app,]> <-R <move_path>>		- Move installed apps to a new custom path.
  sync      <[app,]>|<*>					- Sync apps moved by 'move' command.
  list      [scoop_args]					- List installed apps with paths.
  
Caveat: 
  - You should install scoop first.
  - You should use `,` to separate apps due to the parse logic of powershell script.
  - You should place `<[app,]>` always at the first argument due to the **partial** parse logic.

Common Options:
  -h, --help, /?    Display help for a command.

Examples:
  scoop-ext move 7zip -R D:\MyPortableApps
  scoop-ext sync 7zip
  scoop-ext list
'@
	move = @"
Usage: scoop-ext move <[app,]> <-R <move_path>>

You can move apps multiple times with different paths.
"@
	sync = @"
Usuage: scoop-ext sync <[app,]>|<*>
"@
	list = @"
Usage: scoop-ext list [scoop_args]
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
	
	# Safety: conanical must be exist
	$handle = "$PSScriptRoot/exec/$normal.ps1"
	Write-Debug "$handle $($args -join ' ')"
	flatten_exec $handle @args
}

Invoke-Entry @args