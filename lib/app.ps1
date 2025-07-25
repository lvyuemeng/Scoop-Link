. "$PSScriptRoot/../context.ps1"

function scoop_appsub {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string]$appName,
		[Parameter(Mandatory = $true)]
		[ValidateSet("app", "persist")]
		[string]$sub,
		[switch]$global,
		[switch]$exist
	)
	
	process {
		$dir = switch ($sub) {
			"app" {
				$base = if ($global) {
					$Script:scoopSubs["global"]
				}
				else {
					$Script:scoopSubs["apps"]
				}
				Join-Path $base $appName
			}
			"persist" {
				Join-Path $Script:scoopSubs["persist"] $appName
			}
		}
		if ($exist -And (-Not (Test-Path $dir))) {
			Write-Error "[scoop_appsub]: $sub : $dir does not exist" -ErrorAction Stop
		}
		$dir
	}
}

function resolve_ver_path {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[System.IO.DirectoryInfo]$ver
	)

	$tg = if ($ver.Attributes -band [IO.FileAttributes]::ReparsePoint) {
		# If the version is already a symlink
		# 	retrieve the target path (first layer)
		# Safety: target path must be a rooted path
		$ver.Target
	} else {
		$ver.FullName
	}

	return $tg
}

function installed_versions {
	[CmdletBinding()]
	[OutputType([System.IO.DirectoryInfo])]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string]$appName,
		[switch]$global
	)

	process {
		$app = scoop_appsub $appName -sub "app" -Global:$global
		if (-Not (Test-Path $app)) {
			return @()
		}
		$src_vers = Get-ChildItem $app -Directory | Where-Object { $_.Name -ne "current" }
		return $src_vers
	}
}

function cur_version {
	[CmdletBinding()]
	[OutputType([System.IO.DirectoryInfo])]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string]$appName,
		[switch]$global
	)
	
	process {
		$app = scoop_appsub $appName -sub "app" -Global:$global
		$cur = Join-Path $app "current"

		if (-Not (Test-Path $cur)) {
			$cur = installed_versions $appName -Global:$global | Sort-Object LastWriteTime -Descending | Select-Object -First 1
			return $cur
		}

		# Safety: the current dir is a symlink to the `apps/<app>/<version>` dir
		Get-Item ((Get-Item $cur).Target)
	}
}