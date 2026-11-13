#!/bin/bash
# Capture an FMRTE grid copy (clipboard) plus FMRTE's player-grid column layouts as test fixtures.
#
#   tools/capture_fmrte_paste.sh <name>     writes <name>.tsv and <name>.grids.json
#   tools/capture_fmrte_paste.sh --list-grids   lists the player grids that would be saved; touches nothing
#
# Environment overrides:
#   CAPTURE_DIR   output directory (default: LineupEngine/Tests/LineupEngineTests/Fixtures/captures in the repo)
#   FMRTE_CONFIG  FMRTE config path (default: ~/Library/Application Support/FMRTE27/config.json)
set -euo pipefail

CONFIG="${FMRTE_CONFIG:-$HOME/Library/Application Support/FMRTE27/config.json}"

# Prints the player-grid items (those with a DisplayedName column) as JSON on stdout.
filtered_items() {
python3 - "$CONFIG" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    config = json.load(f)
items = config["ColumnsSettings"]["Items"]
player = [i for i in items if any(c.get("Path") == "DisplayedName" for c in i.get("Columns", []))]
json.dump(player, sys.stdout)
PY
}

if [ "${1:-}" = "--list-grids" ]; then
    filtered_items | python3 -c '
import json, sys
for i in json.load(sys.stdin):
    print("%s\t%d" % (i["SettingsKey"], len(i["Columns"])))
'
    exit 0
fi

if [ $# -ne 1 ] || [ -z "$1" ]; then
    echo "usage: $0 <name> | --list-grids" >&2
    exit 2
fi
NAME="$1"
case "$NAME" in
    */*|.*) echo "error: name must be a plain file stem, got '$NAME'" >&2; exit 2 ;;
esac

if [ -n "${CAPTURE_DIR:-}" ]; then
    OUT="$CAPTURE_DIR"
else
    OUT="$(git rev-parse --show-toplevel)/LineupEngine/Tests/LineupEngineTests/Fixtures/captures"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pbpaste > "$TMP/clip.tsv"
if ! grep -q "$(printf '\t')" "$TMP/clip.tsv"; then
    echo "error: clipboard has no tab character; copy rows from FMRTE's grid first" >&2
    exit 1
fi

filtered_items > "$TMP/items.json"
python3 - "$TMP/items.json" "$TMP/grids.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    items = json.load(f)
with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.dump({"ColumnsSettings": {"Items": items}}, f, indent=1, ensure_ascii=False)
    f.write("\n")
PY

mkdir -p "$OUT"
cp "$TMP/clip.tsv" "$OUT/$NAME.tsv"
cp "$TMP/grids.json" "$OUT/$NAME.grids.json"

python3 - "$OUT/$NAME.tsv" "$OUT/$NAME.grids.json" <<'PY'
import json, sys
data = open(sys.argv[1], "rb").read().decode("utf-8", errors="replace")
rows = [r for r in data.splitlines() if r != ""]
print("rows: %d" % len(rows))
print("fields in first row: %d" % len(rows[0].split("\t")))
print("grids saved: %d" % len(json.load(open(sys.argv[2]))["ColumnsSettings"]["Items"]))
PY
