[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repository = 'simpleble/simpleble'
$assetName = 'libsimplecble_windows-x64.zip'
$releaseApiUrl = "https://api.github.com/repos/$repository/releases/latest"

function Invoke-Download([string]$Uri, [string]$OutFile, [hashtable]$Headers = @{}) {
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -Headers $Headers -UseBasicParsing
            return
        } catch {
            if ($attempt -eq 4) { throw }
            Start-Sleep -Seconds (3 * $attempt)
        }
    }
}

$headers = @{
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
if ($env:GITHUB_TOKEN) {
    $headers.Authorization = "Bearer $env:GITHUB_TOKEN"
}
$release = Invoke-RestMethod -Uri $releaseApiUrl -Headers $headers
if (-not $release.tag_name -or $release.draft -or $release.prerelease) {
    throw "GitHub did not return a stable latest release for $repository."
}
$assets = @($release.assets | Where-Object { $_.name -eq $assetName })
if ($assets.Count -ne 1) {
    throw "Latest release $($release.tag_name) must contain exactly one $assetName asset."
}
$asset = $assets[0]

New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$archivePath = Join-Path $OutputDirectory $assetName
$expandedDirectory = Join-Path $OutputDirectory 'expanded'
Remove-Item -Force $archivePath -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $expandedDirectory -ErrorAction SilentlyContinue
Invoke-Download $asset.browser_download_url $archivePath
$archiveSha256 = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($asset.digest) {
    if ($asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
        throw "GitHub returned an unsupported digest for $assetName."
    }
    if ($archiveSha256 -ne $Matches[1].ToLowerInvariant()) {
        throw "SHA-256 mismatch for $assetName."
    }
}

Expand-Archive $archivePath -DestinationPath $expandedDirectory -Force
$dllDirectory = Join-Path $expandedDirectory 'shared/bin'
$dlls = @('simplecble.dll', 'simpleble.dll')
foreach ($dll in $dlls) {
    $source = Join-Path $dllDirectory $dll
    if (-not (Test-Path $source)) {
        throw "$assetName does not contain shared/bin/$dll."
    }
    Copy-Item -Force $source (Join-Path $OutputDirectory $dll)
}

[ordered]@{
    repository = $repository
    selector = 'latest_release'
    release_tag = [string]$release.tag_name
    release_url = [string]$release.html_url
    asset = [ordered]@{
        name = $assetName
        url = [string]$asset.browser_download_url
        sha256 = $archiveSha256
    }
    dlls = @(
        foreach ($dll in $dlls) {
            [ordered]@{
                name = $dll
                sha256 = (Get-FileHash (Join-Path $OutputDirectory $dll) -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
    )
} | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $OutputDirectory 'simpleble-dependency.json') -Encoding utf8

Remove-Item -Force $archivePath
Remove-Item -Recurse -Force $expandedDirectory
Write-Host "Downloaded $assetName from $repository release $($release.tag_name)."
