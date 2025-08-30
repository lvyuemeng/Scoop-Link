. "$PSScriptRoot/../context.ps1"

function scoop_appsub {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string]$pkg,
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
				Join-Path $base $pkg
			}
			"persist" {
				Join-Path $Script:scoopSubs["persist"] $pkg
			}
		}
		if ($exist -And (-Not (Test-Path $dir))) {
			Write-Error "[scoop_appsub]: $sub : $dir does not exist" -ErrorAction Stop
		}
		$dir
	}
}

function resolve_dir {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[System.IO.DirectoryInfo]$ver
	)

	$tg = if ($ver.Attributes -band [IO.FileAttributes]::ReparsePoint) {
		# If the version is already a symlink
		# 	retrieve the target path (first layer)
		# Safety: target path must be a full path
		$ver.Target
	} else {
		$ver.FullName
	}

	$tg
}

function may_installed_vers {
	[CmdletBinding()]
	[OutputType([System.IO.DirectoryInfo])]
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string]$pkg,
		[switch]$global
	)

	process {
		$pkg_dir = scoop_appsub $pkg -sub "app" -Global:$global
		if (-Not (Test-Path $pkg_dir)) {
			return @()
		}
		$src_vers = Get-ChildItem $pkg_dir -Directory | Where-Object { $_.Name -ne "current" }
		return $src_vers
	}
}

function may_cur_ver {
	[CmdletBinding()]
	[OutputType([System.IO.DirectoryInfo])]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string]$pkg,
		[switch]$global
	)
	
	process {
		$pkg_dir = scoop_appsub $pkg -sub "app" -Global:$global
		$cur = Join-Path $pkg_dir "current"

		if (-Not (Test-Path $cur)) {
			$cur = may_installed_vers $pkg -Global:$global | Sort-Object LastWriteTime -Descending | Select-Object -First 1
			return $cur
		}

		# Safety: the current dir is a symlink to the `apps/<app>/<version>` dir
		Get-Item ((Get-Item $cur).Target)
	}
}