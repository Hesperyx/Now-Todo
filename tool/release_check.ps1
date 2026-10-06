<#
.SYNOPSIS
    Now Todo 发布前的机械检查。

.DESCRIPTION
    对应 docs/MILESTONES.md 里的「发布检查清单」，把能在机器上验的四项跑一遍：
      1. dart format --output=none --set-exit-if-changed .
      2. flutter analyze
      3. flutter test --concurrency 1（迁移测试也在里面）
      4. -Apk 时额外打一次 release 包，再用 aapt 核对包名与权限清单
         （重点：发布产物里不许出现 INTERNET 权限）

    清单里剩下的几条只能在真机上手工走查——全新安装、从上一版升级、断网可用、
    通知按时、时区切换、导出 → 卸载 → 重装 → 导入，脚本替不了，别把这份全绿
    当成可以上架。

    每个步骤的完整输出写到 build/<步骤>.log，失败时把末尾 30 行回显出来。

.EXAMPLE
    powershell -File tool/release_check.ps1

.EXAMPLE
    powershell -File tool/release_check.ps1 -Apk
#>

[CmdletBinding()]
param(
    [switch]$Apk,
    [string]$LogDirectory = 'build'
)

# 故意**不**设 'Stop'：flutter.bat 每次都会往 stderr 写一行
# 「Flutter assets will be downloaded from …」，在 Stop 下它会被当成终止性错误，
# 脚本会在第一步之后就死掉——而它其实只是个提示。每一步的结果一律看 $LASTEXITCODE。
$ErrorActionPreference = 'Continue'

# 上架后不可更改，所以这里写死并与 android/app/build.gradle.kts 对齐。
$ExpectedPackage = 'io.github.hesperyx.nowtodo'
$ExpectedAppLabel = 'Now Todo'

# `dart format` 必须用 Flutter 自带的那一份 SDK。
# 本机 PATH 上的 dart 是独立安装的另一套（实测 3.11.5），而 Flutter 3.35.5 自带
# 3.9.2——两个版本的格式化器输出不一定一致，拿错版本会让这道门变成假信号：
# 按 3.9.2 排好的代码可能在 3.11.5 下「需要改动」。
$flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if (-not $flutter) {
    throw '找不到 flutter：请把它加到 PATH，或在 Flutter 的 bin 目录下运行本脚本。'
}
$dart = Join-Path (Split-Path $flutter -Parent) 'cache\dart-sdk\bin\dart.exe'
if (-not (Test-Path $dart)) {
    throw "找不到 Flutter 自带的 dart：$dart"
}
Write-Host "flutter: $flutter"
Write-Host "dart:    $dart（Flutter 自带的那份）"
Write-Host ''

$script:Results = @()

function Invoke-Step {
    param(
        [string]$Name,
        [string]$Command,
        [string[]]$StepArgs
    )

    if (-not (Test-Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory | Out-Null
    }
    $log = Join-Path $LogDirectory "$Name.log"
    Write-Host "==> $Name" -ForegroundColor Cyan

    & $Command @StepArgs *> $log
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Host "    失败（exit $code），末尾输出：" -ForegroundColor Red
        Get-Content $log -Encoding UTF8 -Tail 30 | ForEach-Object { Write-Host "    $_" }
    }
    else {
        Write-Host "    通过" -ForegroundColor Green
    }

    $script:Results += [pscustomobject]@{ 步骤 = $Name; 结果 = $code }
    return $code
}

$failed = 0

# 1. 格式：--set-exit-if-changed 让「需要改动」直接算失败。
$failed += Invoke-Step -Name 'release-format' -Command $dart `
    -StepArgs @('format', '--output=none', '--set-exit-if-changed', '.')

# 2. 静态分析。
$failed += Invoke-Step -Name 'release-analyze' -Command $flutter -StepArgs @('analyze')

# 3. 全部测试。并发固定为 1：这些用例会碰同一批临时文件与真实的时间源。
$failed += Invoke-Step -Name 'release-test' -Command $flutter `
    -StepArgs @('test', '--concurrency', '1')

# 4. 可选：打 release 包并核对产物。
if ($Apk) {
    $failed += Invoke-Step -Name 'release-build-apk' -Command $flutter `
        -StepArgs @('build', 'apk', '--release')

    $apkPath = 'build/app/outputs/flutter-apk/app-release.apk'
    $sdk = $env:ANDROID_HOME
    if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
    if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }

    Write-Host '==> release-apk-permissions' -ForegroundColor Cyan
    $apkFailure = 0
    if (-not (Test-Path $apkPath)) {
        Write-Host "    找不到 $apkPath" -ForegroundColor Red
        $apkFailure = 1
    }
    else {
        $buildTools = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory -ErrorAction SilentlyContinue |
            Sort-Object { [version]$_.Name }
        if (-not $buildTools) {
            Write-Host "    在 $sdk\build-tools 下找不到 aapt" -ForegroundColor Red
            $apkFailure = 1
        }
        else {
            $aapt = Join-Path $buildTools[-1].FullName 'aapt.exe'
            $lines = & $aapt dump badging $apkPath 2>&1
            $lines | Set-Content -Path (Join-Path $LogDirectory 'release-apk-badging.txt') -Encoding UTF8

            # aapt 的输出是一行一条，但 `-match` / `-notmatch` 作用在数组上时返回的是
            # **匹配到的元素**（非空数组恒为真），不是布尔值，所以先拼成一个字符串再判。
            $badging = $lines -join "`n"

            $lines | Where-Object {
                $_ -match '^package:' -or
                $_ -match '^launchable-activity:' -or
                $_ -match '^uses-permission:' -or
                $_ -match '^application-label:'
            } | ForEach-Object { Write-Host "    $_" }

            if ($badging -notmatch [regex]::Escape("package: name='$ExpectedPackage'")) {
                Write-Host "    包名不是 $ExpectedPackage" -ForegroundColor Red
                $apkFailure = 1
            }
            if ($badging -notmatch [regex]::Escape("application-label:'$ExpectedAppLabel'")) {
                Write-Host "    应用名不是 $ExpectedAppLabel" -ForegroundColor Red
                $apkFailure = 1
            }
            if ($badging -match 'android\.permission\.INTERNET') {
                Write-Host '    发布产物里出现了 INTERNET 权限——隐私政策里那句话就不成立了' -ForegroundColor Red
                $apkFailure = 1
            }
            if ($apkFailure -eq 0) { Write-Host '    通过' -ForegroundColor Green }
        }
    }
    $script:Results += [pscustomobject]@{ 步骤 = 'release-apk-permissions'; 结果 = $apkFailure }
    $failed += $apkFailure
}

Write-Host ''
$script:Results | Format-Table -AutoSize | Out-String | Write-Host

if ($failed -ne 0) {
    Write-Host '机械检查没过，先修完再谈发布。' -ForegroundColor Red
    exit 1
}

Write-Host '机械检查全部通过。' -ForegroundColor Green
Write-Host '仍然只能靠真机的部分：全新安装 / 升级 / 断网 / 通知 / 时区 / 导出→卸载→重装→导入。' -ForegroundColor Yellow
exit 0
