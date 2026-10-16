#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build_dir="$(mktemp -d /tmp/dockstudio-tile-capture.XXXXXX)"
source_files=()
while IFS= read -r path; do
  source_files+=("$path")
done < <(rg --files DockStudio -g '*.swift' | rg -v '/DockStudioApp.swift$')
xcrun swiftc -swift-version 5 -parse-as-library "${source_files[@]}" \
  spikes/001-native-dock-tile/Capture.swift -o "$build_dir/capture"
"$build_dir/capture" "${1:-$PWD/docs/media/native-dock-tile}"
