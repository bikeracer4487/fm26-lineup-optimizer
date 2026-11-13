# Getting a full FM27 squad snapshot into a file on macOS (FMRTE 27 and alternatives)

The most reliable low-effort route on macOS today is FMLibreEditor's built-in player-list export (CSV/JSON, one click, or one command via its `fmlibre-probe` tool), not FMRTE 27.\[1\] I could not find any official FMRTE 27 bulk exporter, and the "Exporters / AttributesToIgnore" config section is not documented in any public source I could reach. FMLibreEditor's export probably does not include the live fitness fields (condition, jadedness, sharpness, injured/banned). For those, the best stopgap is FMRTE 27's grid copy (Cmd+C), joined to the FMLibreEditor file on the player's unique ID.

## TL;DR
- **Best primary source: FMLibreEditor (free, GPL-3.0, macOS Steam).** Its Export button writes the filtered player list to CSV/JSON. Each row has UID, age, club, positions and all position ratings, CA/PA, every attribute (hidden ones included) and the full contract, plus the in-game date. There is also a `fmlibre-probe players --export FILE` command, so a refresh can in principle run with no clicks. Gaps: the developer says export skips the injury, ban and retirement lookups, and the PR doesn't list condition, jadedness or sharpness as columns.
- **FMRTE 27 has no documented bulk exporter.** Officially it has per-player "Export & import" (copies selected categories onto another player), free browsing, scheduled AI-Assistant tasks and Cmd+C copy of grid rows (macOS changelog). I found no documentation of a command line, plugin API, file-writing assistant tasks or the "Exporters/AttributesToIgnore" keys. Treat anything about them as unverified.
- **Other options are worse for your field list.** Genie Scout 27 is Windows-only. MacLibero RT shows hidden attributes but advertises no data export. FM27 itself has no Print/Export to file. The F8/F9 BepInEx "view exporter" mods export only what the in-game view shows, so no hidden attributes and no numeric jadedness, and the one macOS port has a user report of empty exports.

## How to read the labels
Each claim has a source URL, a date, and one of these labels:
- **(a)** official documentation or the vendor's own site
- **(b)** verified by someone using FM27
- **(c)** carried over from an earlier version
- **(d)** speculation, mine or the source's

"Accessed 13 Nov 2026" means the page showed no date of its own.

## Key Findings

### 1. FMRTE 27 export features

| Question | Finding | Source / date / label |
|---|---|---|
| What exists officially | The docs list "Export & import" under Editing tools, next to Presets, Mass Edit and Freezer.\[2\] | docs.fmrte.com/tools/presets/ (sidebar), accessed 13 Nov 2026, **(a)** |
| What it does | "Export and Import copies selected data onto an existing player, it does not create an additional player. Check the destination player and selected categories before importing."\[3\] It is a player-template/clone feature, not a data-dump feature. | docs.fmrte.com/help/faq/ (labelled "Version: FMRTE 27"), accessed 13 Nov 2026, **(a)** |
| File formats | FMRTE 27's macOS changelog, Build 4: "Ability to import players from legacy .pxml files."\[4\] In earlier editions, export was to JSON or CSV.\[5\] I found no FMRTE 27 source naming its export format. | fmrte.com/files/file/185-fmrte-for-macos/ (updated 12 Nov 2026), **(a)** for the import. fmrte.com/forums/topic/9762-exporting/ **(c)**, archive-era FMRTE (exact edition not stated). |
| Whole squad / search result in one go | Archived staff answer: "FMRTE does not offer any feature to export players in bulk, you can though export players to json or csv, but you have to do it 1 by 1." The same was said for FMRTE 19/20, and users asked for "mass export" from FMRTE 19 onward.\[5\]\[6\] No FMRTE 27 source says this has changed. | fmrte.com/forums/topic/9762-exporting/ **(c)**; fmrte.com/forums/topic/7495-19-export-csv/ (Oct 2018) **(c, FMRTE 19)** |
| How it's triggered | In older editions: "when you've opened player details in FMRTE. You'll find Export and Export CSV down the right side of the screen."\[7\] | fmrte.com/forums/topic/7719-… **(c, FMRTE 19)** |
| Choosing which attributes | The developer (BraCa) said "Next release (build 5) will allow you to configure which attributes are imported."\[8\] That is the closest public trace of an "attributes to ignore" setting, and it concerns **import**, not export. | fmrte.com/bug-tracker/…/staff-attributes-exportimport-r472/ **(c, FMRTE 22)** |
| "Exporters" section / "AttributesToIgnore" key | **Not found** in the FMRTE 27 docs, the full macOS changelog (builds 2–12) or the forum. You have seen these keys in your own config file, but I cannot confirm from any source what they control, whether they apply to the per-player export or the import, or whether they enable a bulk mode. I did not invent a meaning for them. | (no source) |
| Where files go on macOS | **Not found.** The only documented user-data path is reached through Settings → Support → Diagnostics → "Open folder" next to Log folder, which holds the Presets subfolder. On FMRTE 24 for Mac, that folder was `~/.config/FMRTE 24/`.\[2\]\[9\] | docs.fmrte.com/tools/presets/ **(a)**; fmrte.com/forums/topic/10581-… **(c, FMRTE 24)** |
| Free or licence-only | "Browsing and searching are free. Saving edits requires an activated license." Licences cost €7.99 once, or €11/year by subscription.\[10\]\[11\] Nothing says export needs a licence. Writing an import into the game is an edit, so it does. | docs.fmrte.com (accessed 13 Nov 2026) **(a)**; fmrte.com home page (accessed 13 Nov 2026) **(a)** |

**What this means for you:** FMRTE 27's documented export works one player at a time and is meant for making templates. It is not a replacement for your Windows grid-to-Excel workflow. Before relying on the "Exporters" config section, test it on two or three players and see what file appears.

### 2. Can FMRTE 27 be scripted or automated?

- **Command line / plugin API:** none documented. On macOS, "Plugin" in the changelog refers to FMRTE's own loader inside the game ("Plugin not loading from Heroic with SIP enabled", Build 3), not an extension API.\[4\] Source: fmrte.com/files/file/185-fmrte-for-macos/, updated 12 Nov 2026, **(a)**.
- **Copying a grid to the clipboard:** the macOS changelog, Build 3, lists under Fixed: "Copying grid rows (CMD+C)".\[4\] So grid rows can be copied on the Mac build **(a)**. FMRTE 27 grids also "sort by up to three columns and remember your layout"\[10\] (fmrte.com home page, accessed 13 Nov 2026, **(a)**). I found no documentation of the clipboard format (tab-separated or not), the maximum number of rows, or which columns you can add.
- **AI Assistant and its tasks:** official. It is off by default and needs your own OpenAI/Anthropic/Gemini key or a local model (Ollama, LM Studio). "You can also ask for a scouting report every week, or approve a preset to run on a schedule. Schedules follow the in-game calendar, while FMRTE is open with your save." Your save data goes to the provider you pick.\[10\] Source: fmrte.com home page, accessed 13 Nov 2026, **(a)**.
  - I found **no** documentation that these tasks write files or export data, and no public mention of an "assistant-tasks" file or key. Using the assistant as an exporter is **(d)**.
- **Shortlists:** search results can be saved as an FM `.fmf` shortlist ("Right-click and choose Shortlists → Add to new shortlist").\[12\] That moves player IDs, not attributes. Source: docs.fmrte.com/scouting/shortlists/, **(a)**. Note that the page's sample path still says "Football Manager 26", so parts of the doc may be carried over **(c)**.\[12\]

**My assessment (d):** the only FMRTE 27 path that comes close to your old workflow is to select all rows in a squad grid, press Cmd+C, and save the clipboard to a file with `pbpaste > squad.tsv`. You could drive that keystroke with AppleScript/System Events, but that is the same kind of fragile UI scripting you are trying to leave behind.

### 3. Alternatives on macOS for FM27

#### FMLibreEditor (open source), the best fit
- **Platform:** "Works on Windows (Xbox / Game Pass and Steam) and macOS (Steam)." GPL-3.0, beta.\[13\]\[14\] Source: github.com/tozmoz/FMLibreEditor README, accessed 13 Nov 2026, **(a)**.
- **FM27 release support:** v0.5.1 "works with FM27's full release (Steam 27.0.1 on Windows and macOS…)" and "adds staff and club export".\[15\] Source: sortitoutsi.net/content/78126/…, accessed 13 Nov 2026, **(a)** (developer's own post).
- **The export:** PR #74, merged 3 Nov 2026. The developer's own testing was on an FM27 Steam save, build 26340721, so this is **(a)/(b)**.\[1\]
  - **Trigger:** "Export, in the player list's toolbar, writes what the list's search, filters and order select".\[1\] Filtering to your club therefore gives first team, U21 and U18 in one file, provided the filter matches every player your club owns. Check this for players out on loan.
  - **Fields:** "UID, names, date of birth, age, nationality and club; positions and all position ratings, CA and PA, height; every attribute on the 1–20 scale, hidden ones included, and personality; reputation, caps and asking price; the contract: wage, dates, squad status, number, listing and clauses." Every CSV row carries the in-game date.\[1\]
  - **Formats:** CSV, either comma or semicolon, UTF-8 with BOM. JSON has a header object, then one object per line. Money is in pounds.\[1\]
  - **Speed:** the PR #74 test log records "all 37,971 players in 2.4 s as CSV and 3.9 s as JSON (debug build)", with "37,971 rows of 106 cells, the in-game date on each".
  - **Headless option:** "`fmlibre-probe players [filters] --export FILE` writes the same file."\[1\] The command-line probe is documented in docs/DEVELOPING.md.
  - **Known gap:** "Players are read as a profile is (read_player_details), without the injury, ban and retirement lookups."\[1\] Expect the injured and banned flags to be missing from the export.
  - **Output folder:** Windows `Documents\FMLibreEditor\Exports`, with files named after the in-game date (e.g. `players-2027-01-02.csv`). On macOS, PR #78 (release 0.4.2) reports that "a bundled copy of the app wrote into ~/Documents/FMLibreEditor/Exports". The v0.4.2 release notes add that "Files go to Documents/FMLibreEditor/Exports… All of this works on Windows… and on macOS."
- **Mac check:** PR #78 ("#72 to #76 checked on the Mac; release 0.4.2") says of those changes: "Four of them needed nothing: they were tried in the app on the Mac and work." The one that needed Mac-specific work was #75, not the export (#74) **(a)**. A GitHub issue author also wrote "I run it on macOS (Steam, Apple Silicon) with my FM27 save, and the player export is now part of how I plan my squad"\[16\] (github.com/tozmoz/FMLibreEditor/issues/133, Nov 2026, **(b)**).
- **Jadedness:** the app reads the numeric value. It is "an i16 at player +0x25A, between match sharpness and energy, and -500 when the player is rested", and it shows in the profile and as a sortable Squad-tab column (PR #48, **(a)/(b)**).\[17\] Whether the export includes jadedness, condition or match sharpness is **not documented**: the PR #74 field list doesn't mention them.
- **Loans:** v0.5.0 (7 Nov 2026) shows a player's loan and its terms on his profile **(a)**.\[18\] Whether loan status is an export column is not documented.
- **Position familiarity (1–20):** "positions and all position ratings" are exported, and FM stores familiarity on a 1–20 scale, so this most likely covers your need.\[1\] Confirm against one player.
- **Unattended?** Partly. The GUI needs one click after you set the filter. The probe CLI can be called by a script or launchd job while FM27 is open. It has been run on macOS: PR #78 reports "fmlibre-probe players --club arsenal --export wrote 97 players as JSON", and PR #160 ran the probe "with FM27 on macOS Steam (build 26385295, 27.0.1, Apple silicon)" **(a)/(b)**.

#### MacLibero RT
- Native Mac app, free scouting "hidden attributes included", position ratings, contracts, loans, condition/morale editing (licence €6.99 once). Version 1.1.0 (10 Nov 2026) supports FM 27.0.1. macOS 15+, Steam or Epic. "Always launch FM 27 from MacLibero RT."\[19\] Source: maclibero.com, accessed 13 Nov 2026, **(a)**.
- **Export:** the feature list has no CSV/JSON player export. Its only "Export to FM 27…" is for tactics.\[19\] No CLI was found. **Not suitable for unattended snapshots** on current evidence.

#### Genie Scout 27
- "Does it work on a Mac? No. Genie Scout is a Windows program, and there is no Mac or Linux version." Beta 4 (10 Nov 2026) supports FM 27.0.1.\[20\]\[21\] Sources: geniescout.com/download/ and fmscout.com Genie Scout 27g FAQ, **(a)**. Running it through Wine is a FM-era-2010 workaround **(c)** and wouldn't work anyway: Genie Scout must run on the same Windows PC as FM.\[21\]\[22\]

#### Official In-Game Editor
- The FM27 IGE player screen has Personal Details, Player Attributes and Contracts tabs, with Hidden Attributes, Positions, Fitness and Bans, plus quick actions to "export and import an attribute template".\[23\] Source: fmportugal.net/en/in-game-editor-fm27/ (summarising SI's October material), **(a)** at second hand.
- That export is per player and covers attributes only. I found no squad-wide export and no documentation of the template file format. I didn't find SI's own manual page confirming IGE features on Mac. **Not suitable.**

#### FM27's own export (print screen / custom views)
- None. FM View Exporter's README says "Since FM26 there is no Print → Export any more" (github.com/ElectroHugin/FM-View-Exporter, accessed 13 Nov 2026). An SI-community thread titled "FM27 is NOT going to have an export function?" dates from 26 Sep 2026.\[24\]\[25\] Both are **(b)**. I found no SI manual page saying otherwise.
- Custom views can still show attributes, condition and sharpness on screen, but only as FM displays them: masked or ranged attributes, no hidden attributes, no numeric jadedness.

#### BepInEx "view exporter" mods (they export the in-game table)
- **fm27-player-export-macos** (oeknudsen; fork of vinteset's FM26 plugin): Apple Silicon, needs sptndc's FM27 BepInEx loader and Rosetta. Select players, press F9, and it writes CSV and HTML.\[26\] The author's own caveat: "I haven't verified the star columns (Ability/Potential)". Another user on an M1 Mac reports that "every export comes out empty… captures 0 rows".\[26\] Source: sortitoutsi.net/content/78155/…, **(b)**.
- **FM View Exporter** (F9, CSV/HTML, 375 documented columns) and **FM27 Exporter** (F8, HTML/RTF/CSV in the FM24 Print-Screen layout):\[25\]\[27\] both document only Windows, plus Linux/Proton for FM27 Exporter.\[25\]\[27\] Neither documents macOS. Sources: github.com/ElectroHugin/FM-View-Exporter; sortitoutsi.net/content/78451/fm27-exporter, **(a)**.
- **Limit for you:** these export only what the view shows ("Unscouted values stay hidden").\[25\] They can't supply hidden attributes, CA/PA numbers or numeric jadedness.

#### Other Mac tools found (lower confidence)
- **Pitchside:** open-source, "Genie Scout-style" tool for FM27 Steam on Apple Silicon. It shows hidden attributes and potential, and installs a BepInEx setup.\[28\] Export capability is not documented in what I saw (github.com/alizadyx/pitchside, **(a)**).
- **Regenesis 27:** Windows and Mac. It edits condition, sharpness and injuries, and has "shortlists with CSV export".\[29\] The CSV fields are not documented (sortitoutsi.net/content/78082/…, **(a)**).
- **FM Lens:** a Mac companion derived from FMLibreEditor (github.com/IamDejman/fm-lens, **(a)**).\[30\] Its export features weren't checked.

### Field coverage at a glance

| Your field | FMLibreEditor export | FMRTE 27 (grid Cmd+C) | View-exporter mods | MacLibero RT |
|---|---|---|---|---|
| Name, age, positions, club | Yes (a) | Likely, if the grid has the columns (d) | Yes, as shown | On screen only |
| CA / PA (numeric) | Yes (a) | Likely (d) | Stars only, unverified (b) | On screen only |
| Visible + hidden attributes | Yes, 1–20, hidden included (a) | Unknown which columns a grid offers | Visible only, may be masked | On screen only |
| Position familiarity 1–20 | "All position ratings" (a) | Unknown | No | On screen |
| Condition %, sharpness | Not listed (gap) | Unknown | Yes, as FM shows them | On screen |
| Jadedness (numeric, ±) | Read by the app; export not documented | An older FMRTE showed it as a signed number: a user in the FMRTE forum archive thread "The Fitness Cheat…with a tweak!" notes "jadedness is -32767" as a limit value (c) | No | Not documented |
| Injured / banned | **Skipped by export** (a) | Unknown | As FM shows | On screen |
| Loan status | Not documented in export | Unknown | If the view has the column | On screen |
| Contract type, wage, expiry → months left | Wage, dates, squad status (a); compute months yourself | Unknown | If the view has the column | On screen |
| One-shot whole squad | Yes (filter, then Export) | Select all + Cmd+C | Yes (F8/F9) | No |
| Unattended | Possibly, via `fmlibre-probe` (d) | Only with UI scripting (d) | No (keypress) | No |

## Recommendations (fewest manual steps per refresh)

1. **FMLibreEditor export as the backbone (≈1 click; potentially 0).** Install the macOS build, connect to the running save, filter the player list to your club, and press Export (CSV or JSON). Your optimizer reads the newest file in the exports folder; find the macOS path with "Show in folder". If the `fmlibre-probe` binary runs on macOS, call `fmlibre-probe players [club filter] --export ~/fm/squad.json` from your tool and drop the click entirely. Trade-offs:
   - It is a beta memory-reader.\[14\]
   - Each FM patch may need an app update. It "stays read-only on a version of FM27 it has not been checked with yet".\[31\]
   - The injured and banned flags are missing; condition, sharpness and jadedness are probably missing.
2. **Fill the fitness gaps with FMRTE 27's grid copy (≈3 actions: open squad grid, Cmd+A, Cmd+C, then `pbpaste`).** Build a squad grid layout in FMRTE with UID, condition, jadedness, sharpness, injured and banned (layouts persist), and join it to file 1 on UID. Test first whether FMRTE's grid offers those columns and copies them as tab-separated text. None of that is documented **(d)**.
3. **Ask the FMLibreEditor maintainer to add the live fields to the export.** The project actively accepts issues; for example, club export was proposed in #133\[16\] and shipped in v0.5.1.\[15\] Jadedness, condition and sharpness are already read by the app.\[15\]\[17\] Injury and ban lookups exist but are skipped "for speed", even though export takes under a second.\[1\] This is the change most likely to get you to a single, fully unattended file.
4. **Test FMRTE's "Exporters/AttributesToIgnore" yourself, not on trust.** Export one player, check the file and the folder it lands in, then edit the key and repeat. If it turns out to support multi-select export, FMRTE becomes a strong option, but no public source says so.
5. **Avoid as a primary source:** the BepInEx view exporters (no hidden data, and the Mac port is fragile), MacLibero RT (no export), the In-Game Editor (per-player templates only), Genie Scout (Windows-only) and FM27's built-in screens (no export).

## Caveats
- Sports Interactive's FM27 page (footballmanager.com/fm27) states that "all digital versions of FM27 release on 10 November 2026 on all supported platforms", so everything here is days or weeks old. FMLibreEditor, the BepInEx mods and FMRTE 27 are all at early builds and change quickly.
- I could not fetch the official FMRTE "Export & import" docs page or the "AI Assistant" docs page. The site's link points to docs.fmrte.com/tools/export-and-import/, but tool restrictions blocked the fetch. Read it yourself before deciding; it may answer the format, folder and bulk questions directly.
- FMLibreEditor's export column list comes from the merge PR (3 Nov 2026).\[1\] The v0.5.1 changelog adds "Export the staff and club lists to CSV or JSON" (club export from issue #133, staff export from PR #160) but lists no new player columns. Open one export and check before building on it.
- All three tools read game memory. Use them only in offline single-player saves, and keep backups.\[14\]
## Sources

1. [Export the player list to CSV or JSON by tozmoz · Pull Request #74 · tozmoz/FMLibreEditor](https://github.com/tozmoz/FMLibreEditor/pull/74)
2. [Reusing changes with Presets](https://docs.fmrte.com/tools/presets/)
3. [Frequently asked questions | FMRTE Documentation](https://docs.fmrte.com/help/faq/)
4. [FMRTE for macOS](https://www.fmrte.com/files/file/185-fmrte-for-macos/)
5. [Exporting - Archive - FMRTE](https://www.fmrte.com/forums/topic/9762-exporting/)
6. [\[19\] - export .csv - Archive - FMRTE](https://www.fmrte.com/forums/topic/7495-19-export-csv/)
7. [How can I export to .csv? I read about Build 2 feature. - Archive - FMRTE](https://www.fmrte.com/forums/topic/7719-how-can-i-export-to-csv-i-read-about-build-2-feature/)
8. [Staff Attributes Export/Import - FMRTE for Windows](https://www.fmrte.com/bug-tracker/fmrte/windows/staff-attributes-exportimport-r472/)
9. [Editing preset jsons directly on FMRTE 24 for MacOS - Archive - FMRTE](https://www.fmrte.com/forums/topic/10581-editing-preset-jsons-directly-on-fmrte-24-for-macos/)
10. [FMRTE 27: real-time editor for Football Manager 27 (FM27)](https://www.fmrte.com/)
11. [Getting started with FMRTE 27 | FMRTE Documentation](https://docs.fmrte.com/)
12. [Sending players to a Football Manager shortlist](https://docs.fmrte.com/scouting/shortlists/)
13. [GitHub - morganlaw/FMLibreEditor: Free, open-source live editor for Football Manager 27 on Windows (Game Pass, Steam) and macOS (Steam) · GitHub](https://github.com/morganlaw/FMLibreEditor)
14. [GitHub - tozmoz/FMLibreEditor: Free, open-source live editor for Football Manager 27 on Windows (Game Pass, Steam) and macOS (Steam)](https://github.com/tozmoz/FMLibreEditor)
15. [FMLibreEditor](https://sortitoutsi.net/content/78126/fmlibreeditor-free-open-source-live-editor-for-fm27-windows-steam-game-pass-macos-steam)
16. [Export the club list (JSON/CSV), as players are exported · Issue #133 · tozmoz/FMLibreEditor · GitHub](https://github.com/tozmoz/FMLibreEditor/issues/133)
17. [Jadedness: read, edit and rest it by tozmoz · Pull Request #48 · tozmoz/FMLibreEditor · GitHub](https://github.com/tozmoz/FMLibreEditor/pull/48)
18. [Release FMLibreEditor v0.5.0 · tozmoz/FMLibreEditor · GitHub](https://github.com/tozmoz/FMLibreEditor/releases/latest)
19. [MacLibero RT — FM27 in-game editor and scout for Mac](https://maclibero.com/)
20. [Genie Scout 27g FAQ](https://www.fmscout.com/q-34928-Genie-Scout-27g-FAQ.html)
21. [Download Genie Scout 27 for Football Manager 27](https://geniescout.com/download/)
22. [Getting Genie Scout to work with Mac](https://www.fmscout.com/q-2550-Getting-Genie-Scout-to-work-with-Mac.html)
23. [FM27 In-Game Editor: how to get it and what you can edit - FMPortugal](https://fmportugal.net/en/in-game-editor-fm27/)
24. [FM27 is NOT going to have an export function? And you pretend you listen to your serious players? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/611958-fm27-is-not-going-to-have-an-export-function-and-you-pretend-you-listen-to-your-serious-players/)
25. [GitHub - ElectroHugin/FM-View-Exporter: Free, open-source BepInEx plugin for Football Manager 27+ that exports the player list on screen (squad, player search, scouting) to CSV and HTML. Restores the export SI removed in FM26. Offline, never touches your save. Not affiliated with Sports Interactive or SEGA.](https://github.com/ElectroHugin/FM-View-Exporter)
26. [FM27 Player Export for Mac (Apple Silicon) - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/78155/fm27-player-export-for-mac-apple-silicon)
27. [FM27 Exporter - C# and Unity Development - FM27 - Football Manager 27](https://sortitoutsi.net/content/78451/fm27-exporter)
28. [GitHub - alizadyx/pitchside: Pitchside: a free, open-source Genie Scout-style tool for FM27 on Apple Silicon Macs · GitHub](https://github.com/alizadyx/pitchside)
29. [Regenesis 27 - Live & Youth Academy Editor for FM27 (Windows & Mac) - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/78082/regenesis-27-live-youth-academy-editor-for-fm27-windows-mac)
30. [GitHub - IamDejman/fm-lens: Football Manager 27 companion for macOS: browse and edit your save while you play · GitHub](https://github.com/IamDejman/fm-lens)
31. [GitHub - WavyhairAlex/FMLibreEditor: Free, open-source live editor for Football Manager 27 on Windows (Game Pass, Steam) and macOS (Steam)](https://github.com/WavyhairAlex/FMLibreEditor)