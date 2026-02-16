#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT_DIR/.app/PomodoroBuddy.app"

"$ROOT_DIR/scripts/build_app_bundle.sh"
open "$APP_PATH"
