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
	[OutputType([string[]], [System.Collections.Hashtable])]
	param(
		[string[]]$flags,
		[Parameter(ValueFromRemainingArguments = $true)]
		$args
	)
	
	if (-not $args -or $args.Count -eq 0) {
		return @{}, @()
	}
    
	$pkgs = @()
	$flags_in = @{}
	$i = 0
    
	while ($i -lt $args.Count) {
		$cur = $args[$i]
        
		# flag
		if ($cur.StartsWith('-')) {
			$values = @()
			$i++
			# absorb flag values
			while ($i -lt $args.Count -and -not $args[$i].StartsWith('-')) {
				$values += $args[$i]
				$i++
			}
			switch ($values.Count) {
				0 { $flags_in[$cur] = $true }
				1 { $flags_in[$cur] = $values[0] }
				Default { $flags_in[$cur] = $values }
			}
		}
		# pkg
		else {
			$pkgs += $cur
			$i++
		}
	}
    
	$pkgs, $flags_in
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