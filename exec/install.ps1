param(
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = "High"
	)]
	[string]$appName,
	[Alias("p")]
	[string]$path,
	[Alias("f")]
	[switch]$Force,
	# scoop args
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/opts.ps1"

Write-Debug "[install]: appName: $appName"
Write-Debug "[install]: path: $path"

$f = if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {
	$true
}
else {
	$false
}
Write-Debug "[install]: force: $Force"

$opts = opts "--global", "-g" @args
$global = $opts["--global"] -or $opts["-g"]
Write-Debug "[install]: global: $global"

& scoop install $appName @args
if ($LASTEXITCODE -ne 0) { 
	exit $LASTEXITCODE
}

# if path is not provided, install to default path
if ([string]::IsNullOrEmpty($path)) {
	return
}

$move = "$PSScriptRoot/move.ps1"
$global_flag = if ($global) { "--global" }
Invoke-Expression "$move $appName $path $f $global_flag"