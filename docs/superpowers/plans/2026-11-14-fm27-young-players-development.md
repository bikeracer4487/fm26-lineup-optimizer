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

- **One line in place of three.** The tier line is worked out as today (−40, −20, +15) and the reach line from `outlook.level` (`couldPassFirst` −40, `couldMakeSecond` −20, `couldBeCover` +15, `markedlyLower` +70: the four are `firstElevenPoints`, `secondElevenPoints`, `neitherElevenPoints` and the sum `neitherElevenPoints + weakestPoints + farBelowAveragePoints`, read from the rules, not written again). Only a place in the first or second eleven competes with the reach line, and on a tie the place; a backup takes the reach line (corrected at the close: the text here first said the one with fewer points is added). With `outlook.level` nil the tier line stands. The weakest-30% line and the ability-against-average line are not added.
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

- [x] **Step 1: Run everything**: both suites and the full picture run to `LineupApp/.build/pictures-development`. Put the three results in the report.
- [x] **Step 2: Update `CLAUDE.md`**, reading the code as built: this plan and its design in the list of plans; the research file is already covered by the Research line; in "How the engine works", the Planning bullet (the favour by age, the successor's favour and its limits, the Development setting, the monthly stop) and the Advisors bullet (Player Removal judges a player of 23 or under on his reach against his position's first and second choice; the four kinds of advice; youth contracts kept or released only; what replaced the prospect rules); the `plan` command's `--development`; in the app section, the Young players part, the mark refused on a youth contract, the setting, and `removal-young*` among the checked pictures in `.build/pictures-development`. Replace statements this plan made false; match the file's plain style.
- [x] **Step 3: Close this plan**: fill the three sections below from what the tasks reported, in plain sentences with no task numbers, agent names or commit ids; mark the design built. Record that the install and the hands-on check are left to the controller and the owner.
- [x] **Step 4: Commit**: "Close the young players' development plan: record what changed and what is left".

---

## After this plan

- The owner's own test of a 17-year-old kept against loaned (the research's last section) would replace the carried-over growth numbers with FM27 ones.
- A favour for players of 24 to 26, if the owner wants one.
- A bar that looks ahead to a promotion.

## What the advice showed on the captured squads

The advice was worked out on the captured first team and U21 squad with the sample 4-2-3-1, as `advise` and `plan` print it, and the lineup plan was run with Development at 1 (the default) and at 0. The captured squads have no goalkeeper, no youth contract and nobody of 17 or under; the goalkeeper slot is filled by an outfield player rated about 4.

Every player of 23 or under, as the advice stands at the end of the build. Players are named by squad, age and position only.

| Squad, age, position | Advice |
|---|---|
| U21, 19, centre-back, contract out | Release, at the high level. |
| U21, 19, centre-back, 10 months left, second choice, ability 25 | Score 20, keep level. Keep and play: he is markedly lower, but he is in the second eleven and, with too few matches confirmed, a solid second choice counts as getting his matches; "He keeps the place until the squad has someone better there." follows. "Contract ends in 10 months" adds its points. |
| U21, 19, defensive midfield, 10 months left, second-eleven goalkeeper only as a stand-in, ability 25 | Score 10, keep level. Watch: "This tool does not expect him to reach the level of the squad: watch how he does." His reach is below the bar at both defensive midfield slots. |
| U21, 20, right attacking midfield, second choice | Keep and play. |
| U21, 18, left attacking midfield, backup | Watch, needed as cover: a loan would leave the squad short. He could pass or make the second eleven, so he is worth developing. |
| First team, 23, defensive midfield, first choice | Keep and play. |
| First team, 23, right attacking midfield, second choice at a slot he is not solid at | Keep and develop, renew his contract first. He could pass the first choice; with fewer than six matches confirmed, his place in the elevens says nothing about his starts, so the sentence says that too few matches are confirmed and does not say he is not getting matches. |
| First team, 20, left back, first choice | Keep and play. |
| First team, 23, right back, second choice | Keep and play. |
| First team, 20, right back, first choice | Keep and play. |

- Nobody is newly advised to leave. The two who are advised to leave are the same two as before the build: the first-team 25-year-old (critical, terminate) and the U21 19-year-old centre-back whose contract is out (high, release). The wages at stake are unchanged.
- The three U21 19-year-olds of ability 25 are markedly lower. The first estimate, which scaled a rating in proportion to ability, called one of them able to pass the first choice at centre-back, because ratings here run about 72 at ability 25 and about 118 at ability 66. Scaling from an offset removed that, and the bar then kept the weak second choice on a thin squad from lifting them. On the captures that moved one of them, the U21 19-year-old defensive midfielder, from "keep and develop, renew his contract" to watch. No captured player was ever advised "loan for matches"; that pair, "renew his contract" and "loan for matches", came from the app's sample with young players.
- No young player on the captures is advised a loan for matches; that advice is tested on built players and on the app's sample.

Development at 1 against 0, over the five fixtures of the sample plan (14, 17, 21, 24 and 28 November). Nothing differs at 21 November, a high fixture.

- 14 November, a low fixture. At right defensive midfield the first-team 23-year-old defensive midfielder starts in place of a first-team 30-year-old defensive midfielder. He is first choice there; the consecutive-starts rule (×0.90) would rest him after two starts in a row, and the age favour (×1.10) brings him back. This is the favour reaching a player who already gets his matches, which is a known limit below. At right attacking midfield the first-team 23-year-old wide attacking midfielder starts in place of a first-team 37-year-old wide attacking midfielder: he is close to passing him there, and the successor's favour (×1.15) takes him past.
- 17 November, a medium fixture. The 23-year-old defensive midfielder is rested again in favour of the 30-year-old, since he has started three in a row at 1 and no favour acts at his slot in a medium fixture. The U21 20-year-old wide attacking midfielder keeps his place at right attacking midfield with the successor's medium favour (×1.05), but the pick is the same at 0.
- 24 November, a sharpness fixture. The goalkeeper slot and left attacking midfield swap between players of the first team as a knock-on of the earlier fixtures' fitness; neither carries a development reason. The 23-year-old wide attacking midfielder keeps right attacking midfield with the successor's favour (×1.15).
- 28 November, a medium fixture. The goalkeeper slot goes to the first-team 23-year-old wide attacking midfielder and right defensive midfield to the 23-year-old defensive midfielder, both as knock-ons of earlier fixtures, with no development reason at this fixture.
- A first-team 20-year-old left back and a first-team 20-year-old right back carry the age favour (×1.07) on 14 November and start either way.
- The three U21 19-year-olds of ability 25 are never picked and never favoured at either setting.

## Changes made while building

What was decided while building, where it differs from the design or from the plan's text. The design was corrected in the three places it names.

- **A rating is scaled with ability from an offset, not in proportion.** The design scaled a rating by reach over current ability. On the captured squads that called a U21 19-year-old of ability 25 and potential 41 able to pass the first choice at centre-back. A rating is now scaled by (offset + ability) ÷ (offset + current ability) wherever a rating is taken from one ability to another, including the points a player needs. The offset is a new parameter, 70, taken from a straight line through the best rating of each of 20 outfield players of the captured squads (rating = 57.0 + 0.798 × ability, R² 0.82, offset about 71.5, rounded to 5). It is loosely pinned: very roughly 45 to 110 fixes the fault found. At 0 it is the old behaviour. On the captures the three U21 19-year-olds of ability 25 went from "could pass the first choice" to "could make the second eleven" and nobody was newly advised to leave.
- **The band counts "ahead" as level or above.** The design said above. A player exactly level with the first choice a season on is Close, not only Possible, so he is not both "could pass him" and merely "possible".
- **The growth table's anchors are checked.** The Professionalism rates are an open table, so a check requires its anchors to be exactly at 1, 10 and 20; an extra one would be ignored silently.
- **Which line competes with the reach line.** The plan said the one with fewer points is added. Only a place in the first or second eleven competes with the reach line, and on a tie the place; a backup takes the reach line. The sentence in this plan's Player Removal scoring task has been corrected with a note.
- **A reach below the bar is markedly lower whoever the second choice is.** The bar is 80% of the first choice's rating, 70% at 16 or under. Before, a reach at or above the second choice's gave "could make the second eleven", and on a thin squad the second choice is another weak young player: two U21 19-year-olds of ability 25 were told "renew his contract" and "loan for matches". A reach at or above the bar is "could make the second eleven" when it reaches the second choice's rating or there is none, and "could become cover" otherwise.
- **A player not worth developing is never advised to develop or to be loaned.** Worth developing means he is first choice at a slot he can play, could pass the first choice or make the second eleven, or has no level. One who is not is kept to play when he is in an eleven and playing, and otherwise watched, with a sentence that follows his level: "This tool expects him to become cover at best: watch how he does." or "This tool does not expect him to reach the level of the squad: watch how he does." One needed as cover reads "He is needed as cover here: he stays until the squad has someone better there." where the loan sentence would be untrue of a player never considered for a loan.
- **A youth contract is released at any age and read in one way.** The owner's statement has no age, so a youth contract is released, never sold, terminated or loaned, whatever the age and whether or not he has an outlook. One engine function says whether a player is on one (a youth contract with 0 months left is read as no contract, one with months unknown is still a youth contract); the advice, the mark rule in the planner and the app all take it from there.
- **"Renew it" is for a player worth developing.** "Contract ends in N months: renew it", at no points, is said only of a young player worth developing (one who is first choice at a slot he can play, could pass the first choice or make the second eleven, or has no level), decided by his outlook and not by the size of the points; a place in an eleven alone does not earn it, though first choice at a slot he can play does. For a player not worth developing the contract line keeps its words and points, so the two captured U21 19-year-olds of ability 25 score higher than before and stay at the keep level. One not worth developing who is kept to play reads a second sentence, "He keeps the place until the squad has someone better there.", and a cover player not worth developing reads "He is needed as cover here: he stays until the squad has someone better there." where one worth developing still reads the loan sentence.
- **Watch reasons.** A watched young player now says why: not worth developing, or needed as cover. The generic sentence was not the reason.
- **Getting matches here.** A first choice always has enough. With fewer than six matches confirmed in the last 60 days, a second choice counts as getting matches only at a slot he is solid at (familiarity 15 or over in both phases); a stand-in, such as an outfield player who is the second eleven's goalkeeper, a backup, or a player the elevens did not rate, does not. When starts were not counted the develop and loan sentences say that he has no solid place in the first or second eleven and that too few matches are confirmed, and do not say he is not getting matches; the sentence that said "He is getting his matches here." now says, by what decided it, that he is first choice, that he is getting his matches, or that he is second choice and too few matches are confirmed to count his starts.
- **The standing at a like-named slot.** A young player's standing line leaves out the comparison with a first choice at another slot of the same position words (two defensive midfield slots), since it read as comparing him with himself.
- **The thresholds in the words became parameters.** Professionalism 10 (where it holds growth back) and age 30 (where a first choice is named with his age) are `EngineParameters` entries with flags on the estimate and on the rival, in keeping with the rule that no rule number sits outside them.
- **The reach is labelled as an estimate.** A young player's advice carries the weakest evidence behind it, which now includes the reach's derived growth numbers, so a release on an estimate is not labelled as firmly as one on the removal rules alone.
- **No floor for a loaned-in young player.** The floor comes from the outlook, which exists only for the club's own players, and the owner's aim is the growth of his own players. A loanee of 21 or under loses the old ×1.10 in lesser fixtures.
- **The floor applies only at slots he can play.** A 19-year-old outfield player was "favoured for minutes" in goal. The floor goes to the slots in his outlook, and the successor's favour replaces it at a slot where he is one.
- **A first choice is nobody's successor.** A player who is first choice at any slot of the tactic gets no successor's favour: on the captures it only swapped two defensive midfielders between slots and gave an odd reason.
- **The cap of two goes to players who can be picked.** In a medium fixture the two successors favoured are chosen among those who could be picked for the fixture; an injured one took a place nobody could use.
- **Outlooks are worked out once per tactic.** They depend on the fixture only through its tactic, so a plan works them out once for each distinct tactic. The plan comes out identical, and planning is faster.
- **A failed plan's fix is chosen for each kind of failure.** A missing player value, or two players with one identity, goes to Squad, a fixture problem to Fixtures, bad settings or parameters to Settings, and a duplicated fixture id offers no button, since no screen changes it. The planner now needs personality values for a developing player, so a missing one must not send the owner to Settings. The advice and the plan send the same player data to the same screen.
- **One engine function gives a young player's lines.** The sentences of a young player's row (his reach with its working, his standing, his advice and its reason, and whether the matches line is shown) come from `AdvisorText.youngLines`, so the app and the command line share them, and every line ends with a full stop.
- **A young row's title names the slot he is first choice at**, the first such slot in his outlook in the tactic's order; failing that his first-eleven slot from the elevens, and failing that his best slot. The fallback can name a slot his standing line does not mention.
- **Development setting.** It runs from 0 to 1, defaults to 1, and saved settings from before read as 1. Each favour is 1 + (factor − 1) × the setting.
- **A mark on a youth contract.** The app refuses a new mark and shows the engine's sentence in place of the control; the planner ignores one held from before.
- **A young first choice is worth developing whatever his other slots.** His outlook's level is that of his best slot where he is not first choice, so a first choice with a second position where his reach is only cover, or below the bar, was told he keeps the place until the squad has someone better, was charged the contract's points where he would have read "renew it", and lost the planner's favour by age: an extra position made the tool think less of the same player. A player who is first choice at a slot he can play is now worth developing and never markedly lower, in Player Removal's scoring, renewal, advice and sentences and in the planner's favour. His score is unchanged, since his place in the first eleven wins over his reach line. A stand-in first choice at a slot he cannot play is still not seen as one. Nothing changed on the captures or the sample.
- **"now, fewer later" only when it is true.** The working said every season's growth would fall, but the growth table is the same each season from 21 to 26. The estimate now says whether a later season's step for his age is lower than this season's, before the cap at his potential (which the working's ending already states), and the words follow it. On the captures the three first-team 23-year-olds lost the words.
- **With Development at 0 the planner works out no outlooks.** At 0 no favour reads them, and a young player missing Professionalism, Ambition or Determination stopped the whole plan, where the design says development changes no lineup. At 0 the plan now needs no personality values and comes out as before; above 0 the missing value is still an error naming him.
- **The young row's stamp comes from Core.** It was built in the view in one tone. It is now the action in the tone of his level's stamp in the table above, so a young player advised to go stands out in the Young players part as he does in the table, and a kept one recedes.
- **The Development explanation uses the app's words.** It said "lesser", "ordinary" and "biggest" fixtures and overstated who is favoured in a medium one. It now names the importances as the app does (Low, Sharpness, Medium, High) and reads its age and the count of successors favoured in a medium fixture from the engine's parameters.

### After the owner read the result (15 November 2026)

- **A loaned-in player stays without a development favour.** In the owner's words, loaned players "get used when I need them and no more, priority is on developing my own players". Nothing changed; a planner test now pins that a loaned-in young successor, fixed in the lineup, carries the loan mark-down and neither favour in medium, low and sharpness fixtures.
- **A player Player Removal advises to leave gets no development favour.** A player advised to release, sell or terminate (critical or high) gets neither the floor nor the successor's favour, at any slot, in any fixture, and takes no place among the two successors favoured in a medium fixture; since he is no longer a successor the fixture favours, he is not got sharp as one in a sharpness fixture either. The mark to sell or loan out, rest, sharpness and the other rules still apply to him as to anyone. The planner is handed the set beside the marks (`PlanRequest.advisedToLeave`) and does not work the advice out itself; the app and the command line's `plan` work it out with Player Removal on the inputs the advice uses (the primary tactic, the history, the day and the accepted retrainings). With Development at 0 it is not worked out; when it cannot be worked out the plan is made with nobody left out, and the advice screens show their own failure. On the captures no pick changed: the U21 19-year-old advised to be released has a reach markedly lower than the squad, so he had no favour before either, and the other player advised to leave is 25.
- **A successor who is retraining at the same slot gets whichever total is larger.** At such a slot he gets the successor's favour alone, or the floor and the retraining favour together as a player who is no successor would have them there (just the retraining favour where the floor does not apply, as in a medium fixture), whichever is larger, the floor and retraining on a tie; never all three. A successor who would carry the successor's favour at none of his slots in a medium fixture takes no place among the two favoured there, and the closest are ranked over the slots where he would carry it.
- **"Loan for matches" stands out in the Young players part.** Its stamp is drawn in ink where the player's level would draw it muted; every other stamp keeps its level's tone, and the table above is unchanged.

## Known limits and small faults left

Known before building (the design's section 11):

- The growth numbers come from FM24 and FM26 tests whose conditions are mostly not stated; if the bases were measured on average players, reach is underestimated below Professionalism 20, which errs toward release.
- The estimate is weakest for the youngest. Professionalism can be raised by mentoring.
- A rating is assumed to rise with ability along one straight line from an offset (70), the same at every position. The offset comes from 20 outfield players of the captured squads and is loosely pinned; it would be better fitted within a position, or on more squads. Pace arrives early and stops near 21, so a slow 20-year-old is overrated.
- The bar is today's squad. Depth is counted by familiarity, not quality.
- The tool cannot see youth-team matches, loan offers, or the level of a club that would take a loanee.
- No captured squad has a youth contract or a player of 17 or under: those cases are tested on built players only.

Found while building:

- With fewer than six confirmed matches the advice reads a player's place in the elevens in place of his starts, so a second choice at a slot he is not solid at reads as not getting matches until six are confirmed.
- The favour by age can bring a young first choice back into a lesser fixture he would have been rested for, until four starts in thirty days are on record. The sample history holds only two confirmed matches; with a real history a regular starter has four.
- A youth-contract player marked before this plan keeps the mark's label, with the refusal shown, until any squad is next imported (the app checks every mark after each import), and the planner ignores the mark meanwhile; the owner cannot clear it by hand before then.
- A loaned-in young player gets no development favour. This is the owner's decision (see "After the owner read the result"), not a fault.
- Each plan in the app now works Player Removal out to learn who is advised to leave, and the advice screens work it out again when they are read, so the primary tactic's elevens and depth are worked out twice. The app's tests went from about 212 to about 262 seconds for it.
- A successor whose floor and retraining favour win at every slot still counts as a favoured successor for being got sharp in a sharpness fixture, though he takes no place among the two favoured in a medium one; no test says so.
- Three cases of the owner's changes are right by reading the code and have no test of their own: a player advised to leave who is retraining keeps only the retraining favour; the larger-total rule with Development below 1 and after the monthly stop; and the command line's sentence when Player Removal cannot be worked out.
- A medium fixture's cap of two can spend a place on a successor the owner has overridden into the lineup; the cap's test of who can be picked does not count the owner's overrides.
- The planner still works out its tiers for each fixture, though they depend only on the tactic.
- "First choice" is read from the outlook, so a stand-in first choice at a slot he cannot play (an outfield player in goal) is not seen as one.
- The advice for a loan for matches and the successor's favour in a medium fixture are tested on built players and on the app's sample; the captures show a successor's favour only in lesser fixtures and on the two U21 and first-team wide attacking midfielders.
- A youth contract with 0 months left is told "out of contract", and below the high level "renew his contract before a loan".
- Some step-order tests are missing: age before a youth contract (there is a test), getting his matches before being needed as cover, being needed as cover before a youth or short contract, and a youth contract with a false prospect at high.
- A test in the end-to-end suite uses a literal 15 for "not solid" in place of the parameter.
- `Development.matchesHere` treats a second choice whose slot is missing from the assignments as having too few matches confirmed without saying so; it cannot happen through Player Removal.
- A reach working or a standing line can print "about 0 points a season".
- The matches line says "Too few matches are confirmed" when no matches are confirmed at all on a counted basis, which cannot happen in practice.
- A test of the successor rule has a developing first choice rated 60 against 50 where equal ratings were intended, and the second-choice comparison, the bar, the "possible" band and the points needed with a developing rival are not pinned by a test that would fail on the wrong rating being used.
- Some tests are weaker than they look: one would pass if Ambition and Determination were ignored (a test of a factor of one); one has a check that can no longer fail (a false prospect adding no line); a second-eleven player whose reach is only cover has no test of his own; a test asserts the order the enum declares and not an order the code produces; the successor's age check has no test; the 60-day boundary of the matches window is pinned only through a 3-day override, and there is no test of an unrated player with six or more matches; and a test of a slot with no first choice does not assert the level and average it gives.
- The planner's favour by age still goes to a player who could only become cover, whom Player Removal calls not worth developing; a future cover player's growth helps the squad, but it is a small favour in lesser fixtures for a player the advice would not develop.
- The app's sample with young players has a loan player with a potential of 85 on an ability of 25, which is wide for a sample.
- No parameter check keeps the successor's favour at or above the largest floor factor.
- A plain `//` heading comment sits in the parameter list where its neighbours use `///`; the planner works out each fixture's assignments again though it holds them; the age factor repeats the age step's shape; a comment in the app's plan code about the planner refusing settings is out of date.
- Development is not rounded to its step as Saving players is, so a value like 0.35000000000000003 can be saved, and the Development text reads "0%" for a value between 0 and 0.005, which the slider cannot produce.
- A slider saves only when a drag ends, so a change by keyboard or VoiceOver may show and not save. This is older than this plan and holds for every slider.
- The young explanation's fallback to an empty string can never be used and its test unwraps the note.
- The sample's expected order of young rows has no tie-break on the player's key.
- The engine's sentences for the three fixture planning errors name fixtures by id; the app's own checks stop them.
- A young player with an outlook but no level (no slot compares him with a first choice other than himself) who is outside both elevens now reads "renew it" at no points where he used to get the contract's points; no test pins it.
- A youth contract in its last month (0 months left) is read as no contract, so he can be marked and the mark counts.
- The standing line gives the season's growth rate even for a player already at his potential.
- A markedly lower player who is in the second eleven of a thin squad is kept to play until someone better arrives.
- Loan for matches can be advised on a contract type the tool does not read.
- A comment in Player Removal's code says a player not worth developing is "first choice nowhere", where the rule is first choice at no slot he can play, and the same comment has a stray short line.
- The build was installed with `tools/build_app.sh` after both suites passed on a clean build with no warnings. The hands-on check of the real app is left to the owner; opening the real app on saved state from before this plan has been checked by tests only.
