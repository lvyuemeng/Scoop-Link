param(
	[string]$appName,
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)

. "$PSScriptRoot/../lib/data.ps1"
. "$PSScriptRoot/../lib/manifest.ps1"
