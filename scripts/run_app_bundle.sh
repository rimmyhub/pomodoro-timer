#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/.app/PomodoroBuddy.app"
VERSION="${1:-1.0.3}"
BUILD_NUMBER="${2:-3}"

"$ROOT_DIR/scripts/build_app_bundle.sh" "$VERSION" "$BUILD_NUMBER"
open "$APP_PATH"
