param(
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = "High"
	)]
	[string[]]$appNames,
	[Alias("p")]
	[string]$path,
	[Alias("f")]
	[switch]$Force,
	# scoop args
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/parse.ps1"

Write-Debug "[install]: appNames: $appNames"
Write-Debug "[install]: path: $path"

$f = if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {
	$true
}
else {
	$false
}
Write-Debug "[install]: force: $Force"

Write-Debug "[install]: args: $args"
$opts, $args = opts "--global", "-g" @args
$global = $opts["--global"] -or $opts["-g"]
Write-Debug "[install]: global: $global"
Write-Debug "[install]: args: $args"

& scoop install @appNames @args
if ($LASTEXITCODE -ne 0) { 
	exit $LASTEXITCODE
}

# if path is not provided, install to default path
if ([string]::IsNullOrEmpty($path)) {
	return
}

$move = "$PSScriptRoot/move.ps1"
$global_flag = if ($global) { "--global" } else { "" }
$force_flag = if ($f) { "-f" } else { "" }
flatten_exec $move $appNames -Path $path $force_flag $global_flag