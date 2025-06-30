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
	
	It "opts" -Tag "opts" {
		$opts = opts "--force","-f" "--force", "something"
		$opts["--force"] | Should -BeTrue
		$opts["-f"] | Should -BeFalse
	}
}