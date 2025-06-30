function opts{
	param(
		[string[]]$flags,
		[Parameter(ValueFromRemainingArguments = $true)]
		$args
	)
	
	$res = @{}
	foreach ($flag in $flags) {
		if ($args -contains $flag) {
			$res["$flag"] = $true
		}
	}
	$res
}