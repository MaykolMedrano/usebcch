[CmdletBinding()]
param(
    [string]$OutputRoot,
    [switch]$Archive
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $projectRoot 'dist'
} elseif (-not [System.IO.Path]::IsPathRooted($OutputRoot)) {
    $OutputRoot = Join-Path $projectRoot $OutputRoot
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)

$packageName = 'usebcch'
$stataRoot = Join-Path $projectRoot 'stata'
$packageFile = Join-Path $stataRoot "$packageName.pkg"
$packageLines = Get-Content -LiteralPath $packageFile -Encoding UTF8
$versionLine = $packageLines | Where-Object { $_ -match '^d\s+Version:?\s+(\S+)\s*$' } |
    Select-Object -First 1
if (-not $versionLine) {
    throw "Version declaration was not found in $packageFile"
}
$version = ([regex]::Match($versionLine, '^d\s+Version:?\s+(\S+)\s*$')).Groups[1].Value
$releaseDir = Join-Path $OutputRoot "$packageName-$version"
$zipPath = "$releaseDir.zip"
$manifestFiles = @($packageLines | ForEach-Object {
    if ($_ -match '^[fF]\s+(.+?)\s*$') { "stata/$($Matches[1])" }
})
$installFiles = @('stata/stata.toc', "stata/$packageName.pkg") + $manifestFiles
$documentationFiles = @('README.md', 'CHANGELOG.md', 'LICENSE',
    'stata/docs/GUIA_USUARIO.md', 'stata/docs/DISTRIBUTION.md')
$files = $installFiles + $documentationFiles
$files = @($files | Select-Object -Unique)

if ($Archive) {
    if (-not (Test-Path -LiteralPath $releaseDir -PathType Container)) {
        throw "Stage and validate the release directory before creating its archive: $releaseDir"
    }
    if (Test-Path -LiteralPath $zipPath) {
        throw "Release archive already exists: $zipPath"
    }

    $expectedFiles = @($files + 'SHA256SUMS.txt')
    $actualFiles = @(Get-ChildItem -LiteralPath $releaseDir -Recurse -File |
        ForEach-Object { $_.FullName.Substring($releaseDir.Length + 1).Replace('\', '/') })
    $missingFiles = @($expectedFiles | Where-Object { $_ -notin $actualFiles })
    $unexpectedFiles = @($actualFiles | Where-Object { $_ -notin $expectedFiles })
    if ($missingFiles.Count -or $unexpectedFiles.Count) {
        throw "Release contents changed after staging. Missing: $($missingFiles -join ', '); unexpected: $($unexpectedFiles -join ', ')"
    }

    $storedChecksums = Get-Content -LiteralPath (Join-Path $releaseDir 'SHA256SUMS.txt')
    foreach ($file in $files) {
        $item = Join-Path $releaseDir $file
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item).Hash.ToLowerInvariant()
        if ("$hash *$file" -notin $storedChecksums) {
            throw "Checksum verification failed after staging: $file"
        }
    }

    Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zipPath
    Write-Output "Validated release directory: $releaseDir"
    Write-Output "Release archive:            $zipPath"
    return
}

if (Test-Path -LiteralPath $releaseDir) {
    throw "Release directory already exists: $releaseDir"
}

New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
foreach ($file in $files) {
    $source = Join-Path $projectRoot $file
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required distribution file is missing: $source"
    }
    $destination = Join-Path $releaseDir $file
    $destinationDir = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
}

$checksums = foreach ($file in $files) {
    $item = Join-Path $releaseDir $file
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item).Hash.ToLowerInvariant()
    "$hash *$file"
}
$checksums | Set-Content -LiteralPath (Join-Path $releaseDir 'SHA256SUMS.txt') -Encoding ascii

Write-Output "Release directory: $releaseDir"
Write-Output 'Release archive:   not created (validate first, then use -Archive)'
