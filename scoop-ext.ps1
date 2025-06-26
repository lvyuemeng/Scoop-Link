<#
.SYNOPSIS
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('install', 'uninstall', 'list', 'path')]
    [string]$Command,
    
    [Parameter(Position = 1)]
    [string]$AppName,
    
    [Parameter(Position = 2)]
    [string]$CustomPath
)

Get-ChildItem "$PSScriptRoot/lib" | Where-Object { $_.Name -like "*.ps1" } | ForEach-Object { . $_.FullName }
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE "scoop" }
$scoopApps = Join-Path $scoopRoot "apps"
$scoopShims = Join-Path $scoopRoot "shims"
# entries of scoop-ext
$STORAGE_DIR = Join-Path $scoopRoot "custom_store"
$APPS_FILE = Join-Path $STORAGE_DIR "apps.json"
$BIN_FILE = Join-Path $STORAGE_DIR "bin.json"

function Get-Manifest($app) {
    $path = Join-Path $scoopRoot "buckets\*\bucket\$app.json"
    $manifest = Get-ChildItem $path | Select-Object -First 1
    if (-not $manifest) { throw "找不到$app的清单文件" }
    Get-Content $manifest.FullName | ConvertFrom-Json -Depth 10
}

if (-not (Test-Path $STORAGE_DIR)) {
    New-Item -Path $STORAGE_DIR -ItemType Directory -Force | Out-Null
    @{} | ConvertTo-Json | Set-Content $APPS_FILE
    @{} | ConvertTo-Json | Set-Content $BIN_FILE
}

function Get-AppsData {
    Get-Content $APPS_FILE | ConvertFrom-Json -AsHashtable
}

function Update-AppsData($data) {
    $data | ConvertTo-Json -Depth 5 | Set-Content $APPS_FILE
}

function Get-BinData {
    Get-Content $BIN_FILE | ConvertFrom-Json -AsHashtable
}

function Update-BinData($data) {
    $data | ConvertTo-Json -Depth 5 | Set-Content $BIN_FILE
}

function Resolve-InstallPath($app, $path) {
    if (-not [System.IO.Path]::IsPathRooted($path)) {
        $path = Join-Path (Get-Location).Path $path
    }
    return $path
}

switch ($Command) {
    'install' {
        if (-not $CustomPath) { throw "必须指定CustomPath参数" }
        $realPath = Resolve-InstallPath $AppName $CustomPath
        
        $manifest = Get-Manifest $AppName
        
        $tempDir = Join-Path $scoopRoot "apps\$AppName"
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        try {
            scoop install $AppName --no-cache
            $versionDir = Get-ChildItem (Join-Path $scoopRoot "apps\$AppName") -Directory |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        
            if (-not $versionDir) { throw "无法检测到安装版本" }

            $realVersionPath = Join-Path $realPath $versionDir.Name
            $currentLink = Join-Path $realPath "current"

            robocopy $versionDir.FullName $realVersionPath /MIR /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC | Out-Null
        
            if (Test-Path $currentLink) { Remove-Item $currentLink -Force }
            New-Item -ItemType Junction -Path $currentLink -Target $realVersionPath -Force | Out-Null

            if (Test-Path $versionDir.FullName) { Remove-Item $versionDir.FullName -Force }
            New-Item -ItemType Junction -Path $versionDir.FullName -Target $currentLink -Force | Out-Null

            $binTargetDir = if ($manifest.installer.script) { 
            (Get-Item (Join-Path $currentLink "*\bin")).FullName 
            }
            else { 
                $currentLink 
            }

            $bins = @()
            if ($manifest.bin) {
                $bins = $manifest.bin | ForEach-Object { 
                ($_ -split '\|')[0].Trim() 
                }
            }
            else {
                $bins = Get-ChildItem $binTargetDir -Recurse -File |
                Where-Object { $_.Extension -match '\.(exe|bat|cmd|ps1)$' } |
                Select-Object -ExpandProperty Name
            }

            $binData = Get-BinData
            foreach ($bin in $bins) {
                $shimPath = Join-Path $scoopRoot "shims\$bin"
                $targetBin = Join-Path $currentLink $bin

                if (-not (Test-Path $targetBin)) {
                    Write-Warning "二进制文件未找到: $targetBin，尝试在子目录查找..."
                    $targetBin = Get-ChildItem $currentLink -Recurse -Filter $bin | 
                    Select-Object -First 1 -ExpandProperty FullName
                }

                if ($targetBin) {
                    if (Test-Path $shimPath) { Remove-Item $shimPath -Force }
                    $null = New-Item -ItemType HardLink -Path $shimPath -Target $targetBin -Force
                    $binData[$bin] = @{
                        App     = $AppName
                        Version = $versionDir.Name
                    }
                }
            }
            Update-BinData $binData

            $apps = Get-AppsData
            $apps[$AppName] = @{
                Path      = $realPath
                Current   = $versionDir.Name
                Versions  = @($versionDir.Name) + $apps[$AppName].Versions
                Installed = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            Update-AppsData $apps
        }
        catch {
            if (Test-Path $realVersionPath) { Remove-Item $realVersionPath -Recurse -Force }
            if (Test-Path $currentLink) { Remove-Item $currentLink -Force }
            throw $_
        }
    }
    
    'uninstall' {
        $apps = Get-AppsData
        if (-not $apps.ContainsKey($AppName)) { throw "未找到安装记录" }

        $allVersions = Get-ChildItem (Join-Path $apps[$AppName].Path "*") -Directory

        if ($CustomPath) {
            $versionToRemove = $CustomPath
            $remainingVersions = $allVersions.Name | Where-Object { $_ -ne $versionToRemove }
        }
        else {
            $remainingVersions = @()
            $versionToRemove = $allVersions.Name
        }

        foreach ($version in $versionToRemove) {
            $versionPath = Join-Path $apps[$AppName].Path $version
            if (Test-Path $versionPath) {
                Remove-Item $versionPath -Recurse -Force
            }
        }

        if ($apps[$AppName].Current -in $versionToRemove -and $remainingVersions) {
            $newCurrent = $remainingVersions | Sort-Object -Descending | Select-Object -First 1
            $currentLink = Join-Path $apps[$AppName].Path "current"
            if (Test-Path $currentLink) { Remove-Item $currentLink -Force }
            New-Item -ItemType Junction -Path $currentLink -Target (Join-Path $apps[$AppName].Path $newCurrent) -Force
        }
        
        $binData = Get-BinData
        $binData.Keys.Clone() | ForEach-Object {
            if ($binData[$_] -eq $AppName) {
                $shimPath = Join-Path $scoopRoot "shims\$_"
                if (Test-Path $shimPath) { Remove-Item $shimPath -Force }
                $binData.Remove($_)
            }
        }
        Update-BinData $binData
        
        $apps.Remove($AppName)
        Update-AppsData $apps
        
        scoop uninstall $AppName
    }
    
    'list' {
        Get-AppsData | Format-Table @{
            Name       = "应用名称"
            Expression = { $_.Key }
        }, @{
            Name       = "安装路径"
            Expression = { $_.Value.Path }
        }, @{
            Name       = "安装时间"
            Expression = { $_.Value.Installed }
        }
    }
    
    'path' {
        (Get-AppsData)[$AppName].Path
    }
}