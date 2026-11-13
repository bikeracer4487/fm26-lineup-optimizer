# FM27 Lineup Optimizer: native Mac app design

Date: 12 November 2026
Status: draft for approval

## 1. Intent

The lineup optimizer was built on Windows for Football Manager 26 and a Brixham save. Its owner now plays Football Manager 27 on an Apple Silicon Mac, managing Oxford City, and wants the tool working there: a native Mac app, updated for FM27, with a newly designed interface.

The tool exists to answer one question well: who should start each of the next few matches, given how fit and sharp everyone is, what the tactic asks of each slot, and which matches matter most. Everything else (rest, training and squad-trimming advice) supports that.

The owner's favourite way to play is to build a team over time from young players. Youth-squad players are therefore full candidates for selection, and development through match time is a legitimate reason for a pick in lesser fixtures.

Investigation during this design found that the most recent version of the app (branch `origin/customizable-tactics`) has the right tactics model and a sound rating core, but its match planner was designed and never connected: match importance barely changes a pick, the five-match plan uses one fitness snapshot for every match, and "saving players for big games" is calculated but never used. This design therefore covers building the planner as it was intended, not only porting what runs.

## 2. Goals

1. A native macOS app (SwiftUI) with the selection engine written in Swift. No Python, Electron, Excel or Windows tooling at run time.
2. Squad data comes in by copying rows from FMRTE 27 and pressing Import in the app.
3. Tactics are configurable: several saved tactics, each with an in-possession shape, an out-of-possession shape, a role per slot per phase, and a mapping between the two shapes. Roles come from the FM27 role list.
4. A match planner in which importance, look-ahead and saving players for big games all change the picks, and every pick can explain itself.
5. All eight existing screens are kept: Fixtures, Tactics, Match Selection, First XI, Second XI, Training, Rest, Player Removal. Two are added: Squad, for importing, and Depth, for cover and recruitment.
6. Numbers follow FM27 evidence where it exists. Every tunable constant records where it came from.
7. A new, properly themed interface, designed in its own pass (section 12).

## 3. Non-goals

- Windows or Linux support, FM26 support, or migrating the Brixham fixtures and lineup history.
- App signing, notarization or distribution. It runs on the owner's Mac, built from Xcode.
- Reading FM27 save files directly (the branch's `fm26_parser/` experiment is dropped).
- FMLibreEditor or any second data source. The import sits behind a small boundary so one could be added later.
- Modelling Tactical Understanding, team cohesion, Player Buy-In or opposition scouting. The research shows Tactical Understanding matters, but the app has no way to read it yet. The lineup-stability setting is the only nod to cohesion.
- Picking the bench, or modelling substitution and registration rules. FM27 non-league squad rules are undocumented.
- Keeping the Python command-line scripts.

## 4. Anti-goals

These would make the result a failure even if it runs:

- **Silent wrong data.** A paste with missing columns, a shifted column order or an unexpected scale must stop with a clear message, never produce a plausible-looking lineup.
- **Rules that exist but do nothing.** Any rule described in this document must be shown by a test to change an outcome. The branch's main fault was code that looked finished and was never called.
- **Unexplained picks.** If the planner rests a first-choice player, the screen must say why.
- **FM26 numbers presented as FM27 fact.** Carried-over constants are labelled as such in the code, and the interface marks advice that rests on unverified numbers.
- **Reproducing known bugs** for the sake of matching the Python (section 11 lists them).

## 5. Constraints

- macOS 26 on Apple Silicon, Xcode 27, Swift 6. No third-party run-time dependencies are expected; adding one is the builder's call if it clearly earns its place.
- The app must not be sandboxed, because it reads FMRTE's configuration file from another app's Application Support folder.
- FMRTE 27 must be running with the save loaded for the user to copy rows; the app itself never talks to FMRTE or the game.
- FMRTE's clipboard text has no header row. Column meaning comes only from FMRTE's saved grid configuration.
- The repository is public. Player data and app state live outside it from now on (section 9). Captured clipboard samples used as test fixtures are the exception, in line with the player data already tracked there.
- FM27 was three days old when the research was done. Most FM27 numbers come from a few community testers working from one club's matches. The design must make these numbers easy to change.

## 6. Approaches considered

### Getting squad data in

| Option | Trade-off | Outcome |
|---|---|---|
| Copy rows in FMRTE 27, import from the clipboard | A few keystrokes per refresh. Carries every field including condition, sharpness, jadedness, injured and banned. | **Chosen.** Tested on real pastes of 18 first-team and 6 U21 players. |
| FMLibreEditor export | Could be fully hands-off. A second beta memory-reading tool; its export lacks the fitness and availability fields. | Rejected by the owner. |
| Port the Windows click automation | Same fragile approach on a new platform. | Rejected. |

### Application shape

| Option | Trade-off | Outcome |
|---|---|---|
| SwiftUI app, engine rewritten in Swift | One app, one language, no Python environment. Largest first step. | **Chosen.** |
| SwiftUI app calling the Python scripts | Faster to a working window. Depends on a Python install; the FM27 rework would happen in Python and be ported later or never. | Rejected. |
| Tauri with a web UI | Lighter than Electron, closest fit to web design tooling. Not native; needs Rust. | Rejected. |

### How much engine

| Option | Trade-off | Outcome |
|---|---|---|
| Port what runs on the branch, bugs fixed | Smallest. Importance stays nearly meaningless; no look-ahead. | Rejected. |
| Also restore importance rules and project fitness forward | Makes rotation planning real. | Included. |
| Also let "saving players for big games" change picks | Never exercised in practice, so it needs its own tests and a way to see its effect. | **Chosen** (this includes the row above). |

## 7. What exists today

Two versions of the Python app exist. `main` is the older one, hard-coded to a single 4-2-3-1. Branch `origin/customizable-tactics` contains everything on `main` plus about 25 commits and is the reference for this work. `main` has no commits the branch lacks.

What the branch runs, per a traced reading of the code:

- **Rating core** (`rating_calculator.py`): a per-player, per-slot rating built from position attribute weights, the role's key and secondary attributes, a familiarity factor per phase, and an in-possession/out-of-possession blend.
- **Match selection** (`ui/api/api_match_selector.py` over `fm_match_ready_selector.py`): that rating multiplied by condition, sharpness and jadedness factors, solved as an assignment problem, with manual overrides, per-match rejections, a lineup-stability term, consecutive-start counts from confirmed lineups, and auto-rest rules.
- **Advisors**: First and Second XI (`api_rotation_selector.py`), Rest (`api_rest_advisor.py`), Training (`api_training_advisor.py` over `fm_training_advisor.py`), Player Removal (`api_player_removal.py`).
- **Written but not connected**: forward simulation of fitness (`state_simulation.py`), shadow pricing beyond a display value (`shadow_pricing.py`), pick explanations (`explainability.py`), automatic match importance (`match_importance.py`). These are design references, not behaviour to match.
- **Research and specifications**: `docs/new-research/` (FM26) and `docs/Research/fm27-*.md` plus `docs/Research/fm27_roles.json` (FM27).

The branch's 155 tests exercise the unconnected modules and parameter helpers. Nothing tests the path that produces lineups.

## 8. The design

### 8.1 Structure

Two parts in this repository:

- **Engine**: a Swift package with no UI or file-system dependencies beyond what it is handed. It holds the domain model, importer, rating core, planner and advisors, and is where almost all tests live.
- **App**: a SwiftUI macOS app that owns persistence, the clipboard, FMRTE's configuration file and the screens, and calls the engine.

The engine takes plain values in and returns plain values out. That replaces the old arrangement of JSON over standard input and output, and keeps the engine testable without the app.

### 8.2 Import

1. The user copies rows from an FMRTE 27 player grid, presses Import, and says which squad the rows are: First team, U21 or U18.
2. The app reads the clipboard text: one player per line, tab-separated, every field in double quotes, UTF-8, CRLF line endings.
3. The app reads FMRTE's configuration at `~/Library/Application Support/FMRTE27/config.json`. Under `ColumnsSettings.Items`, each grid has a `SettingsKey` and an ordered `Columns` list whose `Path` values name each column (for example `MentalAttributes.Anticipation`, `Positions.DefenderCentral`, `Contract.MonthsLeft`).
4. The importer works out which grid the rows came from. Candidates are the player grids whose column count equals the pasted field count. Among those it keeps the ones whose column types fit every row: attributes and position ratings are whole numbers from 1 to 20, the injured and banned flags are `True` or `False`, condition and sharpness are 0 to 10,000, and age, CA and PA are numeric. Columns that FMRTE formats as currency must carry a pound sign: wages, asking price and, through an FMRTE quirk, the Balance attribute. Balance is a strong signal because it is the only attribute formatted that way, but it must not be the only test, since FMRTE may fix the quirk. Exactly one grid must fit. If none or several fit, or a required column is missing, it stops and names the problem and the missing columns.
5. Values are parsed by column path, not by position, so reordering columns in FMRTE keeps working.

The owner's configuration currently holds two 98-column grids with different orders, `SearchPlayersColumns` and `TeamPlayersColumns`, so column count alone cannot choose. The type check does: against a saved real paste, the search grid's layout fits with no violations and the team grid's layout has 41.

Both grids are supported. The first test pastes came from the search grid; the owner's working pastes come from the team grid, one squad at a time. The team grid has no `Contract.Club` or `AskingPrice` column and adds the squad number and agreed playing time. So those two columns are optional:

- Without `Contract.Club`, the owner's club comes from the club-name setting.
- Without `AskingPrice`, Player Removal shows the transfer value as unavailable.
- Squad number and agreed playing time are kept when present.

Squads:

- Importing a squad replaces that squad's players and leaves the other squads alone. The previous snapshot and the "what changed" view are kept per squad.
- A player who appears in a later import of a different squad moves to that squad.
- Players from every squad are candidates for selection and count in squad comparisons, with their squad shown beside them. The owner confirmed this.
- FMRTE offers no way the owner has found to copy every squad at once, so one paste per squad is the normal case.

Observed value formats the parser must handle: currency with a pound sign and thousands separators; `True`/`False`; trailing spaces in position text; multiple nationalities separated by commas; the Balance attribute formatted as currency by an FMRTE quirk; `-1518` months and zero wages for players with no contract.

Field meanings established from the test pastes:

- Condition and match sharpness are 0 to 10,000. Jadedness is roughly -500 to 1,000.
- Fourteen position ratings, each 1 to 20: GK, D (L/C/R), WB (L/R), DM, M (L/C/R), AM (L/C/R), ST.
- `Contract.ContractType` is `FullTime` or a bare number. `4` corresponds to "Out of Contract" in the game. Such players stay selectable and are flagged.
- `LoanContract.LoanedToTeam` is blank for players at the club. A club name there other than the owner's means the player is out on loan: he is excluded from selection and listed separately. The owner's own club name there is taken to mean a player loaned in.
- `IsInjured` is authoritative for injury. Injured players can still show about 95% condition.
- `IsBanned` players are excluded from the next fixture only and flagged; a manual override can still place them, since the ban's competition is unknown.

Calls made here:

- The owner's club is the most common value of `Contract.Club` when that column is present, with a setting to override. When the column is absent and the setting is empty, the club is unknown: any player with a "loaned to" club is treated as out on loan, and the app warns that the club name is not set.
- Loaned-in players are expected to show the owner's club in "loaned to", and their parent club in `Contract.Club` where that column exists. This is unconfirmed until one exists to copy; the importer must not drop such players, and a test case is added when a real example is available.
- Players are identified by normalised name (case and accents folded). If FMRTE offers a unique ID column and it is present in the grid, it is used instead. The owner will check whether one exists.
- The app shows a confirmation after import: which grid it recognised, player count, players out on loan, and any warnings.

### 8.3 Domain model

- **Player**: identity, squad (First team, U21 or U18), age, positions text, fourteen position ratings, all attributes including hidden ones, current fitness (condition, sharpness, jadedness), availability flags, contract and loan facts, CA and PA for display.
- **Tactic**: a name; in-possession slots and out-of-possession slots, each with a position and a role; a mapping from each in-possession slot to an out-of-possession slot. Validity rules carry over: eleven slots per phase, a goalkeeper in both, every in-possession slot mapped to an active out-of-possession slot.
- **Fixture**: date, opponent, importance (High, Medium, Low, Sharpness), which tactic to use (defaulting to the primary), manual overrides by slot, rejected players, and whether its lineup is confirmed.
- **Confirmed lineup**: the fixture, the tactic's slot identifiers and the players who actually started, including overrides.
- **Retraining**: a player, the position he is being retrained in, the date the owner accepted it, and his familiarity in that position at each import since.
- **Plan**: for each upcoming fixture in the horizon, a lineup with, per pick, the rating, the factors that produced it, the fitness the planner projected for that day, and its reasons.

Several tactics can be saved and one is marked primary. This goes beyond the branch, which had one tactic; FM27 lets a manager prepare three.

The branch stored training intensity and lineup stability inside its single tactic. With several tactics, both become app-wide settings: neither describes a tactic, and a per-tactic training intensity would be ambiguous between fixtures that use different tactics.

### 8.4 Rating core

The structure follows `rating_calculator.py` on the branch: a position score from attribute weights, a role score from the role's attribute tiers, a blend of the two, a familiarity factor per phase, then a weighted mix of the in-possession and out-of-possession results (even for defensive out-of-possession positions, weighted toward in-possession otherwise).

Changes for FM27:

- Roles come from `docs/Research/fm27_roles.json` (79 roles, tiers named `key` and `preferable`, fourteen position codes). A role missing from the file is an error, not a silent default.
- The current-ability factor is removed. FM27 engine tests found CA has no effect on matches.
- Familiarity is applied per phase using the position rating for that phase's position, as the branch does. The step shape is kept: none at 18 and above, small at 15 to 17, growing below.
- The position attribute weights are carried over from the branch (they came from FM26 engine testing) and labelled as carried over.

**Decisions of 13 November 2026**, after the research in `docs/Research/fm27-attribute-weights-and-role-thresholds.md`:

- **Role thresholds are dropped for FM27.** The Python penalised a player whose attributes fell below fixed minimums for seven roles. No engine test in any version supports those minimums, about half the attributes they gate show little or no measurable effect in FM27 tests, and on a lower-league squad nearly everyone hit the penalty's floor, so it changed picks arbitrarily. They remain only in the FM26 configuration used for the port check. Thresholds set relative to the squad's own average or median were considered and rejected: half the squad fails each by construction, a squad weak at something lowers its own bar for it, and they add nothing to ranking players within the squad.
- **Two rating profiles.** The carried-over profile is the formula above with the FM26 weight tables. The FM27 engine-tests profile uses one outfield weight table from FM27 match-engine testing (Pace, Acceleration, Stamina and Jumping Reach at the top; no weight for attributes that showed no measurable effect), a curve per attribute in place of the straight line, a 70/30 split between the engine weights and the role's key attributes, and no consensus bonus. Goalkeepers are rated without the curves, which were measured on outfield players only, and keep the carried-over goalkeeper weights apart from Kicking. The FM27 evidence is thin: one tester on the preview build, tabulated by a third party.
- **FM26 research fills what FM27 testing does not cover** (owner's decision, 13 November 2026: a lot carries over between game years). In the FM27 profile that means two things. Goalkeeper weights are the FM26 table. How an attribute's weight differs between outfield positions comes from the FM26 position tables, because no FM27 test splits attribute value by position: each FM27 base weight is multiplied by `0.5 + 0.5 × min(r, 2)`, where `r` is the attribute's FM26 weight at that position divided by its average FM26 weight across the thirteen outfield positions (1 when FM26 gives the attribute no weight anywhere), and each position is then rescaled to sum to 1. The halving and the cap of 2 are this design's derivation: they keep every multiplier between 0.5 and 1.5, so the FM26 pattern steers the FM27 weights without overriding them, and attributes FM26 weighted at only one or two positions cannot dominate. This replaces the position multipliers the research labelled speculative. An attribute FM27 tested and found to have no measurable effect stays at zero; that is a finding, not a gap. The same rule applies to the planner and advisors: where FM27 research is silent, use the FM26 research in `docs/Research/`, labelled as carried over.
- **The default profile is FM27 engine tests** (owner's decision, 13 November 2026, after comparing both lineups for the real squad). The carried-over profile stays available for comparison; the command-line tool prints either or both.

The rating core takes its role data, weights and switches as inputs. That allows one check against the Python: run in an "FM26 configuration" against outputs generated once from the branch on the committed FM26 data, to prove the formula was ported correctly. The app itself uses the FM27 configuration.

### 8.5 Fitness and availability

A pick's match-day value is its slot rating multiplied by factors for condition, sharpness and jadedness on the day of the match.

All penalties share one yardstick: FM27 engine tests report costs in points per game for a whole starting eleven, and the same tests say such costs add up. Familiarity gives the exchange rate (all starters capped at 15 cost about 0.26 points per game against a factor of about 0.95; capped at 10 cost about 0.85 against about 0.80). The other curves must pass close to these anchors:

| Input | FM27 measured cost | Approximate factor |
|---|---|---|
| Condition 90% | 0.28 points per game | 0.94 |
| Condition 80% | 0.80 | 0.82 |
| Sharpness 75% | 0.37 | 0.92 |
| Sharpness 50% | 1.00 | 0.78 |

The factor column is this design's derivation and is provisional. The branch's curves (a cliff near 88% condition, an 0.15 multiplier below 91%) are far harsher than these measurements and are not carried over.

Separate from performance, risk rules keep players out regardless of rating. These are the only hard exclusions in the planner; there is no separate stage that schedules rests.

- **Condition floor.** A player whose condition on the day is below the floor does not start, at any importance. The default is 85% and it is adjustable. The FM27 injury threshold is unverified.
- **Jaded.** Jadedness above 400 is "jaded" (confirmed for FM27). A jaded player does not start Medium, Low or Sharpness fixtures. For a High fixture he is available with his jadedness penalty. The branch's stepped penalties for lower levels are kept as provisional.
- **Unavailable.** Injured players and players out on loan never start. A banned player misses the next fixture only.

A manual override beats every rule except injury and being out on loan, and the pick is marked as overridden against the rule it broke.

### 8.6 Planner

The planner produces lineups for the next several fixtures (default five) in date order.

**Projection.** After choosing a lineup for one fixture, the planner projects every player's condition, sharpness and jadedness to the next fixture's date: starters lose condition and gain sharpness and jadedness; everyone recovers condition and loses sharpness with the days in between. Rates come from the FM27 research where measured (sharpness gain of about 0.1% per minute played, sharpness loss of about 0.5% per day) and from FM26 testing otherwise (condition recovery per rest day, jadedness gain per match and loss per rest day), labelled accordingly. Stamina affects in-match condition loss more in FM27, so projected post-match condition depends on it. `state_simulation.py` on the branch is the reference for structure, not for constants.

The app-wide training-intensity setting (Low, Medium, High) feeds the projection: it scales condition recovery between fixtures. The branch's figures are the starting point (Low 20% faster, High 20% slower), labelled as carried over; FM27 testers report the same direction without numbers.

**Importance.** Each level changes what the planner optimises for that fixture. The complete list of adjustments is:

| Adjustment | High | Medium | Low | Sharpness |
|---|---|---|---|---|
| Fitness factors and risk rules (8.5) | yes | yes | yes | yes |
| Cost of using a player needed for a bigger fixture soon | no | yes | yes, weighted more | yes |
| Penalty for a long run of consecutive starts | no | yes | yes | yes |
| Preference for players who need minutes to build sharpness | no | no | yes | this is the objective |
| Loaned-in players marked down in favour of the club's own | no | by 5% | by 15% | by 15% |
| Preference for young players with room to grow | no | no | yes | yes |
| Preference for playing a player in the position he is retraining | no | familiarity 15 and above | familiarity 10 and above | familiarity 10 and above |

- **High** is the strongest available eleven on the day.
- **Sharpness** is built to raise match sharpness among the first eleven and their main backups. Players already fully sharp are avoided unless needed.

The loaned-in factors are the ones the branch runs today. The consecutive-start limits by position are carried over from FM26 and marked.

**Development preference.** In Low and Sharpness fixtures, young players with room to grow are favoured for minutes, alongside players who need sharpness. This serves the owner's aim of building a team from youth. The starting definition is the one Player Removal already uses for a prospect: aged 21 or under with potential ability at least 15% above current ability. Both figures and the size of the preference are parameters. The evidence is one FM27 tester's report that player growth still comes mainly from match time, as in earlier versions, so it is labelled as FM27 community observation. Risk rules still apply, and the preference never outweighs them.

**Retraining preference.** A player the owner has accepted for retraining (8.7) is favoured for a slot in his new position, so that he gains match experience there. The research in this repository says match time in the new position is essential and should be introduced gradually: friendlies first, then lesser fixtures, then competitive ones. It is FM26-era and has no FM27 confirmation, so it is labelled carried over. The staging above implements that:

- Below familiarity 10 there is no preference. He trains but does not start there.
- From 10 he is favoured in Sharpness and Low fixtures.
- From 15 he is also favoured in Medium fixtures.
- Never in High fixtures. The preference ends when he reaches 18.

The size of the preference starts from the old app's values (up to 15% in Low fixtures and 8% in Medium) and is a parameter. The two thresholds are parameters too. The FM27 cost of fielding one player at these levels is small by the measurements in 8.5: a whole eleven capped at 10 costs about 0.85 points per game, so one such player costs under a tenth of a point, and at 15 about a quarter of that. That is this design's rough derivation.

Two bonuses documented for `main` stay dropped, with the owner's agreement. The versatility bonus raised the rating of individual players who cover several positions; it never looked at whether a position was short of cover. FM27 tests found being natural in more positions has no effect on a match. What the owner wants from versatility is cover for the team, which the Depth view and the Training advisor provide (8.7). The position-pathway bonus favoured players who merely fitted a retraining pattern; the explicit retraining list replaces it. The branch's proactive rest before a High fixture is also dropped as a separate rule, because the cost of using a player before a bigger fixture now does that job.

These restore the intent documented for `main` and expressed in the branch's importance weights (High 3.0, Medium 1.5, Low 0.8, Sharpness 0.1).

**Saving players for big games.** Using a player today has a cost if it leaves him less fit for a more important fixture soon after. The planner estimates that cost from how much better he is than his replacement in the later fixture, how important and how close that fixture is, and what today's start does to his projected fitness. The cost is subtracted when choosing today's lineup, except for High fixtures. The branch computed a similar figure from raw current ability and only displayed it; here it uses slot ratings and changes picks. A setting scales its influence, and zero turns it off, so its effect can be seen by comparing plans.

**Carried between fixtures.** Projected fitness, consecutive-start counts (seeded from confirmed lineups), and each player's recent slots for the stability term.

**Stability.** The existing setting from "pure optimisation" to "maximum stability" biases picks toward the slot a player held most recently. History uses tactic slot identifiers throughout and is ordered newest first.

**User control.** Manual overrides fix a player in a slot. Rejections exclude a player from one fixture. Confirming a fixture locks its lineup, records who actually started including overrides, and removes it from replanning. Unlocking reverses that. Deleting a fixture removes its history entry.

**Explanations.** Every pick carries its factors and plain-language reasons. Every notable omission (a first-choice player left out) carries the reason he was left out. A first-choice player is one in the ideal eleven or in the best eleven of the players available for the fixture.

**Assignment.** Lineups are found by solving a players-to-slots assignment exactly. Ties are broken deterministically so the same inputs always give the same lineup.

### 8.7 Advisors

Each is ported from the branch with the tactic taken into account and the listed faults fixed:

- **First XI and Second XI**: the best eleven for the primary tactic at full fitness, then the best eleven from the rest. One calculation serves both screens.
- **Squad tiers**: first-choice, second-choice and backup per slot, derived from those two elevens. Player Removal and the planner use the same tiers.
- **Depth**: for a chosen tactic (the primary by default), every slot with the players who can cover it, ranked by slot rating at full fitness, with their familiarity in each phase, squad and current availability. It answers "how many real options do I have here if someone is injured" and shows where to recruit. It warns where cover is thin; the starting rule is fewer than two available players at familiarity 15 or above in a slot, and the rule is a parameter. It also shows the drop in rating from first choice to second, and marks cover that is shared, meaning the backup for one slot is first or second choice in another, since that cover disappears when he is needed elsewhere. Players out on loan are shown apart from available cover. The old app computed depth only inside the Training advisor and its command-line reports and never showed it on a screen.
- **Rest**: who needs rest or a holiday, from jadedness, condition and workload. Only the 400 threshold is FM27-confirmed; the age and attribute adjustments are carried over and marked.
- **Training**: position retraining recommendations, driven by depth gaps in the saved tactics instead of a fixed 4-2-3-1. It checks familiarity in both phases. Retraining speeds and timelines are FM26-era and marked. The research also asks for an "old position may decay" warning and a "may not reach natural" outcome; these are included as advisory text. The owner can accept a recommendation as well as reject it. Accepting records that the player is being retrained in that position in the game, which is what the planner's retraining preference (8.6) acts on; the old app boosted every recommended player whether or not he was being trained. For each accepted retraining the app records the player's familiarity at every import and shows the progress, so the owner can see real retraining speed in his own save and adjust the thresholds. Nothing is published for FM27, and the research recommends exactly this kind of tracking. The app does not pick a bench, so "give him twenty minutes as a substitute" remains advice text.
- **Player Removal**: sell, loan or release advice, plus the loan review. Money is shown in pounds.
- **Importance suggestion**: the app suggests an importance for each fixture, and the user's choice always wins. `match_importance.py` is the reference. It needs facts the fixture does not have today, so a fixture gains two optional fields, competition type and opponent strength. Without them the suggestion uses the schedule alone.

### 8.8 Parameters and evidence

Every tunable number lives in one place in the engine, each with an evidence label and a source: FM27 measured, FM27 official, carried over from FM26, or this design's derivation. The interface marks advice that depends on carried-over or derived numbers. Changing a number is a one-line edit with no other code affected.

## 9. Persistence

App state lives in `~/Library/Application Support/` under the app's own folder, not in the repository: the current date, fixtures, tactics, settings, rejections and overrides; the confirmed-lineup history; and the latest and previous squad snapshots. Files are JSON with a version number. A missing or unreadable file produces a clear message and a fresh start for that file, never a crash.

The app keeps a user-set current date, as the old app did, because the pasted data does not carry the in-game date.

## 10. Screens

The eight existing screens are kept, plus a home for the import and a depth view. First XI, Second XI and Depth are three views of one calculation; whether they stay separate screens is for the visual design pass to settle with the owner.

| Screen | Purpose |
|---|---|
| Squad | Import from the clipboard; show the imported squad, what changed since the last import, and any warnings. New. |
| Fixtures | Add, edit and delete fixtures; importance with the app's suggestion; tactic per fixture. |
| Tactics | Create and edit tactics: both shapes, roles and the mapping between them; choose the primary tactic. |
| Match Selection | The plan for the next fixtures: picks with fitness, factors and reasons; override, reject, confirm and unlock. |
| First XI, Second XI | Best elevens at full fitness. |
| Depth | Cover for every slot of a tactic, thin-cover warnings, and where to recruit. New. |
| Training | Retraining recommendations, with accept and reject; progress of accepted retraining. |
| Rest | Rest and holiday advice. |
| Player Removal | Sell, loan and release advice, and the loan review. |

App-wide settings have their own place, separate from these screens: training intensity, lineup stability, the condition floor, how strongly to save players for bigger fixtures, how many fixtures to plan, and the club-name override.

`ui/src/` on the branch is the reference for what each screen shows and does. Fields the old screens computed but never displayed are available to the new design: pick reasons, a training recommendation's current skill and age, and a player's tier by position.

## 11. Faults in the Python that must not be carried over

- Tactic changes did not reach other screens until restart.
- Confirmed lineups were saved without manual overrides, and looked up by date instead of fixture.
- Confirmed-lineup history used old position names that never matched tactic slots, and was read oldest-first as if newest-first.
- Squad tiers came from a formation that no longer matched the data.
- The Data Sources file fields had no effect on Match Selection.
- A training rejection stored one position per player, so a second rejection replaced the first.
- Missing values were handled differently from script to script; a missing current ability raised a rating by 15%.
- Invalid player-slot pairings were given the most attractive cost and filtered afterwards.
- Attribute name mismatches (`Professionalism`, `Work Rate`, `Best Position`) silently fell back to defaults.
- Status flags mixed 0-to-1, 0-to-100 and 0-to-10,000 scales.

## 12. Visual design

The look of the app is decided in a separate design pass, after this document is approved and before any screen is built: a design direction and mock-ups for the owner to react to, using the frontend-design skill for direction and expressed in SwiftUI. Engine work does not wait for it. That pass produces its own short design document.

## 13. Testing

- **Engine rules**: tests written from the rules in this document, including, for each planner rule, a case where the rule changes the outcome and a case where it does not.
- **Rating core**: comparison against outputs generated once from the branch's Python on the committed FM26 data, stored as fixtures so the tests need no Python.
- **Importer**: captured real clipboard text and the FMRTE grid configuration as it was at the moment of capture, plus malformed cases: wrong field count, missing required column, reordered columns, unexpected scale, and two grids with the same column count. The captures do not exist in the repository yet. Six real U21 rows and a configuration snapshot were saved during this design, but only in a temporary folder, and the first-team paste was never saved to disk. The work therefore opens with a capture step (section 14).
- **Planner scenarios**: fixture congestion, a High fixture after two Low ones, a squad with injuries, a Sharpness fixture, and the same plan with saving-for-later on and off.
- **App**: what the builder judges worthwhile; the engine carries the weight.

## 14. Sequence

The implementation plan will set the detail. The intended order:

1. Repository preparation: `main` is fast-forwarded to `origin/customizable-tactics` so there is one Python reference. The Python stays in place as reference during the work. The owner copies each squad from FMRTE once more, and each paste is saved with FMRTE's grid configuration as importer test fixtures.
2. Engine foundation: model, importer, FM27 roles, rating core checked against the Python.
3. Single-fixture selection: fitness factors, risk rules, assignment, overrides, rejections, explanations.
4. Planner: projection, importance rules, saving players for big games, stability, confirmed-lineup history.
5. Advisors.
6. App screens, starting with Squad, Tactics and Match Selection as soon as steps 2 and 3 allow, following the visual design pass.
7. Clean-up, after the owner signs off the new app: remove the Electron app, the Python engine, the Windows scripts, the Excel workbook and `fm26_parser/`; rewrite `CLAUDE.md` and the README for the Swift app.

The visual design pass (section 12) starts as soon as this document is approved and runs alongside steps 2 to 4.

## 15. Left to the builder

- Project layout, target names, and how the Xcode project and Swift package are arranged.
- The exact curve shapes for condition, sharpness and jadedness, provided they respect the anchors in 8.5.
- The assignment algorithm and its tie-breaking rule.
- The precise formula for the cost of using a player before a bigger fixture, provided it uses slot ratings, importance, proximity and projected fitness, and can be scaled to zero.
- File layout and schema of the persisted JSON.
- How the engine's parameter table is represented.
- Whether to add a small command-line harness for running the engine against a paste during development.

## 16. Open items for the owner

These do not block planning:

- Whether FMRTE's grid offers a unique player ID column.
- A copied row for a loaned-in player, when one exists, to confirm how he appears.
- Whether FMRTE exposes any Tactical Understanding figure per player in a grid column, which would make it possible to model later.
