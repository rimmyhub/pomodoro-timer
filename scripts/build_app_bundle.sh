#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PomodoroBuddy"
VERSION="${1:-1.0.2}"
BUILD_NUMBER="${2:-2}"
CONFIGURATION="${CONFIGURATION:-release}"
APP_DIR="$ROOT_DIR/.app/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE_DIR="$ROOT_DIR/.build/ModuleCache"

cd "$ROOT_DIR"
mkdir -p "$MODULE_CACHE_DIR"

echo "Building $APP_NAME ($CONFIGURATION)..."
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR" \
swift build -c "$CONFIGURATION" --product "$APP_NAME" >/dev/null
BIN_DIR="$(
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" \
  SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_DIR" \
  swift build -c "$CONFIGURATION" --show-bin-path
)"
EXECUTABLE="$BIN_DIR/$APP_NAME"

if [[ ! -f "$EXECUTABLE" ]]; then
  echo "Build output not found: $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy SwiftPM resource bundles (for custom sounds loaded via Bundle.module).
for bundle in "$BIN_DIR"/"${APP_NAME}"_*.bundle "$BIN_DIR"/"${APP_NAME}".bundle; do
  if [[ -d "$bundle" ]]; then
    cp -R "$bundle" "$RESOURCES_DIR/"
  fi
done

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>PomodoroBuddy</string>
  <key>CFBundleIdentifier</key>
  <string>com.hyerim.pomodorobuddy</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>PomodoroBuddy</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "App bundle created:"
echo "$APP_DIR"
echo "Version: $VERSION ($BUILD_NUMBER)"
echo ""
echo "Run with:"
echo "open \"$APP_DIR\""
