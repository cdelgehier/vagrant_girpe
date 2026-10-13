# Verify the official archive before copying its portable application.
param(
    [string]$SourcePath = "$PSScriptRoot/source.json",
    [Parameter(Mandatory)][string]$DestinationPath,
    [string]$ArchivePath
)
$ErrorActionPreference = 'Stop'
$source = Get-Content -LiteralPath $SourcePath -Raw | ConvertFrom-Json
if ($source.version -notmatch '^\d+\.\d+\.\d+$' -or
    $source.url -ne "https://www.fftt.com/deploiements/girpe-v2/downloads/Girpe%20V2-$($source.version).zip" -or
    $source.sha256 -notmatch '^[0-9a-f]{64}$' -or
    $source.executable -ne "Girpe V2 $($source.version).exe") {
    throw 'Invalid source metadata'
}
$download = $null
try {
    if (!$ArchivePath) {
        $download = [IO.Path]::GetTempFileName()
        Invoke-WebRequest -Uri $source.url -OutFile $download -UseBasicParsing
        $ArchivePath = $download
    }
    if ((Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $source.sha256) {
        throw 'The GIRPE2 archive checksum does not match the source pin'
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        # Only the expected executable is accepted; extra paths cannot escape extraction.
        if ($archive.Entries.Count -ne 1 -or $archive.Entries[0].FullName -ne $source.executable) {
            throw 'Unexpected GIRPE2 archive contents'
        }
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        $executable = Join-Path $DestinationPath $source.executable
        [IO.Compression.ZipFileExtensions]::ExtractToFile($archive.Entries[0], $executable)
        Write-Output $executable
    } finally {
        $archive.Dispose()
    }
} finally {
    if ($download) { Remove-Item -LiteralPath $download -Force }
}
