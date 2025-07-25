param(
	[string[]]$appNames,
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/config.ps1"
. "$PSScriptRoot/../lib/manifest.ps1"

Write-Debug "[uninstall]: args: $args, count: $($args.Count)"

$opts, $args = opts "--global", "-g", $args
$global = $opts["--global"] -or $opts["-g"]
$global_flag = if ($global) { "--global" } else { "" }
Write-Debug "[uninstall]: appNames: $appNames"
Write-Debug "[uninstall]: global: $global"

if (-Not $appNames) {
	Show-Help -Context "uninstall"
	exit 0
}

& scoop uninstall $appNames @args $global_flag

with_inventory -Global:$global {
	param($cfg)
	foreach ($appName in $appNames) {
		if (-Not $cfg.ContainsKey($appName)) {
			continue
		}
		$app = Join-Path $cfg[$appName].Path $appName
		Remove-Item $app -Recurse -Force
		Write-Debug "[uninstall]: app path: $app"
		$cfg.Remove($appName)
	}
	return $cfg
}

# uninstall will be executed no matter `LASTEXITCODE`
exit $LASTEXITCODE
