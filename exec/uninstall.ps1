param(
	[string]$appName,
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/data.ps1"
. "$PSScriptRoot/../lib/manifest.ps1"

Write-Debug "[install]: appName: $appName"

& scoop uninstall $appName @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apps_config = get_apps_config 
# the app is installed independently by scoop
if (-Not $apps_config.ContainsKey($appName)) 
{ 
	return
}

$app = Join-Path $apps_config[$appName].Path $appName
$versions = Get-ChildItem $app -Directory | ForEach-Object { $_.FullName }

foreach ($version in $versions) {
	Remove-Item $version -Recurse -Force
}

Remove-Item $app -Force

$apps_config.Remove($appName)
set_apps_config $apps_config