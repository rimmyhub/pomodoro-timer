#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PomodoroBuddy"
VERSION="${1:-1.0.3}"
BUILD_NUMBER="${2:-3}"
APP_PATH="$ROOT_DIR/.app/$APP_NAME.app"
ZIP_NAME="${APP_NAME}-macOS-v${VERSION}.zip"
ZIP_PATH="$ROOT_DIR/$ZIP_NAME"

"$ROOT_DIR/scripts/build_app_bundle.sh" "$VERSION" "$BUILD_NUMBER"

rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Release zip created:"
echo "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH"
