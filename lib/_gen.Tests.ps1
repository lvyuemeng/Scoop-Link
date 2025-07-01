BeforeAll {
	Get-ChildItem $PSScriptRoot | Where-Object { $_.Name -like "*.ps1" } | ForEach-Object { . $_.FullName }
}
 
Describe "Manifest" {
	It "get-manifest" -Tag "rage" {
		$json = Get-Manifest "rage"
		$json | Should -Not -BeNullOrEmpty
		Write-Host $json
		$bin = $json.bin
		Write-Host $bin
	}
}

Describe "Route" {
	It "get-scoop" -Tag "scoop" {
		$scoop = Get-Scoop
		$scoop | Should -Not -BeNullOrEmpty

		$scoop_all = Get-ScoopAll
		$scoop_all | Should -Not -BeNullOrEmpty
		Write-Host $scoop_all
	}
	It "get-scoop-ext" -Tag "scoop-ext" {
		$scoop_ext = Get-ScoopExtAll $PSScriptRoot
		$scoop_ext | Should -Not -BeNullOrEmpty
		Write-Host $scoop_ext
	}
}

Describe "Parse" {
	It "double-hypen" -Tag "hypen" {
		function two_hypens {
			param (
				[ValidateSet("--force", "-f")]
				$DashForce
			)
			if ($DashForce) {
				Write-Host "[two_hypens]: raw literal input success"
			}
		}

		# -f parsed as flag
		two_hypens --force
		two_hypens -f
	}
	
	It "opts something" -Tag "opts1" {
		$opts, $args = opts "--force", "-f" "--force","isforce", "-someflag", "someval"
		$opts["--force"] | Should -BeTrue
		$opts["-f"] | Should -BeFalse
		Write-Host $args
		$opts_2, $args = opts "-something" $args
		Write-Host $args.Count
	}
	
	It "opts nothing" -Tag "opts2" {
		$args = @()
		$opts, $args = opts "--force", "-f" @args
		Write-Host "$($args.Count)"
	}
	
	It "list collision" -Tag "list" {
		function parse_list {
			param (
				[string[]]$appNames,
				[switch]$Force,
				[Parameter(ValueFromRemainingArguments = $true)]
				$args
			)
			Write-Host "appNames: $appNames"
			Write-Host "force: $force"
			Write-Host "args: $args"
		}
		
		function direct_call {
			param (
				[Parameter(ValueFromRemainingArguments = $true)]
				$args
			)
			Write-Host "$args"
			parse_list @args	
		}
		function invoke_call {
			param (
				[Parameter(ValueFromRemainingArguments = $true)]
				$args
			)
			$args.ToString()
			
			Write-Host "[invoke_call]: $(expand $args)"
			Invoke-Expression "parse_list $(expand $args)"
		}
		
		function expand {
			param(
				[Parameter(ValueFromRemainingArguments = $true)]
				$args
			)
			
			$format = foreach ($arg in $args) {
				if (-Not $arg) {
					""
				} elseif ($arg -is [array] -or ($arg -is [System.Collections.IEnumerable] -and $arg -isnot [string])) {
					$arg -join ", "
				} else {
					$arg.ToString()
				}
			}
			$format
		}
		
		parse_list app1, app2 "aehhh"
		direct_call app1, app2 "aehhh"
		invoke_call app1, app2 "aehhh"
	}
}