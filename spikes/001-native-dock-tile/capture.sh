#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build_dir="$(mktemp -d /tmp/dockstudio-tile-capture.XXXXXX)"
trap 'rm -rf "$build_dir"' EXIT
output_dir="${1:-$(mktemp -d /tmp/dockstudio-tile-images.XXXXXX)}"
source_files=()
while IFS= read -r -d '' path; do
  source_files+=("$path")
done < <(find DockStudio -name '*.swift' ! -name DockStudioApp.swift -print0)
xcrun swiftc -swift-version 5 -parse-as-library "${source_files[@]}" \
  spikes/001-native-dock-tile/Capture.swift -o "$build_dir/capture"
"$build_dir/capture" "$output_dir"
