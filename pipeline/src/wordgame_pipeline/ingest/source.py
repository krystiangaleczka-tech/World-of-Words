"""Checksum-verified source cache. ZIP members are read, never extracted."""

import hashlib
import io
import re
import urllib.request
import zipfile
from collections.abc import Callable
from dataclasses import asdict, dataclass, fields
from pathlib import Path

from ..config import parse_json
from ..stages import _write_atomic


@dataclass(frozen=True)
class SourcePin:
    id: str
    version: str
    url: str
    sha256: str
    archive_bytes: int
    member: str
    member_bytes: int
    entry_count: int
    encoding: str
    license: str
    license_url: str
    source_url: str

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


def load_pin(root: Path) -> SourcePin:
    data = parse_json((root / "sources" / "sjp-pl.json").read_text(encoding="utf-8"))
    if not isinstance(data, dict) or set(data) != {field.name for field in fields(SourcePin)}:
        raise ValueError("Invalid SJP source pin fields")
    for key in ("archive_bytes", "member_bytes", "entry_count"):
        if type(data[key]) is not int or data[key] <= 0:
            raise ValueError(f"Invalid SJP {key}")
    for key in set(data) - {"archive_bytes", "member_bytes", "entry_count"}:
        if not isinstance(data[key], str):
            raise ValueError(f"Invalid SJP {key}")
    if data["id"] != "sjp-pl-game" or not re.fullmatch(r"[0-9]{8}", data["version"]):
        raise ValueError("Invalid SJP source/version")
    if data["url"] != f"https://sjp.pl/sl/growy/sjp-{data['version']}.zip":
        raise ValueError("SJP archive must use the pinned selected endpoint")
    if not re.fullmatch(r"[0-9a-f]{64}", data["sha256"]):
        raise ValueError("Invalid SJP SHA256")
    if data["member"] != "slowa.txt" or data["encoding"] != "utf-8":
        raise ValueError("Unsupported SJP member/encoding")
    if (
        data["license"] != "CC-BY-4.0"
        or data["license_url"] != "https://creativecommons.org/licenses/by/4.0/"
        or data["source_url"] != "https://sjp.pl/sl/growy/"
    ):
        raise ValueError("SJP provenance must match decision 0008")
    return SourcePin(**data)


def read_words(data: bytes, pin: SourcePin) -> list[str]:
    if len(data) != pin.archive_bytes or hashlib.sha256(data).hexdigest() != pin.sha256:
        raise ValueError("SJP archive size/SHA256 mismatch")
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            members = [member for member in archive.infolist() if member.filename == pin.member]
            if len(members) != 1 or members[0].file_size != pin.member_bytes:
                raise ValueError("SJP member missing, duplicated or wrong size")
            words = archive.read(members[0]).decode(pin.encoding).splitlines()
    except (zipfile.BadZipFile, UnicodeError) as exc:
        raise ValueError(f"Invalid SJP archive/member: {exc}") from exc
    if len(words) != pin.entry_count or any(not word for word in words):
        raise ValueError("SJP entry count/empty word mismatch")
    return words


def download_archive(
    root: Path, pin: SourcePin, fetcher: Callable[[str], bytes] | None = None
) -> Path:
    path = root / "build" / "pl" / "sources" / f"sjp-{pin.version}.zip"
    if path.exists():
        read_words(path.read_bytes(), pin)
        return path
    if fetcher is None:
        with urllib.request.urlopen(pin.url, timeout=30) as response:
            data = response.read(pin.archive_bytes + 1)
    else:
        data = fetcher(pin.url)
    read_words(data, pin)
    _write_atomic(path, data)
    return path
