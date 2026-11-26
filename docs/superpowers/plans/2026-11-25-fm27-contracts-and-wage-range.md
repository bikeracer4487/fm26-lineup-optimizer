# Menu, Contracts Screen and Wage Range Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move five screens into a "More" menu, add a Contracts screen that lists and counts the players worth
renewing who are in their last year, and show a reasonable wage range there and on Scouting's candidates.

**Architecture:** The engine gains two advisors, each a function of the data it is handed: `WageRange` (a tier's
wages, the range, the ceiling, the verdict on a figure) and `Contracts` (who is listed and in which part), with
every sentence in `AdvisorText+Contracts.swift`. The app's Core keeps what the owner types and dismisses in
`contracts.json`, builds the rows and the count, and the views draw them.

**Tech Stack:** Swift 6, macOS 26, SwiftUI and Observation, Swift Testing, Foundation only. No third-party code.

**Spec:** `docs/superpowers/specs/2026-11-25-fm27-contracts-and-wage-range-design.md`. Research:
`docs/Research/fm27-contract-wage-demands.md`. Project rules: `CLAUDE.md`.

## Global Constraints

- Work on branch `fm27-native`. Commit after each task; say why in the message. No merge, no pull request, no push.
- The engine has no UI and reads no files. The same inputs always give the same output: sort before any median
  or tie.
- No silent defaults in the engine: a missing value is an error that names the player and the column.
- Every tunable number lives in `EngineParameters` with an evidence label and a source. Here that is one entry,
  `wageRangeRules`, labelled `.derived`.
- Every rule gets a test where it changes an outcome and a test where it does not.
- Every word about advice is the engine's (`AdvisorText`), shown as written. Core holds plain labels and
  headings only. A view computes nothing and holds no literal colour, font or measure: all from `Theme`.
- Nothing the owner reads is an id: slots are "left back" in a sentence (`PositionText.plain`).
- Money is written through the squad book's `MoneyStyle` (`Display.wage(perWeek:_:)`); wages are kept by the week.
- No test, picture run or sample-data run touches `~/Library/Application Support` or the real clipboard.
- Test output is clean: no build warnings.
- Do not modify the old Python, `ui/`, or root-level data files.
- Commands: engine `cd LineupEngine && swift test --filter <Suite>`; app `tools/test_app.sh --filter <Suite>`
  from the repository root; pictures `cd LineupApp && swift run -q LineupApp --sample-data .. --pictures
  .build/pictures-contracts`.
- For a dispatched implementer: no `rm -rf`, no archives, nothing written outside the repository and the
  build folders; if a command asks for permission or hangs, do the step another way and report it.

## Review Focus

1. **The player's own wage is left out of his tier's range.** An own player who is his tier's top earner sees a
   range below his present wage. The line must say "the rest of your first eleven", and a figure equal to his
   present wage must not read as a fault of the figure. Test in Task 4.
2. **Every wage in a tier is the same** (the captures repeat wages exactly). The line must not read "$3,269 to
   $3,269". Test in Task 4.
3. **Wages spent above the wage budget, or a highest wage of 0.** The budget left is never below 0, and 0 is a
   value, so every figure is over a highest wage of 0. Tests in Task 2.
4. **The date moved past a contract's end day.** He stays listed under "Other clubs can approach them now"; no
   crash, no negative months in a sentence. Test in Task 3.
5. **The advice is not ready** (no squad, no tactic, a failed advice). The pill shows no count, Contracts shows
   the gate, and Scouting's rows carry no wage lines. Tests in Tasks 6 and 8.

---

### Task 1: The "More" menu

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/Screen.swift`
- Modify: `LineupApp/Sources/LineupAppUI/Board/BoardFrame.swift` (`TopRow.pills`, new `MorePill`)
- Modify: `LineupApp/Sources/LineupAppUI/Theme.swift` (only if the menu mark needs a measure)
- Modify: `LineupApp/Sources/LineupApp/main.swift` (one more picture)
- Test: `LineupApp/Tests/LineupAppCoreTests/ScreenTests.swift`

**Interfaces:**
- Produces, on `Screen`:
  - `public var isInMenu: Bool` — true for `.tactics, .elevens, .rest, .offers, .settings`.
  - `public static var rowScreens: [Screen]` — `allCases` not in the menu, in `allCases` order.
  - `public static var menuScreens: [Screen]` — `allCases` in the menu, in `allCases` order.
  - `public static let moreTitle = "More"`.
  - `public static func morePillTitle(current: Screen?) -> String` — the current screen's `title` when it is in
    the menu, else `moreTitle`.

- [x] **Step 1: Write the failing tests** in `ScreenTests.swift`

```swift
@Test func theRowAndTheMenuSplitTheScreens() {
    #expect(Screen.menuScreens == [.tactics, .elevens, .rest, .offers, .settings])
    #expect(Screen.rowScreens == [.squad, .fixtures, .league, .matchSelection, .training, .removal, .scouting])
    #expect(Set(Screen.rowScreens + Screen.menuScreens) == Set(Screen.allCases))
}
@Test func theMorePillNamesAMenuScreenAndNothingElse() {
    #expect(Screen.morePillTitle(current: .rest) == "Rest")
    #expect(Screen.morePillTitle(current: .settings) == "Settings")
    #expect(Screen.morePillTitle(current: .squad) == "More")
    #expect(Screen.morePillTitle(current: nil) == "More")
}
```

- [x] **Step 2: Run** `tools/test_app.sh --filter ScreenTests`. Expected: fails to build, `menuScreens` not found.
- [x] **Step 3: Implement** the five members on `Screen`. `isInMenu` is an exhaustive `switch`, no `default`.
- [x] **Step 4: Run** the same filter. Expected: pass.
- [x] **Step 5: Draw the row.** In `TopRow.pills`, `ForEach(Screen.rowScreens)` as today, then a `MorePill`: a
  SwiftUI `Menu` whose entries are `Screen.menuScreens` by `title` (each sets `navigation.screen`), whose label
  is drawn as `ScreenPill` draws its own (same shape, padding, typeface, current and plain colours) with
  `Screen.morePillTitle(current: navigation.screen)` and a small downward chevron after it, current style when
  `navigation.screen?.isInMenu == true`. Share the pill's drawing between `ScreenPill` and `MorePill`; do not
  copy it. The menu's own indicator is hidden so only the chevron shows. VoiceOver: label "More screens", value
  the current menu screen's title when one is shown.
- [x] **Step 6: Add a picture** to `main.swift`: the Rest screen drawn as `more-rest-…`, so the pill reads
  "Rest". Run the picture command with `.build/pictures-contracts`; look at `squad-*` (pill reads "More") and
  `more-rest-*` (pill reads "Rest", drawn as current), light and dark, and at the smallest window.
  Expected: one row of eight pills where twelve fitted.
- [x] **Step 7: Run** `tools/test_app.sh`. Expected: all pass. Fix any test that counted twelve pills.
- [x] **Step 8: Commit.** "Move Tactics, Elevens, Rest, Offers and Settings into a More menu" with the owner's
  reason (he visits them less often).

---

### Task 2: The engine's wage range

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Advisors/WageRange.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift` (the entry, beside `offerRules`)
- Modify: `LineupEngine/Sources/LineupEngine/Selection/FitnessModel.swift` (`problems(in:)` adds
  `WageRange.problems(in:)`)
- Test: `LineupEngine/Tests/LineupEngineTests/WageRangeTests.swift`

**Interfaces:**
- Consumes: `SquadTiers` (`tier(of:)`, `slot(of:)`), `LoanStatus.of(_:ownClub:)`, `Removal.isOnYouthContract`,
  `CandidateSlot` (`level`, `marginOverFirst`, `slot`), `Player.wagePerWeek`.
- Produces:

```swift
public struct WageRangeRules: Equatable, Sendable {
    public var lastYearMonths: Int      // 12
    public var approachMonths: Int      // 6
    public var keyPlayerShare: Double   // 0.075
    public var starterShare: Double     // 0.043
    public var backupShare: Double      // 0.027
    public var fewestWages: Int         // 3
}
public enum WageTier: String, CaseIterable, Sendable { case firstEleven, secondEleven, neither }

/// The club's three figures, by the week; nil when not entered.
public struct WageLimits: Equatable, Codable, Sendable {
    public var wageBudgetPerWeek: Double?
    public var wagesSpentPerWeek: Double?
    public var highestWagePerWeek: Double?
    public static let none: WageLimits
}
public struct PlayerWage: Equatable, Sendable { public let player: PlayerID; public let perWeek: Double }
public struct PaidRange: Equatable, Sendable {
    public let lowerQuartile: Double; public let highest: Double; public let count: Int
}
public enum WageCap: Equatable, Sendable { case tierHighest, ceiling, highestWage }
public enum WageShown: Equatable, Sendable {
    case range(low: Double, high: Double, setBy: WageCap)
    case upTo(Double, setBy: WageCap)
    case none
}
public struct WageGuide: Equatable, Sendable {
    public let tier: WageTier
    public let slot: SlotID?
    public let leavesHimOut: Bool           // true when `excluding` was one of the tier's wages
    public let paid: PaidRange?
    public let ceilingPerWeek: Double?
    public let starterSharePerWeek: Double? // first eleven only
    public let highestWagePerWeek: Double?
    public let budgetLeftPerWeek: Double?
    public let countsHisWageBack: Bool      // true when a present wage above 0 was added to the budget left
    public let shown: WageShown
    public let basis: Evidence
}
public enum WageVerdict: Equatable, Sendable {
    case overHighestWage(limit: Double)
    case overCeiling(ceiling: Double)
    case aboveTier(highest: Double)
    case withinTier
    case underTier
    case overBudgetLeft(by: Double)
    case timesPresentWage(Double)
}
public enum WageRange {
    static func problems(in rules: WageRangeRules) -> [String]
    public static func tierWages(tiers: SquadTiers, players: [Player], ownClub: String?) -> [WageTier: [PlayerWage]]
    public static func tier(of player: PlayerID, in tiers: SquadTiers) -> (tier: WageTier, slot: SlotID?)?
    public static func tier(of level: CandidateLevel) -> WageTier
    public static func bestLevel(_ slots: [(slot: SlotID, level: CandidateLevel, margin: Double?)])
        -> (slot: SlotID, level: CandidateLevel)?
    public static func guide(tier: WageTier, slot: SlotID?, wages: [WageTier: [PlayerWage]], excluding: PlayerID?,
                             presentWagePerWeek: Double?, limits: WageLimits,
                             parameters: EngineParameters) throws -> WageGuide
    public static func verdict(figurePerWeek: Double, guide: WageGuide, presentWagePerWeek: Double?) -> [WageVerdict]
    public static func caution(in verdicts: [WageVerdict]) -> WageVerdict?
}
```

- `EngineParameters.wageRangeRules: Parameter<WageRangeRules>`, value `(12, 6, 0.075, 0.043, 0.027, 3)`,
  `.derived`, source: "docs/Research/fm27-contract-wage-demands.md: no test in any version says what a player
  asks. approachMonths is the game's rule (carried over from FM26, official). keyPlayerShare, starterShare and
  backupShare are one author's rule of thumb on Sports Interactive's site for FM23 (30% of the wage budget to
  each of 4 key players, 7 starters and 11 backups). lastYearMonths and fewestWages are the design's choice of
  25 November 2026".

**The rules the bodies must follow** (spec sections 4 and 5):

- `problems`: months at least 1; `approachMonths <= lastYearMonths`; each share finite, above 0 and at most 1;
  `backupShare <= starterShare <= keyPlayerShare`; `fewestWages >= 1`. One sentence each, in the form
  `Offers.problems` uses.
- `tierWages`: players whose `LoanStatus` is `.own`, whom `tiers` rates, with `wagePerWeek > 0`, and not
  `Removal.isOnYouthContract`. `.first` is `.firstEleven`, `.second` is `.secondEleven`, `.backup` is
  `.neither`. Each list sorted by `perWeek`, then the player's key. Every tier has an entry, empty or not.
- `tier(of level:)`: `.wouldStart` first eleven, `.wouldMakeSecond` second eleven, the other two neither.
- `bestLevel`: the best level in the order `CandidateLevel` declares; then the greatest margin, nil counting
  above every number; then the earliest in the list. Nil for an empty list.
- `guide`: throws `PlanError.badParameters` while `FitnessModel.problems(in:)` is not empty. The tier's wages
  without `excluding`. With fewer than `fewestWages`, `paid` is nil. The lower quartile is the median of the
  lower half: the first `count / 2` values, their middle value, or the mean of the middle two when that half
  has an even count. The ceiling is the wage budget times `keyPlayerShare` (first eleven) or `backupShare`
  (the other two); `starterSharePerWeek` is set for the first eleven only. The budget left is
  `max(0, budget − spent + (presentWagePerWeek ?? 0))`, nil unless both are entered. `shown`:
  - `paid` known: the top is the smallest of `paid.highest`, the ceiling and the highest wage, each when
    known; on a tie the first of `.tierHighest`, `.ceiling`, `.highestWage`. `.range(low: lowerQuartile, high:
    top, setBy:)` when the top is at least the lower quartile, else `.upTo(top, setBy:)`.
  - `paid` nil and a ceiling: `.upTo` the smaller of the ceiling and the highest wage (ceiling on a tie).
  - `paid` nil and no ceiling: `.none`, whatever the highest wage.
- `verdict`, in this order, each only when it applies, comparisons with a noise of `1e-6` so a figure typed
  equal to a line is not over it:
  1. `.overHighestWage` when the figure is above the highest wage.
  2. `.overCeiling` when above the ceiling.
  3. With `paid`: `.aboveTier` above its highest, `.underTier` below its lower quartile, else `.withinTier`.
  4. `.overBudgetLeft(by:)` when above the budget left.
  5. `.timesPresentWage(figure / present)` when a present wage above 0 is handed in.
- `caution`: the first of `.overHighestWage`, `.overCeiling`, `.aboveTier` in the list, else nil.

- [x] **Step 1: Write the failing tests** in `WageRangeTests.swift`. Build wages directly as
  `[WageTier: [PlayerWage]]`; no squad is needed except for `tierWages` (use the player helper the neighbouring
  `DevelopmentTests` uses). Cover, with these exact values:

```swift
// wages 500, 600, 700, 800, 900 in the second eleven, no limits
#expect(guide.paid == PaidRange(lowerQuartile: 550, highest: 900, count: 5))
#expect(guide.shown == .range(low: 550, high: 900, setBy: .tierHighest))
// three wages 500, 600, 700: lower quartile 500. Two wages: paid == nil, shown == .none
// excluding the 900 earner: paid.highest == 800, leavesHimOut == true; excluding a stranger: false
// budget 20_000: second eleven ceiling 540, shown == .upTo(540, setBy: .ceiling); first eleven ceiling 1_500,
//   starterSharePerWeek 860
// budget 30_000 (ceiling 810): shown == .range(low: 550, high: 810, setBy: .ceiling)
// highest wage 700 with no budget: .range(low: 550, high: 700, setBy: .highestWage)
// two wages and budget 20_000: .upTo(540, setBy: .ceiling); two wages, no budget, highest wage 700: .none
// budget 20_000, spent 19_000, present 600: budgetLeftPerWeek == 1_600, countsHisWageBack == true
// spent 25_000 over budget 20_000, present 600: budgetLeftPerWeek == 0   (max(0, -4_400)), not negative
// verdict(1_000) with highest wage 700, budget 20_000, spent 19_800, present 400:
//   [.overHighestWage(limit: 700), .overCeiling(ceiling: 540), .aboveTier(highest: 900),
//    .overBudgetLeft(by: 400), .timesPresentWage(2.5)]
// verdict(700) with highest wage 700: no .overHighestWage (equal is not over)
// verdict(600), no limits: [.withinTier]; verdict(500): [.underTier]; with paid nil: []
// highest wage 0: verdict(1) starts with .overHighestWage(limit: 0)
// caution([.withinTier, .overBudgetLeft(by: 5)]) == nil; caution([.overCeiling(ceiling: 540), .aboveTier(highest: 900)]) == .overCeiling(ceiling: 540)
// bestLevel: [(a, .wouldCountAsCover, 0.1), (b, .wouldStart, 0.02), (c, .wouldStart, 0.05)] gives (c, .wouldStart);
//   a nil margin beats 0.05; equal margins give the earlier; [] gives nil
// tierWages: a player on loan here, one out on loan, one on a youth contract and one paid 0 are in no tier's list;
//   the same players in another order give the same lists
// problems: a starterShare above keyPlayerShare, a share of 0, fewestWages 0 and approachMonths 13 each give a sentence;
//   EngineParameters.standard's give none
```

- [x] **Step 2: Run** `cd LineupEngine && swift test --filter WageRangeTests`. Expected: fails to build.
- [x] **Step 3: Implement** the types, the entry and the functions; add the problems to `FitnessModel.problems`.
- [x] **Step 4: Run** the filter, then `swift test --filter EngineParameters` (the size test: the entry is one
  pointer, so it holds). Expected: pass.
- [x] **Step 5: Commit.** "Work out a wage range from what a tier is paid and the club's limits", saying that
  the research found no formula and why the range is the squad's own.

---

### Task 3: Who is listed on Contracts

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Advisors/Contracts.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Planner/Day.swift` (`adding(months:)`)
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/ScoutingCandidates.swift` (extract the level test)
- Test: `LineupEngine/Tests/LineupEngineTests/ContractsTests.swift`, and `DayTests` for the months

**Interfaces:**
- Consumes: Task 2's `WageTier`, `WageRange.tier(of:in:)`, `WageRange.tier(of level:)`, `WageRange.bestLevel`;
  `RemovalReport` (`advice`, `advisedToLeave`), `RemovalAdvice` (`tier`, `outlook`, `action`),
  `Removal.isWorthDeveloping(_:)`, `Removal.isOnYouthContract(_:)`, `ElevensReport` (`tiers`, `second`),
  `Development.rivals(at:tiers:squad:ownClub:parameters:)`, `SaleMark`.
- Produces:

```swift
extension Day { public func adding(months: Int) -> Day }   // the same day of the month, or its last day when shorter

extension Scouting {
    /// The four tests `slotsToday` applies, unchanged, in one place.
    static func level(rating: Double, first: Rival?, second: Rival?, secondPlaceIsOpen: Bool,
                      parameters: EngineParameters) -> CandidateLevel
}

public enum ContractPart: String, CaseIterable, Sendable { case approachable, lastYear, noContract }
public enum ContractStanding: Equatable, Sendable {
    case first(SlotID), second(SlotID), neither
    case outOnLoan(to: String, level: CandidateLevel?, slot: SlotID?)   // nil level: he can play no slot
}
public struct ContractEntry: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let part: ContractPart
    public let ends: Day?
    public let approachableFrom: Day?     // lastYear with an end day only
    public let standing: ContractStanding
    public let action: RemovalAction?     // nil when out on loan
    public let tier: WageTier
    public let slot: SlotID?
    public let presentWagePerWeek: Double
}
public struct ContractsReport: Equatable, Sendable {
    public let listed: [ContractEntry]
    public let dismissed: [ContractEntry]
    public let leftOutAsGoing: Int
    public let basis: Evidence
}
public enum Contracts {
    public static func part(of player: Player, today: Day, parameters: EngineParameters) -> ContractPart?
    public static func report(players: [Player], ownClub: String?, marks: [PlayerID: SaleMark],
                              removal: RemovalReport, elevens: ElevensReport, tactic: Tactic,
                              dismissed: Set<PlayerID>, today: Day, catalog: RoleCatalog, profile: RatingProfile,
                              parameters: EngineParameters) throws -> ContractsReport
}
```

**The rules** (spec section 2; the first is this plan's reading where the spec is silent):

- `part(of:)`, the first that holds: `.noContract` for `contractType == .outOfContract` or months left below
  0. With a `contractEnds` day: `.approachable` when it is on or before `today.adding(months:
  approachMonths)` (a day already past included), `.lastYear` when on or before `today.adding(months:
  lastYearMonths)`, else nil. With no end day and months left known: `.approachable` at `approachMonths` or
  fewer, `.lastYear` at `lastYearMonths` or fewer, else nil. With neither: nil.
- A player is a candidate for the list when `LoanStatus.of` is `.own` or `.loanedOut` and `part` is not nil.
- Standing: an own player's from `WageRange.tier(of:in: elevens.tiers)` and his advice; a player Player
  Removal gave no advice and the tiers did not rate is `.neither`. A player out on loan is rated at every
  slot `slotsToday` would rate a pasted player at (the same helper it uses for the playable slots), against
  `Development.rivals` of the whole squad with `elevens.tiers`, `secondPlaceIsOpen` read from `elevens.second`
  as `slotsToday` reads it, and takes `WageRange.bestLevel`. A rating error is thrown, not swallowed.
- The youth and no-contract gate: a player for whom `Removal.isOnYouthContract` holds, or whose part is
  `.noContract`, passes only when his tier is first or second eleven, or his advice has an outlook that
  `Removal.isWorthDeveloping` accepts; out on loan, only at `.wouldStart` or `.wouldMakeSecond`.
- Going: he has a mark, or is in `removal.advisedToLeave`. `leftOutAsGoing` counts candidates who pass the gate
  and are going. They are in neither list.
- `listed` and `dismissed` hold the rest, split by `dismissed`. Order in each: the parts in declaration order;
  within a part the earlier end day first, a player with no end day after those with one and by fewer months
  left; then the order of `players`.
- `approachableFrom` is `ends.adding(months: -approachMonths)`.
- `basis` is the weakest of `wageRangeRules`' evidence and `removal`'s advice it read.

- [x] **Step 1: Write the failing tests.** `DayTests`: 31 Aug 2026 plus 6 months is 28 Feb 2027; 30 Jun 2027
  minus 6 is 30 Dec 2026; 15 Jan 2027 plus 12 is 15 Jan 2028. `ContractsTests`, on a squad built with the
  helper `RemovalTests` uses, today 25 Nov 2026:

```swift
// ends 30 Apr 2027 -> .approachable; ends 30 Jun 2027 -> .lastYear, approachableFrom 30 Dec 2026;
// ends 25 Nov 2027 -> .lastYear (on the day counts); ends 26 Nov 2027 -> nil
// ends 1 Oct 2026 (already past) -> .approachable                       (Review Focus 4)
// no end day: 6 months -> .approachable, 12 -> .lastYear, 13 -> nil, months nil -> nil
// out of contract -> .noContract; months -1 -> .noContract
// a first-eleven player in his last year is listed with standing .first(slot), tier .firstEleven
// the same player marked to sell, or in advisedToLeave: not listed, leftOutAsGoing == 1
// the same player on loan here: in no list, not counted
// the same player dismissed: in `dismissed`, not in `listed`
// a youth-contract backup of 17 whose outlook is "could become cover": not listed, not counted as going;
//   the same with an outlook "could make the second eleven": listed
// a full-time backup of 28 with no outlook, in his last year: listed (the gate is for youth and no contract only)
// a backup of 28 with no contract: not listed; the same in the second eleven: listed, part .noContract
// out on loan, full-time, in his last year, rated above the first choice at his slot: listed,
//   standing .outOnLoan(to: "Wallingford", level: .wouldStart, slot: that slot), tier .firstEleven, action nil
// out on loan on a youth contract at .wouldCountAsCover: not listed
// order: approachable before lastYear before noContract; within a part 30 Apr before 31 May;
//   two with the same day keep the order of `players`; shuffling `players` changes only that tie
```

- [x] **Step 2: Run** `swift test --filter ContractsTests` and `--filter DayTests`. Expected: fail to build.
- [x] **Step 3: Implement** `Day.adding(months:)`.
- [x] **Step 4: Extract** `Scouting.level` from `slotsToday` and call it there. Run `swift test --filter
  Scouting`. Expected: every existing Scouting test passes unchanged.
- [x] **Step 5: Implement** `Contracts.part` and `Contracts.report`.
- [x] **Step 6: Run** both filters. Expected: pass.
- [x] **Step 7: Commit.** "List the players worth renewing who are in their last year".

---

### Task 4: The sentences

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Contracts.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/AdvisorTextContractsTests.swift`

**Interfaces:**
- Consumes: Tasks 2 and 3's types; `Display.wage(perWeek:_:)`, `AdvisorText.shortDay`, `PositionText.plain`,
  the engine's existing name for a `RemovalAction` (lowercased).
- Produces, all `public static` on `AdvisorText`:

```swift
enum WageFigure { case agents, presentWage }                 // public
static let contractsIntro: String
static let nobodyInLastYear: String
static func contractPartHeading(_ part: ContractPart) -> String
static func standingLine(_ entry: ContractEntry) -> String
static func timingLine(_ entry: ContractEntry) -> String?
static func wageGuideLines(_ guide: WageGuide, money: MoneyStyle) -> [String]
static func wageVerdictLine(_ verdict: WageVerdict, figure: WageFigure, guide: WageGuide, money: MoneyStyle) -> String
static func candidateWageLead(level: CandidateLevel, slot: SlotID) -> String
static func candidatePresentWage(perWeek: Double, money: MoneyStyle) -> String
static let candidateAskNotKnown: String
static let candidateWageOtherCurrency: String
static func leftOutAsGoingLine(_ count: Int) -> String
static func notRenewingLine(_ count: Int) -> String
static func contractsEvidenceNote(_ rules: WageRangeRules) -> [String]
static let wageEvidenceSentence: String                      // the one line Scouting's note gains
```

**The copy.** `T` is "first eleven", "second eleven" or "players in neither eleven"; `are` follows it ("Your
first eleven are", "Your players in neither eleven are"). With `guide.leavesHimOut`, "Your T" becomes "The
rest of your T". Money is `Display.wage(perWeek:money)`.

| Function | Case | Sentence |
|---|---|---|
| `contractsIntro` | | "Players you are keeping whose contracts are running down, with what your own squad is paid as a guide to a reasonable wage." |
| `nobodyInLastYear` | | "Nobody you are keeping is in the last year of his contract." |
| `contractPartHeading` | approachable / lastYear / noContract | "Other clubs can approach them now" / "In their last year" / "No contract" |
| `standingLine` | first, second | "First choice at left back." / "Second choice at striker." |
| | neither, with an action | "In neither eleven; Player Removal says keep and develop." |
| | neither, no action | "In neither eleven." |
| | out on loan, by level | "Out on loan at Wallingford; he would start at left back." / "…he would make the second eleven at left back." / "…he would count as cover at left back." / "…he would be below cover at left back." |
| | out on loan, no slot | "Out on loan at Wallingford; he can play no slot of this tactic." |
| `timingLine` | approachable | "Other clubs can approach him now." |
| | lastYear with `approachableFrom` | "Other clubs can approach him from Wed 30 Dec." (`shortDay`) |
| | lastYear without | nil |
| | noContract | "He has no contract and can leave at any time." |
| `wageGuideLines` line 1 | `.range`, set by the tier | "Your second eleven are paid $2,786 to $3,905 a month (this tool's estimate of a reasonable range)." |
| | `.range`, low equal to high | "Your second eleven are all paid $3,269 a month (this tool's estimate of a reasonable wage)." |
| | `.range`, set by the ceiling | "A reasonable range is $2,786 to $3,400 a month: from what your second eleven are paid up to a backup's share of your wage budget (this tool's estimate)." |
| | `.range`, set by the highest wage | "… up to the most you can offer one player (this tool's estimate)." |
| | `.upTo` with `paid`, ceiling | "Up to $1,870 a month: a backup's share of your wage budget is below what your second eleven are paid, $2,786 to $3,905 a month (this tool's estimate)." |
| | `.upTo` with `paid`, highest wage | "Up to $1,500 a month: the most you can offer one player is below what your second eleven are paid, $2,786 to $3,905 a month." |
| | `.upTo` without `paid` | "Up to $1,870 a month, a backup's share of your wage budget; too few of your second eleven are paid a wage to read a range from them (this tool's estimate)." |
| | `.none` | "No range can be given: too few of your second eleven are paid a wage to read one from. Enter your wage budget for a ceiling." |
| line 2, with a ceiling | first eleven | "By one rule of thumb a key player's share of your wage budget is $5,200 a month, kept for four players, and a starter's is $2,980 a month (this tool's estimate)." |
| | the others | "By one rule of thumb a backup's share of your wage budget is $1,870 a month (this tool's estimate)." |
| line 3, limits | both | "The most you can offer one player is $6,500 a month, and $2,140 a month of your wage budget is left." |
| | highest wage only | "The most you can offer one player is $6,500 a month." |
| | budget left only | "$2,140 a month of your wage budget is left." |
| | with `countsHisWageBack` | the budget clause ends "is left, counting his present wage back." |
| `wageVerdictLine` | `S` is "The agent's figure" or "His wage now" | |
| | overHighestWage | "S is above the most you can offer one player, $6,500 a month." |
| | overCeiling | "S is above a backup's share of your wage budget, $1,870 a month (this tool's estimate)." ("a key player's share" for the first eleven) |
| | aboveTier | "S is above anything your second eleven is paid; the highest is $3,905 a month." |
| | withinTier / underTier | "S is within what your second eleven are paid." / "S is under what most of your second eleven are paid." |
| | overBudgetLeft | "S is $860 a month more than your wage budget has left; money or wages would have to move." |
| | timesPresentWage | "S is 2.4 times his wage now." (one decimal) |
| `candidateWageLead` | by level | "For wages he is set beside your first eleven: he would start at right back." / "… your second eleven: he would make the second eleven at striker." / "… your players in neither eleven: he would count as cover at striker." / "…: he would be below cover at striker." |
| `candidatePresentWage` | paid / unpaid | "He is paid $5,536 a month now." / "He is paid no wage now." |
| `candidateAskNotKnown` | | "What he would ask of you is not known; check the agent's figure before you bid." |
| `candidateWageOtherCurrency` | | "His wage is in another currency than your squads', so it cannot be compared with them." |
| `leftOutAsGoingLine` | 1 / more | "1 other player in his last year is marked or advised to go." / "3 other players in their last year are marked or advised to go." |
| `notRenewingLine` | 1 / more | "1 player you are not renewing" / "3 players you are not renewing" |
| `wageEvidenceSentence` | | "A wage range is what your own players are paid now, not what a player will ask: no test in any version says what a player asks (this tool's estimate)." |
| `contractsEvidenceNote` | four lines, numbers from the rules | `wageEvidenceSentence`; "The shares of the wage budget are one author's rule of thumb for FM23: 7.5% for each of four key players, 4.3% for a starter and 2.7% for a backup."; "The most you can offer one player and the budget left are FMRTE's own figures for your club."; "Other clubs can approach a player in his last 6 months; that is the game's rule (carried over from FM26)." |

`wageGuideLines` returns line 1, then line 2 when there is a ceiling, then line 3 when either limit is known.

- [x] **Step 1: Write the failing tests**: one `#expect` per row of the table, with the sentence as written
  there and a `MoneyStyle(symbol: "$", period: .monthly)`; plus Review Focus 1 (`leavesHimOut` gives "The rest
  of your first eleven are paid …" and, in a verdict, "… above anything the rest of your first eleven is
  paid"), Review Focus 2 (the "are all paid" row), and that a guide with no limits and no ceiling gives
  exactly one line.
- [x] **Step 2: Run** `swift test --filter AdvisorTextContractsTests`. Expected: fails to build.
- [x] **Step 3: Implement.** Every `switch` exhaustive, no `default`.
- [x] **Step 4: Run** the filter. Expected: pass.
- [x] **Step 5: Commit.** "Word the contracts list and the wage range in the engine".

---

### Task 5: What the app keeps

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/ContractsState.swift`,
  `LineupApp/Sources/LineupAppCore/AppModel+Contracts.swift`
- Modify: `LineupApp/Sources/LineupAppCore/Store.swift` (`StoreFile.contracts`, "your contract figures",
  "nothing is entered"), `AppModel.swift` (load, save, notice, as `scouting` is), `AppModel+Squad.swift`
  (call the drop beside `dropSpentMarks(imported:)`)
- Test: `LineupApp/Tests/LineupAppCoreTests/ContractsStateTests.swift`

**Interfaces:**
- Consumes: `WageLimits`, `Contracts.part(of:today:parameters:)`, `TypedNumber.value`, `WagePeriod.perWeek`,
  `squad.book.moneyStyle`, `today()`.
- Produces:

```swift
public struct AgentFigure: Equatable, Codable, Sendable { public var perWeek: Double; public var entered: Day }
public struct ContractsState: Equatable, Codable, Sendable {
    public var limits: WageLimits = .none
    public var limitsEntered: Day?
    public var dismissed: [PlayerID: Day] = [:]
    public var figures: [PlayerID: AgentFigure] = [:]
    public init() {}
}
public enum WageLimitField: CaseIterable, Sendable { case wageBudget, wagesSpent, highestWage }

extension AppModel {
    public internal(set) var contracts: ContractsState                      // stored on AppModel
    public static let contractsActionInterval: TimeInterval = 0.5
    public func setWageLimit(_ field: WageLimitField, text: String)
    public func setAgentFigure(text: String, for player: PlayerID)
    public func dismissContract(_ player: PlayerID)
    public func showContractAgain(_ player: PlayerID)
    func dropSpentContractEntries(imported target: Squad?)
}
```

**The rules** (spec sections 3, 4 and 8):

- A typed amount is `TypedNumber.value(text)` in FMRTE's wage period, kept by the week; blank clears it; 0 is a
  value. `limitsEntered` is today in the game whenever a limit changes, and nil once all three are blank.
- `setAgentFigure` does nothing for a player in no squad held. A blank text removes his entry.
- `dismissContract` and `showContractAgain` are ignored within `contractsActionInterval` of the end of the
  last of either (one clock, apart from Scouting's and Training's, read as `scoutingAction` reads its own).
  Dismissing a player already dismissed, or showing one who is not, does nothing.
- Every action saves `contracts.json` and nothing else, and none plans or clears the kept advice.
- `dropSpentContractEntries`: for each key in `dismissed` or `figures`, drop both entries when the player is
  held and `Contracts.part` is nil for him (he was renewed), or when every squad held has been imported
  without him (the bookkeeping `dropSpentMarks` uses for marks, with a set of its own). Saves only when
  something was dropped. A player with no contract stays.
- The file: versioned JSON through `Store`; absent is no notice; unreadable gives a notice and a fresh start
  and is kept aside; a file with keys missing reads as the defaults.

- [x] **Step 1: Write the failing tests** (the model from the sample data in a temporary directory, as
  `ScoutingHiddenTests` builds it):

```swift
// setWageLimit(.wageBudget, "16000") under a monthly style keeps WagePeriod.monthly.perWeek(16_000) and limitsEntered == today
// switching the squads' style to weekly afterwards leaves the kept per-week figure unchanged
// setWageLimit(.wageBudget, "") after the only figure clears it and limitsEntered
// "12abc34" reads as 1234; "0" keeps 0, not nil
// setAgentFigure("900", for: held) keeps it with today's day; for a key nobody holds: state unchanged, nothing saved
// dismiss then show again within 0.5 s of the fake clock: the second is ignored; after 0.6 s it is taken
// each action writes contracts.json and no other file (compare the directory's other files' dates or contents)
// no action replans: planState and the kept advice are the same objects as before
// an import in which a dismissed player's end day is now 3 years off drops his dismissal and his figure
// an import of the first team without a dismissed first-team player drops him only when every held squad
//   has since been imported without him
// a dismissed player with no contract survives an import
// state saved without the file opens with no notice and ContractsState(); a corrupt file gives a notice and is kept aside
```

- [x] **Step 2: Run** `tools/test_app.sh --filter ContractsStateTests`. Expected: fails to build.
- [x] **Step 3: Implement.**
- [x] **Step 4: Run** the filter, then `--filter StoreTests`. Expected: pass.
- [x] **Step 5: Commit.** "Keep the club's wage figures, the agents' figures and the players not being renewed".

---

### Task 6: The Contracts rows and the count

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/ContractsPresentation.swift`
- Modify: `LineupApp/Sources/LineupAppCore/Screen.swift` (`.contracts` after `.removal`, title and pill title
  "Contracts"; Task 1's `rowScreens` test gains it), `AppModel+Contracts.swift`, `Navigation.swift`
  (`contractsDismissedOpen = false`, in memory only), `SampleData.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/ContractsPresentationTests.swift`

**Interfaces:**
- Consumes: Tasks 2 to 5; `adviceState` (`.ready(AdvisorsReport)` gives `removal` and `elevens` for the primary
  tactic), `PlayerFacts`, the squad book's players in its order, `marks`.
- Produces:

```swift
public struct WageLimitRow: Equatable, Sendable {
    public var field: WageLimitField
    public var label: String        // "Wage budget, a month", "Wages spent, a month", "Highest wage you can offer, a month"
    public var text: String         // the digits as kept, in FMRTE's period
    public var reading: String?     // "$16,000 a month"
}
public struct ContractRow: Equatable, Identifiable, Sendable {
    public let id: PlayerID
    public let name: String
    public let detailsText: String      // "Age 27 · D L · CA 92 · PA 120 · $68,820 a year · contract ends 30 Jun 2027"
    public let standingLine: String
    public let timingLine: String?
    public let guideLines: [String]
    public let figureLabel: String      // "The agent's figure, a month"
    public let figureText: String
    public let figureReading: String?
    public let figureEnteredText: String?   // "entered Wed 25 Nov"
    public let verdictLines: [String]
}
public struct ContractsPartRows: Equatable, Sendable { public let heading: String; public let rows: [ContractRow] }
public struct ContractsSheet: Equatable, Sendable {
    public let intro: String
    public let limitRows: [WageLimitRow]
    public let limitsEnteredText: String?
    public let parts: [ContractsPartRows]      // only parts with rows
    public let emptyLine: String?              // the engine's line when no part has a row
    public let leftOutLine: String?            // nil at 0
    public let dismissedLine: String?          // nil with nobody dismissed
    public let dismissed: [ContractRow]
    public let evidenceNote: [String]
}
public enum ContractsSheetState: Equatable, Sendable {
    case notReady(AdviceState)
    case failed([String])
    case ready(ContractsSheet)
}
extension AppModel {
    public var contractsSheet: ContractsSheetState
    public var contractsCount: Int?            // nil while not ready, failed, or 0
    public static func pillTitle(_ screen: Screen, count: Int?) -> String   // "Contracts 3", else the pill title
    public static func pillAccessibilityLabel(_ screen: Screen, count: Int?) -> String  // "Contracts, 3 players"
}
```

**The rules:**

- `contractsSheet` calls `Contracts.report` with the squad book's players in its order, the marks, the ready
  advice's `removal` and `elevens`, the primary tactic, `Set(contracts.dismissed.keys)` and today in the game.
  A thrown error becomes `.failed` with `ErrorDescriptions.describe`. It is worked out when read, not kept.
- Each row's guide is `WageRange.guide` for his tier and slot, `wages` from `WageRange.tierWages(tiers:
  elevens.tiers, …)`, `excluding` him, `presentWagePerWeek` his wage, `limits` the state's. Its verdict lines
  are `wageVerdictLine(_, figure: .agents, …)` over `WageRange.verdict` on his typed figure, empty with none.
- `detailsText` is age, positions and `PlayerFacts`' one line, with "Out on loan at …" last for one who is
  (the loan words come from the engine's standing line, so this is the club's name after a plain label, as
  Scouting's details write "On loan at").
- `dismissed` rows carry their facts and standing only: no guide, figure or verdict lines.
- `contractsCount` is the number of rows in `parts`.
- Sample data: `SampleData.modelWithContracts(repositoryRoot:)`, on the `first-team-with-expiry` capture, today
  set so that at least one player falls in each of the first two parts, with one player made out of contract
  and in the second eleven, one dismissed, the three limits typed (wage budget 130,000, wages spent 118,000,
  highest wage 9,000, in the capture's dollars a month; its 27 full-time players are paid $1,912 to $8,724) and one agent's figure typed above the highest wage.
  `modelWithContractsNoFigures` is the same with nothing typed.

- [x] **Step 1: Write the failing tests:**

```swift
// the sample: parts' headings in the engine's order and words; every row's player is in his last year or has no contract
// a row's guideLines equal AdvisorText.wageGuideLines of the guide worked out by hand for his tier
// the row with the typed figure above 9,000: verdictLines[0] is the engine's overHighestWage sentence
// the dismissed player is in `dismissed`, not in parts; dismissedLine == "1 player you are not renewing"
// contractsCount == the rows in parts; marking one of them to sell lowers it by 1 and leftOutLine counts him
// nobody in a part: parts is empty, emptyLine is the engine's, contractsCount == nil
// no squad, no tactic, a failing advice: contractsSheet is .notReady / .failed and contractsCount == nil   (Review Focus 5)
// pillTitle(.contracts, count: 3) == "Contracts 3"; pillTitle(.contracts, count: nil) == "Contracts"; pillTitle(.squad, count: 3) == "Squad"
// limitRows' labels follow the squads' period ("a week" under weekly); the reading is Display.wage of the kept figure
// moving today in the game one year on moves a player with an end day into the list without an import
```

- [x] **Step 2: Run** `tools/test_app.sh --filter ContractsPresentationTests`. Expected: fails to build.
- [x] **Step 3: Implement.** Add `.contracts` to every exhaustive `switch` over `Screen`; in `RootView` it may
  show an empty view until Task 7. The sheet and the count are worked out on every read, and the top row reads
  the count: time `contractsSheet` on the sample in the optimized test build, and if it takes more than about
  5 milliseconds keep it in `adviceCache` and clear it when `contracts`, the marks or today change.
- [x] **Step 4: Run** `tools/test_app.sh`. Expected: all pass.
- [x] **Step 5: Commit.** "Build the Contracts screen's rows and the count for its pill".

---

### Task 7: The Contracts screen and the count on the pill

**Files:**
- Create: `LineupApp/Sources/LineupAppUI/Advice/ContractsScreen.swift`
- Modify: `LineupApp/Sources/LineupAppUI/RootView.swift`, `Board/BoardFrame.swift` (the pill's title and label
  from `AppModel.pillTitle` and `pillAccessibilityLabel`, the count from `model.contractsCount`),
  `Theme.swift` (only for a new measure), `LineupApp/Sources/LineupApp/main.swift` (`drawContracts`)

**Interfaces:**
- Consumes: Task 6's `ContractsSheetState`, rows and actions; `AdviceGate` (as `RemovalScreen` uses it);
  the field with a reading beside it that `OfferPlayerBlock` uses for "His value".

**The layout**, top to bottom, in a lazy stack (spec sections 2 to 4):

1. The heading "Contracts" and the intro.
2. The three limit fields in a row that wraps, each sending every keystroke to `setWageLimit`, its reading
   beside it in muted ink; `limitsEnteredText` under them.
3. Each part: its heading, then its rows. A row: the name with "Not renewing" at the trailing end of the
   name's line, outside any button that covers the row; `detailsText` in muted ink; the standing line; the
   timing line (caution style in the approachable part); the guide lines; the figure field with its reading
   and day; the verdict lines, the first in the caution style when it is the over-the-highest-wage line.
4. `emptyLine` in place of the parts when there are none.
5. `leftOutLine` with a button to Player Removal.
6. `dismissedLine` as a line that opens and closes (`navigation.contractsDismissedOpen`), then the dismissed
   rows, each with "Show again".
7. The evidence note.

- [x] **Step 1: Build the view** and wire `RootView`. `cd LineupApp && swift build`. Expected: no warnings.
- [x] **Step 2: Draw the pill's count.** The pill's text is `AppModel.pillTitle(screen, count:)` for
  `.contracts` and the plain pill title for the rest; the count is part of the text, in the same face.
- [x] **Step 3: Add `drawContracts`** to `main.swift`, writing: `contracts-*` (the sample), `contracts-nofigures-*`,
  `contracts-empty-*` (the plain sample with today such that nobody is listed), `contracts-dismissed-open-*`,
  `contracts-notready-*`, `contracts-small-*` (the smallest window) and `contracts-tall-*` (tall enough for
  every part).
- [x] **Step 4: Run the picture command and look at every `contracts-*` picture**, light and dark, and at the
  top row in each. Check: the count is on the pill and absent on `contracts-empty-*`; nothing is clipped at
  the smallest window; no line reads as a forecast; no id or slot code shows.
- [x] **Step 5: Run** `tools/test_app.sh`. Expected: all pass.
- [x] **Step 6: Commit.** "Show the Contracts screen and its count on the top row".

---

### Task 8: The wage line on Scouting's candidates

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/WageRange.swift`,
  `LineupApp/Sources/LineupAppCore/ScoutingPresentation.swift`, `AppModel+Scouting.swift`,
  `LineupApp/Sources/LineupAppUI/Advice/ScoutingCandidatesTab.swift`, `main.swift` (`drawScouting`),
  `SampleData.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/WageRangeTests.swift`,
  `LineupApp/Tests/LineupAppCoreTests/ScoutingWageTests.swift`

**Interfaces:**
- Consumes: `Candidate` (`player`, `slots`), Tasks 2 and 4, `elevens(for:)` for the tactic shown,
  `ScoutingPaste.money`, `contracts.limits`.
- Produces:

```swift
extension WageRange {
    /// His best level at any slot he is judged at and the guide for its tier; nil when he can play no slot.
    public static func candidateGuide(_ candidate: Candidate, wages: [WageTier: [PlayerWage]], limits: WageLimits,
                                      parameters: EngineParameters) throws
        -> (level: CandidateLevel, slot: SlotID, guide: WageGuide)?
}
// ScoutingCandidateRow gains:
public let wageLines: [String]      // in the opened row; empty when he can play no slot or the elevens are not ready
public let wageCaution: String?     // on the closed row
```

**The rules** (spec sections 5 and 6):

- `candidateGuide`: `bestLevel` over his slots with `marginOverFirst`; `excluding` nil, `presentWagePerWeek`
  nil (nothing is added back for a signing).
- `wageLines`, in order: `candidateWageLead`; `wageGuideLines`; then, when the paste's currency symbol is the
  squads', `candidatePresentWage` and, for a wage above 0, a `wageVerdictLine(_, figure: .presentWage, …)` for
  each verdict; when the symbols differ, `candidateWageOtherCurrency` in place of those; last
  `candidateAskNotKnown`. A candidate's wage is already kept by the week, so a paste in another period needs
  no conversion.
- `wageCaution` is the sentence of `WageRange.caution(in:)` on those verdicts; nil when the currencies differ
  or he is paid nothing.
- The tier's wages are `tierWages` of the whole squad's elevens for the tactic shown (`elevens(for:)`), not
  Scouting's staying squad. While those are not ready, both are empty.
- The Candidates tab's evidence note gains `AdvisorText.wageEvidenceSentence` as its last line.
- A hidden candidate has neither. No level, part, order or caution of a candidate changes.
- View: `wageCaution` after the cautions line on the closed row, in the caution style; `wageLines` after the
  other slots in the opened row, under the plain label "Wage".
- Sample data: one of the sample candidates is given a wage above the top of his tier, so the caution shows.

- [x] **Step 1: Write the failing tests:**

```swift
// engine: a candidate headlined as cover at one slot who would start at another gets tier .firstEleven and that slot
// engine: a candidate with no slot gives nil
// Core, on the sample paste with the limits typed:
//   the opened row's wageLines start with the engine's lead and end with candidateAskNotKnown
//   the candidate paid above his tier's highest has wageCaution == the engine's aboveTier sentence with "His wage now"
//   a candidate paid within the range has wageCaution == nil and a "within" line among wageLines
//   a candidate paid nothing: wageLines hold candidatePresentWage's "no wage" line and no verdict
//   the paste re-read with "€" amounts: candidateWageOtherCurrency, wageCaution == nil
//   a budget left of 0 puts no caution on any closed row
//   the candidates' parts, groups and order are identical with and without limits typed
//   with the advice not ready, the sheet is as before and no row has wage lines        (Review Focus 5)
//   typing a limit changes the rows the next time they are read, with no paste and no replan
```

- [x] **Step 2: Run** both filters. Expected: fail to build.
- [x] **Step 3: Implement** the engine function, the row's two fields, the view's two places.
- [x] **Step 4: Run** `cd LineupEngine && swift test --filter WageRange` and `tools/test_app.sh --filter
  Scouting`. Expected: pass, the existing Scouting suites unchanged.
- [x] **Step 5: Draw** `scouting-candidates-*`, `scouting-candidates-open-*` and `scouting-candidates-small-*`
  into `.build/pictures-contracts` and look at them: the caution on one closed row only, the "Wage" lines in
  the opened row, the evidence note's new last line.
- [x] **Step 6: Commit.** "Set a pasted player's wage beside what his tier is paid here".

---

### Task 9: Current ability on the Elevens tables

Added at the owner's request of 25 November 2026, after the design was approved: "add CA to the First XI and
Second XI tables on the Elevens screen". It changes no advice.

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/ElevensPresentation.swift` (`ElevenRow`, `elevenColumns`, where the
  rows are built), `LineupApp/Sources/LineupAppUI/Advice/ElevensScreen.swift` (the headings and the row),
  `LineupApp/Sources/LineupAppUI/Theme.swift` (`Theme.Elevens.abilityColumn`)
- Test: `LineupApp/Tests/LineupAppCoreTests/ElevensPresentationTests.swift`

**Interfaces:**
- Produces: `ElevenRow.abilityText: String?` — his current ability as a whole number ("92"), from the squad
  book's player with the row's key; nil for an unfilled slot. `ElevensPresentation.elevenColumns` gains "CA"
  between the player's column and the rating's, the name Player Removal's table uses.

- [x] **Step 1: Write the failing tests:**

```swift
// every filled row of the sample's first and second eleven has abilityText == String(his currentAbility)
// an unfilled slot's row has abilityText == nil
// elevenColumns == [<the first heading as it is>, "CA", <the rating heading>, <the familiarity heading>]
// spokenText reads "left back, Evan Humphries, CA 92, 124.4": the ability after the name, said with its label
```

- [x] **Step 2: Run** `tools/test_app.sh --filter ElevensPresentationTests`. Expected: fails to build.
- [x] **Step 3: Implement** in Core, then draw the column in `ElevensScreen` between the name and the rating,
  in the body face like the other numbers, its width from `Theme.Elevens.abilityColumn`. The Depth view is
  left as it is.
- [x] **Step 4: Run** the filter. Expected: pass.
- [x] **Step 5: Draw** `elevens-*` into `.build/pictures-contracts` and look at the First XI and Second XI
  pictures, light and dark and at the smallest window: the column lines up under its heading and no name is
  cut short that was whole before.
- [x] **Step 6: Commit.** "Show current ability on the First XI and Second XI tables", with the owner's request.

---

### Task 10: Close out

**Files:**
- Modify: `CLAUDE.md`, this plan (closing sections), the spec (mark anything revised during the build)

- [x] **Step 1: Run** `cd LineupEngine && swift test` and `tools/test_app.sh`. Expected: every test passes
  with no warnings. Record the counts and times.
- [x] **Step 2: Run** `cd LineupApp && swift test` in the background (it takes eight to twelve minutes).
  Expected: every test passes.
- [x] **Step 3: Run the engine on the capture** to see what the list and the ranges say on the owner's real
  squad of 23 November: a scratch test or a few lines in a test marked for the purpose that print
  `Contracts.report` and each listed player's guide lines for `first-team-with-expiry`. Read the output for
  sense: who is listed, whether any range is "too few", whether the first eleven's range is below the
  second's. Record what it showed.
- [x] **Step 4: Write the plan's closing sections**: what the list and ranges showed on the capture, what
  changed during the build, the limits left (the spec's section 10 as it stands), and the small faults left.
- [x] **Step 5: Update `CLAUDE.md`**: an entry for this plan in the list at the top, `Advisors` and
  `LineupApp` notes for Contracts and the wage range in the style of the others, the nav row's new shape, the
  test counts, and the pictures checked in `.build/pictures-contracts`. Say that the install, the three
  figures typed against FMRTE, whether FMRTE shows them in its wage period, and the look of the menu and the
  buttons in a live window are left to the owner.
- [x] **Step 6: Commit.** "Record the Contracts screen, the wage range and the More menu".

## Calls this plan makes beyond the design

Each is the tool's and the owner's to change.

1. With an end day, a contract is judged by the day even when FMRTE's months left read 0; without one, 0
   months is the last year, not "no contract" (Player Removal still reads 0 months as no contract).
2. A player with neither an end day nor months left is not listed.
3. A player out on loan who cannot be rated stops the Contracts list with the engine's sentence, as any
   missing value does.
4. For one of the owner's players the range says "the rest of your first eleven", since his own wage is left
   out.
5. A tier in which everyone is paid the same reads "are all paid".
6. The count is written in the pill's text ("Contracts 3").
7. The command line prints no Contracts part.
8. An agent's figure is typed in FMRTE's wage period, like every wage in the app.

---

## What the list and the ranges showed on the capture

A scratch test, run and then removed, printed `Contracts.report` and each listed player's
`AdvisorText.wageGuideLines` for the capture `first-team-with-expiry` (30 players, dollars a month) with the sample
4-2-3-1, the club as Oxford City, Player Removal worked out on it with no history, nobody marked and nobody dismissed;
with no wage figures typed, then with a wage budget of $130,000 a month and nothing else. Four days were read.

- **The tiers' wages.** First eleven, 10 wages, $2,786 (Jack Thompson, the goalkeeper) to $5,735 (Caelan Avenell).
  Second eleven, 10 wages, $1,912 (Mark Tomlinson, 17) to $7,483 (Iestyn Hughes, second choice at right back and the
  best-paid player in the squad). Neither eleven, 3 wages: Rafiq Khaleel $3,269, Desmond Charles $3,741 and Ayman
  Benarous $6,236, of whom Player Removal advises Khaleel and Benarous to leave.
- **23 November 2026, the day the paste was taken: nobody is listed** ("Nobody you are keeping is in the last year of
  his contract."). Every contract ends on 30 June 2028 or later. That day is the real one, not the game's: the
  paste's months left (4 to 30 June 2028, 16 to 2029, 28 to 2030) put the game's date in February 2028.
- **15 February 2028, about the game's date: seven listed**, all under "Other clubs can approach them now": Christian
  N'Guessan, Ciaran O'Connor, Evan Humphries, Ewan Clark (out on loan at Hemel Hempstead, would make the second
  eleven at left attacking midfield), Iestyn Hughes, Ruban Khan (out on loan at Tamworth, below cover at left
  defensive midfield) and Zack Clarke; "2 other players in their last year are marked or advised to go." (Benarous
  and Khaleel). So on the owner's own date the pill would read "Contracts 7".
- **1 July 2027**: the same seven, under "In their last year", each "Other clubs can approach him from Thu 30 Dec."
- **30 June 2028**: eighteen: the seven, now approachable on the day their contracts end, and eleven whose contracts end
  on 30 June 2029 (Darnell Johnson, out on loan at Merthyr; Deago Nelson, Dejan Tetek, Jack Thompson, Josh Lewis, Kai
  Payne, Kieran Petrie, Laolu Omobolaji, Mark Tomlinson, Sammy Henia-Kamau, Samuel Onyekachukwu), each "Other clubs
  can approach him from Sat 30 Dec."
- **No range read "too few".** Each listed player's tier had at least 3 other wages. The neither tier has exactly 3,
  so a player of the club's own in neither eleven would have 2 left once his own is taken out, and no range; none was
  listed. Ruban Khan, out on loan, is in no tier's wages and is priced from all three: "Your players in neither eleven
  are paid $3,269 to $6,236 a month", a range read from two players the tool advises to move on (the design's call
  12: the wages are the whole squad's, whoever is going).
- **The first eleven's range is not below the second's at the top.** The second eleven's lower quartile ($2,661 with
  the player himself out, $2,786 for a player out on loan) is below the first's ($3,296, or $3,614 for a first-choice
  player in its lower half), but its top, Iestyn Hughes's $7,483, is above anything the first eleven is paid, and the
  neither tier's top, Benarous's $6,236, is too. So with no budget typed, every listed second-eleven player but Hughes
  is shown a range up to $7,483 a month, more than the first eleven's best-paid player. Hughes himself, his own wage
  out, is shown $2,661 to $5,653.
- **With a wage budget of $130,000 a month** a key player's share is $9,750 and a starter's $5,590 (line 2 on every
  first-eleven row), both above the first eleven's top, so its range is unchanged. A backup's share, $3,510, caps
  every second-eleven and neither range: "A reasonable range is $2,661 to $3,510 a month: from what the rest of your
  second eleven are paid up to a backup's share of your wage budget (this tool's estimate)." That puts Hughes's
  reasonable range at under half his present wage, a second-eleven range whose top is only a little above the first
  eleven's lower quartile, and Ruban Khan at $3,269 to $3,510. The starter's share is below what N'Guessan ($5,653)
  and Avenell ($5,735) are paid now. The $130,000 is the sample's figure, not the owner's budget, which is not known.
- **Reads oddly, beyond the above.** Mark Tomlinson, 17 and second choice at right centre-back on $1,912, is shown
  $3,028 to $7,483: his own wage is the lowest in the tier, so the whole range is above it. The months left beside each
  player stay as pasted (4 and 16) whatever the date, since the list reads the end day; Player Removal still reads the
  months.

## What the count on the pill costs

The top row reads `contractsCount` on every screen, so the advice is worked out after any change that clears it
wherever the owner is. Measured in a scratch test, run in the optimized test build (`tools/test_app.sh`) and removed,
ten runs each, setting and clearing a mark to sell on one listed player:

| | `modelWithContracts` | the standard sample ("Contracts 22") |
|---|---|---|
| the change itself (`setMark`, which plans again) | 0.6 ms | 44 ms |
| the first read of `contractsCount` after it | 6.4 ms | 5.6 ms |
| of which the advice alone (`adviceState` after a replan) | 5.9 ms | 5.1 ms |
| a second read with nothing changed | 0.62 ms | 0.38 ms |

So the count costs about 6 ms once after each change, nearly all of it the advice, which an advisor screen or Fixtures
would have worked out anyway, and about half a millisecond on each later drawing of the top row, since the sheet is
built again on every read and not kept. Nobody would notice either beside a plan. The release app was not built or
installed for this (`tools/build_app.sh` replaces the owner's app), so the time in it is not measured.

## The test runs at close-out

On 26 November 2026, with no build warnings: `cd LineupEngine && swift test`, 1,785 tests in 69 suites in 59 seconds;
`tools/test_app.sh`, 1,152 tests in 67 suites in 48 seconds; `cd LineupApp && swift test`, unoptimized, the same
1,152 in 524 seconds.

## What changed during the build

- **The More pill's pictures are `rest-more-*` and `rest-more-small-*`**, not `more-rest-*`: the picture run names
  files by screen, then variant. `ScreenPill` and `MorePill` share one `PillLabel`; `Theme.Pill.chevronGap` was added.
  At the default window the row is one line; at the smallest it wraps to two rows and fits.
- **The range's arithmetic.** A budget share is rounded to a millionth (`WageRange.share(of:_:)`), so 20,000 × 0.043
  is 860 and not 859.999…, which the plan's exact figures needed. With `fewestWages` at 1 and one wage, the lower
  half is empty: the lower quartile is that wage (found by Task 2's review; it crashed). `WageRangeRules` and
  `WageLimits` have public memberwise inits, since Core builds them.
- **Who is listed.** The plan's order example ("30 Apr before 31 May" in one part, today 25 November 2026) was wrong,
  since 31 May 2027 is past the approach line of 25 May 2027; the tests use 31 Mar before 30 Apr, and 31 May before 30
  Jun. `Contracts.report` throws `PlanError.badParameters` while the parameters have problems; `ContractEntry.action`
  is nil also for a player of the club's own whom Player Removal gave no advice; the open second place is read by an
  internal `Scouting.secondPlaceIsOpen(at:in:)`.
- **The sentences.** Wordings for cases the plan's table lacked: an "up to" set by the highest wage with no squad
  range ("Up to X, the most you can offer one player; too few of …"), a first-eleven ceiling with no starter's share
  (the starter's clause left out) and the under-tier verdict with his wage left out ("under what most of the rest of
  your T are paid"). After Task 4's review the neither tier's above-tier verdict says "are paid", and the two ends of a
  range are compared as written, so ends that read alike are written once: "are all paid $3,269 a month" for the
  tier, "A reasonable wage is about …" for a cap, and "are all paid, $3,269 a month" inside an "up to" line.
- **The Contracts state.** A "Not renewing" or "Show again" that changes nothing does not start the half-second clock.
- **The sample** (`SampleData.modelWithContracts`, `modelWithContractsNoFigures`) is the capture with today at 30 June
  2028, the only day that puts players in both of the first two parts with no contract already past its end: Iestyn
  Hughes is made out of contract (Dejan Tetek was tried first, but Player Removal then advises releasing him, so he
  would be left out as going), Dejan Tetek is dismissed, and Evan Humphries's agent asks $9,500 a month. The standard
  sample, the `first-team` capture of 13 November 2026 with months left only, shows "Contracts 22".
- **The rows' cautions.** The plan's interface could not tell the view which lines take the caution style, so
  `ContractRow` gained `timingIsCaution` (the approachable part) and `cautionVerdictLine` (the over-the-highest-wage
  sentence, taken out of `verdictLines` so it is shown once), with tests. `contracts-empty-*` is drawn by setting
  every listed player aside, since no date empties either sample: the standard sample has no end days and the
  contracts sample always lists Iestyn Hughes, who has no contract. The sheet is not kept: it took about 0.5 ms a
  read in Task 6. Offers' `FieldLabel` is shared with the screen, and `Theme.Contracts` takes Offers' measures.
- **Scouting's wage lines.** `candidatesSheet(_:order:for:)` takes the tactic shown, with a default, and the
  candidates' tier wages come in a `CandidateWageBasis` worked out each time the rows are built, so a typed limit
  shows at the next read with no paste or replan. The closed row's caution is a line of its own labelled "Wage" after
  the Cautions line, and is not repeated once the row is opened, where the same sentence is among the wage lines; the
  row's tooltip is now "Show more", since a row can open with wage lines and no other slots. The sample's Owen Pryce
  is paid £1,500 a week against the sample squad's highest of £800. With wage rules that have problems the rows carry
  no wage lines, and the advice reports the problems.
- **CA on the Elevens tables** (Task 9, added at the owner's request when he approved the plan): `Theme.Elevens
  .abilityColumn` is 48 points, and VoiceOver reads "left back, Evan Humphries, CA 92, 124.4". Depth is unchanged.
- Several tasks wrote their tests with or after the code and saw no failing run first (Tasks 1, 2, 4 and 9; Task 6
  put its sources aside to see one).
- The plan's calls beyond the design all stood.

## Limits left

The design's section 10, as built:

- The range is what his club pays now. After a promotion it runs low until wages are renewed or the budget is typed
  again; the ceiling moves with the budget, the squad's range does not.
- A tier has at most eleven wages, fewer once youth contracts and the player himself are left out; on the capture the
  neither tier has three, so a player of the club's own in it would get no range.
- Whether FMRTE shows the club's wage figures in the period of its wage setting is not known (the same doubt as on
  Offers).
- Whether the wage budget also covers youth and non-playing staff is not known, so the shares may be generous. On the
  capture with the sample's budget the backup's share is the tighter worry: it caps the second eleven well below what
  some of it is paid.
- Without the expiry-date column the last year is counted from months left at the import, rounded down by FMRTE.
- A player out on loan is listed without Player Removal's judgement of him.
- The count on the pill reads the advice, so the advice is worked out whenever the top row is drawn after a change;
  measured above at about 6 ms once after a change in the optimized test build, not in the release app.

Also left:

- The tier's wages come from whoever is in it, those advised to leave included, so a range can rest on players the
  tool says to move on (Ruban Khan's, above), and one well-paid second choice lifts the second eleven's top above the
  first's.
- The open menu, its arrow keys, and the look of "Not renewing", "Show again", "Go to Player Removal" and the fields
  in a live window are not checked: the pictures draw an inactive window. The Elevens tables at the narrow and
  smallest windows show only the pitch in a picture.

## Small faults left

Found by the task reviews and deferred; the whole-branch review that follows decides them.

- The More pill has an empty VoiceOver value while a row screen is shown. The comment on `Screen` still says the top
  row lists the screens in their order.
- `WageRange.share(of:_:)` rounds to a millionth, beyond the plan.
- `ContractsReport.basis` takes in the advice of players the gate or the going check then leaves out. No test pins a
  player gated out who is also marked (not counted as going), nor a player out on loan with no contract being gated.
- Retyping an unchanged wage limit on a later day leaves `limitsEntered` at the old day, while an agent's figure
  retyped takes the new day. An action that changes nothing does not start the clock, where Scouting's may. No test
  drops entries with `imported: nil`, or clears `contractsAbsentFrom` for a player who comes back.
- A test hard-codes 130_000 × 0.027 in place of reading the rules. A listed player missing from the book would get an
  empty details line (`?? ""`, a silent default; it cannot happen today). Ready advice with no primary tactic gives
  `.notReady(.ready(…))`, probably unreachable. `contractsCount` builds the sheet again, so the screen and the pill
  each build it. `ContractsSheetState.failed` has no test and no data reaches it today.
- The dismissed rows are indented with `Theme.Scouting.disclosureColumn`, not a Contracts measure of their own. A
  "Not renewing" heading stands over "1 player you are not renewing". The parts are listed by heading, and putting
  `.overHighestWage` first relies on the engine's order without a comment saying so.
- "Out on loan at …" is said twice, once at the end of the details line and again at the start of the engine's
  standing line; the controller's ruling is to drop it from the details line.
- On Scouting, `try?` on `candidateGuide` gives no wage lines when the wage rules have problems, with no test; the
  opened row shows the flagged sentence in plain ink, not the caution style; no test covers `overHighestWage` or
  `overCeiling` on a candidate's wage.
- On Elevens, the `spokenText` test builds its expectation from the row's own fields, the unfilled-slot loop does not
  check its list is not empty, and `elevensAbilities` and `elevensSquads` are near-identical builders.

## Left to the owner

- The install (`tools/build_app.sh`).
- The three club figures typed against FMRTE's club Finances page, and whether FMRTE shows them in its wage period.
- Whether the list and the ranges read right on his own save and date, where the capture suggests seven players and
  ranges that one well-paid second choice stretches.
- The look of the More menu, the count on the pill and the buttons in a live window.
