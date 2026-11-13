#!/bin/bash
# Build the Mac app in the release configuration and assemble it as an app bundle.
#
#   tools/build_app.sh      run from the repository root; writes build/FM27 Lineup Optimizer.app
#                           and prints its path last
#
# The bundle holds the executable, an Info.plist, the app's icon, and every SwiftPM resource bundle found
# beside the executable (the engine's role catalogue and rating tables, and the app's two
# typefaces, among them), copied into Contents/Resources. It is signed ad hoc, for this Mac
# only. The signed app then draws its empty screens into a temporary directory, which proves
# it can load the engine's resources and its typefaces from inside the bundle (a picture run
# stops if a typeface is missing); the script fails if it cannot.
set -euo pipefail

ROOT="$(pwd)"
if [ ! -f "$ROOT/LineupApp/Package.swift" ]; then
    echo "Run this from the repository root (the directory that holds LineupApp/)." >&2
    exit 1
fi

NAME="FM27 Lineup Optimizer"
APP="$ROOT/build/$NAME.app"

swift build --quiet --package-path "$ROOT/LineupApp" -c release --product LineupApp
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

ICON="$ROOT/LineupApp/Sources/LineupAppUI/Resources/AppIcon.icns"
if [ ! -f "$ICON" ]; then
    echo "The app's icon was not found at $ICON; run tools/make_app_icon.sh." >&2
    exit 1
fi
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

CHECK="$(mktemp -d)"
trap 'rm -rf "$CHECK"' EXIT
if ! "$APP/Contents/MacOS/LineupApp" --pictures "$CHECK/pictures" >"$CHECK/output.txt" 2>&1; then
    echo "The built app could not draw its screens, so it cannot load the engine's resources or its typefaces:" >&2
    cat "$CHECK/output.txt" >&2
    exit 1
fi

echo "$APP"
