function opts {
	param(
		[string[]]$flags,
		[Parameter(ValueFromRemainingArguments = $true)]
		$args
	)
	
	if (-Not $args -or $args.Count -eq 0) {
		return @{}, @()
	}
    
	$res = @{}
	$filter_args = @()
	$i = 0
    
	while ($i -lt $args.Count) {
		$current = $args[$i]
        
		# flag
		if ($current.StartsWith('-') -and $current -in $flags) {
			$values = @()
			$i++
            
			# absorb flag values
			while ($i -lt $args.Count -and -not $args[$i].StartsWith('-')) {
				$values += $args[$i]
				$i++
			}
            
			if ($values.Count -eq 0) {
				$res[$current] = $true
			}
			elseif ($values.Count -eq 1) {
				$res[$current] = $values[0]
			}
			else {
				$res[$current] = $values
			}
			# unknown flag or arg
		}
		else {
			$filter_args += $current
			$i++
		}
	}
    
	$res, $filter_args
}

# avoid object[] fuzzy problem in @args splatting
# flatten args and invoke expression to execute
function flatten_exec {
	param(
		[string]$command,
		[Parameter(ValueFromRemainingArguments = $true)]
		$args
	)
			
	$format = foreach ($arg in $args) {
		if (-Not $arg) {
			""
		}
		elseif ($arg -is [array] -or ($arg -is [System.Collections.IEnumerable] -and $arg -isnot [string])) {
			$arg -join ", "
		}
		else {
			$arg.ToString()
		}
	}
	Invoke-Expression "$command $format"
}