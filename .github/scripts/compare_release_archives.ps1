[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$PublishedArchive,
    [Parameter(Mandatory = $true)] [string]$PublishedChecksum,
    [Parameter(Mandatory = $true)] [string]$RebuiltArchive
)

$ErrorActionPreference = 'Stop'

function Get-ArchiveFiles([string]$Archive, [string]$Destination) {
    Remove-Item -Recurse -Force $Destination -ErrorAction SilentlyContinue
    Expand-Archive $Archive -DestinationPath $Destination -Force
    $result = [ordered]@{}
    Get-ChildItem $Destination -Recurse -File | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Destination, $_.FullName).Replace('\', '/')
        $result[$relative] = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    return $result
}

$publishedName = [IO.Path]::GetFileName($PublishedArchive)
$checksumText = (Get-Content -Raw $PublishedChecksum).Trim()
$checksumPattern = '(?i)^([0-9a-f]{64})\s+\*?' + [regex]::Escape($publishedName) + '$'
if ($checksumText -notmatch $checksumPattern) {
    throw "Published checksum for $publishedName has an invalid format."
}
$expectedPublishedHash = $Matches[1].ToLowerInvariant()
$publishedHash = (Get-FileHash $PublishedArchive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($publishedHash -ne $expectedPublishedHash) {
    throw "Published archive $publishedName does not match its release checksum."
}
$rebuiltHash = (Get-FileHash $RebuiltArchive -Algorithm SHA256).Hash.ToLowerInvariant()

$workRoot = Join-Path $env:RUNNER_TEMP 'release-comparison'
$publishedFiles = Get-ArchiveFiles $PublishedArchive (Join-Path $workRoot 'published')
$rebuiltFiles = Get-ArchiveFiles $RebuiltArchive (Join-Path $workRoot 'rebuilt')
$allPaths = @(@($publishedFiles.Keys) + @($rebuiltFiles.Keys) | Sort-Object -Unique)
$differences = @()
foreach ($path in $allPaths) {
    if (-not $publishedFiles.Contains($path)) {
        $differences += "Only in rebuilt archive: $path"
    } elseif (-not $rebuiltFiles.Contains($path)) {
        $differences += "Missing from rebuilt archive: $path"
    } elseif ($publishedFiles[$path] -ne $rebuiltFiles[$path]) {
        $differences += "Content differs: $path"
    }
}

$summary = @(
    '## Rebuild comparison',
    '',
    "| Item | SHA-256 |",
    "| --- | --- |",
    ('| Published ZIP | `{0}` |' -f $publishedHash),
    ('| Rebuilt ZIP | `{0}` |' -f $rebuiltHash),
    '',
    "Extracted file count: published $($publishedFiles.Count), rebuilt $($rebuiltFiles.Count)."
)
if ($differences.Count -eq 0) {
    $summary += @('', 'Result: **all extracted files are identical**.')
    if ($publishedHash -ne $rebuiltHash) {
        $summary += 'The ZIP hashes differ only because archive container metadata is not required to be deterministic.'
    } else {
        $summary += 'The ZIP files are also byte-for-byte identical.'
    }
} else {
    $summary += @('', 'Result: **the rebuilt content differs**.', '', '```text')
    $summary += $differences
    $summary += '```'
}
$summary | Add-Content $env:GITHUB_STEP_SUMMARY
$summary | Write-Host

if ($differences.Count -ne 0) {
    throw "Rebuilt archive content differs in $($differences.Count) path(s)."
}
