param (
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = "High"
	)]
	[string[]]$appNames,
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/parse.ps1"
. "$PSScriptRoot/../lib/move.ps1"

Write-Debug "[move]: args: $args, count: $($args.Count)"

$opts, $args = opts "--global", "-g", "-R" $args
$global = $opts["--global"] -or $opts["-g"]
$path = $opts["-R"]
Write-Debug "[move]: appNames: $appNames"
Write-Debug "[move]: path: $path"
Write-Debug "[move]: global: $global"
Write-Debug "[move]: filter args: $args"

if (-Not $appNames) {
	Show-Help -Context "move"
	exit 0
}

foreach ($appName in $appNames) {
	move_app $appName $path -Global:$global
}


