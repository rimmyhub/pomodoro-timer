#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp/appicon"
ICONSET_DIR="$TMP_DIR/AppIcon.iconset"
BASE_PNG="$TMP_DIR/appicon-1024.png"
OUTPUT_ICNS="$ROOT_DIR/Assets/AppIcon.icns"

mkdir -p "$TMP_DIR" "$ICONSET_DIR" "$ROOT_DIR/Assets"

python3 - "$BASE_PNG" <<'PY'
import math
import struct
import sys
import zlib

output_path = sys.argv[1]
w = 1024
h = 1024

CANVAS_BG = (255, 255, 255, 255)
PIE_DARK = (227, 61, 51, 255)
PIE_LIGHT = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

left = 72
top = 72
right = 952
bottom = 952
corner_r = 204

cx = 512.0
cy = 512.0
pie_outer_r = 292.0
sector_degrees = 305.0

def in_rounded_rect(px, py):
    # Center rectangle strips.
    if left + corner_r <= px <= right - corner_r and top <= py <= bottom:
        return True
    if left <= px <= right and top + corner_r <= py <= bottom - corner_r:
        return True

    # Corner circles.
    corners = (
        (left + corner_r, top + corner_r),
        (right - corner_r, top + corner_r),
        (left + corner_r, bottom - corner_r),
        (right - corner_r, bottom - corner_r),
    )
    for ccx, ccy in corners:
        if (px - ccx) ** 2 + (py - ccy) ** 2 <= corner_r ** 2:
            return True
    return False

rows = bytearray()
for y in range(h):
    rows.append(0)  # PNG filter type: None
    py = y + 0.5
    for x in range(w):
        px = x + 0.5

        if not in_rounded_rect(px, py):
            rows.extend(TRANSPARENT)
            continue

        color = CANVAS_BG
        d = math.hypot(px - cx, py - cy)
        clockwise_degrees = math.degrees(math.atan2(px - cx, -(py - cy)))
        if clockwise_degrees < 0:
            clockwise_degrees += 360

        if d <= pie_outer_r:
            color = PIE_LIGHT
            if clockwise_degrees <= sector_degrees:
                color = PIE_DARK

        rows.extend(color)

def png_chunk(tag, data):
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )

header = b"\x89PNG\r\n\x1a\n"
ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
idat = zlib.compress(bytes(rows), level=9)
png_data = header + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", idat) + png_chunk(b"IEND", b"")

with open(output_path, "wb") as f:
    f.write(png_data)
PY

sips -z 16 16 "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$BASE_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
echo "generated: $OUTPUT_ICNS"
