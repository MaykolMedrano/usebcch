[CmdletBinding()]
param(
    [string]$StataPath = 'C:\Program Files\StataNow19\StataSE-64.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path -LiteralPath $StataPath -PathType Leaf)) {
    throw "Stata executable was not found: $StataPath"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = Join-Path $projectRoot "artifacts\logs\$stamp"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

$process = Start-Process -FilePath $StataPath `
    -ArgumentList '/e','do','stata/tests/run_all.do' `
    -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -Wait

Get-ChildItem -LiteralPath $projectRoot -File -Filter '*.log' |
    Move-Item -Destination $logDir

$mainLog = Join-Path $logDir 'run_all.log'
if (-not (Test-Path -LiteralPath $mainLog -PathType Leaf)) {
    throw 'Stata did not produce run_all.log.'
}
$passed = Select-String -LiteralPath $mainLog `
    -SimpleMatch 'usebcch offline suite: all tests passed' -Quiet
if (-not $passed) {
    throw "usebcch tests failed; inspect $mainLog"
}

Write-Output "usebcch offline suite passed (process exit $($process.ExitCode))."
Write-Output "Logs: $logDir"
