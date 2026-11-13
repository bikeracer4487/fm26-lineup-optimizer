#!/bin/bash
# Rebuild the app's icon from its source artwork.
#
#   tools/make_app_icon.sh      run from the repository root
#
# Reads LineupApp/Icon/app-icon-source.jpeg and writes the icon the app ships,
# LineupApp/Sources/LineupAppUI/Resources/AppIcon.icns, which holds every size macOS asks for.
# Run it again after changing the source, then build the app.
set -euo pipefail

ROOT="$(pwd)"
SOURCE="$ROOT/LineupApp/Icon/app-icon-source.jpeg"
if [ ! -f "$SOURCE" ]; then
    echo "Run this from the repository root: $SOURCE was not found." >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SET="$WORK/AppIcon.iconset"
mkdir "$SET"

swift "$ROOT/tools/make_app_icon.swift" "$SOURCE" "$WORK/master.png"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$WORK/master.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$WORK/master.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done

OUT="$ROOT/LineupApp/Sources/LineupAppUI/Resources/AppIcon.icns"
iconutil -c icns "$SET" -o "$OUT"
echo "$OUT"
