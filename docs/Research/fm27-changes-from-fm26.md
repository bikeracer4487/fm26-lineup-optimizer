# FM26 → FM27 Breakage Checklist for a Data-Driven Lineup & Squad Tool

The change most likely to break your tool is the data pipeline, not the player model. Sports Interactive says FM27 does not support exporting player data, so any tool that reads exported squad views needs a community mod or a new input method.\[1\] The second is that Tactical Familiarity has been replaced by a four-part Tactical Effectiveness system, and training has been rebuilt around it.\[2\] Community-measured weights for that system, credited to lqf0624 and reposted on sortitoutsi, are Tactical Understanding 50%, Player Ability 10%, Player Buy-In 25% and Next Match Info 15%; these are unofficial (b). I found no FM27 evidence that player attributes, hidden attributes, CA/PA scaling or position codes were added, removed or rescaled. That part of the data model probably carries over, but nobody has confirmed it.

## TL;DR

- **Input breaks first.** SI confirmed in its 23 Sep 2026 AMA that player data export is "not set to be supported in FM27". Community mods (FM27 Exporter on F8, FM View Exporter on F9) bring back HTML/RTF/CSV output in the FM24 format, but they are unofficial BepInEx plugins and may break with each patch. The current build is 27.0.1, plus a small 12 Nov hotfix (27.0.1.2503222) with no published notes.
- **Rebuild the tactical and training logic.** Tactical Effectiveness (Tactical Understanding, Player Ability, Player Buy-In, Next Match Information; unofficial community weights 50/10/25/15%) replaces Familiarity. The training "Units" system is gone, and SI says Stamina matters more in the engine. Early FM-Arena engine tests by user caiograco (11 Nov 2026) found that condition, sharpness and positional fit outweigh any tactical setting: "Nothing I changed on the tactics screen came anywhere near those." That supports keeping fitness-first selection logic.
- **The player data model looks stable, but it is unproven.** I found no FM27 source documenting new, removed or rescaled attributes or CA/PA changes. Squad rules for the English National League also have no FM27-specific documentation. Treat both as FM26 knowledge assumed to carry over, and check them in your own save or the Pre-Game Editor.

## How to read this checklist

Evidence labels: **(a)** official SI material; **(b)** FM27 community testing or observation with data; **(c)** FM26 knowledge assumed to carry over; **(d)** speculation or anecdote, including press impressions. Items are ordered from most to least likely to break or invalidate a data-driven lineup tool. Dates are publication or "updated" dates as shown on the page. Where a page showed no date, I say so.

A warning on sources: a lot of "FM27" content online is FM26 material with a new title, or invented guide-site filler. Examples I found:
- Several fan wikis (footballmanagers27.wiki, fm27game.wiki, football-manager-27-mobile.wiki) give confident rules such as "don't start a player below 90% condition" with no testing behind them. I have not used them as evidence.
- A sortitoutsi "Training Bug" thread tagged FM27 (sortitoutsi.net/content/54184) says the poster "can't play this game since 2 months now".\[3\] That is impossible for a game released on 10 Nov, and the low content ID points to an older thread. I treat it as FM26 content.
- A wonderkidfinder roles guide says outright that its role names are FM26's.

---

## Checklist (most likely to break the tool first)

### 1. ☐ No native export / Print Screen of player data
- **Change:** SI confirmed that "the ability to export player data is not set to be supported in FM27". The end-of-season review is not returning either.\[1\]
- **What it breaks:** Any ingestion that depends on in-game "Print screen → text/web page" output, or on spreadsheet exports of squad views. If your FM26 pipeline used a mod or a workaround, you need to re-check it against FM27.
- **Evidence:** (a)
- **Sources:**
  - Official SI forum, "Summary of FM27 user interface and navigation AMA": https://community.sports-interactive.com/forums/topic/611916-summary-of-fm27-user-interface-and-navigation-ama/ (AMA held 23 Sep 2026)
  - Corroborated by SortItOutSI, https://sortitoutsi.net/content/77801/fm27-what-we-learned-from-chris-ama (Sep 2026)\[4\]
  - Corroborated by FM Scout, https://www.fmscout.com/a-football-manager-2027-new-features.html (updated 22 Oct 2026)\[5\]
- **Conflict to note:** SortItOutSI's summary says export "like in FM26" is not supported.\[4\] FM Scout's FM26-vs-FM27 tracker lists data export as "Missing" in FM26 (https://www.fmscout.com/a-fm27-vs-fm26.html), \[6\] and the FM27 Exporter mod says it restores *FM24's* export.\[7\] Whichever is right, FM27 has no official export.

### 2. ☐ The community export mods use FM24 output formats, so re-validate your parser
- **Change:** "FM27 Exporter" (by v1adicke) works as follows:
  - Press F8 on any list (squad, player search, shortlist) and the whole list is saved as HTML, RTF and CSV in `Documents/Sports Interactive/Football Manager 27/exports`.\[8\]
  - The HTML/RTF "use the same layout as FM24's Web Page and Text File exports, so spreadsheets and tools built for FM24 keep working".\[7\]
  - It exports every row, not just the visible ones.\[8\]
  - Ctrl+F8 adds "all 47 attribute columns" to the current view.\[8\]
  - Values are written "as shown in game: attribute ranges, star ratings, condition and morale levels, effectiveness".\[8\]
  - The author notes "FM27 player lists also have a unique id column".\[7\]
  
  A separate BepInEx mod, FM View Exporter (F9), writes CSV/Excel files to `Documents\Sports Interactive\FM View Exporter` with names like `squad_20261108_201500.csv`.\[9\]\[10\]
- **What it breaks:**
  - If your FM26 parser expected a different layout, the column order, headers and value encodings will differ.
  - Scouted attribute *ranges* (e.g. "12-15") and text-level condition or morale values need range-aware parsing.
  - The new "effectiveness" column has no FM26 equivalent.
  - Use the unique ID column as your stable player key instead of names.
  - Both mods depend on BepInEx, and authors already note breakage after patches.\[9\]
- **Evidence:** (b) community tools, unofficial
- **Sources:**
  - https://www.fmscout.com/a-fm27-exporter.html (published by v1adicke on 11 Nov 2026)
  - https://sortitoutsi.net/content/78451/fm27-exporter (v1.0.0, undated)
  - FMStag, https://fmstag.com/my-favourite-fm27-mods-and-downloads/ (undated, FM27-era)
  - Dixnnn tactic builder README describing the FM View Exporter path and filename format: https://github.com/Dixnnn/FM27-System-and-Tactic-Designer (undated, references Nov 2026 file names)

### 3. ☐ Tactical Familiarity replaced by Tactical Effectiveness (TE) and Tactical Complexity
- **Change:** TE "builds on the previous Tactical Familiarity system". It is made of four areas, each with a gauge: Tactical Understanding, Player Ability, Player Buy-In and Next Match Information.\[2\]\[11\]\[12\]
  - The gauges appear on the Tactics, Training and Recruitment screens, and in Scout Reports.\[11\]\[13\]
  - A new Tactical Complexity measure depends on the positions and the number of team, player and opposition instructions. Complex tactics take longer to learn, and lower-league squads may not cope with them.\[2\]
  - Tactics now show Intensity, Complexity and Effectiveness ratings.
  - AI managers also use TE.
- **What it breaks:** Any familiarity field or weighting, and any "tactic fit" score. A community screen-reader (FM27 Trainer) reads 4 components and 17 key factors. Users report it misreading values (some show 0 when they are actually 50–60%), so TE is not trivially machine-readable yet.\[14\]
- **Evidence:** (a) for the system. (b) for the measured effect and the reading problems.
- **Sources:**
  - Official feature: https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (deep dive 9 Oct 2026)
  - Official guide: https://www.footballmanager.com/the-dugout/tactical-effectiveness-understanding-fm27s-key-new-feature (undated)
  - FM Scout summary (updated 22 Oct 2026)
  - FM27 Trainer thread: https://sortitoutsi.net/content/78370/fm27-trainer-read-your-tactical-effectiveness-and-train-your-weakest-areas (undated, Nov 2026)
- **Measured data:** FM-Arena user caiograco ran about 190,000 engine simulations ("So far I've thrown about 190,000 matches at it") on 27.0.0 and 27.0.1. He used Fm-Match-Lab, a macOS port of lqf0624's Windows FM Tactics Lab that runs FM27's own match engine outside the game. Results:
  - Tactical Understanding is driven about twice as much by training as by match exposure.\[15\]
  - Untrained costs about −0.4 points per game. Well-trained (about 75 per area) gains about +0.2, and there is no further gain above that cap.\[15\]
  - Going from low to high in every area was worth about +0.5 ppg.\[15\] That is "about the same as +7 Pace for the whole squad", and attributes and familiarity "just add up".
  - Caveat: the study used "ten real matches of one club (a newly promoted PL side…)", and each test replayed all ten matches 200–300 times.
  - Source: https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/ (posted 11 Nov 2026), (b).

### 4. ☐ Training rebuilt: Units gone, match-prep focus, physical load shown
- **Change:**
  - Training is now a primary menu section.\[16\]
  - The "old Units system is gone". Team training now centres on the next match and opponent, with sessions for things like high pressing, low block and build-up.
  - The senior squad works on cohesion and tactical understanding.\[5\]\[12\]
  - You can see the physical load of the plan for this week and the weeks ahead.
  - Copy/paste of schedules is back,\[17\] and you can create, save and export weekly training schedules.
  - Individual training still covers attributes, traits and new positions.\[5\]\[12\]
  - National-team camp training is new.
- **What it breaks:** Training recommendations built on FM26 unit or session logic. Rest logic should now account for the shown physical-load figures.
- **Evidence:** (a)
- **Sources:** official TE/Training feature (9 Oct 2026); FM Scout new-features page (updated 22 Oct 2026, citing SI Reddit replies from 12 Oct 2026)
- **Related community findings (b):** In the FM-Arena thread (11 Nov 2026), a contributor (nyutso) found that Normal or Double training intensity lowered match-day condition with no clear gain compared with Half. Intensity also feeds injury risk.\[15\]

### 5. ☐ Fitness model weighting: Stamina matters more; condition and sharpness are the biggest measured levers
- **Change:**
  - SI: "Stamina now having a greater impact on your player's ability to both cover ground and make more repeated sprints with less recovery time."\[18\]
  - Speed and acceleration were rebuilt with Hawk-Eye data.
  - Marking and Anticipation carry more weight in defending.\[5\]\[18\]
  - Exhaustion is now visible in body language.\[19\]
- **What it breaks:** FM26-calibrated rotation and rest thresholds, and attribute weightings for pressing or high-tempo roles.
- **Evidence:** (a) for the design change. (b) for the measured effects.
- **Sources:**
  - https://www.footballmanager.com/fm27/features/fm27-tactical-tweaks-and-match-engine-upgrades (deep dive 5 Oct 2026)
  - FM-Arena Match Lab (11 Nov 2026). Its results:
    - Starting players at 50% sharpness cost about 1.0 ppg; at 75% sharpness, about 0.37 ppg.\[15\]
    - 80% condition cost about 0.8 ppg.\[15\]
    - Starters out of position (position rating capped at 10) cost about 0.85 ppg.\[15\]
    - Pace and Acceleration remain the top attributes (about +0.07 ppg per point squad-wide).\[15\]
    - The author's interpretation: the engine reads condition and sharpness at kick-off. Fatigue likely acts *between* matches, on recovery and injury risk, rather than as a separate in-match number.\[15\]
- **Interface note (b):** Users in SI's official feedback thread refer to squad-view columns named "Overall physical conditions", "Match sharpness" and "Fatigue", and say some columns are only available in certain base views.\[20\] Map your parser to those labels and check which view you export from. Source: https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/21/ (Nov 2026).

### 6. ☐ Status flags: up to three stack, four new types
- **Change:** Up to three status flags can stack again. Four new flags: language course, coaching badge, leadership training, and available for reserve/youth team.\[11\]
- **What it breaks:** Parsers that expect a single status value per player. Availability logic may also misread the new "available for reserve/youth" flag.
- **Evidence:** (a)
- **Sources:** https://www.footballmanager.com/fm27/features/fm27-2d-match-engine-game-editor-and-deeper-world-upgrades (deep dive 16 Oct 2026); FM Scout new-features page (updated 22 Oct 2026)

### 7. ☐ Out of Possession roles now in the Player Database key attributes; role list not officially published
- **Change:** SI: "Out of Possession player roles have been added to the key attributes section of the Player Database."\[21\]\[22\]
  - The IP/OOP role split and the removal of duties came in FM26.\[23\]
  - SI has not published an FM27 role list.\[21\]
  - One community site claims "all 79 role names" were verified in installed FM27 UI resources.\[24\] That is unconfirmed.
  - Patch 27.0.1 corrected the Stopping Centre-Back role description,\[25\] which confirms that FM26-era OOP role names are still present.\[25\]
- **What it breaks:** Role-suitability lookups, and any hard-coded role list.
- **Evidence:** (a) for the database change and the patch note. (c) for the FM26 role set carrying over. (b/d) for the 79-role claim.
- **Sources:**
  - Official 2D/IGE feature (16 Oct 2026)
  - FM26 roles: https://www.footballmanager.com/fm26/features/possession-out-possession-fm26s-new-tactical-evolution
  - https://touchlinefm.com/tactics (undated)
  - Patch 27.0.1 notes: https://www.fmscout.com/a-fm27-update-27.0.1.html (10 Nov 2026)

### 8. ☐ Player attributes, hidden attributes, CA/PA and positions: no documented change
- **Finding:** I found no FM27 source saying any player attribute was added, removed, renamed or rescaled, or that CA/PA scaling or position codes changed. Indirect evidence points to continuity:
  - The FM27 Exporter adds "all 47 attribute columns".\[8\] That matches the familiar outfield-plus-goalkeeper set (b).
  - Third-party FM27 live editors (FMLibreEditor, FM27€0, FM Studio 27, FMLE 27) all list the same structure: CA/PA, all attributes including hidden ones (consistency, important matches, injury proneness), personality, positions and position ratings (b).\[26\]\[27\]\[28\]\[29\]
  - SI's own IGE screenshot shows player tabs "Personal Details, Player Attributes, Contracts", with Hidden Attributes, Positions, Player Traits, Fitness and Bans inside (a, via FMPortugal).\[30\]
  - SI: staff attributes stay as text in FM27 (a), and there is "no major change to how newgen attributes are spread" (a).\[5\]
  - FM Scout's tracker says player weight remains hidden, not removed,\[6\] and FM-Arena found weight has zero engine effect (b).\[15\]
  - Coloured attribute boxes are off by default, with new background and border options.\[31\] This only matters if you scrape rendered screens (a).
- **What it could break:** Probably nothing, but nobody has confirmed the schema. One engine finding matters if your tool uses CA as a proxy for quality: "CA, reputation and height showed nothing… The engine plays on attributes, not on the CA number" (b, one study).\[15\] Rank by role-weighted attributes, not CA.
- **Evidence:** (a)/(b) as tagged above; otherwise (c)
- **Sources:**
  - https://sortitoutsi.net/content/78126/fmlibreeditor-free-open-source-live-editor-for-fm27-windows-steam-game-pass-macos-steam (undated)
  - https://sortitoutsi.net/content/78059/fm27eur0-v100-live-editor-for-fm27 (undated)
  - https://fmportugal.net/en/in-game-editor-fm27/ (undated)
  - https://www.fmscout.com/a-fm27-vs-fm26.html (undated, Sep–Oct 2026)
  - FM Scout new-features page (SI Reddit replies of 28 Sep and 12 Oct 2026)

### 9. ☐ Squad registration bug (UEFA) fixed; domestic/non-league rules undocumented
- **Change:** Patch 27.0.0.2493426 (2 Nov 2026) fixed "squad registration messages sometimes didn't appear for UEFA club competitions, which left senior players unregistered".\[32\]
- **What it breaks:** Saves started on the Launch Preview may contain unregistered players. Check registration status before trusting eligibility.\[33\]
- **Evidence:** (a)
- **Sources:** https://steamdb.info/patchnotes/26340721/ (SI Steam post, 2 Nov 2026); https://www.fmscout.com/a-fm27-update-27.0.0.2493426.html (2 Nov 2026)
- **English National League (Step 1) and North/South (Step 2):** I found no FM27 documentation of matchday squad size, named subs, substitutions or loan limits. Background only:
  - In FM23, an SI researcher confirmed the game used "3 subs from 5 named" in the National League and NL North/South (c, old).\[34\]
  - In real life, the National League (Step 1) moved to 7 named and 5 usable subs from 2024/25, after a motion passed 18–6 (Non-League Football Paper, 1 May 2024). At Step 2, the 2024/25 rules as quoted by Bulls News (9 Aug 2024) allow "a maximum of 5 (five) substitutes" to be named, all of them usable. On SI's forum, FM24 users reported the old 5/3 rule still applied and had to be edited.
  - Do not hard-code either value. Read the competition rules in your save.
  - An SI forum moderator in the FM27 feedback thread said the FM27 database only includes loans that run "window to window" (undated, about early Nov 2026).\[35\] This explains some missing real-world non-league loans.
  - A user reports Farnham Town (NL South) cannot offer part-time contracts, only non-contracts (b, undated).\[36\]
  - An FM27 England Non-League data-issues tracker exists, but I could not read it.
- **Sources:**
  - https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2023-bugs-tracker/database-and-research/england-non-league/substitutions-r11027/
  - https://www.thenonleaguefootballpaper.com/latest-news/step-1/487234/seven-substitutes-to-be-available-for-national-league-clubs/
  - https://community.sports-interactive.com/forums/topic/586759-change-vanarama-subs-rules/
  - https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/25/
- **Other registration-relevant changes (a):**
  - English ESC work permits are now only for under-23s.
  - AI managers are "a little more lenient" when deciding to recall a loanee.
  - New Squad Cost Ratio rules.\[5\]\[37\]
  - Sources: official 2D/IGE (16 Oct 2026) and Deeper World (25 Sep 2026) features.

### 10. ☐ Morale and selection psychology: Shouts, Buy-In, and young players' game-time demands
- **Change:**
  - Shouts were rebuilt to change players' "mental state and mood" rather than give attribute boosts, and players react by personality (a).\[19\]
  - Player Buy-In is now a measured part of TE (a).\[12\]\[24\]
  - "Young players care more about game time", and the "stepping stone" promise carries more weight in contract talks (a).\[5\]\[38\]
  - TheGamer's reviewer says it "now takes a much more reasonable amount of time for players to become unhappy, provided their temperament isn't poor", and that players more often accept a status change (d: single-reviewer impression, no data).
  - Third-party editors still list the FM26-style playing-time statuses, from Star Player down to Surplus to Requirements (c/b).\[39\]
- **What it breaks:** Rotation penalties for unhappiness calibrated on FM26 may be too harsh. Young players' playing-time expectations should weigh more in selection and loan decisions.
- **Evidence:** as tagged
- **Sources:**
  - Official ME feature (5 Oct 2026)
  - https://community.sports-interactive.com/forums/topic/611932-fm27-a-deeper-more-immersive-football-world/ (25 Sep 2026)
  - https://www.thegamer.com/football-manager-27-review/ (undated, about Nov 2026)
  - https://maclibero.com/blog/player-happiness-personality/ (undated)
- **No FM27 evidence found:** changes to the Dynamics hierarchy, social groups or promise deadlines.

### 11. ☐ Contracts, selling and releasing
- **Change (a):**
  - Sell-on fees now show in Scout Reports, and clubs with a sell-on clause ask for more.\[5\]\[37\]
  - AI managers and Directors of Football value experience and dressing-room leadership more, so veterans may be harder to sign cheaply and more saleable.\[37\]
  - Squad Cost Ratio rules and global spending were readjusted.\[37\]
  - The Director of Football advises on fees and payment structures.\[5\]
  - Transfer History shows add-ons.\[1\]
  - The first post-launch update will include "tweaks to how the AI handles transfers".\[40\]
- **What it breaks:** Sale-value and release heuristics tuned to FM26 AI demand, especially for experienced players. Wage-to-revenue logic may also need to account for Squad Cost Ratio.
- **Sources:** Deeper World feature (25 Sep 2026); 2D/IGE feature (16 Oct 2026); FM Scout 27.0.1 notes (10 Nov 2026)
- **No FM27 evidence found:** changes to mutual termination, release compensation or contract-clause mechanics.

### 12. ☐ Interface relocation: where squad, fitness and tactics now live
- **Change (a):**
  - Navigation has moved to top menus: Portal, Squad, Tactics, Recruitment, Training, Club.\[11\]\[41\]
  - The Squad dropdown holds Overview, First Team, Youth Team, Dynamics and Loans.
  - Tiles are now mostly informational, and many cards became full screens.\[11\]
  - Each main screen has a control panel. In Squad, it is where you hold team meetings and assign staff tasks.\[5\]
  - You can choose which page each menu opens on (e.g. First Team instead of Overview).
  - The Squad screen has swappable tiles.
  - The toggle button, editable shortcuts and named bookmarks are back.
  - Scaling modes are Small, Medium and Large, at 1440p and above.\[11\] 1080p support is planned for the first post-launch update.\[40\]
  - Tables grow to fill the screen.
  - Fitness test results appear in one table in the inbox.\[11\]\[42\]
  - Custom views are still `.fmf` files loaded via "Import View…" (b).\[43\]
  - Patch 27.0.1 fixed a bug where adding columns hid the default columns.\[25\]\[44\]
  - SI says skinning and modding have "no notable changes" versus FM26.
- **What it breaks:** Screen-scraping, OCR, or any automation that relies on FM26 tile navigation or layout. It also affects custom views you built in FM26.
- **Sources:**
  - https://www.footballmanager.com/fm27/features/fm27-clearer-interface-smoother-navigation (22 Sep 2026)
  - FM Scout new-features page (updated 22 Oct 2026)
  - 27.0.1 notes (10 Nov 2026)
  - https://sortitoutsi.net/content/78227/yoshialfies-squad-view (4 Nov 2026)

### 13. ☐ Save carry-over from FM26/FM24
- **Change:** The FM27 start screen can carry over FM26 and FM24 saves (a).\[5\]
- **What it breaks:** Data from converted saves may have different histories or derived values than fresh FM27 saves. Tag the save's origin in your tool.
- **Source:** FM Scout new-features page, citing SI on Reddit (21 Oct 2026)

---

## Current version and known bugs (as of 12 Nov 2026)

| Build | Date | Relevance to your tool | Label / Source |
|---|---|---|---|
| 27.0.0.2493426 (Launch Preview hotfix) | 2 Nov 2026 | UEFA registration message bug fixed\[32\] | (a) https://steamdb.info/patchnotes/26340721/ |
| 27.0.1 (release-day, Steam build 26385295) | 10 Nov 2026 | Column-hiding bug fixed. Forced injury substitutions can no longer be cancelled (previously could leave you with 10). Push fouls/cards adjusted. Stopping CB description fixed.\[40\] | (a) https://www.fmscout.com/a-fm27-update-27.0.1.html |
| 27.0.1.2503222 (small hotfix) | 12 Nov 2026 | No official notes found. Steam depots updated 12 Nov at 10:01 UTC. Community tool authors (FMLE, FMRTE) report updating for it.\[45\]\[46\]\[47\] | (b) https://steamdb.info/sub/1579953/; https://www.fmscout.com/a-fm-live-editor-27.html |
| First post-launch update | "Later this month" (planned) | 3D match engine (defending, attacking patterns), 1080p scaling, UI, AI transfer tweaks. Not yet released.\[40\]\[48\] | (a) planned, via FM Scout 27.0.1 notes (10 Nov 2026) |

**Known issues relevant to fitness, training and tactics. All are user reports from SI's official feedback thread (Nov 2026), not SI-confirmed bugs:**
- The individual-training link from a player profile opens the whole-squad individual training list.\[49\]
- The weekly Training Review's improvements/regressions box links to a page that shows "no data available".\[50\]
- Condition is hard to see during matches.\[51\]
- Minor injuries are shown in alarming red on the tactics screen even when the player can play.\[20\]
- Lower-league users say TE forces near-total training focus on the weakest area (opinion).\[51\]

Sources: https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/16/, /page/15/, /page/21/, /page/39/ (b/d)

**Recommendation:** Pin your tool to the game build. Record the build string with every import. Re-validate parsing after each patch, because the community exporters you will probably depend on hook into game internals.

---

## Areas where NO FM27-specific evidence was found

- Any added, removed, renamed or rescaled **player attribute** or **hidden attribute** (beyond the "47 columns" continuity signal).
- Any change to **CA/PA scale or calculation**, or to **position codes or grouping**.
- **Matchday squad size and substitute counts** in any English league, including the National League, NL North and NL South. The same goes for **squad registration limits** and **loan limits** (long-term, short-term, youth, work-experience) at Steps 1–2.
- Changes to **Dynamics** (hierarchy, social groups), **happiness calculation**, or **promise deadlines and penalties**.
- Changes to **contract termination or release costs**, or new contract clause types.
- Any official **file-format specification** for views, filters or exports. Also any official word on whether the **Pre-Game Editor** exposes new player fields. SI's own PGE notes only mention a Daylight Offside rule setting.\[22\]\[42\]
- Patch notes for the **12 Nov 2026 hotfix**.
- An **official FM27 role list**.

## Caveats

- The strongest quantitative evidence (FM-Arena Match Lab) comes from one user's study of ten matches for one promoted Premier League club, partly AI-summarised.\[15\] Treat the effect sizes as directional.
- Several confirmations come from SI Reddit replies relayed by FM Scout, rather than pages I could read directly. SI's forums blocked automated fetching, so some official forum content is quoted from search snippets.
- Community mods and editors are unofficial and may break with patches.

## Sources

1. [Summary of FM27 user interface and navigation AMA - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/611916-summary-of-fm27-user-interface-and-navigation-ama/)
2. [FM27: Training and Tactical Effectiveness](https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness)
3. [Training Bug - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/54184/training-bug)
4. [FM27: What We Learned From Chris’ AMA - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/77801/fm27-what-we-learned-from-chris-ama)
5. [FM27 New Features Guide: Everything New in Football Manager 2027](https://www.fmscout.com/a-football-manager-2027-new-features.html)
6. [FM27 vs FM26: Is SI Fixing What Went Wrong?](https://www.fmscout.com/a-fm27-vs-fm26.html)
7. [FM27 Print Screen Export](https://www.fmscout.com/a-fm27-exporter.html)
8. [FM27 Exporter - C# and Unity Development - FM27 - Football Manager 27](https://sortitoutsi.net/content/78451/fm27-exporter)
9. [GitHub - Dixnnn/FM27-System-and-Tactic-Designer · GitHub](https://github.com/Dixnnn/FM27-System-and-Tactic-Designer)
10. [My Favourite FM27 Mods and Downloads - FMStag.com](https://fmstag.com/my-favourite-fm27-mods-and-downloads/)
11. [FM 27 New Features: Every Change From FM26](https://fm-27.wiki/new-features/)
12. [FM27: Everything You Need to Know Before You Play](https://www.footballmanagerblog.org/2026/10/fm27-everything-you-need-to-know.html)
13. [FM27: Advanced tactics, training, and recruitment](https://en.univers-simu.com/guides/fm27-tactiques-entrainement-recrutement-232760/)
14. [FM27 Trainer: read your Tactical Effectiveness and train your weakest areas - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/78370/fm27-trainer-read-your-tactical-effectiveness-and-train-your-weakest-areas)
15. [FM27 Match Lab (macOS): Tool to simulate matches outside the game](https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/)
16. [FM27 training guide](https://footballmanagers27.wiki/guides/fm27-training)
17. [Football Manager 27 Out Now! - Sakura Index](https://www.sakuraindex.jp/press-releases/football-manager-27-out-now/)
18. [FM27: Tactical Tweaks and Match Engine Upgrades](https://www.footballmanager.com/fm27/features/fm27-tactical-tweaks-and-match-engine-upgrades)
19. [FM27: Tactical Tweaks and Match Engine Upgrades|Football Manager 27](https://footballmanager.sega.com/asia-en/info/details/000191.html)
20. [The Official FM27 Feedback Thread - Page 21 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/21/)
21. [FM27 Tactics: Tactical Tweaks, Shouts and Player Instructions](https://footballgpt.co/fm/fm27/tactics)
22. [FM27: 2D Match, In-Game Editor and more](https://www.footballmanager.com/fm27/features/fm27-2d-match-engine-game-editor-and-deeper-world-upgrades)
23. [FM27 Tactics: Formations, Roles & Tactic Calculator](https://wonderkidfinder.com/fm27/tactics/)
24. [FM27 Tactics: Diagnosis & Player Roles](https://touchlinefm.com/tactics)
25. [Football Manager 2027 Patch 27.0.1 - Update Beta to Final](https://www.fmscout.com/a-fm27-update-27.0.1.html)
26. [FM Live Editor 27 for Windows](https://www.fmscout.com/a-fm-live-editor-27-license.html)
27. [FM27€0 v1.1.0 - Live Editor for FM27 - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/78059/fm27eur0-v100-live-editor-for-fm27)
28. [FMLibreEditor](https://sortitoutsi.net/content/78126/fmlibreeditor-free-open-source-live-editor-for-fm27-windows-steam-game-pass-macos-steam)
29. [FM Studio 27](https://fmportugal.net/en/fm-studio-27/)
30. [FM27 In-Game Editor: how to get it and what you can edit - FMPortugal](https://fmportugal.net/en/in-game-editor-fm27/)
31. [What we know about Football Manager 2027](https://www.fmscout.com/a-what-we-know-about-football-manager-2027.html)
32. [Football Manager 2027 Patch 27.0.0.2493426 - First Hotfix for Beta](https://www.fmscout.com/a-fm27-update-27.0.0.2493426.html)
33. [Heads up: UCL/UECL registration bug fixed in next FM27 update - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612561-heads-up-ucluecl-registration-bug-fixed-in-next-fm27-update/)
34. [Substitutions - \[England\] Non-League - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2023-bugs-tracker/database-and-research/england-non-league/substitutions-r11027/)
35. [The Official FM27 Feedback Thread - Page 25 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/25/)
36. [The Official FM27 Feedback Thread - Page 56 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/56/)
37. [FM27: A Deeper, More Immersive Football World - News - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/611932-fm27-a-deeper-more-immersive-football-world/)
38. [Out of Context Football Manager on X: "This went a bit under the radar yesterday, but transfers are getting a BIG overhaul in FM27: - Squad Cost Ratio rules and overall spending have been reworked - Agent Offers will appear throughout the transfer window and increase closer to Deadline Day - Young… / X](https://x.com/nocontextfm1/status/2103809307913421069)
39. [FM27 unhappy player fix: happiness, status, personality — MacLibero RT](https://maclibero.com/blog/player-happiness-personality/)
40. [FM27 Update Tracker: Patch Notes, Builds & Known Issues](https://footballmanager27.wiki/fm27/updates/)
41. [Fully Overhauled 'FM27': It's Time to Make the Switch ⭐8.5 - Inven Global](https://www.invenglobal.com/articles/28406/fully-overhauled-fm27-its-time-to-make-the-switch-85)
42. [FM27 New Features: 2D Match, Editor and Messages](https://fmslovakia.com/fm27s-small-changes-add-up-to-a-lot/)
43. [YoshiAlfie's Squad View - Other Football Manager Graphics - FM27 - Football Manager 27](https://sortitoutsi.net/content/78227/yoshialfies-squad-view)
44. [Passion4FM on X: "#FM27 Launch will features these improvements: Patch Notes for 27.0 includes but are not limited to: 🇯🇵 Japanese (Men) national team is now playable ✅ fixed a bug where adding columns to a table would hide the default columns Other fixes are: Technical - Various crash and… / X](https://x.com/Passion4FM/status/2119839806171537466)
45. [Football Manager 27 (SubID 1579953) · SteamDB](https://steamdb.info/sub/1579953/)
46. [FM Live Editor 27 - Real Time Editor for Football Manager 2027](https://www.fmscout.com/a-fm-live-editor-27.html)
47. [FMRTE 27 for Windows - Discussion and feedback - FMRTE](https://www.fmrte.com/forums/topic/13368-fmrte-27-for-windows/)
48. [FM27 launch patch notes and the first post-launch update - FMPortugal](https://fmportugal.net/en/fm27-patch-lancamento-primeira-atualizacao/)
49. [The Official FM27 Feedback Thread - Page 16 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/16/)
50. [The Official FM27 Feedback Thread - Page 15 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/15/)
51. [The Official FM27 Feedback Thread - Page 39 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/39/)
