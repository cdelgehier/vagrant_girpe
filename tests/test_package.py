"""Check the official portable package before it reaches the Windows lab."""

import hashlib
import json
import os
import subprocess
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


def prepare_package(
    directory: Path, entries: dict[str, bytes], **changes: str
) -> subprocess.CompletedProcess[str]:
    """Use small local archives and the same PowerShell script as the guest."""

    archive = directory / "girpe.zip"
    with zipfile.ZipFile(archive, "w") as package:
        for name, content in entries.items():
            package.writestr(name, content)
    source = {
        "version": "2.2.3",
        "url": "https://www.fftt.com/deploiements/girpe-v2/downloads/Girpe%20V2-2.2.3.zip",
        "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
        "executable": "Girpe V2 2.2.3.exe",
    }
    source.update(changes)
    pin = directory / "source.json"
    pin.write_text(json.dumps(source))
    return subprocess.run(
        [
            os.environ.get("PWSH_BIN", "pwsh"),
            "-NoProfile",
            "-File",
            str(ROOT / "provision/prepare-package.ps1"),
            "-SourcePath",
            str(pin),
            "-ArchivePath",
            str(archive),
            "-DestinationPath",
            str(directory / "output"),
        ],
        text=True,
        capture_output=True,
        timeout=30,
    )


def test_verified_portable_application_is_extracted(tmp_path: Path) -> None:
    result = prepare_package(tmp_path, {"Girpe V2 2.2.3.exe": b"portable application"})
    assert result.returncode == 0, result.stderr
    assert (
        tmp_path / "output/Girpe V2 2.2.3.exe"
    ).read_bytes() == b"portable application"


def test_checksum_error_leaves_no_extracted_files(tmp_path: Path) -> None:
    result = prepare_package(
        tmp_path, {"Girpe V2 2.2.3.exe": b"changed"}, sha256="0" * 64
    )
    assert result.returncode != 0
    assert "checksum" in result.stderr.lower()
    assert not (tmp_path / "output").exists()


@pytest.mark.parametrize(
    "entries",
    [
        {"another.exe": b"wrong application"},
        {"Girpe V2 2.2.3.exe": b"application", "../outside.txt": b"unexpected"},
    ],
)
def test_unexpected_archive_contents_are_rejected(
    tmp_path: Path, entries: dict[str, bytes]
) -> None:
    result = prepare_package(tmp_path, entries)
    assert result.returncode != 0
    assert "contents" in result.stderr.lower()
    assert not (tmp_path / "output").exists()


@pytest.mark.parametrize(
    "changes",
    [
        {"url": "https://example.com/girpe.zip"},
        {"sha256": "invalid"},
        {"executable": "../application.exe"},
        {"version": "latest"},
    ],
)
def test_invalid_source_metadata_is_rejected(
    tmp_path: Path, changes: dict[str, str]
) -> None:
    result = prepare_package(
        tmp_path, {"Girpe V2 2.2.3.exe": b"application"}, **changes
    )
    assert result.returncode != 0
    assert "source metadata" in result.stderr.lower()
    assert not (tmp_path / "output").exists()
