[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$OutputDirectory,
    [string]$LockFile,
    [switch]$ResolveOnly
)

$ErrorActionPreference = 'Stop'
$checksumUrl = 'https://www.lazarus-ide.org/index.php?page=checksums'
$installDirectory = 'C:\lazarus'
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null

if ($LockFile) {
    Write-Host 'Lazarus toolchain: resolving locked installer'
    $lock = Get-Content -Raw $LockFile | ConvertFrom-Json
    $release = $lock.toolchain.lazarus
    if (-not $release -or -not $release.url -or -not $release.sha256) {
        throw 'The locked dependency manifest has no official Lazarus installer metadata.'
    }
    $fileName = $release.file
    $downloadUrl = $release.url
    $expectedHash = $release.sha256.ToLowerInvariant()
} else {
    Write-Host 'Lazarus toolchain: resolving latest official release'
    $page = (Invoke-WebRequest -Uri $checksumUrl -UseBasicParsing).Content
    $plainText = [System.Net.WebUtility]::HtmlDecode([regex]::Replace($page, '(?s)<[^>]+>', ' '))
    $releaseMatch = [regex]::Match($plainText, 'Lazarus\s+(\d+(?:\.\d+)+)')
    if (-not $releaseMatch.Success) { throw 'Could not determine the latest official Lazarus release.' }
    $version = $releaseMatch.Groups[1].Value
    $fileMatch = [regex]::Match($plainText, '([a-fA-F0-9]{64})\s+([^\s<]*lazarus-' + [regex]::Escape($version) + '-fpc-[^\s<]*-win64\.exe)')
    if (-not $fileMatch.Success) { throw "Could not find the SHA-256 for the official Lazarus $version Win64 installer." }
    $expectedHash = $fileMatch.Groups[1].Value.ToLowerInvariant()
    $fileName = $fileMatch.Groups[2].Value
    # Official Lazarus CDN. SourceForge download URLs can serve a Cloudflare
    # challenge page to GitHub-hosted runners instead of the installer.
    $downloadUrl = 'https://download.lazarus-ide.org/Lazarus%20Windows%2064%20bits/Lazarus%20{0}/{1}' -f $version, $fileName
}
Write-Host "Resolved installer: $fileName"

if ($ResolveOnly) {
    if ($env:GITHUB_OUTPUT) {
        "file=$fileName" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        "sha256=$expectedHash" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }
    Write-Output $expectedHash
    exit 0
}

$outputMetadataPath = Join-Path $OutputDirectory 'lazarus-toolchain.json'
$installedMetadataPath = Join-Path $installDirectory 'entime-toolchain.json'
if (Test-Path $installedMetadataPath) {
    try {
        $cachedMetadata = Get-Content -Raw $installedMetadataPath | ConvertFrom-Json
        $cacheValid = (
            $cachedMetadata.sha256 -and
            $cachedMetadata.sha256.ToLowerInvariant() -eq $expectedHash
        )
        $lazbuild = Get-ChildItem -Path $installDirectory -Filter lazbuild.exe -Recurse |
            Select-Object -First 1
        $fpc = Get-ChildItem -Path $installDirectory -Filter fpc.exe -Recurse |
            Select-Object -First 1
        if ($cacheValid -and $lazbuild -and $fpc) {
            $lazbuildVersion = (& $lazbuild.FullName --version | Out-String).Trim()
            $fpcVersion = (& $fpc.FullName -iV | Out-String).Trim()
            $cacheValid = (
                $lazbuildVersion -eq $cachedMetadata.lazbuild -and
                $fpcVersion -eq $cachedMetadata.fpc
            )
        } else {
            $cacheValid = $false
        }
        if ($cacheValid) {
            Write-Host "Installed toolchain cache: hit ($lazbuildVersion, FPC $fpcVersion)"
            Copy-Item $installedMetadataPath $outputMetadataPath -Force
            $lazbuild.DirectoryName | Out-File -FilePath $env:GITHUB_PATH -Append -Encoding utf8
            $fpc.DirectoryName | Out-File -FilePath $env:GITHUB_PATH -Append -Encoding utf8
            "LAZARUS_TOOLCHAIN_DIRECTORY=$OutputDirectory" |
                Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
            Write-Host 'Lazarus toolchain is ready'
            exit 0
        }
        Write-Warning 'Installed Lazarus cache is incomplete or does not match the resolved installer.'
    } catch {
        Write-Warning "Installed Lazarus cache validation failed: $($_.Exception.Message)"
    }
}
Write-Host 'Installed toolchain cache: miss'

$installerPath = Join-Path $OutputDirectory $fileName
Write-Host "Downloading official Lazarus installer: $fileName"
Write-Host "Source: $downloadUrl"
$downloadStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& curl.exe --fail --location --retry 3 --retry-all-errors --silent --show-error `
    --user-agent 'Mozilla/5.0' --output $installerPath $downloadUrl
if ($LASTEXITCODE -ne 0) { throw "Could not download official Lazarus installer $fileName." }
$downloadStopwatch.Stop()
$downloadedSize = (Get-Item $installerPath).Length / 1MB
Write-Host ('Download completed in {0:N0} seconds ({1:N1} MiB)' -f `
    $downloadStopwatch.Elapsed.TotalSeconds, $downloadedSize)
$size = (Get-Item $installerPath).Length
if ($size -lt 100MB) { throw "Downloaded Lazarus file is unexpectedly small ($size bytes), probably not an installer: $downloadUrl" }
Write-Host 'Verifying installer SHA-256...'
$actualHash = (Get-FileHash $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $expectedHash) { throw "SHA-256 mismatch for official Lazarus installer $fileName. Expected $expectedHash, got $actualHash." }
Write-Host 'Installer SHA-256: OK'

Write-Host 'Verifying installer Authenticode signature...'
$signature = Get-AuthenticodeSignature $installerPath
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Programming Free Pascal.*Lazarus Foundation') {
    throw "The Lazarus installer signature is not from the Free Pascal & Lazarus Foundation: $($signature.Status)."
}
Write-Host "Authenticode signature: OK ($($signature.SignerCertificate.Subject))"

Write-Host "Installing Lazarus to $installDirectory..."
$installStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$process = Start-Process -FilePath $installerPath -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/DIR=`"$installDirectory`"") -PassThru
while (-not $process.WaitForExit(60000)) {
    Write-Host ('Lazarus installer is still running ({0:N0} seconds elapsed)...' -f `
        $installStopwatch.Elapsed.TotalSeconds)
}
$installStopwatch.Stop()
if ($process.ExitCode -ne 0) { throw "Lazarus installer exited with code $($process.ExitCode)." }
Write-Host ('Installation completed in {0:N0} seconds' -f $installStopwatch.Elapsed.TotalSeconds)
$lazbuild = Get-ChildItem -Path $installDirectory -Filter lazbuild.exe -Recurse | Select-Object -First 1
if (-not $lazbuild) { throw 'Official Lazarus installer completed, but lazbuild.exe was not found.' }
$fpc = Get-ChildItem -Path $installDirectory -Filter fpc.exe -Recurse | Select-Object -First 1
if (-not $fpc) { throw 'Official Lazarus installer completed, but fpc.exe was not found.' }
$lazbuildVersion = (& $lazbuild.FullName --version | Out-String).Trim()
$fpcVersion = (& $fpc.FullName -iV | Out-String).Trim()
Write-Host "Detected lazbuild: $lazbuildVersion"
Write-Host "Detected FPC: $fpcVersion"

$metadata = [ordered]@{
    file = $fileName; url = $downloadUrl; sha256 = $expectedHash
    lazbuild = $lazbuildVersion
    fpc = $fpcVersion
}
$metadata | ConvertTo-Json | Set-Content -Path $installedMetadataPath -Encoding utf8
Copy-Item $installedMetadataPath $outputMetadataPath -Force
$lazbuild.DirectoryName | Out-File -FilePath $env:GITHUB_PATH -Append -Encoding utf8
$fpc.DirectoryName | Out-File -FilePath $env:GITHUB_PATH -Append -Encoding utf8
"LAZARUS_TOOLCHAIN_DIRECTORY=$OutputDirectory" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
Write-Host 'Lazarus toolchain is ready'
