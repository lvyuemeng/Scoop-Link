param(
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = "High"
	)]
	[string[]]$appNames,
	[Alias("f")]
	[switch]$Force,
	# scoop args
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/parse.ps1"

Write-Debug "[install]: appNames: $appNames"

$f = if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {
	$true
}
else {
	$false
}
Write-Debug "[install]: force: $Force"

Write-Debug "[move]: args: $args, count: $($args.Count)"
$opts, $args = opts "--global", "-g", "--path", "-pa" $args
$global = $opts["--global"] -or $opts["-g"]
$path = $opts["--path"] ?? $opts["-pa"]
Write-Debug "[install]: path: $path"
Write-Debug "[install]: global: $global"
Write-Debug "[install]: filter args: $args"

if (-Not $appNames) {
	Show-Help -Context "install"
	exit 0
}

& scoop install @appNames @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# if path is not provided, install to default path
if ([string]::IsNullOrEmpty($path)) {
	return
}

$move = "$PSScriptRoot/move.ps1"
$global_flag = if ($global) { "--global" } else { "" }
$force_flag = if ($f) { "-f" } else { "" }
flatten_exec $move $appNames --path $path $force_flag $global_flag