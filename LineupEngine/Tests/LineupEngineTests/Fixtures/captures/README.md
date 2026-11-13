# Captured FMRTE pastes

Each `<name>.tsv` is clipboard text copied from an FMRTE 27 player grid, and `<name>.grids.json` is the grid layout snapshot taken from FMRTE's configuration at that time. The `.tsv` files use CRLF line endings and are marked `-text` in `.gitattributes`; do not let an editor or git rewrite them.

| Capture | Grid | How it was taken |
|---|---|---|
| `u21` | search grid (`SearchPlayersColumns`) | exact clipboard bytes |
| `u21-team-grid` | team grid (`TeamPlayersColumns`) | exact clipboard bytes |
| `first-team` | team grid (`TeamPlayersColumns`) | rebuilt from rows the owner pasted into a chat: the fields are the owner's, with the tab separators and CRLF line endings restored to match the other captures. Its grid snapshot is a copy of `u21-team-grid.grids.json`, taken the same evening with the same layout. Replace both files with `tools/capture_fmrte_paste.sh first-team` the next time the first-team rows are on the clipboard. |
