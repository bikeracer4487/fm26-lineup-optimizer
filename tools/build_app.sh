#!/bin/bash
# Build the Mac app in the release configuration, assemble it as an app bundle and install it
# in /Applications.
#
#   tools/build_app.sh      run from the repository root; writes build/FM27 Lineup Optimizer.app,
#                           closes any open copy of the app, replaces
#                           /Applications/FM27 Lineup Optimizer.app with the new build, opens it
#                           again if a copy was closed, and prints the installed app's path last
#
# The bundle holds the executable, an Info.plist, the app's icon, and every SwiftPM resource bundle found
# beside the executable (the engine's role catalogue and rating tables, and the app's two
# typefaces, among them), copied into Contents/Resources. It is signed ad hoc, for this Mac
# only. The signed app then draws its empty screens into a temporary directory, which proves
# it can load the engine's resources and its typefaces from inside the bundle (a picture run
# stops if a typeface is missing); the script fails if it cannot.
#
# Open copies are closed once the build has compiled and before either bundle is touched, so a
# build that does not compile leaves the open app alone. A copy is any process running the
# executable inside a bundle of the app's name, wherever that bundle is; a `swift run` of the
# package is not one. They are ended with a terminate signal, not asked to quit: the app saves
# each change as it is made, by writing a temporary file and swapping it in, so nothing saved
# is lost, and a signal needs no permission to control the app. Changes to a tactic that were
# not yet saved are lost, as they are on any quit.
#
# If a copy was closed, the installed app is opened once it has been replaced, whichever bundle
# the closed copy was running from. If nothing was open, nothing is opened.
set -euo pipefail

ROOT="$(pwd)"
if [ ! -f "$ROOT/LineupApp/Package.swift" ]; then
    echo "Run this from the repository root (the directory that holds LineupApp/)." >&2
    exit 1
fi

NAME="FM27 Lineup Optimizer"
APP="$ROOT/build/$NAME.app"
INSTALLED="/Applications/$NAME.app"

# Set to 1 when close_open_copies ends a copy, so the installed app is opened again at the end.
CLOSED_A_COPY=0

# End every open copy of the app and wait until it has gone: up to five seconds after a
# terminate signal, then two more after a kill.
close_open_copies() {
    local running="$NAME.app/Contents/MacOS/LineupApp"
    pgrep -f "$running" >/dev/null || return 0
    CLOSED_A_COPY=1
    echo "Closing the open copy of $NAME." >&2
    pkill -f "$running" || true
    for _ in $(seq 1 50); do
        pgrep -f "$running" >/dev/null || return 0
        sleep 0.1
    done
    pkill -9 -f "$running" || true
    for _ in $(seq 1 20); do
        pgrep -f "$running" >/dev/null || return 0
        sleep 0.1
    done
    echo "An open copy of $NAME could not be closed; close it and run this again." >&2
    exit 1
}

swift build --quiet --package-path "$ROOT/LineupApp" -c release --product LineupApp
BIN_DIR="$(swift build --package-path "$ROOT/LineupApp" -c release --show-bin-path)"

close_open_copies

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

# Replace whatever is installed with the build that has just passed its check. ditto keeps the
# signature intact.
rm -rf "$INSTALLED"
if ! ditto "$APP" "$INSTALLED"; then
    echo "The app could not be copied to $INSTALLED; the build is at $APP." >&2
    exit 1
fi

# Put the app back in front of the owner if this run closed it. The install has already
# succeeded, so a failure to open is reported and does not fail the run.
if [ "$CLOSED_A_COPY" -eq 1 ]; then
    open "$INSTALLED" || echo "The app was installed but could not be reopened; open it from /Applications." >&2
fi

echo "$INSTALLED"
