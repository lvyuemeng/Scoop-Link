function get_manifest {
	param (
		[string]$app
	)
	$manifest = & scoop cat $app | ConvertFrom-Json
	return $manifest
}

function persist_def {
	param (
		$persist
	)
	if ($persist -is [Array]) {
		$source = $persist[0]
		$target = $persist[1]
	}
 else {
		$source = $persist
		$target = $null
	}
	if (-Not $target) { $target = $source }
	return $source, $target
}

# symlink every app data into persist data
function persist_link {
	param (
		$manifest,
		[string]$app_path,
		[string]$app_persist
	)

	if (-Not $manifest.persist) {
		return
	}
	
	$persist_entries = if ($manifest.persist -is [string]) { @($manifest.persist) } else { $manifest.persist }
	
	$persist_entries | ForEach-Object {
		$src_rel, $target_rel = persist_def $_
		$src_full = Join-Path $app_path $src_rel.TrimEnd("/","\")
		$target_full = Join-Path $app_persist $target_rel.TrimEnd("/","\")
		
		Write-Debug "[symlink]: $src_full -> $target_full"
		if (Test-Path $src_full) {
			Remove-Item -LiteralPath $src_full -Recurse
		}
		New-Item -ItemType SymbolicLink -Path $src_full -Target $target_full -Force | Out-Null
	}
}