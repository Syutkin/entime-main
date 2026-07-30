[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$downloadPageUrl = 'https://www.sqlite.org/download.html'
$page = (Invoke-WebRequest -Uri $downloadPageUrl -UseBasicParsing).Content
$productPattern = '(?m)^PRODUCT,[^,\r\n]+,([^,\r\n]*/(sqlite-dll-win-x64-\d+\.zip)),(\d+),([a-fA-F0-9]{64})\r?$'
$product = [regex]::Match($page, $productPattern)
if (-not $product.Success) {
    throw 'Could not find the current Windows x64 SQLite PRODUCT record on sqlite.org.'
}
$relativePath = $product.Groups[1].Value
$fileName = $product.Groups[2].Value
$expectedSize = [long]$product.Groups[3].Value
$expectedHash = $product.Groups[4].Value.ToLowerInvariant()
$downloadUrl = "https://www.sqlite.org/$relativePath"

New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$archivePath = Join-Path $OutputDirectory $fileName
Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath
$actualSize = (Get-Item $archivePath).Length
if ($actualSize -ne $expectedSize) {
    throw "Size mismatch for $fileName. Expected $expectedSize bytes, got $actualSize."
}
$hashOutput = @(
    & python -c 'import hashlib, pathlib, sys; print(hashlib.sha3_256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())' `
        $archivePath
)
if ($LASTEXITCODE -ne 0) {
    throw "Could not calculate SHA3-256 for $fileName with Python."
}
$actualHash = ($hashOutput | Select-Object -Last 1).Trim().ToLowerInvariant()
if ($actualHash -notmatch '^[a-f0-9]{64}$') {
    throw "Python returned an invalid SHA3-256 value for $fileName."
}
if ($actualHash -ne $expectedHash) {
    throw "SHA3-256 mismatch for $fileName."
}

Expand-Archive -Path $archivePath -DestinationPath $OutputDirectory -Force
$sqlitePath = Join-Path $OutputDirectory 'sqlite3.dll'
if (-not (Test-Path $sqlitePath)) {
    throw "Official SQLite archive $fileName does not contain sqlite3.dll."
}
Write-Host "Downloaded and verified $fileName from sqlite.org."
[ordered]@{
    file = $fileName
    url = $downloadUrl
    sha3_256 = $expectedHash
    archive_sha256 = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    dll_sha256 = (Get-FileHash -Path $sqlitePath -Algorithm SHA256).Hash.ToLowerInvariant()
} | ConvertTo-Json | Set-Content -Path (Join-Path $OutputDirectory 'sqlite-dependency.json') -Encoding utf8
