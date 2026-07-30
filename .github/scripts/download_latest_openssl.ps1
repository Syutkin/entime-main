[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$headers = @{ 'User-Agent' = 'entime-release-workflow' }
$hashRepository = 'https://github.com/slproweb/opensslhashes.git'
$remoteReference = @(& git ls-remote --exit-code $hashRepository 'refs/heads/master')
if ($LASTEXITCODE -ne 0) {
    throw 'Could not query the OpenSSL hash manifest repository.'
}
$remoteReferenceText = ($remoteReference | Select-Object -Last 1).Trim()
if ($remoteReferenceText -notmatch '^([0-9a-f]{40})\s+refs/heads/master$') {
    throw 'Could not resolve the immutable OpenSSL hash manifest revision.'
}
$hashManifestCommit = $Matches[1].ToLowerInvariant()
$hashManifestUrl = "https://raw.githubusercontent.com/slproweb/opensslhashes/$hashManifestCommit/win32_openssl_hashes.json"
$hashManifestPath = Join-Path $env:RUNNER_TEMP 'win32_openssl_hashes.json'
Invoke-WebRequest -Uri $hashManifestUrl -Headers $headers -OutFile $hashManifestPath
$hashManifestSha256 = (Get-FileHash $hashManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
$hashManifest = Get-Content -Raw $hashManifestPath | ConvertFrom-Json
$candidates = @(
    $hashManifest.files.PSObject.Properties |
        ForEach-Object {
            $file = $_.Value
            if (
                $_.Name -like 'Win64OpenSSL_Light-3_5_*.exe' -and
                $file.arch -eq 'INTEL' -and
                $file.bits -eq 64 -and
                $file.light -eq $true -and
                $file.installer -eq 'exe'
            ) {
                [PSCustomObject]@{
                    Name = $_.Name
                    Version = [version]$file.basever
                    Url = $file.url
                    Sha256 = $file.sha256.ToLowerInvariant()
                }
            }
        } |
        Sort-Object Version -Descending
)
if ($candidates.Count -eq 0) {
    throw 'No Win64 OpenSSL Light installer from the 3.5 LTS series was found.'
}

$installer = $candidates[0]
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$installerPath = Join-Path $OutputDirectory $installer.Name
Invoke-WebRequest -Uri $installer.Url -OutFile $installerPath
$actualHash = (Get-FileHash -Path $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualHash -ne $installer.Sha256) {
    throw "SHA-256 mismatch for $($installer.Name)."
}
$signature = Get-AuthenticodeSignature $installerPath
$signatureStatus = $signature.Status.ToString()
$signatureSubject = if ($signature.SignerCertificate) {
    $signature.SignerCertificate.Subject
} else {
    ''
}
$signatureThumbprint = if ($signature.SignerCertificate) {
    $signature.SignerCertificate.Thumbprint
} else {
    ''
}
if ($signatureStatus -eq 'Valid') {
    if ($signatureSubject -notmatch 'Shining Light Productions') {
        throw "The OpenSSL installer has an unexpected Authenticode signer: $signatureSubject."
    }
    $signatureVerification = 'authenticode-and-official-manifest-sha256'
} elseif ($signatureStatus -eq 'NotSigned') {
    # Current SLP releases can be published without Authenticode. They are
    # accepted only after the installer hash has matched the immutable
    # revision of the official SLP hash manifest above.
    Write-Warning "The OpenSSL installer is not Authenticode-signed; accepting it because its SHA-256 matches the immutable official SLP manifest."
    $signatureVerification = 'official-manifest-sha256-only'
} else {
    throw "The OpenSSL installer has an invalid Authenticode status: $signatureStatus, $signatureSubject."
}

$installationDirectory = Join-Path $OutputDirectory 'installed'
$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/DIR=`"$installationDirectory`"")
$process = Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "OpenSSL installer exited with code $($process.ExitCode)."
}

$dllDirectory = Join-Path $OutputDirectory 'dll'
New-Item -ItemType Directory -Force $dllDirectory | Out-Null
foreach ($dllName in @('libcrypto-3-x64.dll', 'libssl-3-x64.dll')) {
    $dll = Get-ChildItem -Path $installationDirectory -Recurse -File -Filter $dllName |
        Select-Object -First 1
    if (-not $dll) {
        throw "Verified OpenSSL installer did not provide $dllName."
    }
    Copy-Item $dll.FullName (Join-Path $dllDirectory $dllName)
}
Write-Host "Downloaded, verified and extracted $($installer.Name)."
[ordered]@{
    file = $installer.Name
    version = $installer.Version.ToString()
    url = $installer.Url
    sha256 = $installer.Sha256
    hash_manifest = [ordered]@{
        commit = $hashManifestCommit
        url = $hashManifestUrl
        sha256 = $hashManifestSha256
    }
    authenticode = [ordered]@{
        status = $signatureStatus
        subject = $signatureSubject
        thumbprint = $signatureThumbprint
        verification = $signatureVerification
    }
    dlls = @(
        Get-ChildItem $dllDirectory -File | Sort-Object Name | ForEach-Object {
            [ordered]@{
                name = $_.Name
                sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
    )
} | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $OutputDirectory 'openssl-dependency.json') -Encoding utf8
