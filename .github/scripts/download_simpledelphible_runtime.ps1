[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$ConfigFile,
    [Parameter(Mandatory = $true)] [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$config = Get-Content -Raw $ConfigFile | ConvertFrom-Json
$packages = @($config.packages | Where-Object { $_.name -eq 'SimpleDelphiBLE' })
if ($packages.Count -ne 1 -or $packages[0].commit -notmatch '^[0-9a-f]{40}$') {
    throw 'Exactly one pinned SimpleDelphiBLE package is required.'
}
$package = $packages[0]
$runtime = $package.runtime
if ($runtime.release_tag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$' -or
    $runtime.asset -notmatch '^simpledelphible-[0-9A-Za-z.-]+\.zip$' -or
    $runtime.sha256 -notmatch '^[0-9a-f]{64}$') {
    throw 'SimpleDelphiBLE runtime requires a release tag, ZIP name and SHA-256.'
}
$url = "https://github.com/simpleble/simpledelphible/releases/download/$($runtime.release_tag)/$($runtime.asset)"
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$archive = Join-Path $OutputDirectory $runtime.asset
$expanded = Join-Path $OutputDirectory 'expanded'
try {
    Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
    $hash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $runtime.sha256) { throw 'SimpleDelphiBLE runtime SHA-256 mismatch.' }
    Expand-Archive $archive -DestinationPath $expanded -Force
    $matches = @(Get-ChildItem $expanded -Recurse -File -Filter 'simplecble.dll' |
        Where-Object { $_.FullName -match '[\\/]lib[\\/]win64[\\/]simplecble\.dll$' })
    if ($matches.Count -ne 1) { throw 'SimpleDelphiBLE runtime must have exactly one Win64 DLL.' }
    $source = $matches[0].FullName
    Copy-Item $source (Join-Path $OutputDirectory 'simplecble.dll') -Force
    [ordered]@{
        provider = 'SimpleDelphiBLE'
        repository = 'simpleble/simpledelphible'
        selector = 'commit'
        commit = $package.commit
        release_tag = $runtime.release_tag
        asset = [ordered]@{ name = $runtime.asset; url = $url; sha256 = $hash }
        dlls = @([ordered]@{
            name = 'simplecble.dll'
            sha256 = (Get-FileHash $source -Algorithm SHA256).Hash.ToLowerInvariant()
        })
    } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $OutputDirectory 'simpleble-dependency.json') -Encoding utf8
} finally {
    Remove-Item $archive -Force -ErrorAction SilentlyContinue
    Remove-Item $expanded -Recurse -Force -ErrorAction SilentlyContinue
}
