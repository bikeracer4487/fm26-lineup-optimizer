# Player Removal Row Facts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Player Removal shows each player's current ability, potential ability, salary by the year and the day his contract ends, the day read from FMRTE's new `Contract.ContractExpiryDate` column.

**Architecture:** The importer reads the column into a new optional field of `Player`. The engine gives the two new pieces of wording (a yearly amount, a day with its year). Core builds the four facts for a row from the player; the views only lay them out.

**Tech Stack:** Swift 6, Swift Testing, SwiftUI; `LineupEngine` and `LineupApp` as they stand.

**Spec:** `docs/superpowers/specs/2026-11-23-fm27-removal-row-facts-design.md`

## Global Constraints

- No silent defaults: a bad cell is an error naming the player and the column.
- A grid without the column, and a squad file saved before this change, give no date and no error or notice.
- Words about a player come from the engine; Core holds plain labels; views hold layout only, every measure from `Theme`.
- No advice, score, reason or release cost changes.
- Test output clean, no build warnings. `cd LineupEngine && swift test`; `tools/test_app.sh`; the unoptimized `cd LineupApp && swift test` once, in the background, before the work is called finished.
- A screen is not done until its pictures have been looked at.

## Review Focus

1. FMRTE set to day-first dates ("30/6/2030"): refused naming the player and the column, never read as a wrong day. (Task 1)
2. The column present and a contracted player's cell blank: refused, not read as "no date". (Task 1)
3. A squad file saved before the change: opens with no notice, every row falling back to months left. (Tasks 1 and 3)
4. Squads half imported: the first team with dates and the U21s without, on one screen. (Task 3)
5. A player with no contract, or in no squad any more: no salary and no date shown, and no crash. (Task 3)

---

### Task 1: The importer reads the day a contract ends

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Model/Player.swift` (the `Player` struct)
- Modify: `LineupEngine/Sources/LineupEngine/Import/Importer.swift`
- Create: `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/first-team-with-expiry.tsv` and `.grids.json` (copied from the scratchpad capture of 23 November 2026, exact clipboard bytes)
- Modify: `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/README.md` (one row)
- Test: `LineupEngine/Tests/LineupEngineTests/ImporterTests.swift`

**Interfaces:**
- Produces: `Player.contractEnds: Day?` (a trailing initialiser parameter, `contractEnds: Day? = nil`; synthesized Codable, so absent in a file reads as nil).

- [ ] **Step 1: failing tests** in `ImporterTests.swift`, on the new capture read with `Wages` "Monthly":
  - 30 players; Caelan Avenell's `contractEnds == Day(iso: "2030-06-30")`, Hudson Waddell's `Day(iso: "2030-05-31")`; no player's `extras` holds `Contract.ContractExpiryDate`.
  - `first-team-with-id` (no such column): every `contractEnds == nil`.
  - Avenell's cell made `""`, `"30/6/2030"`, `"2/30/2030"`, `"6/30"` and `"June 2030"`: each throws `ImportError.invalidValue(player: "Caelan Avenell", column: "Contract.ContractExpiryDate", value: <the cell>)`.
  - Avenell's contract type, months left and wage blanked (no contract), the date cell left filled: imports, `contractEnds == nil`.
  - A `Player` encoded, its `contractEnds` key removed from the JSON, decodes with nil.
- [ ] **Step 2:** run `swift test --filter ImporterTests`; the new tests fail.
- [ ] **Step 3:** add the field; in the importer add the path to `modelledColumns` and, when the layout has it and the player has a contract, read the trimmed cell as exactly three whole numbers split on "/", month then day then year, through `Day(year:month:day:)`.
- [ ] **Step 4:** `swift test` passes, no warnings.
- [ ] **Step 5:** commit.

### Task 2: The engine's words

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Selection/LineupSelector.swift` (`Display`)
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/MoneyTests.swift`, `AdvisorTextTests.swift`

**Interfaces:**
- Produces: `Display.yearlyAmount(perWeek: Double, _ style: MoneyStyle) -> String` ("$68,820", whatever the style's period); `Display.yearly(perWeek:_:) -> String` ("$68,820 a year"); `AdvisorText.fullDay(_ day: Day) -> String` ("30 Jun 2030").

- [ ] **Step 1: failing tests:** a wage of $5,735 a month kept by the week (`WagePeriod.monthly.perWeek(5735)`) gives "$68,820" and "$68,820 a year" in a monthly and in a weekly style; 0 gives "$0"; `fullDay` of 2030-06-30 is "30 Jun 2030" and of 2028-07-01 is "1 Jul 2028".
- [ ] **Step 2:** run them; they fail.
- [ ] **Step 3:** implement with `WagePeriod.yearly.amount(perWeek:)`, rounded, through `Display.money`, and `WagePeriod.yearly.suffix`.
- [ ] **Step 4:** `swift test` passes.
- [ ] **Step 5:** commit.

### Task 3: The rows carry the four facts

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/RemovalPresentation.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/RemovalPresentationTests.swift`

**Interfaces:**
- Consumes: Task 1's field, Task 2's three functions.
- Produces:
  - `public struct PlayerFacts: Equatable, Sendable` with `abilityText`, `potentialText: String`, `salaryText: String?` (the yearly amount; nil with no contract), `contractText: String?` (the full day; else "28 months left"; else "No contract" for one out of contract; else nil), `line: String` ("CA 92 · PA 120 · $68,820 a year · contract ends 30 Jun 2030", the last part "28 months left" or "no contract" as it falls, parts not known left out), and `init(_ player: Player, money: MoneyStyle)`.
  - `RemovalRow.facts: PlayerFacts?` and `YoungRow.factsLine: String?`, nil for a player not handed in; both rows' `spokenText` gain the line.
  - `RemovalPresentation.sheet(_:squads:ages:marks:facts:)`, `facts: [PlayerID: PlayerFacts] = [:]`; the model's call passes every held player's.
  - `RemovalColumn`: `level, action, name, squad, age, ability, potential, salary, contract, score` with titles "CA", "PA", "Salary a year", "Contract ends"; `costs` is no longer a column (`RemovalRow.costsText` stays).

- [ ] **Step 1: failing tests:** the facts of a player with a date, of one with only months left (1 month and 28 months), of one out of contract; a sheet with facts for one player and none for another (row and young row); the columns' titles in order; the spoken text.
- [ ] **Step 2:** `tools/test_app.sh --filter RemovalPresentationTests`; they fail.
- [ ] **Step 3:** implement.
- [ ] **Step 4:** `tools/test_app.sh` passes.
- [ ] **Step 5:** commit.

### Task 4: The screen

**Files:**
- Modify: `LineupApp/Sources/LineupAppUI/Advice/RemovalScreen.swift`, `LineupApp/Sources/LineupAppUI/Theme.swift` (`Theme.Removal`)
- Modify: `LineupApp/Sources/LineupAppCore/SampleData.swift` (the sample first team gets contract end days, the U21s none, so the pictures show both forms)

- [ ] **Step 1:** wide board: the four columns between Age and Score, numbers trailing, the name taking the room left. Narrow board (under the new `wideTableWidth`): no four columns, the facts line under the name in muted small text, where the costs sentence was. The costs sentence is the first line of the opened row in both, above the reasons. This plan's call beyond the design: the narrow form.
- [ ] **Step 2:** Young players: the facts line under the title, muted, above the engine's lines.
- [ ] **Step 3:** `swift run -q LineupApp --sample-data .. --pictures .build/pictures-facts`; look at `removal-*`, `removal-all-open-*`, `removal-young-*`, `removal-young-narrow-*`, and the smallest window.
- [ ] **Step 4:** `tools/test_app.sh` passes; commit.

### Task 5: Notes, the long test run and the review

- [ ] `CLAUDE.md`: the import paragraph (the new column), the Player Removal description, the pictures checked, the test counts.
- [ ] `cd LineupApp && swift test` in the background, once.
- [ ] One fresh reviewer on the whole diff, read-only, bounded; fix what it finds; commit.

---

## What changed during the build

- A two-digit year ("6/30/30") is refused, beyond Task 1's list: it would have been read as the year 30.
- Tasks 3 and 4 were built and committed together: taking the Costs column out of `RemovalColumn` does not compile
  without the view's change.
- On a wide board the name takes the room the fixed columns leave (at least 200 points) instead of a fixed 240.
- Contract end days were added to the young-players sample only (`modelWithYoungPlayers`), not the base sample, which
  many tests read as imported: the plain `removal-*` pictures show months left, the `removal-young-*` ones a day.
- `AdvisorText.fullDay` is tested in `LeagueTextTests`, beside `shortDay`.
- "28 months left", "No contract" and "contract ends …" are composed in Core (`PlayerFacts`), around the engine's
  figure and day, as Offers composes "10 months left". The design's "Words" section gave them to the engine.

## What the whole-branch review found

One fresh reviewer read the whole diff on 23 November 2026, read-only.

- **Fixed.** A player with a contract type and months left below zero (FMRTE's "Amateur" or "4", or a contract that
  has run out) was asked for an expiry date: a blank cell would have refused the whole paste, an opponent's squad
  among them, and a placeholder date would have been shown as a real day. He now has no day and his cell is not read
  (`aPlayerWhoseMonthsLeftAreBelowZeroHasNoDayAndHisCellIsNotRead`, watched failing first). The design is revised.
- **Left, small.** Any four-digit year is accepted for a player with months left, so a placeholder such as "1/1/1900"
  on such a player would be shown as written. The refusal of a day-first date says only that the value is not valid,
  not that month/day/year is wanted. VoiceOver hears the release-cost sentence on the row and again in the opened
  row. A yearly salary of eight figures would be cut short in its 112-point column.

## Limits left

- A date written day first with every day 12 or under cannot be told from a month-first one and is read month first.
- What FMRTE writes in the expiry-date cell of an amateur or a player whose contract has run out is not known; no
  capture holds one.
- The cost of a release is still reckoned from months left plus half a month, not from the day.
- The dates appear only after each squad is imported again with the new column.
- The install, and the look of the four columns in a live window, are left to the owner.

