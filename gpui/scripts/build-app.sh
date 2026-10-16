#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export MACOSX_DEPLOYMENT_TARGET=15.0
app="${1:-$PWD/gpui/target/Dock Studio.app}"
gpui/scripts/build-native.sh
cargo build --manifest-path gpui/Cargo.toml --locked -j 2
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers"
cp gpui/target/debug/dockstudio-gpui "$app/Contents/MacOS/DockStudio"
cp gpui/target/native/dockstudio-bridge "$app/Contents/Helpers/dockstudio-bridge"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>app.dockstudio.gpui</string>
<key>CFBundleName</key><string>Dock Studio</string>
<key>CFBundleExecutable</key><string>DockStudio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
printf 'Built development app: %s\n' "$app"
