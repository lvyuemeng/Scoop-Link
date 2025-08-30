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
		[string]$pkg
	)
	& scoop cat $pkg | ConvertFrom-Json 
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
function may_persist_link {
	param (
		[Parameter(Mandatory = $true)]
		$pkg,
		[switch]$global
	)
	
	$cur_ver = may_cur_ver $pkg -Global:$global
	if (-Not $cur_ver) {
		return $null
	}
	
	$installed_ver = resolve_dir $cur_ver
	Write-Debug "[may_persist_link]: resolved version: $installed_ver"

	$manifest = get_manifest $pkg
	if (-Not $manifest.persist) {
		Write-Debug "[may_persist_link]: no persist"
		return $cur_ver
	}

	$persist = scoop_appsub $pkg -sub "persist" -Exist -Global:$global
	Write-Debug "[may_persist_link]: persist: $persist"
	$entries = @($manifest.persist)
	$entries | ForEach-Object {
		# TODO: better nomination
		$src_rel, $tg_rel = persist_def $_

		$src_full = Join-Path $installed_ver $src_rel.TrimEnd("/", "\")
		$tg_full = Join-Path $persist $tg_rel.TrimEnd("/", "\")
		
		Write-Debug "[may_persist_link]: $src_full -> $tg_full"
		if (Test-Path $src_full) {
			$src_item = Get-Item -LiteralPath $src_full -Force
			$resolved = resolve_dir $src_item
			if ($resolved -eq $tg_full) {
				Write-Debug "[may_persist_link]: already linked"
				continue
			}
			Remove-Item -LiteralPath $src_full -Recurse
		}
		New-Item -ItemType SymbolicLink -Path $src_full -Target $tg_full -Force | Out-Null
	}

	$cur_ver
}