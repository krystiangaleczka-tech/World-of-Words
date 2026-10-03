#!/bin/sh
# Pinned upstream archives; binaries stay outside Git.
set -eu
cd "$(dirname "$0")"
cache=$(mktemp -d)
trap 'rm -rf "$cache"' EXIT
fetch() {
    curl -fL --retry 2 "$1" -o "$cache/$2.zip"
    printf '%s  %s\n' "$3" "$cache/$2.zip" | shasum -a 256 -c -
}
fetch https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/poing-godot-admob-v5.1.0.zip admob 8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f
fetch https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/android-template-v4.7.2.zip android f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee
fetch https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/3.3.0/godot-google-play-billing.zip billing 20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568
unzip -q "$cache/admob.zip" -d "$cache"
mkdir -p addons/admob/android/bin export
cp -R "$cache/poing-godot-admob/addons/admob/." addons/admob/
unzip -oq "$cache/android.zip" -d addons/admob/android/bin
unzip -oq "$cache/billing.zip" -d addons/
