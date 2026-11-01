[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $true)]
    [string]$ExecutablePath,
    [Parameter(Mandatory = $true)]
    [string]$OpenSslDependenciesDirectory,
    [Parameter(Mandatory = $true)]
    [string]$SqlitePath,
    [string]$SimpleBleDependenciesDirectory = '',
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
$bleRuntimeNames = @('simplecble.dll', 'simpleble.dll')
$requiredBleDependencies = @(
    $manifest.runtime_files |
        Where-Object { $_.name -in $bleRuntimeNames } |
        ForEach-Object { $_.name } |
        Sort-Object -Unique
)
if ($requiredBleDependencies.Count -notin @(0, 2)) {
    throw 'The dependency manifest must contain both SimpleBLE runtime DLLs or neither of them.'
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

if (-not (Test-Path $ExecutablePath)) {
    throw "Release build did not produce $ExecutablePath."
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
foreach ($fileName in $requiredBleDependencies) {
    $sourcePath = Join-Path $SimpleBleDependenciesDirectory $fileName
    if (-not (Test-Path $sourcePath)) {
        throw "Required dependency is missing: $sourcePath"
    }
    Assert-ExpectedHash $sourcePath $fileName
    Assert-PeX64 $sourcePath
}

# Older report tags need their bundled fonts; current sources use system fonts.
$reportFonts = @()
if (Test-Path -LiteralPath 'resources/fonts' -PathType Container) {
    $reportFonts = @('LiberationSans-Regular.ttf', 'LiberationSans-Bold.ttf', 'LICENSE.txt')
    foreach ($name in $reportFonts) {
        if (-not (Test-Path -LiteralPath (Join-Path 'resources/fonts' $name) -PathType Leaf)) {
            throw "Required report font resource is missing: $name"
        }
    }
}
$expectedFontEntries = @($reportFonts | ForEach-Object { "fonts/$_" })

# Templates are external files beside the executable; older source tags have none.
$reportTemplates = @()
if (Test-Path -LiteralPath 'templates/reports' -PathType Container) {
    $reportTemplates = @(Get-ChildItem -LiteralPath 'templates/reports' -File |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.html', '.htm') } |
        Sort-Object Name)
    if ($reportTemplates.Count -eq 0) {
        throw 'The report templates directory contains no HTML templates.'
    }
}
$labelTemplates = @()
if (Test-Path -LiteralPath 'templates/labels' -PathType Container) {
    $labelTemplates = @(Get-ChildItem -LiteralPath 'templates/labels' -File |
        Where-Object { $_.Extension.ToLowerInvariant() -eq '.ini' } |
        Sort-Object Name)
    if ($labelTemplates.Count -eq 0) {
        throw 'The label templates directory contains no INI templates.'
    }
}
$expectedTemplateEntries = @($reportTemplates | ForEach-Object { "templates/reports/$($_.Name)" }) +
    @($labelTemplates | ForEach-Object { "templates/labels/$($_.Name)" })

$archiveBaseName = "Entime-$Tag-win-x64"
$stageDirectory = Join-Path $OutputDirectory "$archiveBaseName-stage"
$archivePath = Join-Path $OutputDirectory "$archiveBaseName.zip"
$checksumPath = "$archivePath.sha256"
Remove-Item -Recurse -Force $stageDirectory -ErrorAction SilentlyContinue
Remove-Item -Force $archivePath, $checksumPath -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stageDirectory | Out-Null

Copy-Item $ExecutablePath (Join-Path $stageDirectory 'Entime.exe')
foreach ($fileName in $requiredOpenSslDependencies) {
    Copy-Item (Join-Path $OpenSslDependenciesDirectory $fileName) (Join-Path $stageDirectory $fileName)
}
if (-not (Test-Path $SqlitePath)) {
    throw "SQLite DLL is missing: $SqlitePath"
}
Assert-ExpectedHash $SqlitePath 'sqlite3.dll'
Copy-Item $SqlitePath (Join-Path $stageDirectory 'sqlite3.dll')
foreach ($fileName in $requiredBleDependencies) {
    Copy-Item (Join-Path $SimpleBleDependenciesDirectory $fileName) (Join-Path $stageDirectory $fileName)
}
$languagesStageDirectory = Join-Path $stageDirectory 'languages'
New-Item -ItemType Directory -Force $languagesStageDirectory | Out-Null
foreach ($languageFile in $languageFiles) {
    $relative = [IO.Path]::GetRelativePath($languagesRoot, $languageFile.FullName)
    $destination = Join-Path $languagesStageDirectory $relative
    New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($destination)) | Out-Null
    Copy-Item $languageFile.FullName $destination
}

if ($reportFonts.Count -gt 0) {
    $fontStageDirectory = Join-Path $stageDirectory 'fonts'
    New-Item -ItemType Directory -Force $fontStageDirectory | Out-Null
    foreach ($name in $reportFonts) {
        Copy-Item -LiteralPath (Join-Path 'resources/fonts' $name) -Destination (Join-Path $fontStageDirectory $name)
    }
}

if ($reportTemplates.Count -gt 0) {
    $templateStageDirectory = Join-Path $stageDirectory 'templates/reports'
    New-Item -ItemType Directory -Force $templateStageDirectory | Out-Null
    foreach ($template in $reportTemplates) {
        Copy-Item -LiteralPath $template.FullName -Destination (Join-Path $templateStageDirectory $template.Name)
    }
}

if ($labelTemplates.Count -gt 0) {
    $labelStageDirectory = Join-Path $stageDirectory 'templates/labels'
    New-Item -ItemType Directory -Force $labelStageDirectory | Out-Null
    foreach ($template in $labelTemplates) {
        Copy-Item -LiteralPath $template.FullName -Destination (Join-Path $labelStageDirectory $template.Name)
    }
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
$requiredArchivePaths = @(
    'Entime.exe',
    'libcrypto-3-x64.dll',
    'libssl-3-x64.dll',
    'sqlite3.dll'
) + $requiredBleDependencies + $expectedFontEntries + $expectedTemplateEntries
foreach ($requiredPath in $requiredArchivePaths) {
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
$actualTemplateEntries = @($normalizedArchiveEntries |
    Where-Object { $_ -like 'templates/*' -and -not $_.EndsWith('/') } |
    Sort-Object)
if (($expectedTemplateEntries.Count -ne $actualTemplateEntries.Count) -or
    (($expectedTemplateEntries.Count -gt 0) -and
        (@(Compare-Object $expectedTemplateEntries $actualTemplateEntries).Count -ne 0))) {
    throw 'Archive report templates do not match the source templates.'
}
if ($actualLanguageEntries | Where-Object { $_ -match '\.(?:mo|pot)$' }) {
    throw 'Runtime archive must not contain MO catalogs or POT templates.'
}
if ($normalizedArchiveEntries | Where-Object { $_ -like 'sql/*' }) {
    throw 'Runtime archive must not contain the build-time SQL schema.'
}
$allowedRoots = @(
    'Entime.exe',
    'libcrypto-3-x64.dll',
    'libssl-3-x64.dll',
    'sqlite3.dll',
    'languages',
    'fonts',
    'templates',
    'samples'
) + $requiredBleDependencies
foreach ($entry in $archiveEntries) {
    $root = (($entry -replace '\\', '/') -split '/')[0]
    if ($root -and $root -notin $allowedRoots) {
        throw "Archive contains unexpected top-level entry $root."
    }
}

$verificationDirectory = Join-Path $OutputDirectory "$archiveBaseName-verify"
Remove-Item -Recurse -Force $verificationDirectory -ErrorAction SilentlyContinue
Expand-Archive $archivePath -DestinationPath $verificationDirectory -Force
foreach ($name in $reportFonts) {
    $source = Join-Path 'resources/fonts' $name
    $extracted = Join-Path (Join-Path $verificationDirectory 'fonts') $name
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $extracted -Algorithm SHA256).Hash) {
        throw "Packaged report font resource differs from source: $name"
    }
}
foreach ($template in $reportTemplates) {
    $extracted = Join-Path $verificationDirectory "templates/reports/$($template.Name)"
    if ((Get-FileHash -LiteralPath $template.FullName -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $extracted -Algorithm SHA256).Hash) {
        throw "Packaged report template differs from source: $($template.Name)"
    }
}
foreach ($template in $labelTemplates) {
    $extracted = Join-Path $verificationDirectory "templates/labels/$($template.Name)"
    if ((Get-FileHash -LiteralPath $template.FullName -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $extracted -Algorithm SHA256).Hash) {
        throw "Packaged label template differs from source: $($template.Name)"
    }
}
$extractedExecutable = Join-Path $verificationDirectory 'Entime.exe'
Assert-PeX64 $extractedExecutable
foreach ($runtimeName in @('libcrypto-3-x64.dll', 'libssl-3-x64.dll', 'sqlite3.dll') + $requiredBleDependencies) {
    Assert-ExpectedHash (Join-Path $verificationDirectory $runtimeName) $runtimeName
}
foreach ($runtimeName in $requiredBleDependencies) {
    Assert-PeX64 (Join-Path $verificationDirectory $runtimeName)
}
Remove-Item -Recurse -Force $verificationDirectory
Write-Host "Created $archivePath"
