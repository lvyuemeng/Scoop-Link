. "$PSScriptRoot/../context.ps1"
. "$PSScriptRoot/app.ps1"

<#
.SYNOPSIS
	Gets the manifest of an app by `scoop cat`
.PARAMETER appName 
	App's name
#>
function get_manifest {
	param (
		[Parameter(Mandatory = $true)]
		[string]$appName
	)
	& scoop cat $appName | ConvertFrom-Json 
}

<#
.SYNOPSIS
    Converts a Scoop persist definition to source and target form.
	User should verify the validity of input
.PARAMETER persist
    A string or array representing the persist mapping.
#>
function persist_def {
	param (
		[Parameter(Mandatory = $true)]
		$persist
	)
	$src, $tg = if ($persist -is [Array]) {
		$persist[0], ($persist[1] ?? $persist[0])
	}
 else {
		$persist, $persist
	}
	return $src, $tg
}

<#
.SYNOPSIS
	Creates symlinks from `tg_ver` to the `appName` persist
	User should verify the validity of `tg_ver` is a valid version path of `appName`
.PARAMETER appName
	App's name
.PARAMETER path
	The external installation path of `appName`
#>
function persist_link {
	param (
		[Parameter(Mandatory = $true)]
		$appName,
		[string]$path,
		[switch]$global
	)
	
	$cur_ver = cur_version $appName -Global:$global
	$tg_ver = Join-Path $path "$appName\$($cur_ver.Name)"
	
	Write-Debug "[persist_link]: $tg_ver to $cur_ver"

	$manifest = get_manifest $appName
	if (-Not $manifest.persist) {
		Write-Debug "[persist_link]: no persist"
		return $cur_ver
	}

	$src_persist = scoop_appsub $appName -sub "persist" -Exist -Global:$global
	Write-Debug "[persist_link]: src persist: $src_persist"
	$entries = @($manifest.persist)
	$entries | ForEach-Object {
		# TODO: better nomination
		$src_rel, $tg_rel = persist_def $_

		$src_full = Join-Path $tg_ver $src_rel.TrimEnd("/", "\")
		$tg_full = Join-Path $src_persist $tg_rel.TrimEnd("/", "\")
		
		Write-Debug "[persist_link]: $src_full -> $tg_full"
		if (Test-Path $src_full) {
			$src_item = Get-Item -LiteralPath $src_full -Force
			# resolve src whether it is already the target symlink
			if ($src_item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
				$resolved = $src_item.Target

				if ($resolved -eq $tg_full) {
					Write-Debug "[persist_link]: already linked"
					return
				}
			}
			Remove-Item -LiteralPath $src_full -Recurse
		}
		New-Item -ItemType SymbolicLink -Path $src_full -Target $tg_full -Force | Out-Null
	}

	$cur_ver
}