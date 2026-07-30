[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $true)]
    [string]$OpenSslDependenciesDirectory,
    [Parameter(Mandatory = $true)]
    [string]$SqlitePath,
    [Parameter(Mandatory = $true)]
    [string]$DependencyManifestPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$requiredOpenSslDependencies = @('libcrypto-3-x64.dll', 'libssl-3-x64.dll')
$sampleFiles = @(Get-ChildItem -Path '.' -File -Filter '*.csv' | Sort-Object Name)
if ($sampleFiles.Count -eq 0) {
    throw 'The project root contains no sample CSV files.'
}
Write-Host "Sample CSV files included in the release ($($sampleFiles.Count)):"
foreach ($sampleFile in $sampleFiles) {
    Write-Host "  - $($sampleFile.Name)"
}
$expectedSampleEntries = @(
    $sampleFiles | ForEach-Object { "samples/$($_.Name)" }
)
$manifest = Get-Content -Raw $DependencyManifestPath | ConvertFrom-Json
if (-not $manifest.runtime_files) {
    throw 'The dependency manifest has no runtime DLL hashes.'
}

function Assert-ExpectedHash([string]$Path, [string]$Name) {
    $entry = @($manifest.runtime_files | Where-Object { $_.name -eq $Name })
    if ($entry.Count -ne 1 -or -not $entry[0].sha256) {
        throw "The dependency manifest must contain exactly one SHA-256 for $Name."
    }
    $actual = (Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry[0].sha256.ToLowerInvariant()) {
        throw "SHA-256 mismatch for runtime dependency $Name."
    }
}

function Assert-PeX64([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5a4d) {
            throw "$Path is not a Windows PE executable."
        }
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        if ($peOffset -lt 0x40 -or $peOffset -gt ($stream.Length - 6)) {
            throw "$Path has an invalid PE header offset."
        }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) {
            throw "$Path has no PE signature."
        }
        if ($reader.ReadUInt16() -ne 0x8664) {
            throw "$Path is not a Windows x64 executable."
        }
    } finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

if (-not (Test-Path 'release/Entime.exe')) {
    throw 'Release build did not produce release/Entime.exe.'
}
if (-not (Test-Path 'languages')) {
    throw 'The languages directory is missing.'
}
$languagesRoot = (Resolve-Path 'languages').Path
$languageFiles = @(Get-ChildItem $languagesRoot -Recurse -File -Filter '*.po')
if ($languageFiles.Count -eq 0) {
    throw 'The languages directory contains no PO translation files.'
}
$expectedLanguageEntries = @(
    $languageFiles | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($languagesRoot, $_.FullName).Replace('\', '/')
        "languages/$relative"
    } | Sort-Object
)

foreach ($fileName in $requiredOpenSslDependencies) {
    $sourcePath = Join-Path $OpenSslDependenciesDirectory $fileName
    if (-not (Test-Path $sourcePath)) {
        throw "Required dependency is missing: $sourcePath"
    }
    Assert-ExpectedHash $sourcePath $fileName
}

$archiveBaseName = "Entime-$Tag-win-x64"
$stageDirectory = Join-Path $OutputDirectory "$archiveBaseName-stage"
$archivePath = Join-Path $OutputDirectory "$archiveBaseName.zip"
$checksumPath = "$archivePath.sha256"
Remove-Item -Recurse -Force $stageDirectory -ErrorAction SilentlyContinue
Remove-Item -Force $archivePath, $checksumPath -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stageDirectory | Out-Null

Copy-Item 'release/Entime.exe' (Join-Path $stageDirectory 'Entime.exe')
foreach ($fileName in $requiredOpenSslDependencies) {
    Copy-Item (Join-Path $OpenSslDependenciesDirectory $fileName) (Join-Path $stageDirectory $fileName)
}
if (-not (Test-Path $SqlitePath)) {
    throw "SQLite DLL is missing: $SqlitePath"
}
Assert-ExpectedHash $SqlitePath 'sqlite3.dll'
Copy-Item $SqlitePath (Join-Path $stageDirectory 'sqlite3.dll')
$languagesStageDirectory = Join-Path $stageDirectory 'languages'
New-Item -ItemType Directory -Force $languagesStageDirectory | Out-Null
foreach ($languageFile in $languageFiles) {
    $relative = [IO.Path]::GetRelativePath($languagesRoot, $languageFile.FullName)
    $destination = Join-Path $languagesStageDirectory $relative
    New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($destination)) | Out-Null
    Copy-Item $languageFile.FullName $destination
}

$samplesDirectory = Join-Path $stageDirectory 'samples'
New-Item -ItemType Directory -Force $samplesDirectory | Out-Null
foreach ($sampleFile in $sampleFiles) {
    Copy-Item $sampleFile.FullName (Join-Path $samplesDirectory $sampleFile.Name)
}

Compress-Archive -Path (Join-Path $stageDirectory '*') -DestinationPath $archivePath -CompressionLevel Optimal
$archiveHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
"$archiveHash  $([System.IO.Path]::GetFileName($archivePath))" |
    Set-Content -Path $checksumPath -Encoding ascii -NoNewline

$archiveEntries = @(tar -tf $archivePath)
if ($archiveEntries | Where-Object { $_ -match '(^|/)Entime-[^/]+-win-x64-stage/' }) {
    throw 'Archive contains an unexpected staging-directory prefix.'
}
foreach ($requiredPath in @('Entime.exe', 'libcrypto-3-x64.dll', 'libssl-3-x64.dll', 'sqlite3.dll')) {
    if ($archiveEntries -notcontains $requiredPath) {
        throw "Archive is missing $requiredPath."
    }
}
$normalizedArchiveEntries = @($archiveEntries | ForEach-Object { $_ -replace '\\', '/' })
$actualSampleEntries = @(
    $normalizedArchiveEntries |
        Where-Object { $_ -like 'samples/*' -and -not $_.EndsWith('/') } |
        Sort-Object
)
$sampleDifference = @(Compare-Object $expectedSampleEntries $actualSampleEntries)
if ($sampleDifference.Count -ne 0) {
    $sampleDifference | Format-Table | Out-String | Write-Host
    throw 'Archive sample CSV files do not match the current project root CSV files.'
}
$actualLanguageEntries = @(
    $normalizedArchiveEntries |
        Where-Object { $_ -like 'languages/*' -and -not $_.EndsWith('/') } |
        Sort-Object
)
$languageDifference = @(Compare-Object $expectedLanguageEntries $actualLanguageEntries)
if ($languageDifference.Count -ne 0) {
    $languageDifference | Format-Table | Out-String | Write-Host
    throw 'Archive PO files do not match the current project translations.'
}
if ($actualLanguageEntries | Where-Object { $_ -match '\.(?:mo|pot)$' }) {
    throw 'Runtime archive must not contain MO catalogs or POT templates.'
}
$allowedRoots = @('Entime.exe', 'libcrypto-3-x64.dll', 'libssl-3-x64.dll', 'sqlite3.dll', 'languages', 'samples')
foreach ($entry in $archiveEntries) {
    $root = (($entry -replace '\\', '/') -split '/')[0]
    if ($root -and $root -notin $allowedRoots) {
        throw "Archive contains unexpected top-level entry $root."
    }
}

$verificationDirectory = Join-Path $OutputDirectory "$archiveBaseName-verify"
Remove-Item -Recurse -Force $verificationDirectory -ErrorAction SilentlyContinue
Expand-Archive $archivePath -DestinationPath $verificationDirectory -Force
$extractedExecutable = Join-Path $verificationDirectory 'Entime.exe'
Assert-PeX64 $extractedExecutable
foreach ($runtimeName in @('libcrypto-3-x64.dll', 'libssl-3-x64.dll', 'sqlite3.dll')) {
    Assert-ExpectedHash (Join-Path $verificationDirectory $runtimeName) $runtimeName
}
Remove-Item -Recurse -Force $verificationDirectory
Write-Host "Created $archivePath"
