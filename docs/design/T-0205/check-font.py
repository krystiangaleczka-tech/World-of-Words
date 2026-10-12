"""Offline font audit using the reviewer's installed HarfBuzz; no project dependency."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REQUIRED = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    "ąćęłńóśźżĄĆĘŁŃÓŚŹŻäöüßÄÖÜẞáéíúÁÉÍÚ„”–….,:;!?'-()[]/ +×·"
)


def shape(font: Path, text: str, weight: int, features: str) -> list[dict]:
    result = subprocess.run(
        [
            "hb-shape",
            str(font),
            text,
            "--output-format=json",
            f"--variations=wght={weight}",
            f"--features={features}",
        ],
        check=True,
        text=True,
        capture_output=True,
    )
    return json.loads(result.stdout)


def audit_font(name: str, licence_name: str) -> dict:
    if shutil.which("hb-shape") is None:
        raise RuntimeError("Use an already installed HarfBuzz hb-shape reviewer runtime")
    sources = json.loads((ROOT / "sources.json").read_text())
    for source_name in (name + ".ttf", licence_name):
        actual = hashlib.sha256((ROOT / "fonts" / source_name).read_bytes()).hexdigest()
        assert actual == sources["files"][source_name]["sha256"], f"Changed source: {source_name}"
    licence = (ROOT / "fonts" / licence_name).read_text()
    assert "SIL OPEN FONT LICENSE Version 1.1" in licence
    assert "Copyright" in licence and name in licence
    font = ROOT / "fonts" / (name + ".ttf")
    data = font.read_bytes()
    tables = {}
    for index in range(struct.unpack_from(">H", data, 4)[0]):
        tag, _, offset, size = struct.unpack_from(">4sIII", data, 12 + index * 16)
        tables[tag.decode("ascii")] = data[offset : offset + size]
    fvar = tables["fvar"]
    header = struct.unpack_from(">8H", fvar)
    axes = {}
    for index in range(header[4]):
        tag, low, default, high, _, _ = struct.unpack_from(
            ">4siiiHH", fvar, header[2] + index * header[5]
        )
        axes[tag.decode()] = [low / 65536, default / 65536, high / 65536]
    assert axes["wght"][0] <= 400 and axes["wght"][2] >= 800
    gsub = tables["GSUB"]
    feature_offset = struct.unpack_from(">H", gsub, 6)[0]
    count = struct.unpack_from(">H", gsub, feature_offset)[0]
    features = [
        gsub[feature_offset + 2 + i * 6 : feature_offset + 6 + i * 6].decode() for i in range(count)
    ]
    has_tnum = "tnum" in features
    missing = []
    for char in sorted(set(REQUIRED)):
        glyphs = shape(font, char, 400, "tnum=1")
        if not glyphs or any(g["g"] in (".notdef", "gid0", 0) for g in glyphs):
            missing.append(f"U+{ord(char):04X}")
    assert not missing, f"Missing required characters: {missing}"
    advances = {}
    for weight in (400, 600, 700, 800):
        glyphs = shape(font, "0123456789", weight, "tnum=1,pnum=0")
        widths = [g["ax"] for g in glyphs]
        assert len(widths) == 10 and len(set(widths)) == 1 and widths[0] > 0
        advances[str(weight)] = widths
    proportional = [g["ax"] for g in shape(font, "0123456789", 700, "tnum=0,pnum=1")]
    if has_tnum:
        assert len(set(proportional)) > 1, "Probe does not distinguish tabular/proportional shaping"
    version = subprocess.run(
        ["hb-shape", "--version"], check=True, text=True, capture_output=True
    ).stdout.splitlines()[0]
    disambiguation = {}
    if name == "Inter":
        assert "cv08" in features and "cv05" in features
        for weight in (400, 600, 700, 800):
            normal = shape(font, "Il1", weight, "cv08=0,cv05=0")
            alternate = shape(font, "Il1", weight, "cv08=1,cv05=1")
            assert normal[0]["g"] != alternate[0]["g"]
            assert normal[1]["g"] != alternate[1]["g"]
            disambiguation[str(weight)] = {"normal": normal, "alternate": alternate}
    return {
        "font": name,
        "source_commit": sources["google_fonts_commit"],
        "font_sha256": sources["files"][name + ".ttf"]["sha256"],
        "runtime": version,
        "required_chars": REQUIRED,
        "missing": missing,
        "weight_axes": axes,
        "tnum_feature": has_tnum,
        "feature_tags": features,
        "tabular_advances": advances,
        "proportional_advances_700": proportional,
        "licence": "OFL-1.1",
        "disambiguation_cv08_cv05": disambiguation,
        "status": "PASS; owner adoption pending"
        if has_tnum
        else "REJECTED for explicit tnum: default tabular digits, no tnum feature",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "evidence/font-results.json")
    args = parser.parse_args()
    result = {
        "candidates": [audit_font("Nunito", "OFL.txt"), audit_font("Inter", "Inter-OFL.txt")],
        "recommendation": "Inter, one family; owner adoption pending",
    }
    assert result["candidates"][1]["tnum_feature"]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print("Inter: coverage/tnum/weights/hash/OFL PASS; Nunito explicit tnum absent")
