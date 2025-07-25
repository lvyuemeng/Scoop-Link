. "$PSScriptRoot/config.ps1"
. "$PSScriptRoot/manifest.ps1"
. "$PSScriptRoot/app.ps1"

function test_admin {
	param()
	$user = [Security.Principal.WindowsIdentity]::GetCurrent()
	(New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

function robocopy_move {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$src,
		[Parameter(Mandatory = $true)]
		[string]$dst
	)

	robocopy $src_ver $tg_ver /MIR /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC | Out-Null
	if ($LASTEXITCODE -ge 8) {
		Write-Error "Error: Failed to move package from $src_ver to $tg_ver."
	}
}

function move_app {
	param (
		[CmdletBinding()]
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string]$appName,
		[Parameter(Mandatory = $true, Position = 1)]
		[string]$path,
		[Alias("g")]
		[switch]$global
	)

	process {
		if ($global -And -Not (test_admin)) {
			Write-Warning "[move]: Move global app requires admin privileges"
			return
		}
		if (-Not (Test-Path $path -PathType Container -IsValid)) {
			Write-Error "[move]: Provided path '$path' is not a valid directory path" -ErrorAction Stop
		}
		# normalize path
		$path = [System.IO.Path]::GetFullPath($path)
		$tg_app = Join-Path $path $appName
		# create dir if not exist else default
		New-Item -Path $tg_app -ItemType Directory -Debug:$DebugPreference -ErrorAction SilentlyContinue | Out-Null
		
		# check if app exists
		$vers = installed_versions $appName -Global:$global
		if (-Not $vers) {
			Write-Warning "[move]: app '$appName' is not installed"
			Write-Warning "[move]: remove app '$appName' from config if exists"
			remove_app_inventory $appName -Global:$global
			return
		}

		try {
			$vers | ForEach-Object {
				$ver = $_	
				$tg_ver = Join-Path $tg_app $ver.Name
				$src_ver = resolve_ver_path $ver
				if ($src_ver -eq $tg_ver) {
					Write-Host "[move]: $ver is already symlink to $tg_ver" 
					return
				}
				
				Write-Debug "[move]: $ver\: $src_ver -> $tg_ver"
				robocopy_move -src $src_ver -dst $tg_ver
				# create symlink from tg_ver
				New-Item -ItemType SymbolicLink -Path $ver -Target $tg_ver -Force -Debug:$DebugPreference | Out-Null
			}

			# create persist link: `tg_ver -> persist\<appName>`
			Write-Debug "[move]: create persist link"
			$src_cur_ver = persist_link $appName -path $path -Global:$global
			Write-Debug "[move]: update app inventory"
			update_app_inventory $appName -path $path -ver $src_cur_ver.Name -Global:$global
		}
		catch {
			& scoop uninstall $appName
			Remove-Item $tg_app -Recurse -Force
			Write-Error $_
			Write-Error "Please reinstall the package again by 'scoop-ext install $appName --path $path'."
		}
	}
}