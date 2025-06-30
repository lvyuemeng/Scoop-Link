param (
	[string]$appName,
	[Alias("p")]
	[string]$path,
	[Alias("f")]
	[switch]$Force,
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/data.ps1"
. "$PSScriptRoot/../lib/manifest.ps1"
. "$PSScriptRoot/../lib/opts.ps1"
. "$PSScriptRoot/../context.ps1"

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

$apps = $Script:scoopSubs["apps"]
$global_apps = $Script:scoopSubs["global"]
$persist = $Script:scoopSubs["persist"]
$app = if ($global) { 
	Join-Path $global_apps $appName 
} 
else {
	Join-Path $apps $appName
}
$app_persist = Join-Path $persist $appName

# check if path is valid
if (-Not (Test-Path $path -PathType Container -IsValid)) {
	Write-Error "Error: Provided path '$path' is not a valid directory path." -ErrorAction Stop
}
# create dir in valid path
$new_app = Join-Path $path $appName
New-Item -Path $new_app -ItemType Directory -Force:$f -ErrorAction Stop -Debug:$DebugPreference | Out-Null

try {
	$version = Get-ChildItem $app -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
	$new_version = Join-Path $new_app $version.Name

	# move whole data of specific version to new version path
	robocopy $version.FullName $new_version /MIR /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC | Out-Null
	if ($LASTEXITCODE -ge 8) {
		Write-Error "Error: Failed to move package from $version.FullName to $new_version." -ErrorAction Stop
	}
	# Create symlink for entries in new version to persist
	$manifest = get_manifest $AppName
	persist_link $manifest -app_path $new_version -app_persist $app_persist

	# synlink from new version to original version
	New-Item -ItemType SymbolicLink -Path $version.FullName -Target $new_version -Force:$f -Debug:$DebugPreference | Out-Null
}
catch {
	& scoop uninstall $appName
	Remove-Item $new_app -Recurse -Force
	Write-Error $_
	Write-Error "Please reinstall the package again by 'scoop-ext install $appName --path $path'."
}


$apps_config = get_apps_config
$apps_config[$appName] = @{
	Path    = $path
	Version = $version.Name
	Updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	Global  = $global
}
set_apps_config $apps_config