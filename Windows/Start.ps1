$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'BrickOverlay.cs'
$application = Join-Path $PSScriptRoot 'BrickOverlay.exe'
$launcher = $MyInvocation.MyCommand.Path
$temporaryApplication = $null

try {
    if (-not (Test-Path -LiteralPath $application) -or
        (Get-Item -LiteralPath $source).LastWriteTimeUtc -gt (Get-Item -LiteralPath $application).LastWriteTimeUtc -or
        (Get-Item -LiteralPath $launcher).LastWriteTimeUtc -gt (Get-Item -LiteralPath $application).LastWriteTimeUtc) {
        $temporaryApplication = Join-Path $PSScriptRoot ('BrickOverlay-build-' + [Guid]::NewGuid().ToString('N') + '.exe')
        Add-Type -Path $source -ReferencedAssemblies @(
            'System.dll', 'System.Core.dll', 'System.Drawing.dll',
            'System.Windows.Forms.dll', 'System.Xml.dll', 'System.Xml.Linq.dll'
        ) -OutputAssembly $temporaryApplication -OutputType WindowsApplication
        Move-Item -LiteralPath $temporaryApplication -Destination $application -Force
    }
    Start-Process -FilePath $application -WorkingDirectory $PSScriptRoot
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Brick Overlay 启动失败：`n$($_.Exception.Message)",
        'Brick Overlay',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
} finally {
    if ($temporaryApplication -and (Test-Path -LiteralPath $temporaryApplication)) {
        Remove-Item -LiteralPath $temporaryApplication -Force -ErrorAction SilentlyContinue
    }
}
