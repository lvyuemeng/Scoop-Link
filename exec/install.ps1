param(
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = "High"
	)]
	[string]$appName,
	[string]$path,
	[Alias("f")]
	[switch]$Force,
	# scoop args
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/data.ps1"
. "$PSScriptRoot/../lib/manifest.ps1"

$f = if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {
	$true
}
else {
	$false
}

Write-Debug "[install]: appName: $appName"
Write-Debug "[install]: path: $path"
Write-Debug "[install]: force: $Force"

$apps = $scoopSubs["apps"]
$persist = $scoopSubs["persist"]
$app = Join-Path $apps $appName
$app_persist = Join-Path $persist $appName

$new_app = Join-Path $path $appName

# if path is not provided, install to default path
if ([string]::IsNullOrEmpty($path)) {
	& scoop install $appName @args
	return
}

# check if path is valid
if (-Not (Test-Path $path -PathType Container -IsValid)) {
	Write-Error "Error: Provided path '$path' is not a valid directory path." -ErrorAction Stop
}
# create dir in valid path
New-Item -Path $new_app -ItemType Directory -Force:$f -ErrorAction Stop -Debug:$DebugPreference | Out-Null

& scoop install $appName @args

$version = Get-ChildItem $app -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-Not $version) {
	Write-Error "Installation failed, can not resolve version for $appName" -ErrorAction Stop
	exit 1
}

$new_version = Join-Path $new_app $version.Name

# move whole data of specific version to new version path
robocopy $version.FullName $new_version /MIR /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC | Out-Null
# Remove-Item $version.FullName -Recurse -Force 

# Create symlink for entries in new version to persist
$manifest = get_manifest $AppName
persist_link $manifest -app_path $new_version -app_persist $app_persist

# synlink from new version to original version
New-Item -ItemType SymbolicLink -Path $version.FullName -Target $new_version -Force:$f -Debug:$DebugPreference | Out-Null

$apps_data = get_apps_config
$apps_data[$AppName] = @{
	Path    = $path
	Version = $version.Name
	Updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
set_apps_config $apps_data