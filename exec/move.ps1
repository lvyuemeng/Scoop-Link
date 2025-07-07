param (
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = "High"
	)]
	[string[]]$appNames,
	[Alias("f")]
	[switch]$Force,
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/config.ps1"
. "$PSScriptRoot/../lib/manifest.ps1"
. "$PSScriptRoot/../lib/parse.ps1"
. "$PSScriptRoot/../context.ps1"

Write-Debug "[move]: appNames: $appNames"

$f = if ($Force -and -not $PSBoundParameters.ContainsKey("Confirm")) {
	$true
}
else {
	$false
}
Write-Debug "[move]: force: $Force"

Write-Debug "[move]: args: $args, count: $($args.Count)"
$opts, $args = opts "--global", "-g", "--path", "-pa" $args
$global = $opts["--global"] -or $opts["-g"]
$path = $opts["--path"] ?? $opts["-pa"]
Write-Debug "[move]: path: $path"
Write-Debug "[move]: global: $global"
Write-Debug "[install]: filter args: $args"

# [weight]: no need to check filtered useless args
# filter args with opts
# Write-Debug "[move]: filtered args: $args, $($args.Count)"
# if ($args.Count -gt 0) {
# 	Write-Error "Unknown arguments: $args" -ErrorAction Stop
# }
# 
if (-Not $appNames) {
	Show-Help -Context "move"
	exit 0
}

function move_app {
	param (
		[CmdletBinding()]
		[string]$appName,
		[string]$path,
		[Alias("f")]
		[switch]$Force,
		[Alias("g")]
		[switch]$global
	)

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
		$manifest = get_manifest $appName
		persist_link $manifest -app_path $new_version -app_persist $app_persist

		# synlink from new version to original version
		New-Item -ItemType SymbolicLink -Path $version.FullName -Target $new_version -Force -Debug:$DebugPreference | Out-Null
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
}

foreach ($appName in $appNames) {
	move_app $appName $path -global:$global -Force:$f
}


