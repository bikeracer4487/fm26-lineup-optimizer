#!/bin/bash
# Build the Mac app in the release configuration and assemble it as an app bundle.
#
#   tools/build_app.sh      run from the repository root; writes build/FM27 Lineup Optimizer.app
#                           and prints its path
#
# The bundle holds the executable, an Info.plist, and every SwiftPM resource bundle found
# beside the executable (the engine's role catalogue and rating tables among them), copied
# into Contents/Resources. It is signed ad hoc, for this Mac only.
set -euo pipefail

ROOT="$(pwd)"
if [ ! -f "$ROOT/LineupApp/Package.swift" ]; then
    echo "Run this from the repository root (the directory that holds LineupApp/)." >&2
    exit 1
fi

NAME="FM27 Lineup Optimizer"
APP="$ROOT/build/$NAME.app"

swift build --package-path "$ROOT/LineupApp" -c release --product LineupApp
BIN_DIR="$(swift build --package-path "$ROOT/LineupApp" -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LineupApp" "$APP/Contents/MacOS/LineupApp"

found=0
for bundle in "$BIN_DIR"/*.bundle; do
    [ -e "$bundle" ] || continue
    cp -R "$bundle" "$APP/Contents/Resources/"
    found=$((found + 1))
done
if [ "$found" -eq 0 ]; then
    echo "No resource bundles beside the executable in $BIN_DIR; the engine cannot run without them." >&2
    exit 1
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>local.fm27.lineup-optimizer</string>
    <key>CFBundleName</key>
    <string>FM27 Lineup Optimizer</string>
    <key>CFBundleDisplayName</key>
    <string>FM27 Lineup Optimizer</string>
    <key>CFBundleExecutable</key>
    <string>LineupApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || {
    echo "Ad hoc signing failed:" >&2
    codesign --force --deep --sign - "$APP"
    exit 1
}

echo "$APP"
