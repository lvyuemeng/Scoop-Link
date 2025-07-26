<#
.SYNOPSIS
	Parse command options greedily
	It will return a dict of flags and the residual of unknown args
.PARAMETER flags
	A list of flags start with '-'
.PARAMETER args
	A list of args
#>
function opts {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable], [string[]])]
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
		$cur = $args[$i]
        
		# flag
		if ($cur.StartsWith('-') -and $cur -in $flags) {
			$values = @()
			$i++
            
			# absorb flag values
			while ($i -lt $args.Count -and -not $args[$i].StartsWith('-')) {
				$values += $args[$i]
				$i++
			}
			
			switch ($values.Count) {
				0 { $res[$cur] = $true }
				1 { $res[$cur] = $values[0] }
				Default { $res[$cur] = $values }
			}
		}
		# unknown flag or arg
		else {
			$filter_args += $cur
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