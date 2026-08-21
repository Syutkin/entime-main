[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$DependenciesDirectory,
    [Parameter(Mandatory = $true)] [string]$OpenSslDirectory,
    [Parameter(Mandatory = $true)] [string]$SqliteDirectory,
    [string]$SimpleBleDirectory = '',
    [Parameter(Mandatory = $true)] [string]$OutputDirectory,
    [Parameter(Mandatory = $true)] [string]$GitVersion,
    [Parameter(Mandatory = $true)] [string]$AutomationCommit,
    [Parameter(Mandatory = $true)] [string]$SourceCommit
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$manifest = Get-Content -Raw (Join-Path $DependenciesDirectory 'build-dependencies.json') | ConvertFrom-Json
$manifest.schema = 3
$manifest.toolchain | Add-Member -Force -NotePropertyName git -NotePropertyValue $GitVersion
$manifest | Add-Member -Force -NotePropertyName build_environment -NotePropertyValue ([ordered]@{
    runner_os = $env:RUNNER_OS
    runner_arch = $env:RUNNER_ARCH
    image_os = $env:ImageOS
    image_version = $env:ImageVersion
    automation_commit = $AutomationCommit
    source_commit = $SourceCommit
    workflow_ref = $env:GITHUB_WORKFLOW_REF
})
$runtimeMetadata = [ordered]@{
    openssl = (Get-Content -Raw (Join-Path $OpenSslDirectory 'openssl-dependency.json') | ConvertFrom-Json)
    sqlite = (Get-Content -Raw (Join-Path $SqliteDirectory 'sqlite-dependency.json') | ConvertFrom-Json)
}
$runtimeInputs = @(
    @{ name = 'libcrypto-3-x64.dll'; path = (Join-Path $OpenSslDirectory 'dll/libcrypto-3-x64.dll'); source = 'openssl' },
    @{ name = 'libssl-3-x64.dll'; path = (Join-Path $OpenSslDirectory 'dll/libssl-3-x64.dll'); source = 'openssl' },
    @{ name = 'sqlite3.dll'; path = (Join-Path $SqliteDirectory 'sqlite3.dll'); source = 'sqlite' }
)
if ($SimpleBleDirectory) {
    $simpleBleMetadataPath = Join-Path $SimpleBleDirectory 'simpleble-dependency.json'
    if (-not (Test-Path $simpleBleMetadataPath)) {
        throw "SimpleBLE dependency metadata is missing: $simpleBleMetadataPath"
    }
    $runtimeMetadata['simpleble'] = Get-Content -Raw $simpleBleMetadataPath | ConvertFrom-Json
    $runtimeInputs += @(
        @{ name = 'simplecble.dll'; path = (Join-Path $SimpleBleDirectory 'simplecble.dll'); source = 'simpleble' },
        @{ name = 'simpleble.dll'; path = (Join-Path $SimpleBleDirectory 'simpleble.dll'); source = 'simpleble' }
    )
}
$manifest | Add-Member -NotePropertyName runtime -NotePropertyValue $runtimeMetadata -Force
$runtimeFiles = @(
    foreach ($runtime in $runtimeInputs) {
        if (-not (Test-Path $runtime.path)) {
            throw "Runtime dependency $($runtime.name) is missing."
        }
        [ordered]@{
            name = $runtime.name
            source = $runtime.source
            sha256 = (Get-FileHash $runtime.path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
)
$manifest | Add-Member -Force -NotePropertyName runtime_files -NotePropertyValue $runtimeFiles
$manifestPath = Join-Path $OutputDirectory 'build-dependencies.json'
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding utf8

# The archive contains the verified OPM and Git source ZIPs, not their expanded
# duplicate source trees. A rebuild verifies and expands them again.
$staging = Join-Path $env:RUNNER_TEMP 'build-dependency-asset'
Remove-Item -Force -Recurse $staging -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $staging | Out-Null
$lazarusStaging = Join-Path $staging 'lazarus'
New-Item -ItemType Directory -Force $lazarusStaging | Out-Null
Get-ChildItem -Path $DependenciesDirectory -File -Filter '*.zip' |
    Copy-Item -Destination $lazarusStaging -Force
$openSslStaging = Join-Path $staging 'openssl/dll'
New-Item -ItemType Directory -Force $openSslStaging | Out-Null
foreach ($dll in @('libcrypto-3-x64.dll', 'libssl-3-x64.dll')) {
    Copy-Item -Force (Join-Path $OpenSslDirectory "dll/$dll") (Join-Path $openSslStaging $dll)
}
$sqliteStaging = Join-Path $staging 'sqlite'
New-Item -ItemType Directory -Force $sqliteStaging | Out-Null
Copy-Item -Force (Join-Path $SqliteDirectory 'sqlite3.dll') (Join-Path $sqliteStaging 'sqlite3.dll')
if ($SimpleBleDirectory) {
    $simpleBleStaging = Join-Path $staging 'simpleble/dll'
    New-Item -ItemType Directory -Force $simpleBleStaging | Out-Null
    foreach ($dll in @('simplecble.dll', 'simpleble.dll')) {
        Copy-Item -Force (Join-Path $SimpleBleDirectory $dll) (Join-Path $simpleBleStaging $dll)
    }
}
Copy-Item -Force $manifestPath (Join-Path $staging 'build-dependencies.json')
$archive = Join-Path $OutputDirectory 'lazarus-dependencies.zip'
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $archive -Force
$archiveHash = (Get-FileHash -Path $archive -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -Path "$archive.sha256" -Value "$archiveHash  lazarus-dependencies.zip" -Encoding ascii
