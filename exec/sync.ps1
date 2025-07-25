param(
    [string[]]$appNames,
    [Parameter(ValueFromRemainingArguments = $true)]
    $args
)

. "$PSScriptRoot/../lib/parse.ps1"
. "$PSScriptRoot/../lib/config.ps1"
. "$PSScriptRoot/../lib/move.ps1"

Write-Debug "[sync]: args: $args, count: $($args.Count)"

$opts, $args = opts "--global", "-g", $args
$global = $opts["--global"] -or $opts["-g"]
Write-Debug "[sync]: appNames: $appNames"
Write-Debug "[sync]: global: $global"

$cfg = get_inventory
$cfg = if ($global) { $cfg["global"] } else { $cfg["local"] }

$sync_apps = if (-Not $appNames) { 
    $cfg.Keys 
}
else { 
    $appNames | Where-Object { $cfg.ContainsKey($_) }
}
foreach ($appName in $sync_apps) {
    $path = $cfg[$appName].Path
    Write-Debug "[sync]: app: $appName; path: $path"
    move_app $appName $path -Global:$global
}