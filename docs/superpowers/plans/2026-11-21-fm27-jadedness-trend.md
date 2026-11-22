# Jadedness Trend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app keeps each player's jadedness at every import, measures how fast it moves for each start and each day without one, plans with those rates, rests a player before 400 only when a match off saves him a named fixture, and says on the Rest screen what is happening and which lever works.

**Architecture:** The engine gains a reading type, one function that turns readings and confirmed lineups into rates (`FitnessTrend.rates`), a projection that takes a player's measured pair, a new planner adjustment (`RestBeforeLine`) and Rest advice that carries each player's trend. The app keeps the readings in a new file, records one at each import before the awaiting-import mark is cleared, works the rates out each time it plans or advises, and shows the engine's sentences.

**Tech Stack:** Swift 6, macOS 26, Foundation only in `LineupEngine`; SwiftUI and Observation in `LineupApp`; Swift Testing. No new dependency.

**Spec:** `docs/superpowers/specs/2026-11-21-fm27-jadedness-trend-design.md`. Read it with this plan; section numbers below (§1 to §10) are its sections. `CLAUDE.md` at the repository root has the engine's and the app's rules. Research: `docs/Research/fm27-jadedness-and-holidays.md`.

## Global Constraints

- Work on branch `fm27-native`. Commit messages say why and end with `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. No merge, no pull request, no push unless asked.
- The repository is public: no player data or app state outside `LineupEngine/Tests/LineupEngineTests/Fixtures/`. Nothing in a test, a picture run or a sample-data run touches `~/Library/Application Support` or the real clipboard.
- The old Python and Electron code is reference only: not modified.
- Every tunable number is in `EngineParameters` with an evidence label and a source. `EngineParameters` stays under 1 KB (an existing test holds it).
- Every rule has a test where it changes an outcome and one where it does not. The same inputs give the same output whatever order they arrive in.
- Every word the owner reads about advice is the engine's (`AdvisorText`, the reasons on adjustments). Core holds plain labels and headings; views hold layout only, with every colour, typeface and measure from `Theme`.
- A default argument (`rates: nil`, `trends: .none`) means "nothing measured", the state before this plan; it is not a guessed value.
- Test output is clean: no build warnings.
- Engine tests: `cd LineupEngine && swift test` (or `--filter <name>`). App tests: `cd LineupApp && swift test`, which takes 7 to 20 minutes, so run the whole suite in the background; use `--filter` while working.
- Measured figures are written as whole numbers of their size ("about 45"), with the direction in words. Days are written "Sat 14 Nov" by the engine's `AdvisorText.shortDay` (Task 5).

### Exact copy

`400` is `jadedThreshold`, `4` is `fewestOwnIntervals + 1`, `0.5%` is `sharpnessDecayPerDay`, and "this tool's estimate" is `AdvisorText.note(for: .derived)`; none is a literal.

The planner's reason (no full stop, as the saving reason beside it):

- `Rested before he passes 400: at about +31 a start, starting today would leave him jaded for Buxton on Sat 14 Nov`

A listed player's trend lines, in this order:

1. With no trend as seen: `His trend is not measured yet: it needs 4 imports of his squad, and has 2.`
2. Otherwise one of:
   - `Rising about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings).`
   - `Falling about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings).`
   - `Holding steady over the last 5 weeks, in which he started 6 matches (from 6 readings).` (within `steadyPerWeek` either way)
   - with `in which he started 1 match` and `in which he did not start a match`; `over the last week` for 1.
3. `At that rate he passes 400 around Sun 7 Nov.`
4. What a match off would do:
   - `Without a start he falls about 30 a week, and a start adds about 61, so a match off saves about 61.`
   - `He holds steady without a start, and a start adds about 61, so a match off saves about 61.` (a drift below 0 within `steadyPerWeek`, inclusive; added after the whole-branch review)
   - `He rises about 16 a week without a start, so leaving him out of matches will not bring it down. Lighter training, or rest from training, will.`
   - `He holds steady without a start, so leaving him out of matches will not bring it down. Lighter training, or rest from training, will.`
   - followed, after a space, by where a rate is not his own: `(the first team's rate without a start; his own rate for a start)`, `(the first team's rate without a start; the club's rate for a start)`, `(his own rate without a start; the club's rate for a start)`, or, for the two "will not bring it down" forms given without a gain, `(the first team's rate without a start)`. Nothing when every rate named is his own.
5. `He has not started a match for you in that time: the rise is from training and any matches for another side.`

Above the rows:

- `First team: a player who does not start rises about 16 a week (from 38 readings since Tue 24 Aug; this tool's estimate).` (`falls about 14 a week`, `holds steady`; `U21s`, `U18s`)
- under a squad whose drift is 0 or above: `At this training load, leaving players out of matches cannot bring jadedness down.`
- `A start adds about 31 (from 14 readings; this tool's estimate).`
- `Trend measured from Tue 24 Aug.`

At the foot, under the heading `What the game's messages mean`:

- `'Tired after last match' and 'Very tired after last match' describe condition after a match and clear in days. They are not a reason for a holiday. (this tool's reading of the wording)`
- `The game calls a player jaded above 400. No test in any version shows a cost below that; above 0, condition comes back more slowly. (FM27 tests)`
- `A holiday costs about 0.5% of sharpness a day and the matches missed. A full rest day after each match, and lighter training below full condition, cost less. (FM27 tests; the holiday's effect is carried over from FM24)`

Core's plain labels:

- button `Measure again from today`; its question `Measure the trend again from today? Each squad then needs 4 imports from today on before anything is measured.` (corrected after the whole-branch review) with `Measure again` and `Cancel`
- the Saving players explanation: `Higher rests more of your best players before a more important match soon after, and rests them before they are jaded. Off picks each match on its own.`

## Review Focus

Each of these has its test in the task named.

1. **A player moves between squads, or two squads are imported on one day with him in both.** His readings stay one a day, in day order, and all count under the squad he is in now; nothing is counted twice (Tasks 3 and 8).
2. **Readings are kept for a player who has left every squad.** The rates leave him out, his readings enter no squad's or the club's figure, nothing fails, and his readings go after 120 days (Tasks 3 and 8).
3. **A measured gain of 0 or below** (noisy readings make a start look as if it lowers jadedness). No rest-before-the-line cost, and no "a match off saves" sentence (Tasks 5 and 6).
4. **The game's date is moved back, so a reading is dated after the day the rates are asked for, or readings arrive out of day order.** Readings are put in day order; an interval whose later reading is after that day is not used (Task 3).
5. **The summer.** No import for two months, and players back at −500. The long gap and the readings at the floor are not used, the plan goes back to the fixed figures with no notice, and Rest says the trend is not measured and how many imports it has (Tasks 3 and 6).

## Calls this plan makes beyond the design

The design left these to the builder or did not reach them. Each is built as written here, and is the owner's to change.

1. At the first launch with no fitness file, a reading is taken from each squad held, dated its last import (Task 8). The owner's squads then need three more imports, not four.
2. The club's line says what it rests on, as every other trend line does: "A start adds about 31 (from 14 readings; this tool's estimate)." (§6 gave it bare; the design's anti-goals ask for the count.)
3. The planner's reason has no full stop, as the saving reason beside it has none.
4. A drift within 5 a week of nothing is written "holds steady without a start". A measured gain of 0 or below gives no "a match off saves" line and no cost in the plan.
5. "At that rate he passes 400 around …" is given only within 120 days; the 120 is a field of `jadednessTrendRules` (`passDateWithinDays`), beside the 120 days readings are kept.
6. "It needs 4 imports of his squad, and has 2" counts his used intervals plus one, so an import while he was injured or at −500 does not count; with none used, 1 when he has a reading that can still count (on or after the day to measure from, on or before the day asked for, within the window), else 0 (corrected after the whole-branch review).
7. A player needing a holiday keeps his holiday estimate even when his drift is 0 or above.
8. A player's readings all count under the squad he is in now.
9. The Saving players explanation reads "and rests them before they are jaded", to fit its sentence.

---

### Task 1: Parameters, and a projection that takes measured rates

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Planner/JadednessRates.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift` (properties near line 530, the `fm27` set near line 824)
- Modify: `LineupEngine/Sources/LineupEngine/Selection/FitnessModel.swift` (`problems(in:)`)
- Modify: `LineupEngine/Sources/LineupEngine/Planner/FitnessProjection.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/FitnessProjectionTests.swift`, `FitnessModelTests.swift`, `EngineParametersTests.swift`

**Interfaces:**
- Produces, in `JadednessRates.swift`:

```swift
/// Where a measured rate came from.
public enum RateSource: Equatable, Sendable { case own(intervals: Int), squad(Squad), club }
public struct MeasuredRate: Equatable, Sendable {
    public let value: Double
    public let source: RateSource
    public init(_ value: Double, _ source: RateSource)
}
/// A player's measured pair: used together or not at all.
public struct JadednessRates: Equatable, Sendable {
    /// The change for each day without a start; above or below 0.
    public let drift: MeasuredRate
    /// The change for each start.
    public let gain: MeasuredRate
    public init(drift: MeasuredRate, gain: MeasuredRate)
}
public struct JadednessTrendRules: Sendable, Equatable {
    public var windowDays: Int            // 42
    public var longestGapDays: Int        // 14
    public var fewestOwnIntervals: Int    // 3
    public var fewestSharedIntervals: Int // 5
    public var fewestSharedDays: Int      // 3
    public var onCourseDays: Int          // 42
    public var steadyPerWeek: Double      // 5
    public var keptDays: Int              // 120
    public var passDateWithinDays: Int    // 120
}
```

- Produces, in `EngineParameters`: `jadednessTrendRules: Parameter<JadednessTrendRules>` (`.derived`; the source says every number is this design's choice of 21 November 2026 with no test behind it, and names each); `conditionRecoveryByJadedness: Parameter<[CurvePoint]>` with `x` a jadedness: (−500, 1), (0, 1), (500, 0.832), (1000, 0.574) (`.derived`; source: "Fishi, fm-arena, 13 November 2026, in docs/Research/fm27-jadedness-and-holidays.md: from 7,500 over the same rest a player reached 9,574 at −500 and at 0, 9,225 at 500 and 8,690 at 1,000; the anchors are FM27 measured, applying them day by day is this design's"); `jadednessCeiling: Parameter<Double>` 1,000 (`.fm27Observation`, the editor's range).
- Produces, in `FitnessProjection`:

```swift
public static func afterMatch(_ fitness: ProjectedFitness, player: Player, position: Position,
                              rates: JadednessRates? = nil, parameters: EngineParameters) throws -> ProjectedFitness
public static func afterDays(_ days: Int, _ fitness: ProjectedFitness, player: Player, intensity: TrainingIntensity,
                             rates: JadednessRates? = nil, parameters: EngineParameters) throws -> ProjectedFitness
/// Jadedness after a start: his gain with rates, `jadednessPerMatch` without; within the floor and the ceiling.
public static func jadednessAfterMatch(_ jadedness: Double, rates: JadednessRates?, parameters: EngineParameters) -> Double
/// Jadedness after `days` days without a match: his drift each day with rates; without, the fixed fall scaled by
/// training intensity. Within the floor and the ceiling.
public static func jadednessAfterDays(_ days: Int, _ jadedness: Double, intensity: TrainingIntensity,
                                      rates: JadednessRates?, parameters: EngineParameters) -> Double
```

`afterMatch` and `afterDays` call the two jadedness functions. In `afterDays`, each day's condition recovery is also multiplied by `FitnessModel.evaluate(conditionRecoveryByJadedness, at: start.jadedness)`, for every player, rates or not.

- [ ] **Step 1: Write the failing projection tests** in `FitnessProjectionTests.swift`

```swift
let rates = JadednessRates(drift: MeasuredRate(-4, .squad(.firstTeam)), gain: MeasuredRate(31, .own(intervals: 3)))
func rising(_ perDay: Double) -> JadednessRates {
    JadednessRates(drift: MeasuredRate(perDay, .own(intervals: 3)), gain: MeasuredRate(60, .club))
}

@Test func aStartAddsHisMeasuredGainInPlaceOfTheFixedFigure() throws {
    let player = Player.fixture()
    #expect(try FitnessProjection.afterMatch(fitness(1, 1, 100), player: player, position: .striker, rates: rates, parameters: p).jadedness == 131)
    #expect(try FitnessProjection.afterMatch(fitness(1, 1, 100), player: player, position: .striker, parameters: p).jadedness == 160)
}

@Test func aDayAddsHisMeasuredDriftWhicheverWayItPoints() throws {
    let player = Player.fixture()
    func after(_ r: JadednessRates?, _ i: TrainingIntensity) throws -> Double {
        try FitnessProjection.afterDays(3, fitness(1, 1, 100), player: player, intensity: i, rates: r, parameters: p).jadedness
    }
    #expect(try after(rates, .high) == 88)          // −4 a day, whatever the intensity
    #expect(try after(rates, .low) == 88)
    #expect(try after(rising(2.5), .medium) == 107.5)
    #expect(try after(nil, .high) == 52)            // the fixed 20 × 0.8, as before
}

@Test func jadednessStaysBetweenTheFloorAndTheCeiling() throws {
    #expect(FitnessProjection.jadednessAfterDays(2, -495, intensity: .medium, rates: rates, parameters: p) == -500)
    #expect(FitnessProjection.jadednessAfterMatch(980, rates: rising(0), parameters: p) == 1_000)
    #expect(FitnessProjection.jadednessAfterDays(2, 990, intensity: .medium, rates: rising(30), parameters: p) == 1_000)
}

@Test(arguments: [(-500.0, 1.0), (0.0, 1.0), (250.0, 0.916), (500.0, 0.832), (1_000.0, 0.574)])
func conditionComesBackMoreSlowlyAboveJadednessZero(jadedness: Double, factor: Double) throws {
    // Natural Fitness 10 at medium recovers 0.0813 from 80% in a day.
    let after = try rest(1, fitness(0.80, 1, jadedness))
    #expect(abs(after.condition - (0.80 + 0.0813 * factor)) < 1e-9)
}
```

- [ ] **Step 2: Write the failing parameter tests.** In `EngineParametersTests.swift`: `jadednessTrendRules` holds the nine values above and is `.derived`; `conditionRecoveryByJadedness` holds the four points, is `.derived` and its source contains "Fishi"; `jadednessCeiling` is 1,000 and `.fm27Observation`. In `FitnessModelTests.swift`, one test per problem, each expecting a sentence that names the entry, and one test that `.fm27` has none: a count of 0 (`fewestOwnIntervals`, `fewestSharedIntervals`, `fewestSharedDays`), a day count of 0 (`windowDays`, `longestGapDays`, `onCourseDays`, `keptDays`, `passDateWithinDays`), a negative `steadyPerWeek`, a `conditionRecoveryByJadedness` that is empty, that rises with jadedness or that has a factor outside 0 to 1, and a `jadednessCeiling` not above `jadednessFloor`.

- [ ] **Step 3: Run them to see them fail**

Run: `cd LineupEngine && swift test --filter "FitnessProjectionTests|FitnessModelTests|EngineParametersTests"`
Expected: does not compile (`JadednessRates` is not defined).

- [ ] **Step 4: Implement** the types, the three parameters, the checks in `FitnessModel.problems(in:)` and the projection as the Interfaces block says.

- [ ] **Step 5: Run the whole engine suite**

Run: `cd LineupEngine && swift test`
Expected: PASS, except tests that pinned a condition recovered by a player with jadedness above 0. For each of those, check the new figure is the old one times the factor for his jadedness, change the pinned value and say so in the commit message. Any other failure is a fault.

- [ ] **Step 6: Commit** (`Let the fitness projection take a player's measured jadedness rates, and slow condition recovery above jadedness 0 as FM27 measured`)

---

### Task 2: No mark-down between 200 and 400

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift:771-774`
- Test: `LineupEngine/Tests/LineupEngineTests/EngineParametersTests.swift:35-46`, `FitnessModelTests.swift`, `LineupSelectorTests.swift`, `PlannerTests.swift`, `SavingPlayersTests.swift`

**Interfaces:**
- Produces: `jadednessSteps` is `[JadednessStep(upTo: 400, factor: 1.00), JadednessStep(upTo: 700, factor: 0.70)]`, `.derived`, with a source that says: no test in any version shows a cost under 400, and in FM24 a whole eleven held at 400 lost 2.4 points a season (`docs/Research/fm27-jadedness-and-holidays.md`), so ×1.00 up to 400 is this design's call of 21 November 2026; ×0.70 up to 700 is carried over from `scoring_parameters.py` `JADEDNESS_MULTIPLIERS`. `jadednessAbove` and `jadedThreshold` are unchanged.

- [ ] **Step 1: Write the failing tests.** In `FitnessModelTests.swift`:

```swift
@Test func aPlayerAt300IsRatedTheSameAsAt100() {
    let at = { FitnessModel.factors(condition: 1, sharpness: 1, jadedness: $0, parameters: .fm27).jadedness }
    #expect(at(100) == 1 && at(300) == 1 && at(400) == 1)
    #expect(at(401) == 0.70 && at(700) == 0.70 && at(701) == 0.40)
}
```

In `EngineParametersTests.swift`, change `fitnessStepsAndFloorCiteTheFilesTheyCameFrom` so `jadednessSteps` is expected `.derived` with a source containing "fm27-jadedness-and-holidays.md" and "JADEDNESS_MULTIPLIERS"; `jadednessAbove` and `conditionFloor` keep their expectations.

- [ ] **Step 2: Run to see them fail.** `cd LineupEngine && swift test --filter "FitnessModelTests|EngineParametersTests"`. Expected: FAIL (300 gives 0.90).

- [ ] **Step 3: Change the entry.**

- [ ] **Step 4: Run the whole engine suite and repair the tests that pinned ×0.90.** They are at `FitnessModelTests.swift:40`, `LineupSelectorTests.swift:133, 196-208, 820, 916-919`, `PlannerTests.swift:311` and perhaps `SavingPlayersTests.swift:208`. Keep what each test is for: where it needs a jadedness factor under 1 on a player who can still be picked, hand it parameters with a step under 1 below 400 (as `FitnessModelTests.swift:63` builds one), or use a high-importance match with a jadedness of 401 to 700 and ×0.70. Do not delete a test.

Run: `cd LineupEngine && swift test`. Expected: PASS.

- [ ] **Step 5: Commit** (`Rate a player the same up to jadedness 400: the ×0.90 from 200 came from the old app with no source, and no test in any version shows a cost under 400`)

---

### Task 3: Readings, and the rates worked out from them

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Planner/FitnessReading.swift`
- Create: `LineupEngine/Sources/LineupEngine/Planner/FitnessTrend.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/FitnessTrendTests.swift`

**Interfaces:**
- Consumes: `JadednessRates`, `MeasuredRate`, `RateSource`, `JadednessTrendRules` (Task 1); `ConfirmedLineup`, `Day`, `Squad`.
- Produces:

```swift
public struct FitnessReading: Equatable, Codable, Sendable {
    public var day: Day
    public var jadedness: Int
    public var condition: Double
    public var sharpness: Double
    public var isInjured: Bool
    /// The fixtures of the confirmed lineups that awaited his squad's import when this was taken: by raw id, each once.
    public private(set) var includes: [FixtureID]
    public init(day: Day, jadedness: Int, condition: Double, sharpness: Double, isInjured: Bool, includes: [FixtureID])
    public init(day: Day, player: Player, includes: [FixtureID])
    /// This reading in place of `earlier` of the same day: its own figures, and both sets of fixtures.
    public func replacing(_ earlier: FitnessReading) -> FitnessReading
}

/// His jadedness as the readings show it, with no model.
public struct SeenTrend: Equatable, Sendable {
    public let perWeek: Double
    /// The days of the intervals used, their starts, and the readings at their ends, each once.
    public let days: Int, starts: Int, readings: Int
}
public struct PlayerTrend: Equatable, Sendable {
    public let seen: SeenTrend?
    /// The drift and the gain he takes; either may be missing.
    public let drift: MeasuredRate?, gain: MeasuredRate?
    public let usedIntervals: Int
    /// Both rates, or nil.
    public var pair: JadednessRates? { get }
}
/// A squad's drift or the club's gain.
public struct SharedRate: Equatable, Sendable {
    public let value: Double
    /// The readings at the ends of the intervals behind it, each once, and the earliest of their days.
    public let readings: Int
    public let since: Day
}
public struct FitnessTrends: Equatable, Sendable {
    /// Every player in `squads` with at least one reading.
    public let players: [PlayerID: PlayerTrend]
    public let squadDrift: [Squad: SharedRate]
    public let clubGain: SharedRate?
    /// `measureFrom` when it is later than the window's first day; else the earliest reading that is an end of a used
    /// interval, of any player in a squad; else the earliest reading in the window; else nil (corrected after the whole-branch review).
    public let measuredFrom: Day?
    public static let none: FitnessTrends
    public var pairs: [PlayerID: JadednessRates] { get }
}
public enum FitnessTrend {
    public static func rates(readings: [PlayerID: [FitnessReading]], confirmed: [ConfirmedLineup],
                             squads: [PlayerID: Squad], asOf: Day, measureFrom: Day?,
                             parameters: EngineParameters) -> FitnessTrends
}
```

The rules are §2 of the spec, with these settled here:

- A player's readings are put in day order first; two on one day are one, the later in the list replacing the earlier (`replacing`).
- A lineup belongs to the first of a player's readings whose day is after the lineup's date or whose `includes` holds its fixture. A lineup counts as one start for a player however many slots name him; a fixture id confirmed twice counts once.
- An interval is used when: the later reading is on or before `asOf` and no more than `windowDays` before it; both readings are on or after `measureFrom` when it is set; they are 1 to `longestGapDays` days apart; neither is injured; neither jadedness is at or below `jadednessFloor`.
- A player not in `squads` is left out of everything: no entry, and no part in a squad's or the club's figure.
- Medians sort by value, then player key, then the later reading's day; an even count takes the mean of the middle two. Players are walked in key order.

- [ ] **Step 1: Write the failing tests.** Helpers and the two squads every test starts from:

```swift
@Suite struct FitnessTrendTests {
    let p = EngineParameters.fm27
    let start = Day(year: 2026, month: 9, day: 1)!
    func id(_ name: String) -> PlayerID { PlayerID(key: name) }
    func r(_ day: Int, _ jadedness: Int, injured: Bool = false, includes: [String] = []) -> FitnessReading {
        FitnessReading(day: start.adding(days: day), jadedness: jadedness, condition: 0.9, sharpness: 0.9,
                       isInjured: injured, includes: includes.map(FixtureID.init))
    }
    func lineup(_ fixture: String, day: Int, _ starters: String...) -> ConfirmedLineup {
        ConfirmedLineup(fixture: FixtureID(fixture), date: start.adding(days: day),
                        starters: Dictionary(uniqueKeysWithValues: zip(SlotID.allCases, starters.map(id))))
    }
    /// Falls 2 a day with no start: 100, 86, 72, 58 a week apart.
    var resting: [FitnessReading] { [r(0, 100), r(7, 86), r(14, 72), r(21, 58)] }
    /// Rises 17 a week with one start in each: at −2 a day that is 31 a start.
    var starting: [FitnessReading] { [r(0, 100), r(7, 117), r(14, 134), r(21, 151)] }
    func matches(_ names: String...) -> [ConfirmedLineup] {
        [3, 10, 17].map { day in ConfirmedLineup(fixture: FixtureID("m\(day)"), date: start.adding(days: day),
            starters: Dictionary(uniqueKeysWithValues: zip(SlotID.allCases, names.map(id)))) }
    }
    func rates(_ readings: [String: [FitnessReading]], _ confirmed: [ConfirmedLineup] = [],
               squads: [String: Squad]? = nil, asOf: Int = 21, from: Int? = nil) -> FitnessTrends {
        FitnessTrend.rates(
            readings: Dictionary(uniqueKeysWithValues: readings.map { (id($0.key), $0.value) }), confirmed: confirmed,
            squads: Dictionary(uniqueKeysWithValues: (squads ?? readings.mapValues { _ in .firstTeam }).map { (id($0.key), $0.value) }),
            asOf: start.adding(days: asOf), measureFrom: from.map(start.adding(days:)), parameters: p)
    }
}
```

The tests, each with the assertions that pin it:

| Test | Given | Expect |
|---|---|---|
| `aRestingPlayersOwnDriftIsHisMedianRate` | `["a": resting]` | `a.drift == MeasuredRate(-2, .own(intervals: 3))`; `a.seen == SeenTrend(perWeek: -14, days: 21, starts: 0, readings: 4)`; `a.gain == nil`; `a.pair == nil`; `usedIntervals == 3` |
| `twoIntervalsAreNotEnoughForHisOwnRateOrHisTrend` | `["a": Array(resting.prefix(3))]` | `a.drift == nil`, `a.seen == nil`, `usedIntervals == 2` |
| `aSquadsDriftNeedsFiveIntervalsOnThreeDays` | `["a": resting, "b": resting]` | `squadDrift[.firstTeam] == SharedRate(value: -2, readings: 8, since: start)`. With `b` cut to its first two readings (4 intervals): nil. With `a` and `b` each `[r(0,100), r(7,86), r(14,72)]` and `c` `[r(7,86), r(14,72)]` (5 intervals ending on 2 days): nil |
| `aStarterTakesHisSquadsDriftAndHisOwnGain` | `["a": resting, "b": resting, "q": starting]`, `matches("q")` | `q.drift == MeasuredRate(-2, .squad(.firstTeam))`; `q.gain == MeasuredRate(31, .own(intervals: 3))`; `q.pair != nil`; `q.seen == SeenTrend(perWeek: 17, days: 21, starts: 3, readings: 4)`; `clubGain == nil` (3 intervals) |
| `theClubsGainNeedsFiveIntervalsOnThreeDays` | as above plus `"q2": starting`, `matches("q", "q2")` | `clubGain == SharedRate(value: 31, readings: 8, since: start)`. Then add `"y"` with readings `[r(14, 0), r(21, 15)]` and `matches("q", "q2", "y")`: in `.u18` (no drift for the U18s) `y.drift == nil`, `y.gain == MeasuredRate(31, .club)` (he takes the club's gain even with no drift of his own: design §2, "his own, else the club's, else none") and `y.pair == nil` (corrected during the build: the first text expected `y.gain == nil`); in `.firstTeam` `y.drift == MeasuredRate(-2, .squad(.firstTeam))`, `y.gain == MeasuredRate(31, .club)` (the median of six at 31 and his one at 29) and `clubGain?.readings == 10` |
| `aDriftWithNoGainAndAGainWithNoDriftAreNoPair` | `["a": resting]`; and `["q": starting]` with `matches("q")` | `a.pair == nil`; `q.drift == nil`, `q.gain == nil`, `q.pair == nil`, and `pairs.isEmpty` in both |
| `anIntervalIsKeptOrLeftOutByEachRule` | `["x": resting]`, changed as said, reading `x.usedIntervals` | as given: 3. `asOf: 63` (the last reading exactly 42 days back): 1; `asOf: 64`: 0. `from: 7`: 2; `from: 8`: 1. Readings `[r(0,100), r(14,72), r(21,58)]`: 2; `[r(0,100), r(15,70), r(21,58)]`: 1. `r(7, 86, injured: true)` in place of the second: 1. `r(7, -500)` in place of the second: 1. `asOf: 20` (the last reading is after the day asked for): 2 |
| `aMatchOnAnImportDayCountsByWhatTheReadingIncludes` | `a`, `b` `resting`; `q` reads `[r(0,100), r(7,117, includes: ["m7"]), r(14,134), r(21,151)]`; lineups naming `q`: `m7` on day 7, `m10` on day 10, `m17` on day 17 | each interval has one start: `q.gain == MeasuredRate(31, .own(intervals: 3))`, `squadDrift[.firstTeam]?.readings == 8`. With `includes` removed, `m7` belongs to the day-14 reading: `q`'s first interval is a rest interval (`squadDrift[.firstTeam]?.readings == 10`), `q.gain == nil` (two start intervals), and `q.seen?.starts == 3` still |
| `aLineupConfirmedLateCountsByItsDate` | `a`, `b` `resting`, `q` `starting`; `confirmed` first without the day-3 lineup, then with it | first: `q.gain == nil` and `q.seen?.starts == 2`; then: `q.gain == MeasuredRate(31, .own(intervals: 3))` and 3. The readings are the same in both |
| `aLineupChangedAfterAnUnlockCountsAsItNowStands` | `q` `starting`; `matches("q")` against `matches("other")` | with `"other"`, `q.seen?.starts == 0` |
| `aPlayerNamedInTwoSlotsOrAFixtureConfirmedTwiceCountsOnce` | a lineup naming `q` at two slots; the same fixture id twice in `confirmed` | `q.seen?.starts == 3` |
| `theSameReadingsInAnotherOrderGiveTheSameRates` | the five-player set, readings and lineups reversed and shuffled with a fixed seed | `==` the ordered result |
| `aPlayerInNoSquadIsLeftOutOfEverything` (Review Focus 2) | `["a": resting, "b": resting, "gone": resting]`, `squads` without `gone` | `players[id("gone")] == nil`; `squadDrift[.firstTeam]?.readings == 8` |
| `readingsCountUnderTheSquadHeIsInNow` (Review Focus 1) | `a`, `b` in `.u18`; `squads` says `a` is now `.firstTeam` | `squadDrift[.u18] == nil`, `squadDrift[.firstTeam] == nil` (3 each), and `a.drift?.source == .own(intervals: 3)` |
| `readingsOutOfDayOrderAreSorted` (Review Focus 4) | `["a": resting.reversed()]` | `==` the result for `resting` |
| `afterASummerNothingIsMeasured` (Review Focus 5) | `["a": [r(0,100), r(7,86), r(70,-500), r(77,-500), r(84,-480)]]`, `asOf: 84` | `a.usedIntervals == 0`, `a.seen == nil`, `pairs.isEmpty`; `measuredFrom == start.adding(days: 70)` |
| `measuredFromIsTheOwnersDayOrTheEarliestEndOfAUsedInterval` (corrected after the whole-branch review) | `resting`, `asOf: 21`; then `from: 10`; then `asOf: 60` | `start`; `start.adding(days: 10)`; `start.adding(days: 14)` (the used interval ending on day 21, the only reading within 42 days of day 60, runs from day 14) |
| `noReadingsGiveNone` | `[:]` | `== .none` |

- [ ] **Step 2: Run to see them fail.** `cd LineupEngine && swift test --filter FitnessTrendTests`. Expected: does not compile.

- [ ] **Step 3: Implement `FitnessReading` and `FitnessTrend.rates`.** One pass builds every player's used intervals with their starts; then own drifts, squad drifts, the drift each player takes, each start interval's gain, own gains and the club's gain, in that order. `FitnessReading` encodes `includes` as an array of raw ids, sorted.

- [ ] **Step 4: Run.** `cd LineupEngine && swift test --filter FitnessTrendTests`. Expected: PASS. Then `swift test`: PASS.

- [ ] **Step 5: Commit** (`Work out each player's jadedness trend, and his rise for a start and for a day without one, from the readings kept at each import`)

---

### Task 4: The planner plans with the measured rates

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Planner/Planner.swift` (`PlanRequest`, and the projection calls at lines 126-128, 136, 144, 215, 259-318)
- Modify: `LineupEngine/Sources/LineupEngine/Planner/SavingPlayers.swift:29-52`
- Test: `LineupEngine/Tests/LineupEngineTests/PlannerTests.swift`, `SavingPlayersTests.swift`

**Interfaces:**
- Consumes: `JadednessRates`; `FitnessProjection.afterMatch(..., rates:)` and `afterDays(..., rates:)` (Task 1).
- Produces: `PlanRequest.rates: [PlayerID: JadednessRates]`, an `init` argument `rates: [PlayerID: JadednessRates] = [:]` after `advisedToLeave`, documented as "each player's measured pair; a player with none is projected with the fixed figures". `SavingPlayers.adjustment(for:fitness:position:today:later:rates:settings:parameters:)` with `rates: JadednessRates? = nil` after `later`, handed to its three projections. The planner hands `request.rates[player.id]` to every projection: the days between events, a played match, a planned match, the matches before `asOf`, and the saving rule.

- [ ] **Step 1: Write the failing tests.** In `PlannerTests.swift`, with two fixtures 7 days apart and one starter of the first handed `JadednessRates(drift: −2 a day, gain: 31)` (imported jadedness 100):
  - `aStartersJadednessBeforeTheNextFixtureUsesHisMeasuredRates`: `plan.fixtures[1].fitness[him]!.jadedness == 100 + 31 − 14`.
  - `aPlayerWithNoRatesIsProjectedWithTheFixedFigures`: a second starter with no entry has `100 + 60 − 7 × 20 × recoveryScale` for the request's intensity, as the same request gives with `rates: [:]`.
  - `aMatchPlayedBeforeTheImportUsesHisMeasuredRates`: a `played` lineup dated 3 days before `asOf` naming him gives `100 + 31 − 6` before a fixture on `asOf`.

  In `SavingPlayersTests.swift`:
  - `measuredRatesChangeTheCostOfStartingToday`: a player at jadedness 350, a low fixture today and a medium one in 7 days where he is first choice. With `rates` of gain 120 and drift −2 he is above 400 there after starting and not after resting, so the cost is his whole advantage × 1.5 ÷ 0.8; with `rates: nil` the cost is what the existing tests give for the same inputs.

- [ ] **Step 2: Run to see them fail.** `cd LineupEngine && swift test --filter "PlannerTests|SavingPlayersTests"`. Expected: does not compile (`rates`).

- [ ] **Step 3: Implement.** The private `advance`, `afterMatch` and `afterEarlyMatches` in `Planner` take the request's rates and pass each player's own.

- [ ] **Step 4: Run** `cd LineupEngine && swift test`. Expected: PASS, every earlier planner test unchanged.

- [ ] **Step 5: Commit** (`Project each player's jadedness in the plan with his measured rates where he has them`)

---

### Task 5: Resting a player before the line

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Planner/RestBeforeLine.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Selection/Adjustment.swift:10` (add `restedBeforeLine` after `savedForLater`)
- Modify: `LineupEngine/Sources/LineupEngine/Planner/SavingPlayers.swift` (say which fixture it named, and how)
- Modify: `LineupEngine/Sources/LineupEngine/Planner/Planner.swift:177-191`
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+League.swift:65-73` and `AdvisorText.swift` (`shortDay`)
- Test: `LineupEngine/Tests/LineupEngineTests/RestBeforeLineTests.swift` (new), `PlannerScenarioTests.swift`, `LeagueTextTests.swift`

**Interfaces:**
- Consumes: `FitnessProjection.jadednessAfterMatch`, `jadednessAfterDays` (Task 1); `LaterFixture`, `SquadTiers.slot(of:)`, `SquadTiers.advantage(of:)`; `PlanRequest.rates` (Task 4).
- Produces:

```swift
extension AdvisorText {
    /// "Sat 14 Nov".
    public static func shortDay(_ day: Day) -> String
}
struct SavingAssessment { let adjustment: Adjustment; let named: FixtureID; let brokeAt: Set<FixtureID> }  // (corrected after the whole-branch review); brokeRiskRule is brokeAt.contains(named)
extension SavingPlayers {
    /// As `adjustment`, with the later fixture its reason names and whether that fixture's loss was a broken risk rule.
    static func assessment(for:fitness:position:today:later:rates:settings:parameters:) throws -> SavingAssessment?
}
public struct RestDue: Equatable, Sendable { public let adjustment: Adjustment; public let fixture: FixtureID }
public enum RestBeforeLine {
    /// The cost of starting `player` today when a match off would keep him from being jaded for a later fixture.
    /// `jadedness` is his projected jadedness before today's match. Nil when there is none.
    public static func adjustment(for player: Player, jadedness: Double, today: Fixture, later: [LaterFixture],
                                  rates: JadednessRates?, settings: PlanSettings, parameters: EngineParameters) -> RestDue?
}
```

`SavingPlayers.adjustment` becomes `assessment(...)?.adjustment`. `AdvisorText.pastedDay` in the league text uses `shortDay`.

The rule (§5), exactly:

1. Nil when `settings.savingPlayers` is 0, `rates` is nil, today's importance has no usable weight, or today's fixture rejects him.
2. Take `later` dated after today, in date then id order. Keep two jadedness figures, **starting** (`jadednessAfterMatch` of `jadedness`) and **resting** (`jadedness`), and walk the fixtures: move both on by the days since the previous date (`jadednessAfterDays`, with his rates); then, if the fixture rejects him, it is one he does not start either way: it cannot be M, and neither figure takes a match; otherwise, if the fixture's importance is not high, its weight is usable and above today's (corrected after the whole-branch review), and starting, rounded to a whole number, is above `jadedThreshold`, it is M and the walk stops; otherwise both take a match (`jadednessAfterMatch`) (corrected during the build: the first text let a fixture he is rejected for be M, and tested only the fixture before the rejection; the tests `aFixtureHeIsRejectedForCannotBeTheOneHeIsSavedFor` and `theFixtureAfterOneHeIsRejectedForCanBe` were added).
3. Nil with no M; nil when resting, rounded, is also above the line before M.
4. Nil unless he is in M's first eleven (`tiers.slot(of:)` gives tier 1) with an advantage above 0, and M's importance has a usable weight.
5. The cost is advantage × weight(M) ÷ weight(today) × `settings.savingPlayers`, at most `savingCostCeiling`. Nil at 0.
6. The adjustment is `Adjustment(kind: .restedBeforeLine, cost:, reason:)` with the reason in Exact copy: the threshold, his gain as a whole number after "+", M's opponent and `shortDay` of its date. Nil when the gain rounds to 0 (corrected after the whole-branch review).

In the planner, `RestBeforeLine.adjustment` is worked out once for each player and fixture, with `fitness[player.id]!.jadedness`. For each slot: when the saving rule's assessment there broke a risk rule at the rest rule's fixture, whichever fixture it named (corrected after the whole-branch review), only the larger of the two costs is added (the saving rule's on a tie); otherwise both are.

- [ ] **Step 1: Write the failing tests** in `RestBeforeLineTests.swift`. The suite's setup is `SavingPlayersTests`'s (the `PlannerFixture` squad, its tiers, `today`, `fixture`, `later`, `player`). The striker "ST_C first" is the player; `falling` is drift −2 a day and gain 60; `advantage` is `tiers.advantage(of: PlannerFixture.id(.ST_C, "first"))!`.

| Test | Given | Expect |
|---|---|---|
| `startingTodayWouldLeaveHimJadedForANamedFixture` | jadedness 330, `falling`; today low; later A medium in 7 days ("Buxton" in 14 is B, medium) | fixture B; cost `advantage * 1.5 / 0.8`; kind `.restedBeforeLine`; reason `"Rested before he passes 400: at about +60 a start, starting today would leave him jaded for Buxton on \(AdvisorText.shortDay(today.adding(days: 14)))"` |
| `theCostIsWeightedByHowMuchEachFixtureMatters` | the same with today low and with today sharpness (corrected after the whole-branch review): today medium now gives nil | cost `advantage * 1.5 / 0.8` and `advantage * 1.5 / 0.1`: starting him costs more in the lesser fixture, so that is where the plan rests him |
| `noCostWhenAMatchOffDoesNotSaveHim` | jadedness 380, drift +3, gain 20, one later medium in 7 days | nil (resting he is at 401) |
| `noCostWhenTheFixtureHeWouldMissIsHighImportance` | jadedness 380, `falling`, one later high in 7 days | nil |
| `noCostWhenHeNeverPassesTheLine` | jadedness 100, `falling` | nil |
| `noCostWithSavingPlayersOff` | the first case, `savingPlayers: 0` | nil; and at 0.5 the cost is half |
| `noCostForAPlayerWithNoMeasuredRates` | the first case, `rates: nil` | nil |
| `noCostWhenHeIsNotFirstChoiceThere` | "ST_C second" in the first case | nil |
| `aFixtureHeIsRejectedForIsOneHeDoesNotStart` | the first case with A rejecting him | nil (376 before A, 362 before B) |
| `noCostWhenAStartLooksAsIfItLowersJadedness` (Review Focus 3) | jadedness 395, gain −5 and gain 0, drift +1 | nil for both |
| `theCostIsCapped` | the first case, `savingPlayers: 10`, a ceiling of 1 in the parameters | cost 1 |
| `fixturesInAnyOrderGiveTheSameResult` | the first case with `later` reversed | equal |

In `PlannerScenarioTests.swift` (follow the suite's existing way of building a request and reading omissions):

  - `aPlayerIsRestedInTheLesserFixtureBeforeHePassesTheLine`: fixtures low (today), medium (+7), medium (+14); the striker at 330 with `falling` in `request.rates`. He is not in the first lineup, his omission there is `.heldBack` naming `.restedBeforeLine`, and he starts the other two.
  - `withSavingPlayersOffHeStartsTwoAndMissesTheThirdJaded`: the same request with `savingPlayers: 0`: he starts the first two, and is left out of the third as jaded (422).
  - `theOwnersChoiceStillStartsHim`: the first request with an override for him at his slot in the low fixture: he starts it.
  - `whenBothRulesNameTheSameFixtureOnlyOneCostIsKept`: today low, one later medium in 7 days, jadedness 350 and gain 120: he is left out, and his omission's kinds are `[.savedForLater]`. With the first scenario's shape (low today, medium in 7 and 14 days, at 330) the saving rule breaks no risk rule, both costs are kept and the kinds are `[.savedForLater, .restedBeforeLine]` (corrected after the whole-branch review): the first text's low later fixture can no longer be M. `whenTheSavingRuleBrokeARiskRuleAtTheRestRulesFixtureButNamedAnotherOnlyOneCostIsKept` was added: medium in 7 days and high in 10, the saving rule naming the high one, kinds `[.savedForLater]`.

In `LeagueTextTests.swift`: `AdvisorText.shortDay(Day(year: 2026, month: 11, day: 14)!) == "Sat 14 Nov"`, and the existing pasted-day test still passes.

- [ ] **Step 2: Run to see them fail.** `cd LineupEngine && swift test --filter "RestBeforeLineTests|PlannerScenarioTests|LeagueTextTests"`. Expected: does not compile.

- [ ] **Step 3: Implement** as the Interfaces block says.

- [ ] **Step 4: Run** `cd LineupEngine && swift test`. Expected: PASS.

- [ ] **Step 5: Commit** (`Rest a player before he passes 400 when a match off would keep him from being jaded for a coming fixture, and say which`)

---

### Task 6: Rest says what is happening, and which lever works

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Rest.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Advisors.swift` (`AdvisorsRequest`, `AdvisorsReport`, the call at line 66)
- Create: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Rest.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText.swift:222-230` (`clear(in:)`), `ErrorDescriptions.swift:272-278` (use the shared squad words)
- Test: `LineupEngine/Tests/LineupEngineTests/RestTests.swift`, `RestTextTests.swift` (new), `AdvisorsTests.swift`

**Interfaces:**
- Consumes: `FitnessTrends`, `PlayerTrend`, `SeenTrend`, `SharedRate`, `MeasuredRate`, `RateSource` (Tasks 1 and 3); `AdvisorText.shortDay` (Task 5).
- Produces:

```swift
public struct RestTrend: Equatable, Sendable {
    public let squad: Squad
    public let seen: SeenTrend?
    /// The imports that count towards his trend so far (his used intervals + 1 when he has any; else 1 with a reading
    /// that can still count, `PlayerTrend.hasCountedReading`; else 0) (corrected after the whole-branch review), and how many a trend needs (`fewestOwnIntervals + 1`).
    public let imports: Int, importsNeeded: Int
    /// The day he passes `jadedThreshold` at his trend as seen; nil unless rising, at or under the line, and within
    /// `passDateWithinDays`.
    public let passesOn: Day?
    /// The drift and the gain he takes.
    public let drift: MeasuredRate?, gain: MeasuredRate?
    /// He is over a line and the drift he takes is 0 or above: rest from matches will not clear it.
    public let restWillNotClear: Bool
    public let basis: Evidence     // `jadednessTrendRules`' evidence
}
// RestAdvice gains: public let trend: RestTrend
// Rest.advice gains `trends: FitnessTrends = .none` after `intensity`.
// AdvisorsRequest gains `trends: FitnessTrends = .none` (last init argument); AdvisorsReport gains `public let trends: FitnessTrends`.

public struct SquadTrendLine: Equatable, Sendable { public let text: String; public let caution: String? }
extension AdvisorText {
    public static func name(_ squad: Squad) -> String            // "First team", "U21s", "U18s"
    public static func possessive(_ squad: Squad) -> String      // "the first team's", "the U21s'", "the U18s'"
    public static func trendLines(of advice: RestAdvice, parameters: EngineParameters) -> [String]
    /// A line for each squad with a measured drift, in `Squad.allCases` order.
    public static func squadTrendLines(_ trends: FitnessTrends, parameters: EngineParameters) -> [SquadTrendLine]
    public static func clubGainLine(_ trends: FitnessTrends) -> String?
    public static func trendMeasuredFrom(_ trends: FitnessTrends) -> String?
    public static let gameMessagesHeading: String
    public static func gameMessages(parameters: EngineParameters) -> [String]
}
```

Rules in `Rest.advice`:

- **Listed on course.** A player nothing else lists is listed at watch when his trend as seen is above `steadyPerWeek`, his jadedness is at or under `jadedThreshold`, and (threshold − jadedness) ÷ (perWeek ÷ 7) is at most `onCourseDays`. He gets no reason of the old kind; his trend lines say why. His `basis` takes in `jadednessTrendRules`' and `jadedThreshold`'s evidence. A squad's or the club's rate lists nobody.
- **`passesOn`**: `asOf` plus that number of days, rounded up, when it is at most `passDateWithinDays`.
- **Days until clear**, for a player over his limit or the lineup's line who does not need a holiday: with a drift he takes below 0, the days are counted at that drift (as a fall) in place of `jadednessRecoveryPerDay`, and the basis takes in `jadednessTrendRules`' evidence; with one at 0 or above, `restWillNotClear` is true and `days` is nil; with none, as now. A player who needs a holiday keeps the holiday estimate, and `restWillNotClear` is false for him. `AdvisorText.clear(in:)` returns nil when `restWillNotClear`.
- Everything else in Rest (levels, limits, reasons, order) is unchanged, and with `trends: .none` every existing test passes untouched but for the new `trend` field.

Rules in `trendLines(of:)`, in the order of Exact copy:

1. No `seen`: line 1, with `importsNeeded` and `imports`.
2. `seen`: rising above `steadyPerWeek`, falling below its negative, else steady; weeks are `seen.days ÷ 7` to the nearest whole number, at least 1.
3. `passesOn`: line 3.
4. With `seen`, at least one start in it, both rates and a gain above 0: the "match off saves" line when his drift is below 0 (in its "holds steady" form when the weekly drift is within `steadyPerWeek`, (corrected after the whole-branch review)); else a "will not bring it down" line ("holds steady" when his drift × 7 is under `steadyPerWeek`). The bracket names each rate that is not his own, the drift's first.
5. Rising and no start in `seen`: line 5.
6. `restWillNotClear` and no "will not bring it down" line given at 4: that line, with the drift's bracket only.

`squadTrendLines`: weekly figure is the drift × 7; "holds steady" within `steadyPerWeek`; the caution when the drift is 0 or above. `gameMessages` writes the threshold and the sharpness figure from the parameters.

- [ ] **Step 1: Write the failing text tests** in `RestTextTests.swift`. A helper builds a `RestAdvice` with a given `RestTrend`. One test for each sentence in Exact copy, comparing whole strings: the three forms of line 2 with 6 starts, 1 start and none, and with 1 week; line 3; each form of line 4 with each bracket (own and own: no bracket; squad and own; squad and club; own and club); line 5; line 6 for a player with a drift and no gain; a gain of 0 or below gives no line 4 (Review Focus 3); a player with 1 import after the summer gives `"His trend is not measured yet: it needs 4 imports of his squad, and has 1."` (Review Focus 5). `squadTrendLines` for a rising, a falling and a steady squad, the caution only on drift 0 or above, the squads in order; `clubGainLine`; `trendMeasuredFrom`; the three `gameMessages` and the heading, as written; `name` and `possessive` for each squad; `clear(in:)` nil when `restWillNotClear`.

- [ ] **Step 2: Write the failing rule tests** in `RestTests.swift`, building `FitnessTrends` by hand:
  - `aPlayerOnCourseToPassTheLineWithinSixWeeksIsWatched`: jadedness 190, trend 35 a week: (400 − 190) ÷ 5 = 42 days: listed at watch, `passesOn == asOf.adding(days: 42)`, no reasons, basis `.derived`.
  - `atFortyThreeDaysHeIsNotListed`: jadedness 185 with the same trend: nil.
  - `aSquadsRateAloneListsNobody`: no `seen`, a squad drift of +10 a day: nil.
  - `aFallingTrendListsNobody`: trend −20 a week at jadedness 300: nil; a trend of 35 at 300 lists him.
  - `daysUntilClearUseTheDriftHeTakes`: jadedness 450, limit 400 (watch line 320), drift −10 a day: `days == 13`; with `trends: .none`: the day count the fixed 20 a day gives, as before.
  - `noDaysWhenRestFromMatchesWillNotClearIt`: the same with drift +2: `days == nil`, `trend.restWillNotClear`, and `AdvisorText.clear(in:) == nil`.
  - `aPlayerNeedingAHolidayKeepsTheHolidayEstimate`: jadedness 650, drift +2: `days` as today.
  - `aListedPlayerWithNoReadingsHasNoImports`: `trend.imports == 0`, `importsNeeded == 4`.
  - In `AdvisorsTests.swift`: `theReportCarriesTheTrendsItWasHanded`, and a request with none reports `.none`.

- [ ] **Step 3: Run to see them fail.** `cd LineupEngine && swift test --filter "RestTests|RestTextTests|AdvisorsTests"`. Expected: does not compile.

- [ ] **Step 4: Implement.** `ErrorDescriptions`' private squad possessive becomes a call to `AdvisorText.possessive`.

- [ ] **Step 5: Run** `cd LineupEngine && swift test`. Expected: PASS.

- [ ] **Step 6: Commit** (`Have Rest say each listed player's trend, when he passes 400, what a match off saves, and when only lighter training will bring him down`)

---

### Task 7: The command line reads readings

**Files:**
- Modify: `LineupEngine/Sources/lineup-cli/main.swift` (usage, `Options`, `plan` and `advise`)
- Modify: `LineupEngine/Sources/lineup-cli/Report.swift:243-255`
- Create: `LineupEngine/Tests/LineupEngineTests/Fixtures/plans/sample-fitness-readings.json`
- Modify: `CLAUDE.md` (the `plan` and `advise` paragraphs)

**Interfaces:**
- Consumes: `FitnessTrend.rates`, `PlanRequest.rates`, `AdvisorsRequest.trends`, the `AdvisorText` functions of Task 6.
- Produces: `--fitness-readings <file>` on `plan` and `advise`: a JSON object from a player's key to an array of readings, each `{"day": "YYYY-MM-DD", "jadedness": 120, "condition": 0.92, "sharpness": 0.9, "isInjured": false, "includes": ["<fixture id>"]}` (the `Codable` form of `FitnessReading`). The rates are worked out with `--history`'s lineups, each player's squad from the pastes, `--as-of` as the day and no measure-from day. Without the option the fixed figures are used and no trend is printed. A file that cannot be read or decoded stops the command with a sentence naming the file.

- [ ] **Step 1: Build the fixture.** Readings for the captured first team and U21s, keyed as the pastes key them, on four days a week apart ending on 2026-11-13, written by hand so that, measured against `sample-history-with-readings.json` (a longer history than `sample-history.json`, whose two lineups cannot measure a trend; corrected during the build, which also dropped the acceptance below that the plan's output differs with the option), the first team's drift, the club's gain and at least one player's own gain are measured, the first team's drift is below 0 and one regular starter is rising towards 400 inside six weeks. The figures are invented for the captured names; no real save's values.

- [ ] **Step 2: Add the option, its usage text and the printing.** `advise`'s Rest part prints the squad lines (each caution under its line), the club line, the measured-from line, then under each player's reasons his trend lines; and the game-messages heading and lines at its end. `plan` hands `rates` to the request.

- [ ] **Step 3: Check by running.**

Run the `advise` command from `CLAUDE.md` with `--fitness-readings Tests/LineupEngineTests/Fixtures/plans/sample-fitness-readings.json`.
Expected: under `=== Rest ===` a line starting `First team: a player who does not start falls about`, a line starting `A start adds about`, a player with `Rising about` and `At that rate he passes 400 around`, and the three game-message lines. Run it without the option: none of those lines but the three game messages, and the rest of the output as before.

Run the `plan` command with and without the option. Expected: both succeed; with it, at least one player's projected jadedness in a later fixture differs. (Corrected during the build: this acceptance was dropped. `plan` prints no projected jadedness, and on the captured squad no measured rate reaches 400 inside five fixtures, so it picks the same lineups with and without the option; one printed value differs, by 0.1.)

- [ ] **Step 4: Add the option to `CLAUDE.md`'s `plan` and `advise` paragraphs** in two sentences, and run `cd LineupEngine && swift test` (PASS, clean build).

- [ ] **Step 5: Commit** (`Let the command line plan and advise from saved fitness readings, so the trend can be tried without the app`)

---

### Task 8: The app keeps the readings and plans with the rates

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/FitnessState.swift`
- Create: `LineupApp/Sources/LineupAppCore/AppModel+Fitness.swift`
- Modify: `LineupApp/Sources/LineupAppCore/Store.swift` (`StoreFile.fitness` in every `switch`)
- Modify: `LineupApp/Sources/LineupAppCore/AppModel.swift` (the property, the load near line 175, the notices, `replaced`, `save`, the first reading near line 208)
- Modify: `LineupApp/Sources/LineupAppCore/AppModel+Squad.swift:43-45`
- Modify: `LineupApp/Sources/LineupAppCore/AppModel+Plan.swift:298-302`, `AppModel+Advice.swift:62-65`
- Test: `LineupApp/Tests/LineupAppCoreTests/FitnessStateTests.swift` (new), `AppModelFitnessTests.swift` (new), `StoreTests.swift`

**Interfaces:**
- Consumes: `FitnessReading`, `FitnessTrend.rates`, `FitnessTrends`, `PlanRequest.rates`, `AdvisorsRequest.trends`.
- Produces:

```swift
public struct FitnessState: Equatable, Codable, Sendable {
    /// Each player's readings in day order, one a day.
    public var readings: [PlayerID: [FitnessReading]]
    /// The day the owner said to measure from; nil until he does.
    public var measureFrom: Day?
    public init()
    /// Takes a reading of each player on `day`, which replaces one of the same day and keeps its fixtures; then drops,
    /// for every player, readings more than `keptDays` before `day`, and players left with none. A player recorded
    /// loses his readings dated after `day` first (corrected after the whole-branch review).
    mutating func record(_ players: [Player], on day: Day, including fixtures: [FixtureID], keptDays: Int)
}
extension AppModel {
    public internal(set) var fitness: FitnessState          // stored in AppModel.swift
    /// The rates for the saved state, as of the plan's starting day; `.none` before a squad is imported.
    var fitnessTrends: FitnessTrends { get }
    func recordFitness(after squad: Squad, on day: Day)
    /// Sets the measure-from day to today in the game, saves the file and plans again.
    public func measureTrendAgain()
}
```

`StoreFile.fitness`: file `fitness.json`; description "your fitness readings"; starts with "the readings start empty"; missing subject "fitness readings"; not noticed when missing.

Rules:

- In `attemptImport`, `recordFitness(after: target, on: date)` is called after `save(.squad)` and before the `awaitingImport` marks are cleared. Its fixtures are those of the history records awaiting `target` at that moment. It saves the fitness file and does not plan (the import plans after).
- `fitnessTrends` hands `FitnessTrend.rates` the kept readings, `history.map(\.lineup)`, each held player's squad, `planStartDay`, `fitness.measureFrom` and `planParameters`. The plan request takes its `pairs`; the advisors' request takes it whole. Nothing of it is saved.
- At launch, when the fitness file holds no reading, one is taken for each held squad on the day it was imported, as the mentoring readings are; its fixtures are those of the confirmed lineups dated that day that no longer await that squad. (This plan's call: the owner's squads then need three more imports, not four.)
- `measureTrendAgain()` keeps every reading in the file.

- [ ] **Step 1: Write the failing state tests** in `FitnessStateTests.swift`:
  - `aReadingIsKeptForEachPlayerWithTheFixturesGiven`
  - `aSecondImportTheSameDayReplacesTheReadingAndKeepsBothSetsOfFixtures`: record with `["a"]`, then with `["b"]` and a changed jadedness: one reading, the new jadedness, `includes == [FixtureID("a"), FixtureID("b")]`.
  - `readingsOlderThanTheDaysKeptAreDropped`: a reading 121 days before goes, one 120 days before stays, and a player left with none is removed, whether or not he is among the players recorded (Review Focus 2).
  - `aPlayerImportedInTwoSquadsOnOneDayHasOneReading` (Review Focus 1).
  - `aRecordOnAnEarlierDayDropsTheLaterReading` (Review Focus 4): record on day 10 then day 3: `[3]` (corrected after the whole-branch review); the first text kept both, `[3, 10]`.
  - `theStateRoundTripsThroughJSON`, and JSON with no `measureFrom` decodes.

- [ ] **Step 2: Write the failing model tests** in `AppModelFitnessTests.swift`, on `TestModel`:
  - `anImportRecordsAReadingWithTheFixturesThenWaiting`: import the first team, confirm the next fixture, move the date on, import again: every first-team player has two readings, the second's `includes` holds that fixture, and the record's `awaitingImport` is now empty.
  - `aSquadNotImportedIsNotRead`: importing the U21s leaves the first team's readings as they were.
  - `theReadingsAreSavedAndOpenAgain`: `reopened().fitness == model.fitness`.
  - `stateFromBeforeOpensWithNoNoticeAndAFirstReading`: delete `fitness.json`, reopen: no notice, one reading for each held player dated the squad's import day, and `planState` equal to the plan before.
  - `withTooFewReadingsThePlanUsesTheFixedFigures`: after two imports `fitnessTrends.pairs.isEmpty` and the plan equals the plan worked out with `rates: [:]`.
  - `measuredRatesReachThePlanAndTheAdvice`: set `model.fitness` and `model.history` directly to readings and confirmed records that measure a pair for one player (three weeks without a start, then three with one, all inside the 42 days before the import), `replan()`: `fitnessTrends.pairs[him] != nil`, his projected jadedness before the second planned fixture is his imported figure + his gain + his drift × the days (he starts the first by an override), and `adviceState`'s report has `trends == model.fitnessTrends`.
  - `measureAgainKeepsTheReadingsAndTakesThemOutOfTheRates`: with that state, `measureTrendAgain()`: `fitness.readings` unchanged, `fitness.measureFrom == settings.currentDate`, `fitnessTrends.pairs.isEmpty`, `timesPlanned` one higher, the file saved.
  - `aPlayerWhoLeftEverySquadIsNotMeasured` (Review Focus 2): readings kept for a key in no squad: `fitnessTrends.players[key] == nil`, and the plan and the advice are worked out.
  - In `StoreTests.swift`: `fitness` is among `StoreFile.allCases`, is not noticed when missing, and an unreadable `fitness.json` gives the usual notice, a fresh start and the file kept aside.

- [ ] **Step 3: Run to see them fail.** `cd LineupApp && swift test --filter "FitnessStateTests|AppModelFitnessTests|StoreTests"`. Expected: does not compile.

- [ ] **Step 4: Implement** as the Interfaces block says.

- [ ] **Step 5: Run** the three filters (PASS), then the whole app suite in the background: `cd LineupApp && swift test`. Expected: PASS, no warnings. A test that pinned a planned lineup or a rating on the sample data and now differs is checked against Tasks 1 and 2 (recovery above jadedness 0, no ×0.90) before its value is changed.

- [ ] **Step 6: Commit** (`Keep a fitness reading of every player at each import and plan with the rates measured from them`)

---

### Task 9: The Rest screen, the setting's words, and the pictures

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/RestPresentation.swift`
- Modify: `LineupApp/Sources/LineupAppCore/SquadPresentation.swift:6-12` (`displayName` returns `AdvisorText.name`)
- Modify: `LineupApp/Sources/LineupAppCore/SettingsPresentation.swift`, `LineupApp/Sources/LineupAppUI/Settings/SettingsScreen.swift:76-83`
- Modify: `LineupApp/Sources/LineupAppUI/Advice/RestScreen.swift`, `LineupApp/Sources/LineupAppUI/Theme.swift` (any new measure)
- Modify: `LineupApp/Sources/LineupAppCore/SampleData.swift`, `LineupApp/Sources/LineupApp/main.swift` (corrected during the build: the first text named `ScreenPictures.swift`; every picture variant is registered in `main.swift`)
- Test: `LineupApp/Tests/LineupAppCoreTests/RestPresentationTests.swift`, `SettingsPresentationTests.swift`, `MatchPresentationTests.swift`

**Interfaces:**
- Consumes: `RestAdvice.trend`, `AdvisorsReport.trends`, the `AdvisorText` functions of Task 6, `AppModel.fitness`, `measureTrendAgain()`.
- Produces, in Core:

```swift
// RestRow gains:
public let trendLines: [String]        // AdvisorText.trendLines, as written
public let trendNoteText: String?      // "(this tool's estimate)" when a measured line is shown, not after "not measured yet" alone (corrected after the whole-branch review)
// spokenText says the trend lines after the reasons.

public struct RestSquadLine: Identifiable, Equatable, Sendable { public let id: Int; public let text: String; public let caution: String? }
public struct RestTrendHeader: Equatable, Sendable {
    public let squadLines: [RestSquadLine]
    public let clubLine: String?
    public let measuredFromText: String?
    /// Offered once any reading is kept.
    public let offersMeasureAgain: Bool
}
extension RestPresentation {
    public static let measureAgainTitle = "Measure again from today"
    public static let measureAgainConfirm = "Measure again"
    public static func measureAgainQuestion(imports: Int) -> String
    public static let gameMessagesHeading: String            // the engine's
    public static func gameMessages(_ parameters: EngineParameters) -> [String]
}
extension AppModel {
    public func restTrendHeader(_ report: AdvisorsReport) -> RestTrendHeader
    public var restGameMessages: [String] { get }
}
extension AppSettings { public static let savingPlayersExplanation: String }
```

`RestPresentation.rows` takes the parameters so it can ask the engine for each row's trend lines. `SampleData` gains `modelWithFallingTrends`, `modelWithRisingTrends` (a squad whose drift is above 0), `modelBeforeTrends` (two readings each) and `modelWithPlayerRestedBeforeLine`, each setting `model.fitness` and planning again, and each throwing when the screen would not show what it is for (as the other sample builders do).

Layout, within the visual direction (`docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md`): under the explanation line, the squad lines in the body face, each caution under its line as a `CautionLine`, then the club line; then the measured-from line, muted, with the button beside it, which opens a confirmation as "Remove table" does on the League screen. Each row's trend lines sit under its reasons in line with the name, in the muted ink, with the trend's note after them. The game-messages heading and lines are at the foot of the list, small and muted, and are shown when nobody is listed too. With nobody listed the squad lines, the measured-from line and the foot note are still shown above and below "Nobody needs rest today."

- [ ] **Step 1: Write the failing Core tests.** In `RestPresentationTests.swift` (the helper's `RestAdvice` gains a `trend`):
  - `aRowCarriesTheEnginesTrendLinesAsWritten`: `row.trendLines == AdvisorText.trendLines(of: given, parameters: .fm27)`, `trendNoteText == "(this tool's estimate)"`, and `spokenText` contains each line.
  - `anUnmeasuredRowSaysHowManyImportsItHas`: a row whose trend has no `seen` has the one line "His trend is not measured yet: it needs 4 imports of his squad, and has 2.", and no note (corrected after the whole-branch review).
  - `theHeaderHasALineForEachMeasuredSquadAndTheClub`, with the caution only on a squad whose drift is 0 or above, in squad order.
  - `measureAgainIsOfferedOnceAReadingIsKept`, and not before.
  - `theQuestionSaysHowManyImports`: `measureAgainQuestion(imports: 4)` is the sentence in Exact copy.
  - `theGameMessagesAreTheEngines`.
  - In `SettingsPresentationTests.swift`: `savingPlayersExplanation` is the sentence in Exact copy.
  - In `MatchPresentationTests.swift`: a pick or omission whose adjustments hold a `.restedBeforeLine` reason shows that reason as written, where a `.savedForLater` one is shown.

- [ ] **Step 2: Run to see them fail.** `cd LineupApp && swift test --filter "RestPresentationTests|SettingsPresentationTests|MatchPresentationTests"`. Expected: does not compile.

- [ ] **Step 3: Implement Core, then the views.** The Settings row reads `AppSettings.savingPlayersExplanation`.

- [ ] **Step 4: Run the filters** (PASS).

- [ ] **Step 5: Add the sample models and the pictures** `rest-trend-*`, `rest-trend-rising-*`, `rest-unmeasured-*` and `match-restdue-*` to the picture variants in `LineupApp`'s `main.swift` (corrected during the build: the first text said `ScreenPictures`), then draw them:

Run: `cd LineupApp && swift run -q LineupApp --sample-data .. --pictures .build/pictures-trend`
Expected: the eight new PNGs (light and dark) among the rest. Open each with the Read tool and check: every sentence is whole and unclipped at the default and the smallest window; the squad lines, the caution and the button read in that order; a row's trend lines are plainly under that row; the foot note is legible; `match-restdue-*` shows the rested reason under the player left out. Also look again at `rest-*`, `settings-*` and `match-*` for anything this moved. Fix what is wrong and draw again.

- [ ] **Step 6: Run the whole app suite in the background** (`cd LineupApp && swift test`). Expected: PASS, no warnings.

- [ ] **Step 7: Commit** (`Show each player's jadedness trend and what the game's tiredness messages mean on the Rest screen, with a way to measure again after a change of training`)

---

### Task 10: Record what was built

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/plans/2026-11-21-fm27-jadedness-trend.md` (closing sections)
- Modify: `docs/superpowers/specs/2026-11-21-fm27-jadedness-trend-design.md` (status line; anything the build changed, marked "revised")

- [ ] **Step 1: Run both whole suites once more** (`cd LineupEngine && swift test`; `cd LineupApp && swift test` in the background). Expected: PASS, clean.

- [ ] **Step 2: Run the `plan` and `advise` commands of `CLAUDE.md` on the captured squad, with and without `--fitness-readings`,** and note in the plan's closing sections what changed in the lineups from Tasks 1 and 2 alone (who is now picked that was not), and what the trend added.

- [ ] **Step 3: Update `CLAUDE.md`:** a bullet for this plan in "What this project is"; in the engine's notes, the projection's rates, the readings and `FitnessTrend.rates`, the rest-before-the-line rule under **Planning**, Rest's new lines under **Advisors**, and the changed jadedness steps under **Selection**; in the app's notes, `fitness.json`, the reading at import, the Rest screen's new parts and "Measure again from today"; the `--fitness-readings` option; the pictures checked in `.build/pictures-trend`.

- [ ] **Step 4: Add the plan's closing sections:** "What changed during the build", and "Limits left", which holds the seven limits of §10 as they turned out, and these of this plan: the listing on course reads `jadedThreshold`, not the player's own limit; a player's readings all count under the squad he is in now; the first reading taken at launch is dated the squad's last import.

- [ ] **Step 5: Commit** (`Record the jadedness trend in the project notes, with what it changed on the captured squad and the limits left`)

The install (`tools/build_app.sh`), the first imports on the owner's save and the reading of the Rest screen against the game are left to the owner.

## What the commands showed on the captured squad

Run on 22 November 2026 with the commands of `CLAUDE.md`, on the engine as it was before this build (commit `7583598`) and as it is now.

- **Tasks 1 and 2 alone change no lineup on the captured squad.** `plan`'s output is identical before and after, and `advise`'s differs only by the new heading "What the game's messages mean" and its three lines at the end of the Rest part. Every captured player's jadedness is below 0, so the two changes that could move a lineup on their own, no ×0.90 between 200 and 400 and slower condition recovery above jadedness 0, have nobody to act on. Nobody is picked now who was not.
- **With `--fitness-readings Tests/LineupEngineTests/Fixtures/plans/sample-fitness-readings.json` and `--history Tests/LineupEngineTests/Fixtures/plans/sample-history-with-readings.json`** (`--as-of 2026-11-13`), `advise`'s Rest part adds the squad line "First team: a player who does not start falls about 7 a week (from 72 readings since Tue 6 Oct; this tool's estimate).", the club's "A start adds about 40 (from 98 readings; this tool's estimate).", "Trend measured from Tue 6 Oct.", and under Evan Humphries "Rising about 35 a week over the last 5 weeks, in which he started 6 matches (from 7 readings)." and "At that rate he passes 400 around Wed 3 Mar.", and under Dejan Tetek "Rising about 97 a week over the last 3 weeks, in which he started 4 matches (from 5 readings).", "At that rate he passes 400 around Wed 23 Dec." and "Without a start he falls about 7 a week, and a start adds about 89, so a match off saves about 89. (the first team's rate without a start; his own rate for a start)".
- **`plan` picks the same lineups with and without the option.** From about −150 on the captured paste, no measured rate takes anyone to 400 inside five fixtures, and `plan` prints no projected jadedness; the one difference in its printed table is Dejan Tetek's value in the first fixture, 125.3 without the option and 125.2 with it (so "identical", as the build's notes had it, was not quite so). The readings are invented for the captured names and agree with the paste of 13 November; they hold no real save's values. Whether the trend moves a real lineup is for the owner's own save.

## What changed during the build

1. **A player with no drift of his own still takes the club's gain** when the club has one, though he has no measured pair either way (design §2: "his own, else the club's, else none"). Task 3's table expected no gain for a U18 with no drift; it was corrected in place.
2. **`FitnessTrends.measuredFrom` follows one rule** whether or not readings are kept: the day to measure from when it is later than the window's first day, else the earliest reading in the window, else none. (Changed again after the whole-branch review: see below.)
3. **A fixture the owner has rejected the player for cannot be the fixture resting him saves him for.** The first rule let it be M, so a player could be rested for a match he would not play; the walk now skips it, and two tests were added. Task 5's text was corrected in place.
4. **Rest's estimate of days until condition reaches the floor takes the player's measured pair**, since his jadedness moves with it and slows condition above 0.
5. **With a measured drift below 0, a count of more than 120 days to clear is not given** (`passDateWithinDays`); the existing "Clear in more days than the estimate covers" is shown. A drift just under 0 had given a count of years.
6. **Task 6 repaired the app's Rest test helper** so the app kept building between tasks.
7. **The command line's sample needed its own longer history**, `sample-history-with-readings.json`, since `sample-history.json` has two lineups and cannot measure a trend; its readings agree with the captured paste of 13 November, so the on-course sample is one an import could produce. The acceptance that `plan`'s output differs with the option was dropped (see above). Task 7's text was corrected in place.
8. **One existing Rest test changed beyond its figures** (Task 1): `whenBothApplyTheLargerCounts` had its starting condition changed as well as its pinned days, because recovery is slower above jadedness 0. **Eight tests that pinned ×0.90** (Task 2) now run on a test-only parameter set with the old steps (`EngineParameters.withAMarkDownFrom200`) or moved to 450 and ×0.70.
9. **At launch, when the fitness file can be neither read nor moved aside, no first reading is taken**, so the file is never written over (Task 8).
10. **The pictures are registered in `LineupApp`'s `main.swift`**, where every variant is, not in `ScreenPictures.swift` as the plan said; two pictures were added, `rest-trend-tall-*` and `rest-trend-small-*`, because the default window shows only the first rows (Task 9). Task 9's text was corrected in place.
11. **Commits by an implementer on another model carry that model's Co-Authored-By line.**

### After the whole-branch review

The whole-branch review of 22 November 2026 found these, and one fix round made them. Each has its tests; the task texts above were corrected in place where they gave the old rule.

1. **The rest-before-the-line rule rests a player only for a later fixture that weighs more than today's**, as the saving rule asks (design §5, revised). With equal weights he misses one match of the same worth either way, so a match off buys nothing; with today heavier, a tired first choice could be left out of a high fixture for a medium one. A later fixture that does not outweigh today's is walked as before but cannot be M. Four tests in `RestBeforeLineTests`; `theCostIsWeightedByHowMuchEachFixtureMatters` now compares a low and a sharpness fixture today, and the second half of `whenBothRulesNameTheSameFixtureOnlyOneCostIsKept` shows the rest rule acting beside the saving rule in the first scenario's shape, since its low/low case could no longer fire. The owner should know the cost if this is wrong: in a run of equal-weight matches the rule rests nobody, and he plays until he is over 400 and misses one then, with Rest warning weeks ahead.
2. **Only the larger of the two costs is kept whenever the saving rule broke a risk rule at the rest rule's fixture**, whichever fixture its reason names (`SavingAssessment.brokeAt`). Before, the merge needed the saving rule to name that fixture, so M's whole advantage could be counted twice. The saving rule's cost is then always at least the rest rule's. One planner scenario.
3. **A gain that rounds to 0 charges nothing**, so the reason never says "+0". One test.
4. **The saving reason writes its date by `AdvisorText.shortDay`**: "Kept fresher for Wealdstone on Sat 21 Nov", beside the rest reason's form. Three engine tests changed their expected date and nothing else.
5. **"Trend measured from" is never later than a squad line's "since"**: with no day to measure from in force it is the earliest reading at an end of a used interval, else the earliest reading in the window.
6. **A drift below 0 within the steady band writes "He holds steady without a start, and a start adds about 61, so a match off saves about 61."** (design §6, revised; added to Exact copy). Not in the copy the owner approved, so his to check.
7. **"Has N" counts only readings that can still count**: his used intervals + 1 when he has any, else 1 with a reading on or after the day to measure from, on or before the day asked for and within the window, else 0 (`PlayerTrend.hasCountedReading`). After "Measure again from today" a player with only older readings has 0.
8. **The Rest test that could not fail** (`trendsForOtherPlayersChangeNothing`, keyed to a player not in the squad) is now `aTrendTheAdviceDoesNotFollowChangesOnlyHisTrend`, keyed to the player who needs a holiday: his level, days, reasons and basis stay, and every other player's advice is unchanged.
9. **No estimate note follows "His trend is not measured yet" alone**; it stays whenever a measured line is shown, and the spoken text follows. Three Core tests changed with it (the spoken row, the unmeasured row, and the evidence test, now on a measured trend), and one was added.
10. **The confirmation reads "Measure the trend again from today? Each squad then needs 4 imports from today on before anything is measured."** (design §7, revised): "4 more times" was false when a squad had been imported that day.
11. **A reading recorded on a day drops the recorded players' readings dated after it** (design §7, revised): after the owner reloads an earlier save, readings from the abandoned timeline would otherwise form intervals with the new ones once the date passed them. Other players' readings stay. `readingsStayInDayOrderWhenTheDateIsMovedBack` is now `aRecordOnAnEarlierDayDropsTheLaterReading`, expecting `[3]`. If the owner only moved the app's date back by mistake and imports, that squad's later readings are lost.
12. **Launch after an unreadable `fitness.json` is tested**: one notice, the file kept aside, a first reading of each held squad; and, with a file that can be neither read nor moved aside, no first reading and the file not written over.
13. **The sample that rests a player before the line was changed**: Dejan Tetek is raised to 100, not 330. At 330, starting the first match alone took him past 400 before the second, a Medium match, so the saving rule broke the jaded rule there while naming the High match after it, and under fix 2 only its cost was kept. At 100 he passes the line only after starting the three matches after the first, so the rest rule alone names Opponent E, a Medium match, which outweighs the Low first. `match-restdue-*` was drawn again and shows "Rested before he passes 400: at about +89 a start, starting today would leave him jaded for Opponent E on Sat 28 Nov"; `rest-unmeasured-*` shows no note under "His trend is not measured yet".

After the fixes the engine suite has 1,551 tests and the app suite 943, both passing with no warnings.

The pictures were checked in `LineupApp/.build/pictures-trend`: `rest-trend-*` (a falling squad), `rest-trend-rising-*` (a squad rising without starts, with the caution), `rest-trend-tall-*` and `rest-trend-small-*`, `rest-unmeasured-*` and `match-restdue-*`.

## Limits left

The design's seven limits, as they turned out:

- **Nothing is measured until a squad has been imported four times** (three more after the first reading taken at launch from the squads held). Until then the plan uses the fixed figures, which the owner's save shows are wrong in direction, and rests nobody before the line.
- **A regular starter has no rest intervals, so his drift is his squad's.** What a match off would save him is partly the squad's figure, and the line says so in brackets.
- **A change of training shows slowly** unless the owner presses "Measure again from today".
- **A match played and never confirmed, a holiday and a lay-off each spoil one interval.** The median sets aside a few, not many.
- **Jadedness is taken to move at the same rate at every level.** Whether it clears faster from higher up is untested.
- **The 400 line was read off five prime-age players.** Whether the game's status comes earlier for teenagers or players over 30 is untested.
- **Substitutes are still not planned for.**

The limits this plan names:

- **The listing on course reads `jadedThreshold`, not the player's own limit.** A player whose own limit is lower is listed by the other rules as he nears it.
- **A player's readings all count under the squad he is in now**, so a player moved between squads brings his old readings into his new squad's drift.
- **The first reading taken at launch is dated the squad's last import**, which is the only day the app knows for it.

Small faults found in review and left (those fixed after the whole-branch review are taken off this list and recorded under "After the whole-branch review"):

- A row's spoken text says "this tool's estimate" twice when both its advice and its trend lines carry it.
- The sample readings for the command line cover the first team only, so U21 rows say "has 0".
- The "Measure again from today" question and the button's look are not checked in the running app: the pictures draw buttons as an inactive window would.

Found by the whole-branch review and left:

- **A high-importance fixture more than one match ahead is protected by neither rule.** A jaded player still plays a high match, at the jaded factor, and neither rule charges for the starts that take him there.
- **The planner's reason does not say whose rate it used**, so a new signing can be rested on the squad's and the club's figures with nothing in the reason to say so.
- **Rest can say leaving him out "will not bring it down" while Match Selection says "Rested before he passes 400".** Both are true: the match off buys one named fixture, not a fall.
- **Readings are dated by the app's date**, so an import made without moving the date mis-sizes an interval or replaces that day's reading; one import with the date set months ahead drops the earlier readings.
- **An import made on match day after the match but before the lineup is confirmed** puts the start in the next interval.
- **"Measure again from today" cannot be undone in the app.**
- **A player's pass date is counted from the latest import of any squad**, not his own squad's.

## Left to the owner

- Install with `tools/build_app.sh` from the repository root. It closes the open copy of the app and replaces it. It was not run in this build.
- Import each squad as usual. The app takes a first reading from the squads it holds at the first launch and a reading at every import after; the Rest screen's squad lines, the club's line and "Trend measured from" appear once a squad has enough of them. Check them against what the game shows: whether the first team's drift and the gain for a start are about what the weeks of readings suggest.
- Read the Rest screen against the game: each listed player's trend lines, the date he is said to pass 400, "a match off saves", and "will not bring it down" for a player whose drift is above 0. Say where the tool and the game disagree.
- Look at "Measure again from today" and its question in the running app, since the pictures cannot show how the button and the dialog look. Press it after a change of training in the game.
- Look at Match Selection for a plan that rests a player before the line, once the readings give a pair: "Rested before he passes 400: …" under the player left out.
