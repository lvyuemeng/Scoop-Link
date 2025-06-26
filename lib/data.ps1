. "$PSScriptRoot/../context.ps1"

function get_apps_config {
	param ()
	
	$apps_path = $Script:scoopExtSubs["apps"]
	$apps = Get-Content $apps_path | ConvertFrom-Json -AsHashtable
	$apps = $apps ?? @{}
	return $apps
}

function set_apps_config {
	param(
		[System.Collections.Hashtable]$data
	)
	$apps_path = $Script:scoopExtSubs["apps"]
	$data | ConvertTo-Json -Depth 5 | Set-Content $apps_path
}