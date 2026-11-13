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

# PowerShell 5.1 mengubah setiap baris stderr dari native command menjadi
# NativeCommandError. Karena script ini memakai $ErrorActionPreference = 'Stop',
# warning yang ditulis Flutter/Node/Firebase ke stderr (mis. "Wasm dry run
# findings") membuat script berhenti padahal command-nya sukses. Helper ini
# menggabungkan stderr ke stdout dan hanya gagal berdasarkan exit code.
function Invoke-NativeStep {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "[deploy] $Label"
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command 2>&1 | ForEach-Object {
            $line = if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.Exception.Message
            }
            else {
                $_
            }
            Write-Host $line
        }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previous
    }

    if ($exitCode -ne 0) {
        throw "$Label gagal (exit code $exitCode)"
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot (Join-Path 'sales-app' $App)
$buildPath = "sales-app/$App/build/web"
$buildId = 'local' + (Get-Date -Format 'yyyyMMddHHmmss')

if (-not (Test-Path $appDir)) {
    throw "Folder app tidak ditemukan: $appDir"
}

Push-Location $appDir
try {
    Invoke-NativeStep "flutter build web --release ($App)" {
        flutter build web --release
    }

    Write-Host "[deploy] stamp build id: $buildId"
    $env:BUILD_ID = $buildId
    Invoke-NativeStep 'stamp build id' {
        node (Join-Path $repoRoot 'scripts/stamp_flutter_web.mjs') $buildPath
    }

    Invoke-NativeStep 'firebase deploy --only hosting' {
        firebase deploy --only hosting
    }

    Write-Host "[deploy] selesai. Build id: $buildId"
}
finally {
    Remove-Item Env:BUILD_ID -ErrorAction SilentlyContinue
    Pop-Location
}
