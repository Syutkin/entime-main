param(
    [Parameter(Mandatory = $true)][string]$Executable,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$binary = (Resolve-Path $Executable).Path
& $binary --list --format=xml | Out-File (Join-Path $OutputDirectory 'tests.xml') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'Could not list the GUI tests.' }
$stdout = Join-Path $OutputDirectory 'stdout.log'
$stderr = Join-Path $OutputDirectory 'stderr.log'
$process = Start-Process -FilePath $binary -ArgumentList '--all','--format=plain','--progress' -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$completed = $process.WaitForExit($TimeoutSeconds * 1000)
if (-not $completed) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $image = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($image)
    try {
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $image.Save((Join-Path $OutputDirectory 'timeout.png'))
    } finally {
        $graphics.Dispose()
        $image.Dispose()
    }
    taskkill /PID $process.Id /T /F | Write-Host
}
Get-Content $stdout | Write-Host
Get-Content $stderr | Write-Host
if (-not $completed) { throw "GUI tests exceeded $TimeoutSeconds seconds. See the GUI diagnostics artifact." }
$process.Refresh()
if ($process.ExitCode -ne 0) { throw "Integration tests failed (exit $($process.ExitCode))." }
