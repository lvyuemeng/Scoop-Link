param(
	[Parameter(ValueFromRemainingArguments = $true)]
	$args
)
	
. "$PSScriptRoot/cli.ps1"

Invoke-ScoopExt @args