#!/usr/bin/env python3
"""Build and verify a prototype debug APK using a disposable public test key."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

VERSION = "4.7.2.stable"
PACKAGE = "org.worldofwords.prototype.debug"
PERMISSIONS = {"android.permission.VIBRATE", "android.permission.INTERNET"}


def validate_manifest(badging: str, tree: str) -> None:
    required = [
        f"package: name='{PACKAGE}'",
        "sdkVersion:'24'",
        "targetSdkVersion:'36'",
        "application-debuggable",
    ]
    for text in required:
        if text not in badging:
            raise ValueError(f"APK manifest missing {text}")
    permissions = set(re.findall(r"uses-permission: name='([^']+)'", badging))
    if permissions != PERMISSIONS:
        raise ValueError(f"Unexpected APK permissions: {sorted(permissions)}")
    if not re.search(r"android:screenOrientation\([^)]*\)=\(type 0x10\)0x1\b", tree):
        raise ValueError("APK must request portrait orientation")


def validate_assets(apk: Path) -> None:
    with zipfile.ZipFile(apk) as archive:
        if archive.testzip() is not None:
            raise ValueError("Corrupt APK ZIP entry")
        names = archive.namelist()
        for path in ["assets/content/pl/manifest.json", "assets/data/audio/cues.json"]:
            if path not in names:
                raise ValueError(f"APK missing {path}")
        if not any(name.startswith("assets/features/debug/") for name in names):
            raise ValueError("Debug APK must retain developer tools")
        if any(name.startswith(("assets/tests/", "assets/addons/gut/")) for name in names):
            raise ValueError("APK must not contain test code")


def run(command: list[str], env: dict[str, str]) -> str:
    result = subprocess.run(command, env=env, check=False, text=True, capture_output=True)
    output = result.stdout + result.stderr
    if result.returncode or re.search(r"^(SCRIPT ERROR:|ERROR:)", output, flags=re.MULTILINE):
        raise RuntimeError(output)
    return output


def version_suffix(root: Path, env: dict[str, str]) -> str:
    commit = run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"], env).strip()
    changes = run(
        ["git", "-C", str(root), "status", "--porcelain", "--untracked-files=no", "--", "game"],
        env,
    ).strip()
    return f"{commit}-dirty" if changes else commit


def stamp_debug_version(presets: str, suffix: str) -> str:
    header = re.search(r'^\[preset\.(\d+)\]\nname="Android Debug"$', presets, flags=re.MULTILINE)
    if header is None:
        raise ValueError("Android Debug export preset not found")
    start = presets.index(f"[preset.{header.group(1)}.options]")
    end = presets.find("\n[", start)
    end = len(presets) if end == -1 else end + 1
    section, count = re.subn(
        r'^version/name="([^"]*)"$',
        lambda match: f'version/name="{match.group(1)} ({suffix})"',
        presets[start:end],
        flags=re.MULTILINE,
    )
    if count != 1:
        raise ValueError("Android Debug preset must define exactly one version/name")
    return presets[:start] + section + presets[end:]


def build(
    root: Path, output: Path, godot: str, sdk: Path, java: Path, templates: Path | None
) -> None:
    if not sdk.is_dir() or not (java / "bin/keytool").is_file():
        raise ValueError("An installed Android SDK and JDK are required")
    output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    version = run([godot, "--headless", "--version"], env).strip()
    if not version.startswith(VERSION + "."):
        raise ValueError(f"Pinned Godot {VERSION} required, got {version}")
    with tempfile.TemporaryDirectory(prefix="wow-android-debug-") as directory:
        temporary = Path(directory)
        # Export from a copy so the build-specific version name never touches tracked files.
        project = temporary / "game"
        shutil.copytree(root / "game", project)
        suffix = version_suffix(root, env)
        presets = project / "export_presets.cfg"
        presets.write_text(stamp_debug_version(presets.read_text(), suffix))
        key = temporary / "public-debug.keystore"
        run(
            [
                str(java / "bin/keytool"),
                "-genkeypair",
                "-noprompt",
                "-storetype",
                "JKS",
                "-keystore",
                str(key),
                "-storepass",
                "android",
                "-keypass",
                "android",
                "-alias",
                "androiddebugkey",
                "-keyalg",
                "RSA",
                "-keysize",
                "2048",
                "-validity",
                "10000",
                "-dname",
                "CN=Android Debug,O=World of Words Prototype,C=PL",
            ],
            env,
        )
        config = temporary / "config/godot"
        config.mkdir(parents=True)
        settings = {
            "android_sdk_path": str(sdk),
            "java_sdk_path": str(java),
            "debug_keystore": str(key),
            "debug_keystore_user": "androiddebugkey",
            "debug_keystore_pass": "android",
        }
        content = '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
        content += "".join(
            f"export/android/{name} = {json.dumps(value)}\n" for name, value in settings.items()
        )
        (config / "editor_settings-4.7.tres").write_text(content)
        env["XDG_CONFIG_HOME"] = str(temporary / "config")
        env["GODOT_ANDROID_KEYSTORE_DEBUG_PATH"] = str(key)
        env["GODOT_ANDROID_KEYSTORE_DEBUG_USER"] = "androiddebugkey"
        env["GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD"] = "android"
        if templates is not None:
            destination = temporary / "data/godot/export_templates" / VERSION
            destination.parent.mkdir(parents=True)
            destination.symlink_to(templates.resolve(), target_is_directory=True)
            env["XDG_DATA_HOME"] = str(temporary / "data")
        run([godot, "--headless", "--path", str(project), "--import", "--quit"], env)
        print(
            run(
                [
                    godot,
                    "--headless",
                    "--path",
                    str(project),
                    "--export-debug",
                    "Android Debug",
                    str(output),
                ],
                env,
            )
        )
        tools = sdk / "build-tools/36.0.0"
        badging = run([str(tools / "aapt"), "dump", "badging", str(output)], env)
        tree = run(
            [str(tools / "aapt"), "dump", "xmltree", str(output), "AndroidManifest.xml"], env
        )
        validate_manifest(badging, tree)
        if f"({suffix})'" not in badging:
            raise ValueError(f"APK versionName must carry build {suffix}")
        validate_assets(output)
        run([str(tools / "apksigner"), "verify", "--verbose", str(output)], env)
        resources = output.parent / "android-debug-content.zip"
        print(
            run(
                [
                    godot,
                    "--headless",
                    "--path",
                    str(project),
                    "--export-pack",
                    "Android Debug",
                    str(resources),
                ],
                env,
            )
        )
        smoke_env = env.copy()
        smoke_env["XDG_DATA_HOME"] = str(temporary / "smoke-data")
        (temporary / "smoke-data").mkdir()
        print(
            run(
                [
                    godot,
                    "--headless",
                    "--main-pack",
                    str(resources),
                    "--script",
                    str(root / "tools/export_smoke.gd"),
                ],
                smoke_env,
            )
        )
        (output.parent / "android-debug-verification.txt").write_text(
            f"Godot: {version}\nDebug package: {PACKAGE}\nBuild: {suffix}\n"
            "SDK: 24 minimum / 36 target\nPermissions: INTERNET,VIBRATE\nOrientation: portrait\n"
            "Signature: verified public disposable debug key\n"
            "Packaged boot/audio/debug route: verified with headless cue sink\n"
            "No production upload key or GitHub signing secrets were used.\n"
        )
    print(f"OK: verified prototype debug APK: {output}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--android-sdk", type=Path, default=os.environ.get("ANDROID_HOME"))
    parser.add_argument("--java-home", type=Path, default=os.environ.get("JAVA_HOME"))
    parser.add_argument("--templates", type=Path)
    parser.add_argument("--output", type=Path, default=Path("builds/world-of-words-debug.apk"))
    args = parser.parse_args()
    if args.android_sdk is None or args.java_home is None:
        parser.error("set ANDROID_HOME/JAVA_HOME or pass --android-sdk/--java-home")
    build(
        Path(__file__).resolve().parents[1],
        args.output.resolve(),
        args.godot,
        args.android_sdk.resolve(),
        args.java_home.resolve(),
        args.templates,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
