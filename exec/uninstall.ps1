param(
	[string[]]$appNames,
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/config.ps1"
. "$PSScriptRoot/../lib/manifest.ps1"

Write-Debug "[uninstall]: appNames: $appNames"

if (-Not $appNames) {
	Show-Help -Context "uninstall"
	exit 0
}

& scoop uninstall $appNames $args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apps_config = get_apps_config 

foreach ($appName in $appNames) {
	# the app is installed independently by scoop
	if (-Not $apps_config.ContainsKey($appNames)) 
	{ 
		continue
	}
	$app = Join-Path $apps_config[$appNames].Path $appNames
	$versions = Get-ChildItem $app -Directory | ForEach-Object { $_.FullName }
	Write-Debug "[uninstall]: versions: $versions"

	foreach ($version in $versions) {
		Remove-Item $version -Recurse -Force
	}

	Remove-Item $app -Force
	Write-Debug "[uninstall]: app path: $app"

	$apps_config.Remove($appNames)
	set_apps_config $apps_config
}
