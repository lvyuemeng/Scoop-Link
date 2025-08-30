param (
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = "High"
	)]
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/parse.ps1"
. "$PSScriptRoot/../lib/move.ps1"

Write-Debug "[move]: args: $args, count: $($args.Count)"

$pkgs, $opts = opts "--global", "-g" $args
$global = $opts["--global"] -or $opts["-g"]
Write-Debug "[move]: appNames: $pkgs"
Write-Debug "[move]: global: $global"

if ($pkgs.Count -eq 0) {
	Show-Help -Context "back"
	exit 0
}

foreach ($pkg in $pkgs) {
	back_pkg $pkg -global:$global
}


