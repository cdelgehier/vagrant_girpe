# The FFTT Windows package runs directly; it does not need an installation step.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
try {
    $executable = & C:\GirpeProvision\prepare-package.ps1 -DestinationPath $temporary
    $application = 'C:\Girpe\Girpe V2.exe'
    New-Item -ItemType Directory -Path C:\Girpe -Force | Out-Null
    # The portable launcher stays open while GIRPE runs. Do not start it through WinRM.
    Copy-Item -LiteralPath $executable -Destination $application -Force
    New-Item -ItemType Directory -Path C:\GirpeData -Force | Out-Null
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:PUBLIC\Desktop\GIRPE2.lnk")
    $shortcut.TargetPath = $application
    $shortcut.WorkingDirectory = 'C:\Girpe'
    $shortcut.Save()
    Copy-Item C:\GirpeProvision\source.json C:\Girpe\source.json -Force
} finally {
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
