param(
	[string[]]$appNames,
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/config.ps1"
. "$PSScriptRoot/../lib/manifest.ps1"
. "$PSScriptRoot/../context.ps1"

Write-Debug "[list]: appNames: $appNames"
Write-Debug "[list]: args: $args"

$infos = & scoop list $appNames @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apps_config = get_apps_config

$infos = $infos | Select-Object -Property *, @{
	Name = "Path"
	Expression = {
		$path = $apps_config[$_.Name].Path
		$path
	}
}

$infos | Format-Table