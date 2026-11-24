# Build the Web preset after the collection, input, accessibility, and editor checks.
# Publishing remains opt-in and requires BUTLER_API_KEY and ITCH_TARGET.
param(
    [string]$Godot = $env:GODOT,
    [switch]$Publish,
    [switch]$SkipTests
)
$ErrorActionPreference = 'Stop'
$projectDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectDirectory
if (-not $Godot) { $Godot = 'godot' }
$logDirectory = Join-Path $projectDirectory 'build/logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

function Invoke-GodotCheck([string]$Name, [string[]]$Arguments, [string]$Marker = '') {
    Write-Host "Running $Name"
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $Godot @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    # Godot 4.7's dummy renderer can emit this lone, nonfatal import race.
    # https://github.com/godotengine/godot/issues/124139
    if ($Name -eq 'import' -and $exitCode -eq 0) {
        $importErrors = [regex]::Matches($output, '(?m)^\s*(?:SCRIPT ERROR|ERROR|Parse Error):[^\r\n]*')
        if ($importErrors.Count -eq 1 -and $importErrors[0].Value.Trim() -eq 'ERROR: Parameter "t" is null.') {
            $output | Set-Content -LiteralPath (Join-Path $logDirectory 'import-first.log') -Encoding utf8
            Write-Host 'Retrying import after Godot headless texture race'
            $ErrorActionPreference = 'Continue'
            $output = & $Godot @Arguments 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
            $ErrorActionPreference = $savedPreference
        }
    }
    $output | Set-Content -LiteralPath (Join-Path $logDirectory "$Name.log") -Encoding utf8
    if ($exitCode -ne 0 -or $output -match '(?m)^\s*(SCRIPT ERROR|ERROR|Parse Error):' -or ($Marker -and $output -notmatch $Marker)) {
        Write-Host $output
        throw "Godot check failed: $Name (exit $exitCode). See build/logs/$Name.log."
    }
    if ($Marker) { Write-Host "Passed $Name" }
    return $output
}

$version = Invoke-GodotCheck 'version' @('--headless', '--version')
if ($version -notmatch '(?m)^4\.7\.2\.') { throw 'This build requires Godot 4.7.2.' }
$null = Invoke-GodotCheck 'import' @('--headless', '--path', '.', '--import')
if (-not $SkipTests) {
    foreach ($test in @('smoke_flow', 'test_collection', 'test_input_routes', 'test_presentation', 'check_microgames', 'smoke_variable_scope', 'smoke_new_microgames', 'test_festival', 'smoke_accessibility')) {
        $null = Invoke-GodotCheck $test @('--headless', '--path', '.', '--script', "res://tools/$test.gd") '(?m)^[A-Z_]+_OK\s*$'
    }
    $null = Invoke-GodotCheck 'crossing_framework' @('--headless', '--path', '.', '--script', 'res://tests/crossing/test_framework.gd') 'RESULT: \d+ checks, 0 failures'
    $null = Invoke-GodotCheck 'crossing_editor' @('--headless', '--editor', '--path', '.', 'scenes/crossing/campus_intro.tscn', '--', '--test-native-editor') 'NATIVE EDITOR RESULT: \d+ checks, 0 failures'
}

$webDirectory = [IO.Path]::GetFullPath((Join-Path $projectDirectory 'build/web'))
if (-not $webDirectory.StartsWith($projectDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The export directory must stay inside this project.'
}
foreach ($directory in @((Join-Path $projectDirectory 'build'), $webDirectory)) {
    if ((Test-Path -LiteralPath $directory) -and ((Get-Item -LiteralPath $directory).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Build output cannot use a directory link: $directory"
    }
}
if (Test-Path -LiteralPath $webDirectory) { Remove-Item -LiteralPath $webDirectory -Recurse -Force }
New-Item -ItemType Directory -Path $webDirectory -Force | Out-Null
$null = Invoke-GodotCheck 'export' @('--headless', '--path', '.', '--export-release', 'Web', 'build/web/index.html')
foreach ($file in @('index.html', 'index.pck', 'index.wasm', 'index.js')) {
    $path = Join-Path $webDirectory $file
    if (-not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) { throw "Export is missing $file." }
}
$commit = & git rev-parse --short HEAD 2>$null
if (-not $commit) { $commit = 'local' }
Set-Content -LiteralPath (Join-Path $webDirectory 'BUILD_COMMIT.txt') -Value $commit -Encoding utf8
$archive = Join-Path $projectDirectory 'build/aggieware-web.zip'
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive }
Compress-Archive -Path (Join-Path $webDirectory '*') -DestinationPath $archive
Write-Host "Created $archive"
if ($Publish) {
    if (-not $env:BUTLER_API_KEY -or -not $env:ITCH_TARGET) { throw 'Publishing requires BUTLER_API_KEY and ITCH_TARGET.' }
    & butler push $webDirectory $env:ITCH_TARGET --userversion $commit
    if ($LASTEXITCODE -ne 0) { throw 'butler push failed.' }
}
