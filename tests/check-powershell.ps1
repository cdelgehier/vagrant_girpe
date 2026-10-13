# Parse guest scripts without running Windows configuration on the host.
$ErrorActionPreference = 'Stop'
Get-ChildItem provision -Filter *.ps1 | ForEach-Object {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors) { throw ($errors | Out-String) }
}
