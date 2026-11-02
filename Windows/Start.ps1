$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'BrickOverlay.cs'
$application = Join-Path $PSScriptRoot 'BrickOverlay.exe'

try {
    if (-not (Test-Path $application) -or (Get-Item $source).LastWriteTimeUtc -gt (Get-Item $application).LastWriteTimeUtc) {
        Add-Type -Path $source -ReferencedAssemblies @(
            'System.dll', 'System.Core.dll', 'System.Drawing.dll',
            'System.Windows.Forms.dll', 'System.Xml.Linq.dll'
        ) -OutputAssembly $application -OutputType WindowsApplication
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
}
