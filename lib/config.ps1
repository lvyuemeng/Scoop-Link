. "$PSScriptRoot/../context.ps1"

function get_inventory {
	param ()
	
	$apps_path = $Script:scoopExtSubs["apps"]
	$apps = Get-Content $apps_path | ConvertFrom-Json -AsHashtable
	if (-Not $apps) {
		$apps = @{}
	}
	# ensure the `scope` field
	foreach ($scope in @("global", "local")) {
		if (-Not $apps.ContainsKey($scope)) {
			$apps[$scope] = @{}
		}
	}
	return $apps
}

function set_inventory {
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[System.Collections.Hashtable]$data
	)
	$apps_path = $Script:scoopExtSubs["apps"]
	$data | ConvertTo-Json -Depth 5 | Set-Content $apps_path
}

<#
.SYNOPSIS
	Execute a block with apps config provided
	Modify the apps config by value/reference
.PARAMETER block
	The block to execute
.PARAMETER ref
	Whether to pass the apps config by reference
#>
function with_inventory {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[scriptblock]$block,
		[switch]$global,
		[switch]$ref
	)
	
	$config = get_inventory
	$scope = if ($global) { "global" } else { "local" }
	$app_section = $config[$scope]
	
	if ($ref) {
		$appsRef = [ref]$app_section
		& $block $appsRef
		# `$appsRef` is modified in place
		$config[$scope] = $appsRef.Value
		set_inventory $config
	}
	else {
		$res = & $block $app_section
		if ($res -is [hashtable]) {
			$config[$scope] = $res
			set_inventory $config
		}
	}
}

function update_app_inventory {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true, Position=0)]
		[string]$appName,
		[Parameter(Mandatory=$true)]
		[string]$path,
		[Parameter(Mandatory=$true)]
		[string]$ver,
		[switch]$global
	)

	with_inventory -Global:$global {
		param($cfg)
		if ($cfg.ContainsKey($appName)) {
			$old_path = $cfg[$appName].Path
			$tg_app = Join-Path $path $appName
			$old_tg_app = Join-Path $old_path $appName
			Write-Debug "[update_app_inventory]: $appName : $old_path -> $path"
			# remove old app dir
			if ($old_tg_app -ne $tg_app) {
				# Assume the old path is safely moved into new path
				Remove-Item $old_tg_app -Recurse -Force
			}
		}
		$entry = @{
			Path = $path
			Version = $ver
			Updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		}
		$cfg[$appName] = $entry
		return $cfg
	}
}

function remove_pkg_inventory {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$appName,
		[switch]$global
	)
	with_inventory -Global:$global -Ref {
		param([ref]$cfg)
		if (-Not $cfg.Value.ContainsKey($appName)) {
			return
		}
		$app = Join-Path $cfg.Value[$appName].Path $appName
		if (Test-Path $app) {
			Write-Debug "[remove_pkg_inventory]: remove $app"
			Remove-Item $app -Recurse -Force
		}
		$cfg.Value.Remove($appName)
	}
}