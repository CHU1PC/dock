#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
gpui/scripts/build-native.sh
cargo build --manifest-path gpui/Cargo.toml --locked -j 2
exec gpui/target/debug/dockstudio-gpui "$@"
