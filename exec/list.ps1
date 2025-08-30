param(
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/config.ps1"
. "$PSScriptRoot/../lib/manifest.ps1"
. "$PSScriptRoot/../context.ps1"

Write-Debug "[list]: args: $args, count: $($args.Count)"

$infos = & scoop list @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$apps_config = get_inventory

$infos = $infos | Select-Object -Property *, @{
	Name       = "Path"
	Expression = {
		$path = if ($_.Info -like "Global") {
			$apps_config["global"][$_.Name].Path
		}
		else {
			$apps_config["local"][$_.Name].Path
		}
		$path = $apps_config[$_.Name].Path
		$path
	}
}

$infos | Format-Table