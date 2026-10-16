#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
output="${1:-$PWD/gpui/target/native/dockstudio-bridge}"
mkdir -p "$(dirname "$output")"
xcrun swiftc -swift-version 5 -O -parse-as-library -target "$(uname -m)-apple-macos15.0" \
 DockStudio/Models/DockDocument.swift DockStudio/Models/DockVisibilityState.swift \
 DockStudio/Services/ProfilePersistence.swift DockStudio/Services/ProfileArchive.swift \
 DockStudio/Services/ItemLaunchPolicy.swift DockStudio/Services/AsyncProcessRunner.swift \
 DockStudio/Services/NativeDockReader.swift DockStudio/Services/DisplayOption.swift \
 DockStudio/Store/DockStore.swift \
 gpui/native/BridgeMain.swift -o "$output"
