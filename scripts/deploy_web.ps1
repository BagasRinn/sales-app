<#
.SYNOPSIS
    Build + stamp build id + deploy salah satu Flutter web app ke Firebase Hosting.

.DESCRIPTION
    Deploy manual dari Windows. Langkah "stamp" WAJIB dijalankan supaya
    flutter_bootstrap.js dan main.dart.js memakai URL ?v=<buildId>, sehingga
    browser tidak memakai bundle lama walaupun cache-nya 1 tahun.

    Di CI (push ke main) langkah ini sudah otomatis lewat
    .github/workflows/deploy-*-firebase.yml.

.EXAMPLE
    .\scripts\deploy_web.ps1 -App sales_web

.EXAMPLE
    .\scripts\deploy_web.ps1 -App admin_web
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('sales_web', 'admin_web')]
    [string]$App
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot (Join-Path 'sales-app' $App)
$buildPath = "sales-app/$App/build/web"
$buildId = 'local' + (Get-Date -Format 'yyyyMMddHHmmss')

if (-not (Test-Path $appDir)) {
    throw "Folder app tidak ditemukan: $appDir"
}

Push-Location $appDir
try {
    Write-Host "[deploy] flutter build web --release ($App)"
    flutter build web --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build web gagal' }

    Write-Host "[deploy] stamp build id: $buildId"
    $env:BUILD_ID = $buildId
    node (Join-Path $repoRoot 'scripts/stamp_flutter_web.mjs') $buildPath
    if ($LASTEXITCODE -ne 0) { throw 'stamp build id gagal' }

    Write-Host '[deploy] firebase deploy --only hosting'
    firebase deploy --only hosting
    if ($LASTEXITCODE -ne 0) { throw 'firebase deploy gagal' }

    Write-Host "[deploy] selesai. Build id: $buildId"
}
finally {
    Remove-Item Env:BUILD_ID -ErrorAction SilentlyContinue
    Pop-Location
}
