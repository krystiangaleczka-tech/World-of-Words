#!/bin/sh
# Pinned public dependencies only. Provider config, signing and credentials stay local.
set -eu
cd "$(dirname "$0")"
cache=$(mktemp -d)
trap 'rm -rf "$cache"' EXIT

fetch() {
    curl -fL --retry 2 "$1" -o "$cache/$2.zip"
    printf '%s  %s\n' "$3" "$cache/$2.zip" | shasum -a 256 -c -
}

fetch https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/poing-godot-admob-v5.1.0.zip admob 8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f
fetch https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/ios-template-v4.7.2.zip admob-ios 6e7f1c807761f9c0ad45d335ac4c74acd4bba7a31f9e1c7cd16a5220010cce71
fetch https://github.com/hyodotdev/openiap/releases/download/godot-iap-3.6.2/godot-iap-3.6.2.zip openiap 81035c9835dae89d25bf0cf1f807e765ed03c6a9d8186632ae6384fc8c195621

rm -rf addons
unzip -q "$cache/admob.zip" -d "$cache/admob"
mkdir -p addons/admob/ios/bin export
cp -R "$cache/admob/poing-godot-admob/addons/admob/." addons/admob/
unzip -oq "$cache/admob-ios.zip" -d addons/admob/ios/bin
unzip -oq "$cache/openiap.zip" -d .
printf '%s\n' "Pinned AdMob and OpenIAP dependencies installed. No provider secrets were written."
