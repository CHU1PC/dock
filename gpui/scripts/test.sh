#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
gpui/scripts/build-native.sh
cargo test --manifest-path gpui/Cargo.toml --locked -j 2
swift test --scratch-path /tmp/dockstudio-headless-tests
