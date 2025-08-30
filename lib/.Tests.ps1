BeforeAll {
	Get-ChildItem $PSScriptRoot | Where-Object { $_.Name -like "*.ps1" } | ForEach-Object { . $_.FullName }
}
 
Describe "Manifest" {
	It "get-manifest" -Tag "m-rage" {
		$json = get_manifest "rage"
		$json.bin | Should -Contain "rage.exe"
	}
}

Describe "Route" {
	It "get-scoop" -Tag "r-scoop" {
		$scoop = Get-Scoop
		$scoop | Should -Not -BeNullOrEmpty
		$scoop | Should -Match "scoop"

		$scoop_all = Get-ScoopSubs
		$scoop_all | Should -Not -BeNullOrEmpty
		Test-Path ($scoop_all["apps"]) | Should -BeTrue
		Test-Path ($scoop_all["persist"]) | Should -BeTrue
		Test-Path ($scoop_all["global"]) | Should -BeTrue
	}

	It "get-scoop-ext" -Tag "r-scoope" {
		$scoop_ext = Get-ScoopExtSubs "$PSScriptRoot/../"
		$scoop_ext | Should -Not -BeNullOrEmpty
		Test-Path ($scoop_ext["apps"]) | Should -BeTrue
	}

	It "path root" -Tag "r-root" {
		$root = Join-Path $PWD "../foo"
		$root = [System.IO.Path]::GetFullPath($root)
		Write-Host $root
	}
}

Describe "Config" {
	BeforeAll {
		Mock -CommandName get_inventory -MockWith { @{ local = @{}; global = @{} } }
		Mock -CommandName set_inventory -MockWith { param($data) $script:saved_config = $data }
	}
	
	BeforeEach {
		$script:saved_config = @{}
	}
	
	It "with-config-ref" -Tag "c-ref" {
		with_inventory -Ref {
			param([ref]$cfg)
			$cfg.Value["foo"] = "bar"
		}
		$saved_config["local"]["foo"] | Should -Be "bar"
		Assert-MockCalled get_inventory -Times 1
		Assert-MockCalled set_inventory -Times 1
	}

	It "with-config" -Tag "c-value" {
		with_inventory -Global {
			param($cfg)
			$cfg["foo"] = "gar"
			$cfg
		}
		
		$saved_config["global"]["foo"] | Should -Be "gar"
		Assert-MockCalled get_inventory -Times 1
		Assert-MockCalled set_inventory -Times 1
	}
}

Describe "App" {
	Context "scoop appsubs" -Tag "a-subs" {
		BeforeEach {
			$Script:scoopSubs = @{ apps = 'C:\apps'; persist = 'C:\persist'; global = 'C:\global' } 
		}
		It "exist" {
			Mock -CommandName Test-Path -MockWith { $true }
			$(scoop_appsub "foo" -sub "app") | Should -Be "C:\apps\foo"
		}
		It "not exist" {
			Mock -CommandName Test-Path -MockWith { $false }
			# pipe a lazy valued expression
			{ scoop_appsub "foo" -sub "app" -Exist } | Should -Throw
			{ scoop_appsub "foo" -sub "persist" -Exist } | Should -Throw
		}
	}
	
	Context "installed versions" -Tag "a-i-vers" {
		BeforeEach {
			Mock -CommandName scoop_appsubs -MockWith {
				@{ app = 'C:\apps\foo'; persist = 'C:\persist\foo' }
			}
		}

		It "exclude current" {
			$d1 = [System.IO.DirectoryInfo] 'C:\apps\foo\current'
			$d2 = [System.IO.DirectoryInfo] 'C:\apps\foo\1.0'
			$d3 = [System.IO.DirectoryInfo] 'C:\apps\foo\2.0'
			
			Mock -CommandName Get-ChildItem -MockWith { @($d1, $d2, $d3) }
			
			$(may_installed_vers "foo") | Should -BeExactly @($d2, $d3)
		}
	}

	Context "current version" -Tag "a-c-ver" {
		BeforeEach {
			Mock -CommandName scoop_appsubs -MockWith {
				@{ app = 'C:\apps\foo'; persist = 'C:\persist\foo' }
			}

			$v1 = [pscustomobject]@{
				Name          = '1.0'
				FullName      = 'C:\apps\foo\1.0'
				LastWriteTime = (Get-Date).AddDays(-1)
			}
			$v2 = [pscustomobject]@{
				Name          = '2.0'
				FullName      = 'C:\apps\foo\2.0'
				LastWriteTime = (Get-Date)
			}

			Mock -CommandName may_installed_vers -MockWith { @($v1, $v2) }
		}

		It "resolve symlink" {
			$tg = [pscustomobject]@{ Target = 'C:\apps\foo\1.2.3' }
			Mock -CommandName Test-Path -MockWith { $true }
			Mock -CommandName Get-Item -MockWith { $tg }
			
			$(may_cur_ver "foo") | Should -BeExactly $tg
		}

		It "resolve latest version" {
			Mock -CommandName Test-Path -MockWith { $false }
			$(may_cur_ver "foo") | Should -BeExactly $v2
			Assert-MockCalled may_installed_vers -Times 1
		}
	}
}

Describe "Parse" {
	It "opts something" -Tag "p-some" {
		$list = "pkg1", "pkg2", "pkg3", "--force", "isforce", "-p", "E:\" , "-foo", "bar"
		$pkgs, $opts = opts "--force", "-f", "--path" , "-p" $list
		
		Write-Host "filtered list1: $list"

		$pkgs | Should -Be "pkg1", "pkg2", "pkg3"
		$opts["--force"] | Should -Be "isforce"
		$opts["-f"] | Should -BeFalse
		$opts["-p"] | Should -Be "E:\"
		$opts["-foo"] | Should -Be "bar"
	}

	It "opts something 2" -Tag "p-some-2" {
		$list = "pkg1", "pkg2", "-p", "E:\"
		$pkgs, $opts = opts "--global", "-g", "--path", "-p" $list

		Write-Host "filtered list1: $list"

		$pkgs | Should -Be "pkg1", "pkg2"
		$opts["--global"] | Should -BeFalse
		$opts["-p"] | Should -Be "E:\"
	}
	
	It "opts nothing" -Tag "p-no" {
		$list = @()
		$pkgs, $opts = opts "--force", "-f" $list

		$pkgs.Count | Should -Be 0
		$opts.Count | Should -Be 0
	}
	
	It "call list-fold" -Tag "p-call" {
		function parse_list {
			param (
				[string[]]$appNames,
				[switch]$Force,
				[Parameter(ValueFromRemainingArguments = $true)]
				$args
			)
			Write-Host "[parse_list]: appNames: $appNames, force: $Force, args: $args"
		}
		
		function direct_call {
			param (
				[Parameter(ValueFromRemainingArguments = $true)]
				[string[]]$args
			)
			Write-Host "direct call: $args"
			parse_list @args	
		}
		
		function flatten {
			param(
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
			$format
		}
		function invoke_call {
			param (
				[Parameter(ValueFromRemainingArguments = $true)]
				$args
			)
			Write-Host "invoke call:"
			Invoke-Expression "parse_list $(flatten $args)"
		}
		# [parse_list]: appNames: app1 app2, force: True, args: foo
		# direct call: System.Object[] -Force foo
		# [parse_list]: appNames: app1 app2, force: False, args: -Force foo
		# invoke call:
		# [parse_list]: appNames: app1 app2, force: True, args: foo
		parse_list app1, app2 -Force "foo"
		direct_call app1, app2 -Force "foo"
		invoke_call app1, app2 -Force "foo"
	}
}