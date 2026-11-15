# Young Players' Development Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Judge a player of 23 or under on where his ability could realistically reach, in Player Removal's advice and in the planner's choice of who starts, and never advise a sale or a loan for a youth-contract player.

**Architecture:** One estimate in the engine, `Reach`, and one comparison built on it, `Development.outlooks`, which says for each young player how his reach compares with the first and second choice at each slot he can play. Player Removal scores and advises from an outlook; the planner favours from the same outlooks, worked out for each fixture's tactic. The app shows the engine's words in a new Young players part of Player Removal and gains one setting.

**Tech Stack:** Swift 6, macOS 26, Swift Testing, Foundation only in `LineupEngine/`; SwiftUI and Observation in `LineupApp/`. No third-party code.

**Spec:** `docs/superpowers/specs/2026-11-14-fm27-young-players-development-design.md`. Research: `docs/Research/fm27-development-matches-vs-training.md`.

## Global Constraints

- Work on branch `fm27-native`. Do not push, merge or open a pull request. Stage files by name.
- No silent defaults: a missing attribute is an error naming the player and the column (`RatingError.missingAttribute`, as Player Removal's `Traits` raises today).
- Every tunable number lives in `EngineParameters` with an evidence label and a source, and is checked in `FitnessModel.problems(in:)`. Numbers from the research are `carriedOverFM26` (they come from FM24 and FM26 tests); this plan's own are `derived`.
- Every rule gets a test where it changes an outcome and a test where it does not.
- The same inputs always give the same result: sums and sorts run in a fixed order; ties break on the player's key.
- Every `switch` over an engine enum is exhaustive, with no `default`.
- The engine decides; the app shows. Every word about advice comes from the engine (`AdvisorText`, the reasons on advice and on picks). Core holds only plain labels; a view holds layout only and takes every colour, typeface and measure from `Theme`.
- Nothing the owner reads is an id, a key or a code: slots are "left back" in a sentence.
- A reach figure is never shown as a fact: every row that shows one shows its working, and the evidence note is "this tool's estimate".
- Saved state from before this plan opens with no notice and loses nothing.
- Nothing in a test, a picture run or a sample-data run touches `~/Library/Application Support` or the real clipboard. Do not run `tools/build_app.sh` or open the real app.
- Test output must be clean: no build warnings. `cd LineupEngine && swift test`; `cd LineupApp && swift build && swift test`.
- The old Python, `ui/` and `.bat` files are reference only.

## Review Focus

Conditions the design implies and no rule's own test would otherwise cover, most likely first. Each has a test in the task named.

1. **Settings saved before this plan.** `settings.json` has no `development` key. Expected: it opens with no notice, Development is 1, every other setting is as saved, and the next save writes the key. (Tasks 6, 8)
2. **A young player with current ability 0, or potential below current ability.** Expected: nothing divides by zero; his reach is never below his current ability; with ability 0 he has no outlook and is scored as a player of 24 or over; nothing throws. (Tasks 1, 2, 4)
3. **Too little to compare with.** A slot with no first or no second choice (a squad smaller than the tactic), a young player who is the only one able to play a slot, a squad with no first-team player (no average). Expected: no band where there is nobody to pass; a missing second choice counts as reached; with no average and no slot he is "could become cover"; nothing throws. (Tasks 2, 4)
4. **A young player who is first choice at one slot and an option at others.** Expected: his row says first choice there; he has no band against himself; he is never favoured as his own successor; his best slot is among the others. (Tasks 2, 4, 7)
5. **No confirmed lineups, or fewer than six in sixty days** (a new install; the command line with no history). Expected: no division by zero; a first or second choice counts as getting matches and anyone else does not; the planner's monthly stop never fires. (Tasks 3, 5, 6)

## File Structure

Engine (`LineupEngine/Sources/LineupEngine/`):

- Create `Advisors/Reach.swift`: the estimate. `Advisors/Development.swift`: outlooks, matches here.
- Create `Reporting/AdvisorText+Development.swift`: every new sentence.
- Modify `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift` (checks), `Planner/StartHistory.swift`, `Advisors/Removal.swift`, `Advisors/Advisors.swift`, `Reporting/AdvisorText.swift`, `Planner/PlanInputs.swift`, `Planner/ImportanceRules.swift`, `Planner/Planner.swift`, `Selection/Adjustment.swift`, `Sources/lineup-cli/main.swift`, `Sources/lineup-cli/Report.swift`.

App (`LineupApp/Sources/`): `LineupAppCore/RemovalPresentation.swift`, `AppModel+Marks.swift`, `SettingsPresentation.swift`, `SampleData.swift`; `LineupAppUI/Advice/RemovalScreen.swift`, `Settings/SettingsScreen.swift`, `Theme.swift`; `LineupApp/main.swift`.

---

### Task 1: The reach estimate

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Advisors/Reach.swift`
- Modify: `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/ReachTests.swift` (new), `EngineParametersTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct GrowthStep: Equatable, Sendable { public let upToAge: Int; public let points: Double }

  public struct ReachEstimate: Equatable, Sendable {
      public let age: Int, current: Int, potential: Int
      public let professionalism: Int, ambition: Int, determination: Int
      /// The growth expected in the season he is in now, before the cap at his potential.
      public let seasonGrowth: Double
      /// His ability after each coming season: index 0 is today. Never above his potential (or below today's ability).
      public let bySeason: [Double]
      public var reach: Double { bySeason.last! }
      /// True when the cap, not his rate of growth, is what limits him.
      public let reachesPotential: Bool
  }
  public enum Reach {
      public static func estimate(for player: Player, parameters: EngineParameters) throws -> ReachEstimate
  }
  ```
- Parameters added (names are used by later tasks):

  | Name | Value | Evidence | Source to quote |
  |---|---|---|---|
  | `developingUpToAge: Int` | 23 | carriedOverFM26 | 18 to 23 as one band that needs matches (`player-rotation-guide.md`) |
  | `growthPerSeason: [GrowthStep]` | up to 18: 18; up to 20: 14; up to 26: 12 | derived | EBFM tests in `fm27-development-matches-vs-training.md` finding 3: 14 and 12 with 20 to 30 matches; 18 = 12 with no matches + 0.75 × 8 for youth-team matches (finding 4) |
  | `growthProfessionalismRates: [Int: Double]` | 1: 2.4, 10: 8.2, 20: 17 | carriedOverFM26 | `skill-potential-factors.md` |
  | `growthAmbitionAtOne: Double` | 0.731 | carriedOverFM26 | the research's finding 10 |
  | `growthDeterminationAtOne: Double` | 0.66 | carriedOverFM26 | finding 10 |
  | `growthPersonalityFullFrom: Int` | 10 | carriedOverFM26 | finding 10: no bonus above 10 |

Decisions:

- A season's growth = the step for his age that season × Professionalism factor × Ambition factor × Determination factor. The step is the first whose `upToAge` is at or above the age; past the last step there is no growth. Seasons run from his age now up to and including the last step's age (26), so a 16-year-old has eleven and a player of 27 or over has none (`bySeason` is then `[current]`).
- Professionalism factor: his rate ÷ the rate at 20, the rate read off straight lines between the anchors (Professionalism 15 is 12.6 ÷ 17). Ambition and Determination: `atOne` at 1, rising in a straight line to 1 at `growthPersonalityFullFrom`, 1 from there up.
- The cap: each season's ability is the smaller of the potential and the season before plus growth; where potential is below current ability every entry is the current ability. `reachesPotential` is true when the last entry equals the potential and the potential is above today's ability.
- A missing Professionalism, Ambition or Determination throws `RatingError.missingAttribute` naming him and the attribute.
- `FitnessModel.problems(in:)`: steps not empty, ages rising, points finite and at least 0; the three Professionalism anchors present at 1, 10 and 20 with rates above 0 and rising; the two `atOne` values in 0…1; `growthPersonalityFullFrom` in 2…20; `developingUpToAge` at least 1. One plain sentence each, as the others are.

- [ ] **Step 1: Write the failing tests** in `ReachTests`:
  - `theDesignsFirstWorkedPlayerReachesHisPotential`: aged 16, Professionalism 15, Ambition and Determination 10, ability 55, potential 140: `seasonGrowth` about 13.3 (±0.05), `reach == 140`, `reachesPotential`.
  - `theDesignsSecondWorkedPlayerReachesAboutHalf`: aged 16, Professionalism 3, Ambition 4, Determination 10, ability 40, potential 130: `reach` about 67 (±0.6), not `reachesPotential`.
  - `eachAgeStepIsUsedAtAndBesideItsBoundary` (ages 18, 19, 20, 21, 26, 27: season growth at Professionalism 20 is 18, 14, 14, 12, 12, and no season at 27).
  - `professionalismIsReadOffStraightLines` (1, 5, 10, 15, 20); `ambitionAndDeterminationCountOnlyBelowTen` (1, 5, 10, 15 for each); `aFactorOfOneChangesNothing`.
  - `reachIsNeverAbovePotentialNorBelowToday` (potential below current; potential equal to current; ability 0 with potential 100 gives a finite reach).
  - `aMissingPersonalityAttributeIsAnErrorNamingHim`.
  - `EngineParametersTests`: `theGrowthParametersAreListedWithEvidenceAndSource`; `growthParameterProblemsAreReported` (one bad value for each check).
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter "ReachTests|EngineParametersTests"`: expect a build failure.
- [ ] **Step 3: Implement** the parameters, their checks and `Reach.estimate`.
- [ ] **Step 4: Run** `cd LineupEngine && swift test`: all pass, no warnings.
- [ ] **Step 5: Commit**: "Estimate where a young player's ability could reach".

---

### Task 2: Outlooks: a young player against the first and second choice at his slots

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Advisors/Development.swift`
- Modify: `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/DevelopmentTests.swift` (new), `EngineParametersTests.swift`

**Interfaces:**
- Consumes: `Reach.estimate`; `SquadTiers` (`first`, `second`, `ratings`); `SlotAssignment`; `Retraining`; `LoanStatus.of`.
- Produces:
  ```swift
  public enum ReachBand: String, CaseIterable, Sendable { case close, onCourse, possible, notExpected }
  public enum ReachLevel: String, CaseIterable, Sendable { case couldPassFirst, couldMakeSecond, couldBeCover, markedlyLower }

  /// The player a young player is compared with at a slot.
  public struct Rival: Equatable, Sendable {
      public let player: PlayerID; public let name: String; public let age: Int
      /// His rating at the slot today.
      public let rating: Double
      /// What the young player must reach: the rival's own reach rating when he is developing too, `rating` otherwise.
      public let compared: Double
  }
  public struct SlotOutlook: Equatable, Sendable {
      public let slot: SlotID
      public let rating: Double                 // his full-fitness rating there today
      public let reachRating: Double            // rating × reach ÷ current ability
      public let isFirstChoice: Bool            // he is the first choice at this slot
      public let firstChoice: Rival?            // nil when he is it, or the slot has none
      public let secondChoice: Rival?           // nil when he is it, or the slot has none
      public let band: ReachBand?               // nil when `firstChoice` is nil
      public let pointsNeeded: Int?             // ability points to match the first choice today, rounded up; nil with no first choice, 0 when already level
      public let level: ReachLevel?             // nil when `firstChoice` is nil
  }
  public struct Outlook: Equatable, Sendable {
      public let player: PlayerID
      public let estimate: ReachEstimate
      public let slots: [SlotOutlook]           // the slots he can play, in the tactic's order
      /// Among slots with a first choice who is not him: the one where reachRating ÷ firstChoice.compared is greatest (earlier slot on a tie).
      public let best: SlotOutlook?
      /// `best`'s level; with no such slot and no slot he is first choice at, from his reach against `average`; nil when his only slots are ones he is first choice at.
      public let level: ReachLevel?
      /// The first team's average ability he was compared with, when `best` is nil and he has no slot.
      public let average: Double?
      public var isMarkedlyLower: Bool { level == .markedlyLower }
  }
  public enum Development {
      /// The mean current ability of the club's own first-team players; nil when there is none.
      public static func averageAbility(of players: [Player], ownClub: String?) -> Double?
      /// An outlook for each player of the club's own, not out on loan, aged `developingUpToAge` or under, with a current ability above 0.
      public static func outlooks(players: [Player], ownClub: String?, assignments: [SlotAssignment], tiers: SquadTiers,
                                  retraining: [Retraining], parameters: EngineParameters) throws -> [PlayerID: Outlook]
  }
  ```
- Parameters added:

  | Name | Value | Evidence | Source |
  |---|---|---|---|
  | `onCourseBeforeAge: Int` | 24 | carriedOverFM26 | the target age Player Removal already uses (`player-retention-strategy.md` 3.1) |
  | `markedlyLowerShare: Double` | 0.80 | carriedOverFM26 | "cover can be about 20% worse than the first choice", as `retrainingMinimumShare` |
  | `markedlyLowerShareYoungest: Double` | 0.70 | derived | the design, 7.1: the estimate is weakest for the youngest |
  | `youngestUpToAge: Int` | 16 | derived | the design, 7.1 |

  The fallback share against the average is the existing `removalRules.farBelowAverageShare` (0.85).

Decisions:

- **A slot he can play**: his familiarity is at least `depthCoverFamiliarity` at the slot's in-possession position and at its out-of-possession position, or he has a retraining entry for either of those positions. `tiers` must be worked out with injured players kept in (the caller's duty; say so in the doc comment).
- **Compared rating of a rival**: when the rival is himself in the outlooks' population (own, developing age, ability above 0), his rating at the slot × his reach ÷ his ability; otherwise his rating today.
- **Level at a slot** (needs a first choice who is not him): `couldPassFirst` when reachRating ≥ firstChoice.compared; else `couldMakeSecond` when there is no second choice, he is the second choice, or reachRating ≥ secondChoice.compared; else `couldBeCover` when reachRating ≥ bar × firstChoice.compared; else `markedlyLower`. The bar is `markedlyLowerShareYoungest` for a player aged `youngestUpToAge` or under and `markedlyLowerShare` otherwise. Comparisons allow for rounding (`+ 1e-9`), as `ImportanceRules.development` does today.
- **`Outlook.level`**: the best level over his slots that have one (`couldPassFirst` best), which is `best`'s unless another slot has a better one; he is markedly lower only when every such slot is. With no slot at all: `couldMakeSecond` when reach ≥ the average, `couldBeCover` when reach ≥ `farBelowAverageShare` × the average or there is no average, else `markedlyLower`.
- **Band at a slot**: walk forward one season at a time through `estimate.bySeason` (index k is k seasons on). His rating that season is rating × bySeason[k] ÷ current. The first choice's is `compared` walked the same way when he is developing (rating × his bySeason[k] ÷ his current, holding his last value once his seasons run out) and `rating` otherwise. `close` when he is ahead at k = 0 or 1; `onCourse` when he is first ahead at a k with age + k < `onCourseBeforeAge`; `possible` when rating × potential ÷ current ≥ `firstChoice.compared` and he is neither; `notExpected` otherwise.
- `pointsNeeded` = ceil(current × (firstChoice.rating ÷ rating − 1)), never below 0; nil when his rating there is 0.

- [ ] **Step 1: Write the failing tests** in `DevelopmentTests`, building `SquadTiers(first:second:ratings:)` by hand as `ImportanceRulesTests` does:
  - `aSlotCountsWhenHeIsAnOptionInBothPhasesOrIsRetrainingThere` (familiarity 10/10 counts; 10/9 does not; 9/9 with a retraining entry does).
  - `eachLevelAtAndBesideItsBoundary` (reach rating equal to the first choice's, just under; equal to the second's, just under; at the bar, just under).
  - `thePlayerOfSixteenHasTheLowerBarAndThePlayerOfSeventeenDoesNot`.
  - `aMissingSecondChoiceCountsAsReached`; `aSlotWithNoFirstChoiceHasNoBandAndNoLevel`.
  - `heIsNotComparedWithHimself` (Review Focus 4: first choice at one slot, option at another: `isFirstChoice`, no band there, `best` is the other slot; first choice at his only slot: `best` and `level` nil).
  - `aYoungFirstChoiceIsComparedAtHisOwnReach` (the same youngster is `couldPassFirst` behind a 28-year-old and not behind a 20-year-old of equal rating who grows as fast).
  - `eachBand` (`close` at one season, `onCourse` at 23 and not at 24, `possible`, `notExpected`), and `theBandWalksAYoungFirstChoiceForwardToo`.
  - `hisBestSlotIsWhereHisReachIsTheGreatestShare`, and the earlier slot on a tie.
  - `withNoSlotHeIsComparedWithTheAverage` (at the average, at 85% of it, under; no average gives `couldBeCover`) (Review Focus 3).
  - `whoGetsAnOutlook` (a loanee here, a player out on loan, a player of 24, and one with ability 0 get none) (Review Focus 2).
  - `pointsNeededIsRoundedUpAndNeverNegative`.
  - `EngineParametersTests`: the four parameters listed; their problems reported (shares in 0…1 with the youngest's not above the other; ages at least 1).
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter "DevelopmentTests|EngineParametersTests"`: expect a build failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `cd LineupEngine && swift test`: all pass, no warnings.
- [ ] **Step 5: Commit**: "Compare a young player's reach with the first and second choice at each slot he can play".

---

### Task 3: Whether a player is getting matches here

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Planner/StartHistory.swift`, `Advisors/Development.swift`, `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift`
- Test: `StartHistoryTests.swift`, `DevelopmentTests.swift`, `EngineParametersTests.swift`

**Interfaces:**
- Produces:
  ```swift
  // StartHistory
  /// How many lineups dated in the `days` days ending on `day` (that day included) he started.
  public func starts(of player: PlayerID, inDays days: Int, endingOn day: Day) -> Int
  /// How many lineups are dated in that time.
  public func matches(inDays days: Int, endingOn day: Day) -> Int

  // Development
  public struct MatchesHere: Equatable, Sendable {
      public let starts: Int; public let matches: Int
      /// False when too few matches were confirmed to judge by, and his place in the elevens decided it.
      public let isCounted: Bool
      public let isEnough: Bool
  }
  public static func matchesHere(for player: PlayerID, tiers: SquadTiers, history: StartHistory, asOf: Day,
                                 parameters: EngineParameters) -> MatchesHere
  ```
- Parameters: `matchesHereShare: Double` 1.0 / 3 (derived: about the 15 full matches a season the research gives as the least for a player of 21 or over, of a season of about 46); `matchesHereWindowDays: Int` 60 (derived); `matchesHereMinimumConfirmed: Int` 6 (derived).

Decisions: a first choice at any slot has enough, whatever he has started. Otherwise, with at least `matchesHereMinimumConfirmed` matches in the window, enough means starts ÷ matches ≥ the share (compare `starts × 3 ≥ matches` in whole numbers when the share is a third; in general `Double(starts) + 1e-9 >= share × Double(matches)`). With fewer, `isCounted` is false and a second choice has enough and anyone else does not. Checks: the share in 0…1, the two counts at least 1.

- [ ] **Step 1: Write the failing tests**: `startsAndMatchesAreCountedInTheWindowWithItsLastDayIn` (a lineup on the first day of the window, the day before it, the last day, the day after); `aFirstChoiceHasEnoughWhateverHeStarted`; `aThirdOfSixIsEnoughAndOneOfSixIsNot`; `withFewerThanSixConfirmedHisPlaceDecides` (none confirmed: second choice enough, backup not; five confirmed and he started all five but is a backup: not counted, not enough) (Review Focus 5); the parameters listed and their problems reported.
- [ ] **Step 2: Run** the three suites: expect a build failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `cd LineupEngine && swift test`: all pass, no warnings.
- [ ] **Step 5: Commit**: "Tell whether a player is getting matches here from the confirmed lineups".

---

### Task 4: Player Removal scores a young player from his outlook

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Removal.swift`, `Advisors/Advisors.swift`, `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift`, `Sources/lineup-cli/main.swift`
- Create: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Development.swift`
- Test: `RemovalTests.swift`, `AdvisorsTests.swift`, `EndToEndTests.swift`, `EngineParametersTests.swift`, `AdvisorTextTests.swift`; the app's tests that build a `RemovalAdvice` or call `Removal.report` must still build (`LineupApp/Tests/LineupAppCoreTests/RemovalPresentationTests.swift` and any other the compiler names)

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces:
  ```swift
  // Removal: both entry points gain, after `money:`
  history: StartHistory, asOf: Day, retraining: [Retraining]
  // RemovalAdvice gains (and loses `isProspect`)
  public let outlook: Outlook?            // nil for a player of 24 or over, or with ability 0
  public let matchesHere: MatchesHere?    // with an outlook only
  // AdvisorText (in AdvisorText+Development.swift)
  public static func reachLine(_ outlook: Outlook, names: (SlotID) -> String) -> String   // the sentence of design 7.1's table for his level
  public static func name(_ band: ReachBand) -> String        // "Close", "On course", "Possible", "Not expected"
  ```
  `names` gives a slot's position in plain words; `Removal` passes what it uses for the tier line today (`PositionText.plain`).
- `Advisors.report` hands Removal `request.history`, `request.asOf` and `request.accepted`. The command line keeps `accepted: []`.
- `RemovalRules`: `prospectUpToAge`, `strongProspectRoomFrom` and its points, `prospectRoomFrom` and its points, and `falseProspectPoints` are removed; `stallingFromAge` becomes 24. The false-prospect test's four numbers stay.

Decisions, for a player with an outlook (the rest are scored exactly as today):

- **One line in place of three.** The tier line is worked out as today (−40, −20, +15) and the reach line from `outlook.level` (`couldPassFirst` −40, `couldMakeSecond` −20, `couldBeCover` +15, `markedlyLower` +70: the four are `firstElevenPoints`, `secondElevenPoints`, `neitherElevenPoints` and the sum `neitherElevenPoints + weakestPoints + farBelowAveragePoints`, read from the rules, not written again). The one with fewer points is added; on a tie, the tier line. With `outlook.level` nil the tier line stands. The weakest-30% line and the ability-against-average line are not added.
- **The reach line's sentences** (`AdvisorText.reachLine`): "Could pass Smith at left back", "Could make the second eleven at left back", "Could become cover at left back, no more", "Not expected to reach the level of the squad at any position"; with no slot: "Could reach the level of the first team", "Could come close to the level of the first team, no more", "Not expected to reach the level of the first team". The slot named is the one that gives the level (`best`, or the slot with the better level).
- **Professionalism and Ambition** add no line.
- **Contract ending**: where the line added above is −40 or −20, the contract line reads "Contract ends in N months: renew it" with 0 points; otherwise as today.
- **False prospect**: `isFalseProspect` is set by the same test as today and adds no line. The prospect line and `isProspect` are gone.
- **Stalling** applies at 24 only (the parameter change), so never to a player with an outlook.
- Thin cover, wage, Consistency, Important Matches, Injury Proneness, Controversy, Temperament, and the levels are untouched. `matchesHere` is filled from `Development.matchesHere` with the report's tiers.
- **The action is not changed in this task** beyond what compiles: where today's code reads `isProspect && !isFalseProspect`, a player with an outlook now falls through to terminate or sell. Task 5 gives the young their own advice.

- [ ] **Step 1: Write and change the tests.** New in `RemovalTests`: `aYoungPlayerIsScoredOnOneLineFromHisReach` (each of the four levels: the points, the sentence, and no weakest or ability line); `theBetterOfHisPlaceAndHisReachIsUsed` (in the second eleven with reach past the first choice: −40 with the reach sentence; in the first eleven: the tier sentence); `professionalismAndAmbitionDoNotCountAgainstAYoungPlayerAndStillDoAtTwentyFour`; `aShortContractOnAPlayerWorthKeepingSaysRenewIt` (−20 line: 0 points and the sentence; +15 line: the points as today); `aMarkedlyLowerPlayerNeededForDepthIsWatched` (70 − 30 = 40, medium) and `oneNotNeededScoresSeventy`; `aPlayerWithAbilityZeroIsScoredAsAnOlderPlayer` (Review Focus 2); `aSquadSmallerThanTheTacticStillScoresItsYoungPlayers` (Review Focus 3); `stallingAppliesAtTwentyFourAndNotAtTwentyThree`. Change the tests the old rules pinned (`aFalseProspectAddsThirtyFive`, `aProspectTakesPointsOff`, `aPlayerOfTwentyThreeOrFourWithLittleRoom…`, `aProspectAtHighIsLoanedOut`, `aFalseProspectAtHighIsNotLoanedOut`, `aContractTypeTheToolDoesNotRead…`, `thePlayersAdvisedToLeave…`, `inputOrderDoesNotMatter`, and any other the suite shows): keep what each was checking where the rule still exists, and replace it with the new rule's test where it does not; list each in the report with what it checks now. `EngineParametersTests.theRemovalParametersAreListedWithEvidenceAndSource` follows the rules' new shape. `AdvisorTextTests`: the seven sentences and the four band names.
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter "RemovalTests|AdvisorsTests|AdvisorTextTests|EngineParametersTests"`: expect a build failure.
- [ ] **Step 3: Implement.** Update every caller of the two entry points, in both packages.
- [ ] **Step 4: Run** `cd LineupEngine && swift test`; `cd LineupApp && swift build && swift test`: all pass, no warnings. Where a test on the captures expected somebody to be advised to leave and nobody now is, do not loosen it: report it, with who was advised before and what he gets now.
- [ ] **Step 5: Commit**: "Score a young player in Player Removal on where he could reach, not on today's ability".

---

### Task 5: The advice for a young player, youth contracts, and the words

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Removal.swift`, `Reporting/AdvisorText.swift`, `Reporting/AdvisorText+Development.swift`, `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift`, `Sources/lineup-cli/Report.swift`
- Modify (to build): `LineupApp/Sources/LineupAppCore/RemovalPresentation.swift` and any other app file with a `switch` over `RemovalAction`
- Test: `RemovalTests.swift`, `AdvisorTextTests.swift`, `EndToEndTests.swift`, `EngineParametersTests.swift`

**Interfaces:**
- Consumes: Task 4.
- Produces:
  ```swift
  public enum RemovalAction: String, CaseIterable, Sendable {
      case release, terminate, sell, monitor, develop, play, loanForMatches, keep     // `loan` is removed
  }
  /// Why a young player worth developing who is not getting matches is kept and not loaned.
  public enum KeepReason: String, CaseIterable, Sendable { case age, youthContract, shortContract }
  // RemovalAdvice gains
  public let keepReason: KeepReason?
  // AdvisorText
  name(.develop) == "Keep and develop"; name(.play) == "Keep and play"; name(.loanForMatches) == "Loan for matches"
  public static func reachWorking(_ estimate: ReachEstimate) -> String
  public static func standing(_ outlook: Outlook, names: (SlotID) -> String) -> String?     // nil when he has no slot with a first choice to pass
  public static func matchesHere(_ matches: MatchesHere) -> String
  public static let youthContractNotMarked = "A player on a youth contract cannot be sold or loaned out, only released."
  ```
- Parameters: `loanForMatchesFromAge: Int` 18 (carriedOverFM26: the research's recommendation 1); `loanForMatchesMonthsAbove: Int` 12 (derived).

Decisions, for a player with an outlook:

- **At the high or critical level**: no contract (as today) or a youth contract gives `release`; otherwise a false prospect gives `sell`; otherwise today's terminate-or-sell rule.
- **Below it**, in this order:
  1. Not worth developing (his level is `couldBeCover` or `markedlyLower`, and he is in neither eleven): `monitor`.
  2. Aged under `loanForMatchesFromAge`: `develop`, `keepReason` `.age`.
  3. `matchesHere.isEnough`: `play`.
  4. The thin-cover line was added for him: `monitor`.
  5. On a youth contract: `develop`, `.youthContract`.
  6. Months left unknown or at most `loanForMatchesMonthsAbove`: `develop`, `.shortContract`.
  7. Otherwise `loanForMatches`.
- `advisedToLeave` and the wages at stake keep their rule (high or critical, and an action that moves him on): `release`, `terminate`, `sell` move him on; the others do not. A loan for matches is therefore never in either.
- A player of 24 or over gets `release`, `terminate`, `sell`, `monitor` or `keep`, as today (the old `loan` could only reach a player of 21 or under).
- **Words.**
  - `reachWorking`: "Ability 55, potential 140. At 16 with Professionalism 15 this tool expects about 13 points a season now, fewer later: could reach his potential." Its ending is one of: "could reach his potential." / "could reach about 67. At his Professionalism this tool expects about 3 points a season; mentoring could change that." (Professionalism under 10) / "could reach about 96." (otherwise) / "His potential is the limit." in place of the "could reach" clause when potential − current is under one season's growth. An Ambition or Determination under 10 is named after the Professionalism ("…with Professionalism 15 and Ambition 4…"). A player past the last growth step: "Ability 90, potential 95. At 27 this tool expects no more growth."
  - `standing`: for `best`: "Needs about 14 more ability points to match Smith at left back; this tool expects about 12 a season. On course." A first choice of 30 or over adds " Smith is 31." A first choice who is developing adds " Smith is 20 and still growing." Where he is first choice at a slot the sentence begins "First choice at striker." and the rest follows only if `best` is not nil.
  - `matchesHere`: "He has started 1 of the last 9 matches here." (`isCounted`); otherwise "Too few matches are confirmed to count his starts."
  - `why(_:for:)`: `develop` by `keepReason`: "At his age he grows mainly in training; a loan would add little." / "He is not getting matches here, and a loan needs a full-time contract." / "He is not getting matches here: renew his contract before a loan." `play`: "He is getting his matches here." `loanForMatches`: "He is worth developing and is not getting matches here: a loan gives him matches." and, aged exactly `loanForMatchesFromAge`, " Only where he will start regularly; otherwise he grows nearly as well here."
- **The command line**: after the critical and high rows, a "Young players" part: every advice with an outlook, in the report's order: name, age, the action's name, then `reachWorking`, `standing` when not nil, `matchesHere` for `play`, `develop` (not `.age`) and `loanForMatches`, and `why`.

- [ ] **Step 1: Write the failing tests.** `RemovalTests`: one test for each of the seven steps with a case that gets it and the nearest case that does not (`aSeventeenYearOldWorthKeepingIsDevelopedAndAnEighteenYearOldIsNot`; `aPlayerGettingMatchesIsKeptToPlay`; `oneNeededForDepthIsWatchedNotLoaned`; `aYouthContractIsNeverLoanedOrSold` (below the high level and above it: `develop` and `release`); `twelveMonthsLeftKeepsHimAndThirteenLoansHim`, with unknown months; `aPlayerNotWorthDevelopingIsWatched`); `aFalseProspectIsSoldNotTerminated`; `aLoanForMatchesIsNotAdvisedToLeaveAndHisWageIsNotAtStake`; `withNoConfirmedLineupsASecondChoiceIsKeptToPlay` (Review Focus 5); `aPlayerOfTwentyFourNeverGetsTheYoungPlayersAdvice`. `AdvisorTextTests`: each sentence above, whole, including each ending of `reachWorking` and each `why`; the three new names; `standing` nil for a player with no slot. `EndToEndTests`: `theYoungPlayersOfTheCapturedSquadsEachHaveAnOutlookAndAnAdvice` (every own player of 23 or under in the first-team and U21 captures has an outlook, none is `terminate` or `sell` without being at the high level, none is `loanForMatches` with 12 months or fewer left).
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter "RemovalTests|AdvisorTextTests|EndToEndTests"`: expect a build failure.
- [ ] **Step 3: Implement**, then make the app build: give `RemovalPresentation` what its switches need for the new cases with the least that compiles (Task 8 does the rest).
- [ ] **Step 4: Run** both suites in full: all pass, no warnings.
- [ ] **Step 5: Look at the captured squads.** Run the `advise` command from `CLAUDE.md`. In the report, list every player of 23 or under by age and squad (no names: "first team, 21, central midfield") with his level, band, action and score now, beside the action and score he had before this plan (the controller supplies the command's output from before Task 4). Say plainly if any advice looks wrong to you and why; do not change a rule to fix it.
- [ ] **Step 6: Commit**: "Advise a young player to be developed, played, loaned for matches or released, and never sell or loan a youth contract".

---

### Task 6: The planner's favour by age, the Development setting, and the monthly stop

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Planner/PlanInputs.swift`, `Planner/ImportanceRules.swift`, `Planner/Planner.swift`, `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift`, `Reporting/AdvisorText+Development.swift`, `Sources/lineup-cli/main.swift`, `Sources/lineup-cli/Report.swift`
- Test: `PlanInputsTests.swift`, `ImportanceRulesTests.swift`, `PlannerScenarioTests.swift`, `EngineParametersTests.swift`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces:
  ```swift
  // PlanSettings gains, with its own init(from:) reading a missing key as 1
  public var development: Double        // 0...1, default 1
  // RuleContext gains (defaults keep today's call sites building)
  public var outlooks: [PlayerID: Outlook] = [:]
  public var development: Double = 1
  // AgeFactor
  public struct AgeFactor: Equatable, Sendable { public let upToAge: Int; public let factor: Double }
  ```
- Parameters: `developmentFactors: [AgeFactor]` up to 17: 1.02; up to 20: 1.07; up to 23: 1.10 (derived, from the research's growth per 90 minutes by age: 0.1, 0.35, 0.5); `developmentFactorLowProfessionalism: Double` 1.04 with `developmentLowProfessionalismUpTo: Int` 14 and `developmentLowProfessionalismUpToAge: Int` 17 (derived; the research's recommendation 3); `developmentStartsPerMonth: Int` 4 and `developmentMonthDays: Int` 30 (carriedOverFM26: the game reads at most 150 match points a month). `prospectMaxAge` and `developmentFactor` are removed; `prospectHeadroom` stays.
- The planner works out, once for each fixture, tiers with injured players kept in and from them `Development.outlooks` for the fixture's tactic, and hands them to the rules with `settings.development`. The tiers it already has (injured left out) are used for everything they are used for today.
- The command line: `plan` takes `--development <0…1>`; the plan's header prints it beside the other settings; the usage text names it.

Decisions:

- **The floor** replaces today's `development` rule, in low and sharpness fixtures only, in every slot: for a player aged `developingUpToAge` or under whose potential is at least `prospectHeadroom` × his ability, who has an outlook that is not markedly lower. The factor is the first step at or above his age; a player aged `developmentLowProfessionalismUpToAge` or under with Professionalism at most `developmentLowProfessionalismUpTo` gets `developmentFactorLowProfessionalism`. A player with no outlook (ability 0) gets none.
- **The setting** scales it: 1 + (factor − 1) × `development`. At 0 there is no adjustment and no reason.
- **The stop**: no favour once `history.starts(of:inDays: developmentMonthDays, endingOn: the day before the fixture)` is at least `developmentStartsPerMonth`. The history the planner holds grows with each lineup it plans, so planned starts count.
- **The reason**, from `AdvisorText`: "Young player with room to grow: favoured for minutes (×1.07)".
- **A mark on a youth-contract player** is ignored by `shopWindow`.
- `PlanSettings.problems()`: "Development must be between 0 and 1, but is X", as the others read.

- [ ] **Step 1: Write the failing tests.** `PlanInputsTests`: `settingsSavedBeforeDevelopmentReadAsOne` (Review Focus 1: decode JSON with the four old keys only; development is 1 and the rest as given; encoding writes the key); `developmentOutOfRangeIsReported`. `ImportanceRulesTests`: `theFavourFollowsHisAge` (17, 18, 20, 21, 23: 1.02, 1.07, 1.07, 1.10, 1.10; 24: none); `aYoungTeenagerWithLowProfessionalismIsFavouredMore` (17 with 14: 1.04; with 15: 1.02; 18 with 14: 1.07); `aMarkedlyLowerPlayerIsNotFavoured`; `nothingAtMediumOrHigh`; `theSettingScalesTheFavourAndZeroGivesNoReason` (0.5 gives 1.05 for a 21-year-old); `afterFourStartsInThirtyDaysHeIsNotFavouredAndAfterThreeHeIs`, with a start 31 days back not counting (Review Focus 5: no history favours him); `aMarkOnAYouthContractPlayerIsIgnored`. Change `aProspectIsFavouredInALesserFixture`, `anOlderOrLimitedPlayerIsNotAProspect`, `aPotentialExactlyAtTheHeadroomCountsDespiteRounding`, `aMarkedProspectGetsBothAndInKindOrder`, `adjustmentsComeBackInKindOrder` and `PlannerScenarioTests.youngProspectsGetTheLowFixture` to the new sizes and inputs, keeping what each checks. `EngineParametersTests`: the new parameters listed, the removed ones gone, problems reported (steps rising, factors finite and at least 1).
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter "PlanInputsTests|ImportanceRulesTests|PlannerScenarioTests|EngineParametersTests"`: expect a build failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both suites in full: all pass, no warnings.
- [ ] **Step 5: Commit**: "Favour a young player by what a match is worth at his age, scaled by a Development setting".

---

### Task 7: A successor is favoured more, at his slot

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Selection/Adjustment.swift`, `Planner/ImportanceRules.swift`, `Planner/Planner.swift`, `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift`, `Reporting/AdvisorText+Development.swift`
- Test: `ImportanceRulesTests.swift`, `PlannerScenarioTests.swift`, `EngineParametersTests.swift`

**Interfaces:**
- Consumes: Task 6.
- Produces: `Adjustment.Kind.successor`, placed after `development`; `RuleContext.successorsFavoured: Set<PlayerID>? = nil` (nil means no cap applies); `ImportanceRules.successors(players:context:parameters:) -> Set<PlayerID>`, which the planner calls before building adjustments for a medium fixture.
- Parameters: `successorFactorLow: Double` 1.15 (derived: the size of `retrainingFactorLow`); `successorFactorMedium: Double` 1.05 (derived: the design, section 8); `successorsFavouredAtMedium: Int` 2 (derived); `successorCloseOnlyUpToAge: Int` 17 (derived).

Decisions:

- **A successor at a slot**: he has an outlook that is not markedly lower, he is not the first choice at that slot, and his band there is `close` or `onCourse` (`close` only for a player aged `successorCloseOnlyUpToAge` or under).
- **The favour**, per slot: at a slot where he is a successor he gets a `successor` adjustment in place of the floor: `successorFactorLow` in low and sharpness fixtures, `successorFactorMedium` in medium, nothing in high; scaled by the setting like the floor; stopped by the monthly stop like the floor. So the floor becomes a per-slot adjustment too: at each slot he gets the successor's favour or the floor, never both. Reason: "On course to pass Smith at left back: favoured for matches there (×1.05)", with "Close to passing Smith…" for `close`.
- **With retraining**: at a slot where he has both a retraining adjustment and a successor adjustment, only the one with the larger factor is kept (retraining on a tie). The floor and retraining still multiply, as today.
- **The cap at medium**: `successors` returns, among the players who are a successor at some slot of the fixture's tactic and not stopped, the `successorsFavouredAtMedium` closest to their first choice (the greatest of rating ÷ firstChoice.rating over their successor slots; then the lower key). In a medium fixture only they get the favour. Low and sharpness fixtures have no cap.
- **Sharpness**: at a sharpness fixture a successor at any slot counts as in the elevens for the favour to a player who needs sharpness, and not for the mark-down of a fully sharp player.

- [ ] **Step 1: Write the failing tests.** `ImportanceRulesTests`: `aSuccessorIsFavouredAtHisSlotInPlaceOfTheFloor` (1.15 at that slot, the floor at his others, never both); `atMediumHeGetsFivePercentAndTheFloorGivesNothing`; `nothingAtHigh`; `aSeventeenYearOldNeedsToBeClose` (on course at 17: the floor only; close at 17: the favour; on course at 18: the favour); `aFirstChoiceIsNotHisOwnSuccessor` (Review Focus 4); `aPossibleOrNotExpectedPlayerGetsOnlyTheFloor`; `theLargerOfRetrainingAndSuccessorIsKept` (low: equal factors, retraining kept; medium: retraining 1.08 kept over 1.05; with retraining's familiarity outside its range the successor's stands); `theFloorAndRetrainingStillMultiply`; `onlyTheTwoClosestSuccessorsAreFavouredAtMedium`, the tie broken by key, and all three favoured in a low fixture; `aSuccessorCanBeGotSharpAndIsNotMarkedDownForBeingSharp`; `theSettingAndTheMonthlyStopApplyToTheSuccessorToo`. `PlannerScenarioTests`: `aSuccessorAtOneHundredAgainstOneHundredAndFourStartsAMediumFixture` and `atNinetyEightHeDoesNot` (the design's example, the pick's reason quoted); `heDoesNotStartAHighFixtureOnIt`; `withDevelopmentAtZeroTheLineupIsTheOneWithoutTheRule`.
- [ ] **Step 2: Run** the three suites: expect a build failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both suites in full: all pass, no warnings.
- [ ] **Step 5: Run the `plan` command from `CLAUDE.md`** on the captured squad, with and without `--development 0`, and put in the report which picks differ and their reasons.
- [ ] **Step 6: Commit**: "Favour a likely successor at his slot, a little in ordinary matches and never in the biggest".

---

### Task 8: The app's Core: the Young players part, marks, and the setting

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/RemovalPresentation.swift`, `AppModel+Marks.swift`, `SettingsPresentation.swift`, `SampleData.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/RemovalPresentationTests.swift`, `SaleMarksTests.swift`, `SettingsPresentationTests.swift`, `StoreTests.swift` or `AppModelTests.swift`

**Interfaces:**
- Consumes: Tasks 4 to 7.
- Produces:
  ```swift
  public struct YoungRow: Identifiable, Equatable, Sendable {
      public let id: PlayerID
      public let titleText: String        // "Tom Reed · 16 · striker"; the position is his best slot's, left out when he has none
      public let actionText: String       // the engine's name for his action
      public let lines: [String]          // reachWorking, standing, matchesHere (as the command line shows it), why: the engine's sentences
      public let spokenText: String
  }
  // RemovalSheet gains
  public let young: [YoungRow]            // oldest first, then by name
  // RemovalPresentation
  public static let youngHeading = "Young players"
  public static let youngExplanation: String      // one plain line: who is listed and that the figures are this tool's estimate
  public static let youngEmptyText = "No player of 23 or under."
  // RemovalRow gains
  public let markRefusalText: String?     // the engine's sentence for a youth-contract player; nil otherwise
  // AppSettings (SettingsPresentation)
  public static func developmentText(_ value: Double) -> String    // "Off" at 0, otherwise a percentage: "100%"
  // SampleData
  static func modelWithYoungPlayers(repositoryRoot: URL) throws -> AppModel
  ```

Decisions:

- `setMark` ignores a mark for a player on a youth contract, as it ignores one for a loanee. `dropSpentMarks` drops a mark whose player is on a youth contract. `RemovalRow.markRefusalText` is `AdvisorText.youthContractNotMarked` for such a player, so the view shows the sentence where the control would be.
- A `RemovalRow`'s action text is the engine's name for the action, so the new actions need no rule in Core.
- `modelWithYoungPlayers`: the sample squads with a few players changed through the pastes before import, as `modelWithLoanee` changes one: a 16-year-old on a `Youth` contract worth developing; a 16-year-old on a `Youth` contract who is markedly lower; a 19-year-old with more than 12 months left who is worth developing and has not started; with enough confirmed lineups for starts to be counted. Its test asserts on the engine's report that the four actions `develop`, `release`, `loanForMatches` and `play` each appear.
- The age that heads `youngEmptyText` and the explanation is read from the engine's parameter, not written as 23.

- [ ] **Step 1: Write the failing tests.** `RemovalPresentationTests`: `theYoungPartListsEveryPlayerWithAnOutlookOldestFirst`; `aYoungRowCarriesTheEnginesSentencesAsWritten` (each line equal to the `AdvisorText` call); `aYoungRowNamesHisBestPositionInWordsAndNeverAKey`; `aRowsActionIsTheEnginesNameForEachNewAction`; `aYouthContractRowCarriesTheRefusalAndOthersDoNot`; `theSampleWithYoungPlayersShowsEachAdvice`. `SaleMarksTests`: `aYouthContractPlayerCannotBeMarked`; `aMarkIsDroppedWhenItsPlayerIsImportedOnAYouthContract`. `SettingsPresentationTests`: `developmentReadsAsAPercentageAndOffAtZero`. Store: `settingsSavedBeforeDevelopmentOpenWithNoNoticeAndLoseNothing` (Review Focus 1: save settings, strip the `development` key from the file on disk, reopen: no notice, every setting as saved, development 1; change a setting and the file has the key), on the pattern of `aMentoringFileFromTheInstalledAppOpensWithNoNoticeAndLosesNothing`.
- [ ] **Step 2: Run** `cd LineupApp && swift test --filter "RemovalPresentationTests|SaleMarksTests|SettingsPresentationTests|StoreTests"`: expect a build failure.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `cd LineupApp && swift build && swift test`: all pass, no warnings.
- [ ] **Step 5: Commit**: "Show young players' reach and advice, refuse a mark on a youth contract, and keep the Development setting".

---

### Task 9: The screens and their pictures

**Files:**
- Modify: `LineupApp/Sources/LineupAppUI/Advice/RemovalScreen.swift`, `Settings/SettingsScreen.swift`, `Theme.swift`, `LineupApp/Sources/LineupApp/main.swift`

**Interfaces:**
- Consumes: Task 8.

What is drawn:

- **Player Removal.** A Young players part between the main table and "Loans to the club", in the style of the loans part: the heading, the one-line explanation, then a block for each `YoungRow`: its title in the name's weight with the action at the right as the loans' verdict is shown, and its lines beneath in the body's ink. The empty text when there is none. No level stamp in this part.
- **An opened row** of a youth-contract player shows `markRefusalText` where the mark control is for others. The view shows one or the other by the optional alone.
- **Settings.** "Development" under "Saving players", a slider from 0 to 1 in steps of 0.05 with `AppSettings.developmentText` as its readout and the ends labelled "Off" and "Full", bound like Stability.
- The view asks Core for everything: no `if` about data beyond showing or hiding what Core gave as optional or empty.

Pictures, drawn in `main.swift` beside the other removal variants and named in its usage text: `removal-young` (the sample with young players, tall enough to show the whole part), `removal-young-open` (the same with every row open, showing the refusal on a youth-contract row), and the existing `removal-*` and `settings-*` pictures, which change.

- [ ] **Step 1: Implement** the views and the picture variants.
- [ ] **Step 2: Run** `cd LineupApp && swift build && swift test`: all pass, no warnings.
- [ ] **Step 3: Draw and look.** `swift run -q LineupApp --sample-data .. --pictures .build/pictures-development`. Open the light one of `removal-young`, `removal-young-open`, `removal-all-open`, `removal-loanee`, `removal-marked`, `settings` and `settings-narrow`, and one narrow removal picture. Check: each young player's block reads top to bottom as who he is, what the tool expects, how he stands, what to do; long sentences wrap and are not cut; the part is told apart from the table above and the loans below; nothing overlaps at the narrow width; the refusal sits where the mark control would be; the new slider lines up with its neighbours. Fix what is wrong and draw again. Say in the report which pictures were opened and what changed after looking.
- [ ] **Step 4: Commit**: "Draw the Young players part of Player Removal and the Development setting".

---

### Task 10: Documents, and the plan closed

Documents only. If source code seems to need changing, stop and report it.

**Files:**
- Modify: `CLAUDE.md`; this plan (its closing sections); the design (its Status line only)

- [ ] **Step 1: Run everything**: both suites and the full picture run to `LineupApp/.build/pictures-development`. Put the three results in the report.
- [ ] **Step 2: Update `CLAUDE.md`**, reading the code as built: this plan and its design in the list of plans; the research file is already covered by the Research line; in "How the engine works", the Planning bullet (the favour by age, the successor's favour and its limits, the Development setting, the monthly stop) and the Advisors bullet (Player Removal judges a player of 23 or under on his reach against his position's first and second choice; the four kinds of advice; youth contracts kept or released only; what replaced the prospect rules); the `plan` command's `--development`; in the app section, the Young players part, the mark refused on a youth contract, the setting, and `removal-young*` among the checked pictures in `.build/pictures-development`. Replace statements this plan made false; match the file's plain style.
- [ ] **Step 3: Close this plan**: fill the three sections below from what the tasks reported, in plain sentences with no task numbers, agent names or commit ids; mark the design built. Record that the install and the hands-on check are left to the controller and the owner.
- [ ] **Step 4: Commit**: "Close the young players' development plan: record what changed and what is left".

---

## After this plan

- The owner's own test of a 17-year-old kept against loaned (the research's last section) would replace the carried-over growth numbers with FM27 ones.
- A favour for players of 24 to 26, if the owner wants one.
- A bar that looks ahead to a promotion.

## What the advice showed on the captured squads

(Filled in from Tasks 5 and 7.)

## Changes made while building

(Filled in as the plan is built.)

## Known limits and small faults left

Known before building (the design's section 11):

- The growth numbers come from FM24 and FM26 tests whose conditions are mostly not stated; if the bases were measured on average players, reach is underestimated below Professionalism 20, which errs toward release.
- The estimate is weakest for the youngest. Professionalism can be raised by mentoring.
- A rating is assumed to rise in proportion to ability.
- The bar is today's squad. Depth is counted by familiarity, not quality.
- The tool cannot see youth-team matches, loan offers, or the level of a club that would take a loanee.
- No captured squad has a youth contract or a player of 17 or under: those cases are tested on built players only.
