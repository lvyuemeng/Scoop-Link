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

function may_resolve_tg_path {
	param (
		[Parameter(Mandatory = $true)]
		[string]$path
	)
	
	if ((Test-Path $path -PathType Container -IsValid) -And (-Not $path.Contains("scoop"))) {
		$full_path = [System.IO.Path]::GetFullPath($path)
		return $full_path
	}
 else {
		Write-Error "[move]: Provided path '$path' is not a valid directory path."
		return $null
	}
}

function may_checked_vers {
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$pkg,
		[switch]$global
	)

	$vers = may_installed_vers $pkg -Global:$global
	if (-Not $vers) {
		Write-Warning "[move]: app '$pkg' is not installed"
		Write-Warning "[move]: remove app '$pkg' from config if exists"
		remove_pkg_inventory $pkg -Global:$global
		return $null
	}
	return $vers
}

function move_pkg {
	param (
		[CmdletBinding()]
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string]$pkg,
		[Parameter(Mandatory = $true, Position = 1)]
		[string]$path,
		[switch]$global
	)
	
	process {
		if ($global -And -Not (test_admin)) {
			Write-Warning "[move]: Move global app requires admin privileges"
			return
		}

		if (-Not ($vers = may_checked_vers $pkg -Global:$global)) { return }
		if (-Not ($tg_path = may_resolve_tg_path $path)) { return }
		$tg_pkg = Join-Path $tg_path $pkg
		# create dir if not exist else default
		New-Item -Path $tg_pkg -ItemType Directory -Debug:$DebugPreference -ErrorAction SilentlyContinue | Out-Null

		try {
			$vers | ForEach-Object {
				$ver = $_	
				$tg_ver = Join-Path $tg_pkg $ver.Name
				$src_ver = resolve_dir $ver
				if ($src_ver -eq $tg_ver) {
					Write-Host "[move]: $ver is already symlink to $tg_ver" 
					return
				}
				
				Write-Debug "[move]: $ver\: $src_ver -> $tg_ver"
				robocopy_move -src $src_ver -dst $tg_ver
				# create symlink from tg_ver
				New-Item -ItemType SymbolicLink -Path $ver -Target $tg_ver -Force -Debug:$DebugPreference | Out-Null
			}

			# Safety: $pkg must exist
			$src_cur_ver = may_persist_link $pkg -Global:$global
			Write-Debug "[move]: update app inventory"
			update_app_inventory $pkg -path $tg_path -ver $src_cur_ver.Name -Global:$global
		}
		catch {
			& scoop uninstall $pkg
			Remove-Item $tg_pkg -Recurse -Force
			Write-Error $_
			Write-Error "Please reinstall the package again by 'scoop install $pkg; scpl move $pkg'."
		}
	}
}

function back_pkg {
	param (
		[CmdletBinding()]
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[string]$pkg,
		[switch]$global
	)
	
	process {
		if ($global -And -Not (test_admin)) {
			Write-Warning "[move]: Move global app requires admin privileges"
			return
		}
		
		if (-Not ($vers = may_checked_vers $pkg -Global:$global)) { return }

		try {
			$vers | ForEach-Object {
				$ver = $_	
				$src_ver = resolve_dir $ver
				# tg_ver is the scoop/pkg dir
				$tg_ver = $ver
				if ($src_ver -eq $tg_ver) {
					Write-Host "[move]: $src_ver is already in scoop" 
					return
				}
				
				# Safety: tg_ver must be a symlink
				Remove-Item $tg_ver -Force -ErrorAction SilentlyContinue -Debug:$DebugPreference
				Write-Debug "[move]: $ver\: $src_ver -> $tg_ver"
				robocopy_move -src $src_ver -dst $tg_ver
			}

			# Safety: $pkg must exist
			may_persist_link $pkg -Global:$global
			Write-Debug "[move]: update app inventory"
			remove_pkg_inventory $pkg -Global:$global
		}
		catch {
			& scoop uninstall $pkg
			Remove-Item $tg_pkg -Recurse -Force
			Write-Error $_
			Write-Error "Please reinstall the package again by 'scoop install $pkg; scpl move $pkg'."
		}
	}
}