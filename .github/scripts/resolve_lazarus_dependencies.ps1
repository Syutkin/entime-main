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

function Resolve-GitTarget($Package) {
    $selector = if ($Package.selector) { [string]$Package.selector } elseif ($Package.branch) { 'branch' } else { '' }
    if ($selector -eq 'branch') {
        if (-not $Package.branch) {
            throw "Git package $($Package.name) with selector 'branch' has no branch."
        }
        return [PSCustomObject]@{
            selector = 'branch'
            ref = [string]$Package.branch
            description = "branch $($Package.branch)"
            branch = [string]$Package.branch
            tag = $null
        }
    }
    if ($selector -eq 'latest_tag') {
        $refs = @(& git ls-remote --tags --refs $Package.repository)
        if ($LASTEXITCODE -ne 0) {
            throw "Could not list tags for Git package $($Package.name)."
        }
        $candidates = @(
            foreach ($line in $refs) {
                if ($line -match '\s+refs/tags/(v?(\d+)\.(\d+)\.(\d+))$') {
                    [PSCustomObject]@{
                        tag = $Matches[1]
                        version = [version]::new(
                            [int]$Matches[2],
                            [int]$Matches[3],
                            [int]$Matches[4]
                        )
                    }
                }
            }
        )
        $selected = $candidates | Sort-Object version -Descending | Select-Object -First 1
        if (-not $selected) {
            throw "Git package $($Package.name) has no stable SemVer tags."
        }
        return [PSCustomObject]@{
            selector = 'latest_tag'
            ref = [string]$selected.tag
            description = "tag $($selected.tag)"
            branch = $null
            tag = [string]$selected.tag
        }
    }
    throw "Unsupported Git selector '$selector' for package $($Package.name)."
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
            $target = Resolve-GitTarget $package
            $packageDirectory = Join-Path $OutputDirectory $package.directory
            $checkoutDirectory = Join-Path (
                Join-Path $OutputDirectory 'git-checkouts'
            ) ($package.archive -replace '\.zip$', '')
            New-Item -ItemType Directory -Force (Split-Path $checkoutDirectory -Parent) |
                Out-Null
            & git clone --depth 1 --single-branch --branch $target.ref `
                $package.repository $checkoutDirectory
            if ($LASTEXITCODE -ne 0) {
                throw "Could not clone $($package.repository) at $($target.description)."
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
            $metadata = [ordered]@{
                name = $package.name
                source = 'git'
                repository = $package.repository
                selector = $target.selector
                commit = $commit
                archive = $package.archive
                sha256 = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
                directory = $package.directory
                lpk = @($package.lpk)
            }
            if ($target.branch) { $metadata['branch'] = $target.branch }
            if ($target.tag) { $metadata['tag'] = $target.tag }
            $resolved += [PSCustomObject]$metadata
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
            $selector = if ($package.selector) { [string]$package.selector } elseif ($package.branch) { 'branch' } else { '' }
            $selectorMetadataIsValid =
                (($selector -eq 'branch') -and $package.branch) -or
                (($selector -eq 'latest_tag') -and $package.tag)
            if (-not $package.repository -or -not $selectorMetadataIsValid -or $package.commit -notmatch '^[0-9a-f]{40}$') {
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

# MyForks moved under packages in current sources. The fallback keeps historical
# release tags reproducible with the current automation.
$myForksCandidate = @('packages/myforks/myforks.lpk', 'myforks.lpk') |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $myForksCandidate) {
    throw 'Could not find the project package myforks.lpk.'
}
$myForksPath = (Resolve-Path $myForksCandidate).Path
& lazbuild --add-package-link $myForksPath
if ($LASTEXITCODE -ne 0) { throw 'Could not register project package myforks.lpk.' }
& lazbuild $myForksPath
if ($LASTEXITCODE -ne 0) { throw 'Could not build project package myforks.lpk.' }

$lock | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $OutputDirectory 'build-dependencies.json') -Encoding utf8
