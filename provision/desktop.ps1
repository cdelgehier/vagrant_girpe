# Forwarded ports stay on the Mac's loopback address. Keep guest access authenticated.
$ErrorActionPreference = 'Stop'
$rdp = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
Set-ItemProperty $rdp fDenyTSConnections 0
Set-ItemProperty "$rdp\WinStations\RDP-Tcp" UserAuthentication 1
Set-Service TermService -StartupType Automatic
Start-Service TermService

$account = "$env:COMPUTERNAME\vagrant"
# Only the lab account can use this share. The files still belong to the VM disk.
& icacls.exe C:\GirpeData /inheritance:r /grant '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' "${account}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Document folder permissions could not be set' }
Set-Service LanmanServer -StartupType Automatic
Start-Service LanmanServer
if (!(Get-SmbShare -Name GIRPEData -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name GIRPEData -Path C:\GirpeData -FullAccess $account -EncryptData $true -CachingMode None | Out-Null
}
foreach ($rule in @(@{Name='GIRPE-RDP'; Port=3389}, @{Name='GIRPE-Documents'; Port=445})) {
    if (!(Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue)) {
        # QEMU forwards host connections through its user-network gateway.
        New-NetFirewallRule -Name $rule.Name -DisplayName $rule.Name -Direction Inbound -Action Allow -Protocol TCP -LocalPort $rule.Port -RemoteAddress 10.0.2.2 | Out-Null
    }
}
