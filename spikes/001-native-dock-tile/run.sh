#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
derived_dir="${DOCKSTUDIO_DERIVED_DIR:-/tmp/dockstudio-native-derived}"
xcodebuild -quiet -project DockStudio.xcodeproj -scheme DockStudio \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_dir" CODE_SIGNING_ALLOWED=NO build
open -n "$derived_dir/Build/Products/Debug/DockStudio.app" --args --native-dock-tile
