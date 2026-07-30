[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$DependenciesDirectory,
    [Parameter(Mandatory = $true)] [string]$Tag
)

$ErrorActionPreference = 'Stop'

function Assert-ChecksumFile(
    [string]$FilePath,
    [string]$ChecksumPath,
    [string]$ExpectedName
) {
    if (-not (Test-Path $FilePath) -or -not (Test-Path $ChecksumPath)) {
        throw "Missing file or checksum for $ExpectedName."
    }
    $checksumText = (Get-Content -Raw $ChecksumPath).Trim()
    $pattern = '(?i)^([0-9a-f]{64})\s+\*?' + [regex]::Escape($ExpectedName) + '$'
    if ($checksumText -notmatch $pattern) {
        throw "Checksum file for $ExpectedName has an invalid format."
    }
    $actual = (Get-FileHash $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Matches[1].ToLowerInvariant()) {
        throw "SHA-256 mismatch for $ExpectedName."
    }
}

$dependencyArchive = Join-Path $DependenciesDirectory 'lazarus-dependencies.zip'
$dependencyChecksum = Join-Path $DependenciesDirectory 'lazarus-dependencies.zip.sha256'
$publishedName = "Entime-$Tag-win-x64.zip"
$publishedArchive = Join-Path $DependenciesDirectory $publishedName
$publishedChecksum = "$publishedArchive.sha256"
$manifestPath = Join-Path $DependenciesDirectory 'build-dependencies.json'

Assert-ChecksumFile $dependencyArchive $dependencyChecksum 'lazarus-dependencies.zip'
Assert-ChecksumFile $publishedArchive $publishedChecksum $publishedName
Expand-Archive $dependencyArchive -DestinationPath $DependenciesDirectory -Force

if (-not (Test-Path $manifestPath)) {
    throw 'The locked dependency manifest is missing.'
}
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
if (-not $manifest.runtime_files) {
    throw 'The locked dependency manifest has no runtime DLL hashes.'
}
$currentSourceCommit = (git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $currentSourceCommit -ne $manifest.build_environment.source_commit) {
    throw "Checked out source $currentSourceCommit does not match the locked source commit $($manifest.build_environment.source_commit)."
}
$currentGit = (git --version).Trim()
if ($manifest.toolchain.git -and $currentGit -ne $manifest.toolchain.git) {
    Write-Warning "Runner Git differs from the recorded environment: '$currentGit' instead of '$($manifest.toolchain.git)'."
}
$environmentNotes = @()
foreach ($comparison in @(
    @{ name = 'runner OS'; current = $env:RUNNER_OS; locked = $manifest.build_environment.runner_os },
    @{ name = 'runner architecture'; current = $env:RUNNER_ARCH; locked = $manifest.build_environment.runner_arch },
    @{ name = 'runner image OS'; current = $env:ImageOS; locked = $manifest.build_environment.image_os },
    @{ name = 'runner image version'; current = $env:ImageVersion; locked = $manifest.build_environment.image_version }
)) {
    if ($comparison.locked -and $comparison.current -ne $comparison.locked) {
        $environmentNotes += "$($comparison.name): current ``$($comparison.current)``, recorded ``$($comparison.locked)``"
    }
}
if ($environmentNotes.Count -gt 0 -and $env:GITHUB_STEP_SUMMARY) {
    $environmentSummary = @(
        '## Rebuild environment differences',
        '',
        'These runner metadata differences are recorded for audit and do not change the locked Lazarus, FPC, package or DLL versions.',
        ''
    ) + @($environmentNotes | ForEach-Object { "- $_" })
    $environmentSummary | Add-Content $env:GITHUB_STEP_SUMMARY
}

foreach ($package in $manifest.packages) {
    if ($package.source -eq 'git') {
        if (
            -not $package.repository -or
            -not $package.branch -or
            $package.commit -notmatch '^[0-9a-f]{40}$'
        ) {
            throw "Locked Git metadata for package $($package.name) is incomplete."
        }
    }
    $archivePath = Join-Path (Join-Path $DependenciesDirectory 'lazarus') $package.archive
    if (-not (Test-Path $archivePath)) {
        throw "Locked package archive $($package.archive) is missing."
    }
    $actual = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $package.sha256.ToLowerInvariant()) {
        throw "SHA-256 mismatch for locked package archive $($package.archive)."
    }
}

$runtimePaths = @{
    'libcrypto-3-x64.dll' = Join-Path $DependenciesDirectory 'openssl/dll/libcrypto-3-x64.dll'
    'libssl-3-x64.dll' = Join-Path $DependenciesDirectory 'openssl/dll/libssl-3-x64.dll'
    'sqlite3.dll' = Join-Path $DependenciesDirectory 'sqlite/sqlite3.dll'
}
foreach ($runtimeFile in $manifest.runtime_files) {
    if (-not $runtimePaths.ContainsKey($runtimeFile.name)) {
        throw "Unexpected runtime file '$($runtimeFile.name)' in the locked manifest."
    }
    $path = $runtimePaths[$runtimeFile.name]
    if (-not (Test-Path $path)) {
        throw "Locked runtime file $($runtimeFile.name) is missing."
    }
    $actual = (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $runtimeFile.sha256.ToLowerInvariant()) {
        throw "SHA-256 mismatch for locked runtime file $($runtimeFile.name)."
    }
}
foreach ($name in $runtimePaths.Keys) {
    if (-not ($manifest.runtime_files | Where-Object { $_.name -eq $name })) {
        throw "The locked manifest has no SHA-256 for $name."
    }
}

Write-Host "Verified locked dependencies and published archive for $Tag."
