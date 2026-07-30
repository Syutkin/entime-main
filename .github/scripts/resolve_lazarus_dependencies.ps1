[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidateSet('latest', 'locked')] [string]$Mode,
    [Parameter(Mandatory = $true)] [string]$OutputDirectory,
    [string]$LockFile,
    [string]$ConfigFile = '.github/lazarus-packages.json'
)

$ErrorActionPreference = 'Stop'

function Invoke-Download([string]$Uri, [string]$OutFile) {
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
            return
        } catch {
            if ($attempt -eq 4) { throw }
            Start-Sleep -Seconds (3 * $attempt)
        }
    }
}

function Find-PackageFile([string]$Root, [string]$Name) {
    $file = Get-ChildItem -Path $Root -Recurse -File -Filter $Name | Select-Object -First 1
    if (-not $file) { throw "Package file $Name was not found below $Root." }
    return $file.FullName
}

New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$packagesRoot = Join-Path $OutputDirectory 'packages'
New-Item -ItemType Directory -Force $packagesRoot | Out-Null

if ($Mode -eq 'latest') {
    $configuration = Get-Content -Raw $ConfigFile | ConvertFrom-Json
    $resolved = @()
    foreach ($package in $configuration.packages) {
        $archivePath = Join-Path $OutputDirectory $package.archive
        if ($package.source -eq 'git') {
            $packageDirectory = Join-Path $OutputDirectory $package.directory
            $checkoutDirectory = Join-Path (
                Join-Path $OutputDirectory 'git-checkouts'
            ) ($package.archive -replace '\.zip$', '')
            New-Item -ItemType Directory -Force (Split-Path $checkoutDirectory -Parent) |
                Out-Null
            & git clone --depth 1 --single-branch --branch $package.branch `
                $package.repository $checkoutDirectory
            if ($LASTEXITCODE -ne 0) {
                throw "Could not clone $($package.repository) branch $($package.branch)."
            }
            $commit = ((& git -C $checkoutDirectory rev-parse HEAD) |
                Select-Object -Last 1).Trim().ToLowerInvariant()
            if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') {
                throw "Could not resolve the commit for Git package $($package.name)."
            }
            & git -C $checkoutDirectory archive --format=zip `
                "--output=$archivePath" $commit
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $archivePath)) {
                throw "Could not archive Git package $($package.name) at $commit."
            }
            Expand-Archive -Path $archivePath -DestinationPath $packageDirectory -Force
            $resolved += [PSCustomObject]@{
                name = $package.name
                source = 'git'
                repository = $package.repository
                branch = $package.branch
                commit = $commit
                archive = $package.archive
                sha256 = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
                directory = $package.directory
                lpk = @($package.lpk)
            }
        } elseif (-not $package.source -or $package.source -eq 'opm') {
            $packageDirectory = Join-Path $packagesRoot ($package.archive -replace '\.zip$', '')
            $url = "$($configuration.repository.TrimEnd('/'))/$($package.archive)"
            Invoke-Download $url $archivePath
            Expand-Archive -Path $archivePath -DestinationPath $packageDirectory -Force
            $resolved += [PSCustomObject]@{
                name = $package.name
                source = 'opm'
                archive = $package.archive
                url = $url
                sha256 = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
                directory = "packages/$($package.archive -replace '\.zip$', '')"
                lpk = @($package.lpk)
            }
        } else {
            throw "Unsupported source '$($package.source)' for package $($package.name)."
        }
    }
    $lock = [ordered]@{
        schema = 1
        generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        toolchain = [ordered]@{
            lazarus = (Get-Content -Raw (Join-Path $env:LAZARUS_TOOLCHAIN_DIRECTORY 'lazarus-toolchain.json') | ConvertFrom-Json)
            lazbuild = (& lazbuild --version | Out-String).Trim()
            fpc = (& fpc -iV | Out-String).Trim()
        }
        packages = $resolved
    }
} else {
    if (-not $LockFile -or -not (Test-Path $LockFile)) { throw 'Locked mode requires build-dependencies.json.' }
    $lock = Get-Content -Raw $LockFile | ConvertFrom-Json
    foreach ($package in $lock.packages) {
        if ($package.source -eq 'git') {
            if (
                -not $package.repository -or
                -not $package.branch -or
                $package.commit -notmatch '^[0-9a-f]{40}$'
            ) {
                throw "Locked Git metadata for package $($package.name) is incomplete."
            }
        }
        $archivePath = Join-Path $OutputDirectory $package.archive
        if (-not (Test-Path $archivePath)) { throw "Locked archive $($package.archive) is missing." }
        $actual = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $package.sha256) { throw "Checksum mismatch for locked archive $($package.archive)." }
        $packageDirectory = Join-Path $OutputDirectory $package.directory
        if (-not (Test-Path $packageDirectory)) {
            New-Item -ItemType Directory -Force $packageDirectory | Out-Null
            Expand-Archive -Path $archivePath -DestinationPath $packageDirectory -Force
        }
    }
}

foreach ($package in $lock.packages) {
    $root = Join-Path $OutputDirectory $package.directory
    foreach ($lpk in $package.lpk) {
        $path = Find-PackageFile $root $lpk
        # Runtime packages must be linked for dependency resolution, not
        # installed into the Lazarus IDE with --add-package. Lazarus 4.8
        # rejects the documented --add-package-link=<path> form and expects
        # the option and package path as separate arguments.
        & lazbuild --add-package-link $path
        if ($LASTEXITCODE -ne 0) { throw "Could not register Lazarus package $lpk." }
        & lazbuild $path
        if ($LASTEXITCODE -ne 0) { throw "Could not build Lazarus package $lpk." }
    }
}

# MyForks is project source and is recorded separately from downloaded packages.
$myForksPath = (Resolve-Path 'myforks.lpk').Path
& lazbuild --add-package-link $myForksPath
if ($LASTEXITCODE -ne 0) { throw 'Could not register project package myforks.lpk.' }
& lazbuild $myForksPath
if ($LASTEXITCODE -ne 0) { throw 'Could not build project package myforks.lpk.' }

$lock | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $OutputDirectory 'build-dependencies.json') -Encoding utf8
