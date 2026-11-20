# SCRUM-59: build (and optionally publish) the AggieWare web build on Windows.
#
#   powershell -ExecutionPolicy Bypass -File tools/build_web.ps1 -Godot "C:\path\Godot_v4.7.2-stable_win64_console.exe"
#   add -Publish to push to itch.io with butler (needs BUTLER_API_KEY and ITCH_TARGET env vars)
param(
    [string]$Godot = $env:GODOT,
    [switch]$Publish,
    [switch]$SkipTests
)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
if (-not $Godot) { $Godot = "godot" }

function Write-Step($text) { Write-Host "`n== $text" }

Write-Step "Godot version"
& $Godot --headless --version

Write-Step "Import project"
& $Godot --headless --path . --import *> $null

if (-not $SkipTests) {
    foreach ($test in @("smoke_flow", "check_microgames", "smoke_variable_scope", "smoke_new_microgames")) {
        Write-Step "Smoke test: $test"
        $ErrorActionPreference = "Continue"
        $out = & $Godot --headless --path . --script "res://tools/$test.gd" 2>&1 | Out-String
        $code = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        if ($code -ne 0 -or $out -notmatch "_OK") {
            Write-Host (($out -split "`n" | Select-Object -Last 30) -join "`n")
            throw "FAILED: $test"
        }
        ($out -split "`n") | Where-Object { $_ -match "_OK" } | ForEach-Object { Write-Host $_ }
    }
}

Write-Step "Export Web preset"
if (Test-Path build/web) { Remove-Item -Recurse -Force build/web }
New-Item -ItemType Directory -Force build/web | Out-Null
$ErrorActionPreference = "Continue"
& $Godot --headless --path . --export-release "Web" build/web/index.html
$ErrorActionPreference = "Stop"
if (-not ((Test-Path build/web/index.html) -and (Test-Path build/web/index.pck))) {
    throw "Export did not produce build/web/index.html + index.pck. Are the Godot 4.7.2 export templates installed? (Editor > Manage Export Templates)"
}

Write-Step "Package"
$commit = (git rev-parse --short HEAD) 2>$null
if (-not $commit) { $commit = "local" }
Set-Content -Path build/web/BUILD_COMMIT.txt -Value $commit -Encoding utf8
if (Test-Path build/aggieware-web.zip) { Remove-Item build/aggieware-web.zip }
Compress-Archive -Path build/web/* -DestinationPath build/aggieware-web.zip
Write-Host ("build/aggieware-web.zip  {0:N0} bytes" -f (Get-Item build/aggieware-web.zip).Length)

if ($Publish) {
    Write-Step "Publish to itch.io"
    if (-not $env:BUTLER_API_KEY) { throw "set BUTLER_API_KEY to publish" }
    if (-not $env:ITCH_TARGET) { throw "set ITCH_TARGET, e.g. user/aggieware:html5" }
    & butler push build/web $env:ITCH_TARGET --userversion $commit
    if ($LASTEXITCODE -ne 0) { throw "butler push failed" }
}

Write-Step "Done: build/web ($commit)"
