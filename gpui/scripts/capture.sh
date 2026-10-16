#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
output="${1:-$(mktemp -d /tmp/dockstudio-gpui-images.XXXXXX)}"
data_dir="$(mktemp -d /tmp/dockstudio-gpui-data.XXXXXX)"
gpui/scripts/build-native.sh
cargo build --manifest-path gpui/Cargo.toml --locked -j 2
DOCKSTUDIO_DATA_DIR="$data_dir" DOCKSTUDIO_CAPTURE_DIR="$output" \
  gpui/target/debug/dockstudio-gpui --capture
if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -hide_banner -loglevel error -framerate 12 -i "$output/frames/frame-%03d.png" \
    -vf 'pad=2000:600:(ow-iw)/2:(oh-ih)/2:color=0x25323b' -c:v libx264 -pix_fmt yuv420p -r 30 "$output/dock-motion.mp4"
fi
printf 'Screenshots: %s\nTest data: %s\n' "$output" "$data_dir"
