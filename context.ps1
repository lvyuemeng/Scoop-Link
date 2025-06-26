function Get-Scoop {
	param ()
	
	$scoop = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE "scoop" }
	if (-Not (Test-Path $scoop)) {
		Write-Error "Scoop is not found at $scoop" -ErrorAction Stop
	}
	return $scoop
}

function Get-ScoopSubs {
	param ()
	
	$scoop = Get-Scoop
	$scoop_subs = @{
		"apps" = Join-Path $scoop "apps";
		"buckets" = Join-Path $scoop "buckets";
		"persist" = Join-Path $scoop "persist";
		"shims" = Join-Path $scoop "shims";
	}
	
	return $scoop_subs
}

function Get-ScoopExtSubs {
	param(
		# root path should be "...\<cli root>\"
		[Parameter(Mandatory=$true)]
		[string]$root
	)
	
	$scoop_ext_subs = @{
		"apps" = Join-Path $root "apps.json";
	}
	foreach ($val in $scoop_ext_subs.Values) {
		if (-Not (Test-Path $val)) {
			New-Item -Path $val -ItemType File -ErrorAction Stop
		}
	}
	return $scoop_ext_subs
}

$Script:scoopSubs = Get-ScoopSubs
$Script:scoopExtSubs = Get-ScoopExtSubs $PSScriptRoot