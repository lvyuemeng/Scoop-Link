<#
.SYNOPSIS
Scoop路径管理系统（无依赖版）
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

# 公共变量初始化
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE "scoop" }
$STORAGE_DIR = Join-Path $scoopRoot "custom_store"
$APPS_FILE = Join-Path $STORAGE_DIR "apps.json"
$BIN_FILE = Join-Path $STORAGE_DIR "bin.json"

# 公共函数
function Get-Manifest($app) {
    $path = Join-Path $scoopRoot "buckets\*\bucket\$app.json"
    $manifest = Get-ChildItem $path | Select-Object -First 1
    if (-not $manifest) { throw "找不到$app的清单文件" }
    Get-Content $manifest.FullName | ConvertFrom-Json -Depth 10
}

# 初始化存储目录
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
        
        # 创建临时安装目录
        $tempDir = Join-Path $scoopRoot "apps\$AppName"
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        try {
            # 执行原始安装并获取实际安装版本
            scoop install $AppName --no-cache
            $versionDir = Get-ChildItem (Join-Path $scoopRoot "apps\$AppName") -Directory |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        
            if (-not $versionDir) { throw "无法检测到安装版本" }

            # 创建版本化存储路径
            $realVersionPath = Join-Path $realPath $versionDir.Name
            $currentLink = Join-Path $realPath "current"

            # 迁移版本目录
            robocopy $versionDir.FullName $realVersionPath /MIR /MOVE /NFL /NDL /NJH /NJS /NP /NS /NC | Out-Null
        
            # 创建/更新current链接
            if (Test-Path $currentLink) { Remove-Item $currentLink -Force }
            New-Item -ItemType Junction -Path $currentLink -Target $realVersionPath -Force | Out-Null

            # 更新Scoop的目录结构
            if (Test-Path $versionDir.FullName) { Remove-Item $versionDir.FullName -Force }
            New-Item -ItemType Junction -Path $versionDir.FullName -Target $currentLink -Force | Out-Null

            # 识别二进制文件（从manifest或实际文件）
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

            # 创建版本无关的shim
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

            # 更新应用数据（记录版本信息）
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
            # 增强版清理逻辑
            if (Test-Path $realVersionPath) { Remove-Item $realVersionPath -Recurse -Force }
            if (Test-Path $currentLink) { Remove-Item $currentLink -Force }
            throw $_
        }
    }
    
    'uninstall' {
        $apps = Get-AppsData
        if (-not $apps.ContainsKey($AppName)) { throw "未找到安装记录" }

        # 获取所有版本
        $allVersions = Get-ChildItem (Join-Path $apps[$AppName].Path "*") -Directory

        # 如果指定版本则删除特定版本，否则删除全部
        if ($CustomPath) {
            $versionToRemove = $CustomPath
            $remainingVersions = $allVersions.Name | Where-Object { $_ -ne $versionToRemove }
        }
        else {
            $remainingVersions = @()
            $versionToRemove = $allVersions.Name
        }

        # 删除指定版本
        foreach ($version in $versionToRemove) {
            $versionPath = Join-Path $apps[$AppName].Path $version
            if (Test-Path $versionPath) {
                Remove-Item $versionPath -Recurse -Force
            }
        }

        # 更新current链接（如果删除的是当前版本）
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