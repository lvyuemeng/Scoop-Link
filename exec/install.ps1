param(
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = "High"
	)]
	[string[]]$appNames,
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/parse.ps1"

Write-Debug "[install]: args: $args, count: $($args.Count)"
$opts, $args = opts "--global", "-g", "-R" $args
$global = $opts["--global"] -or $opts["-g"]
$global_flag = if ($global) { "--global" } else { "" }
$path = $opts["-R"]

Write-Debug "[install]: appNames: $appNames"
Write-Debug "[install]: path: $path"
Write-Debug "[install]: global: $global"
Write-Debug "[install]: filter args: $args"

if (-Not $appNames) {
	Show-Help -Context "install"
	exit 0
}

& scoop install $appNames @args $global_flag
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# if path is not provided, install to default path
if ([string]::IsNullOrEmpty($path)) {
	return
}

$move = "$PSScriptRoot/move.ps1"
flatten_exec $move $appNames -R $path $global_flag