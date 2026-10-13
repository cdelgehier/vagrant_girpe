"""Exercise a desktop application and document exchange through the running lab."""

import json
import os
import socket
import subprocess
import uuid
from pathlib import Path

import smbclient

ROOT = Path(__file__).resolve().parents[2]


def guest(command: str) -> dict:
    """Keep guest diagnostics and read machine data without table formatting."""

    result = subprocess.run(
        ["vagrant", "winrm", "-c", command],
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=180,
    )
    reports = ROOT / "reports"
    reports.mkdir(exist_ok=True)
    with (reports / "vagrant-runtime.log").open("a") as log:
        log.write(result.stdout + result.stderr)
    assert result.returncode == 0, (
        f"WinRM failed; see {reports / 'vagrant-runtime.log'}"
    )
    for line in result.stdout.splitlines():
        if line.strip().startswith("{"):
            return json.loads(line)
    raise ValueError("The guest did not return JSON")


def test_windows_arm64_has_the_pinned_application() -> None:
    result = guest(
        "@{arch=$env:PROCESSOR_ARCHITECTURE; app=(Get-Item 'C:/Girpe/Girpe V2.exe').VersionInfo.ProductVersion; source=(Get-Content C:/Girpe/source.json -Raw | ConvertFrom-Json).version} | ConvertTo-Json -Compress"
    )
    assert result["arch"] == "ARM64"
    assert result["app"].startswith("2.2.3")
    assert result["source"] == "2.2.3"


def test_rdp_requires_network_level_authentication() -> None:
    result = guest(
        "@{enabled=(Get-ItemProperty 'HKLM:/SYSTEM/CurrentControlSet/Control/Terminal Server').fDenyTSConnections; nla=(Get-ItemProperty 'HKLM:/SYSTEM/CurrentControlSet/Control/Terminal Server/WinStations/RDP-Tcp').UserAuthentication} | ConvertTo-Json -Compress"
    )
    assert result == {"enabled": 0, "nla": 1}
    # Negotiate CredSSP with the real forwarded RDP endpoint, without opening a session.
    with socket.create_connection(("127.0.0.1", 13389), timeout=15) as connection:
        connection.sendall(bytes.fromhex("030000130ee000000000000100080003000000"))
        response = connection.recv(1024)
    # Capability flags can vary; the endpoint must select CredSSP.
    assert len(response) >= 8 and response[-8] == 2
    assert int.from_bytes(response[-6:-4], "little") == 8
    assert int.from_bytes(response[-4:], "little") == 2


def test_documents_can_be_written_from_the_host_and_read_after_guest_changes() -> None:
    name = f"test-{uuid.uuid4().hex}.txt"
    path = rf"\\127.0.0.1\GIRPEData\{name}"
    smbclient.register_session(
        "127.0.0.1",
        port=1445,
        username="vagrant",
        password=os.environ.get("IMAGE_FACTORY_WINDOWS_PASSWORD", "vagrant"),
        auth_protocol="ntlm",
        encrypt=True,
    )
    try:
        with smbclient.open_file(path, mode="wb", port=1445) as document:
            document.write(b"from the host")
        result = guest(
            f"@{{content=[string](Get-Content C:/GirpeData/{name} -Raw)}} | ConvertTo-Json -Compress"
        )
        assert result["content"] == "from the host"
        guest(
            f"Set-Content C:/GirpeData/{name} 'from the guest' -NoNewline; @{{saved=$true}} | ConvertTo-Json -Compress"
        )
        with smbclient.open_file(path, mode="rb", port=1445) as document:
            assert document.read().decode().removeprefix("\ufeff") == "from the guest"
    finally:
        smbclient.remove(path, port=1445)
        smbclient.delete_session("127.0.0.1", port=1445)


def test_application_opens_in_the_interactive_desktop() -> None:
    result = guest(r"""
$ErrorActionPreference = 'Stop'
$name = 'Girpe-Test-' + [guid]::NewGuid().ToString()
$directory = Join-Path C:\GirpeData $name
$script = Join-Path $directory probe.ps1
$report = Join-Path $directory result.json
New-Item -ItemType Directory -Path $directory | Out-Null
# MainWindowHandle only sees windows in the caller's desktop session.
# Run the probe in that session and return its result through a temporary file.
$probe = @'
param([string]$ReportPath)
$ErrorActionPreference = 'Stop'
$launcher = $null
try {
    $session = (Get-Process -Id $PID).SessionId
    $launcher = Start-Process -FilePath 'C:\Girpe\Girpe V2.exe' -WorkingDirectory C:\Girpe -PassThru
    $window = $null
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
        $window = Get-Process -Name 'Girpe V2' -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -and $_.SessionId -eq $session } | Select-Object -First 1
        if ($window) { break }
        Start-Sleep -Seconds 2
    }
    if (!$window) { throw 'GIRPE2 did not open a window in the signed-in desktop.' }
    $result = @{title=$window.MainWindowTitle; session=$window.SessionId}
} catch {
    $result = @{error=$_.Exception.Message}
} finally {
    # Stop only the launcher from this probe and its children, keeping other instances.
    if ($launcher -and !$launcher.HasExited) {
        & taskkill.exe /PID $launcher.Id /T /F | Out-Null
    }
}
$result | ConvertTo-Json -Compress | Set-Content -LiteralPath $ReportPath -Encoding UTF8
'@
Set-Content -LiteralPath $script -Value $probe -Encoding UTF8
try {
    $action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -ExecutionPolicy Bypass -File $script -ReportPath $report"
    $principal = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\vagrant" -LogonType Interactive
    Register-ScheduledTask -TaskName $name -Action $action -Principal $principal | Out-Null
    Start-ScheduledTask -TaskName $name
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        if (Test-Path -LiteralPath $report) { break }
        Start-Sleep -Seconds 2
    }
    if (Test-Path -LiteralPath $report) {
        Get-Content -LiteralPath $report -Raw
    } else {
        @{error='The desktop probe did not finish. Sign in to the desktop first.'} | ConvertTo-Json -Compress
    }
} finally {
    Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
}
""")
    assert "error" not in result, result.get("error")
    assert result["session"] > 0
    assert result["title"]
