# Who Is Worth Renewing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Contracts lists the players worth renewing, most important first, with the rest behind a closed line with their reasons and a button to overrule; Player Removal stops giving points for thin cover and says to sign a replacement first; Scouting counts a player not being renewed as going.

**Architecture:** One new engine measure, a player's worth against the first eleven's standard (`Advisors/RenewalWorth.swift`), read from the elevens and Depth's ratings already worked out. Player Removal, Contracts and Scouting are handed it; the app shows the engine's sentences. Engine tasks first (1 to 6), then the app (7 and 8), then the checks and notes (9).

**Tech Stack:** Swift 6, macOS 26, Swift Testing, Foundation only in `LineupEngine/`; SwiftUI and Observation in `LineupApp/`.

**Spec:** `docs/superpowers/specs/2026-11-27-fm27-renewal-worth-design.md`. Research: `docs/Research/fm27-age-decline.md`. Read `CLAUDE.md` first: its rules for the engine and the app bind every task.

## Global Constraints

- No silent defaults: a missing attribute or familiarity is an error naming the player and the column (`RatingError`), as everywhere.
- Every tunable number lives in `EngineParameters` with an evidence label and a source. `EngineParameters` stays under 1 KB (a test holds it).
- Every rule gets a test where it changes an outcome and a test where it does not.
- The same inputs give the same output: sort by key or slot order before summing or choosing.
- Every word about advice is the engine's (`AdvisorText`), shown as written. Core holds only plain labels; a view holds no `if` about data and no literal colour, font or measure (`Theme`).
- Errors and warnings are sentences in `Reporting/ErrorDescriptions.swift`; every `switch` over an enum of this work is exhaustive, with no `default`.
- Test output is clean: no build warnings.
- The decline table, copied from the spec: nothing for a season begun under 30, 3 points at 30 or 31, 6 at 32 to 34, 9 from 35; two seasons. The line is `scoutingWeakShare`, 0.95, by Scouting's own rule (`Scouting.clearsWeakLine`), so a worth exactly 5% under does not meet it.
- The name `Worth` is taken (`LineupSelector.worth`, `SlotWorth`, the picker's). This work's names are `Renewal`, `RenewalWorth`, `SquadStandard`.
- Run the engine with `cd LineupEngine && swift test` (`--filter <name>` for one suite) and the app with `tools/test_app.sh` from the repository root (`--filter <name>`). Commit after each task, saying why.
- Nothing reads `~/Library/Application Support` except Task 9's check, which works on a copy outside the repository and commits none of it.

## Review Focus

1. **No standard.** A squad whose first eleven has no outfield player in position has no average. Nobody can be measured: every player in a part is not recommended, with the engine's sentence saying so, and nothing crashes or divides by zero. (Task 2 and Task 5.)
2. **A young player out on loan with Professionalism, Ambition or Determination missing.** His reach cannot be estimated: Contracts fails in the engine's sentence naming him and the attribute, as a rating error stops the list today. (Task 5.)
3. **The owner's choices against a verdict that moves.** A player set aside with "Not renewing" whom the tool later stops recommending is shown once, under "Not recommended", with his reasons; one kept with "Renew anyway" whom the tool later recommends is an ordinary row with no note. (Task 5, Task 7.)
4. **Ability at the edges.** Ability 0, a potential below the ability, and a decline larger than the ability: the ability over a new contract is never below 0, and a reach is never below today's. (Task 2.)
5. **Scouting kept from before a Contracts change.** After "Not renewing", "Show again", "Renew anyway", "Follow the advice", or a change of today's date, the Needs tab and the candidates are worked out again, not served from what was kept. (Task 7.)

---

### Task 1: The first eleven's standard and the decline rules

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Advisors/RenewalWorth.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift` (add `declineRules` beside `wageRangeRules`)
- Modify: `LineupEngine/Sources/LineupEngine/Selection/FitnessModel.swift` (`problems(in:)`, beside `WageRange.problems`)
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Scouting.swift` (`needs`: the averages come from the new helper; `WeakLineAverages.init(_ standard: SquadStandard)`)
- Test: `LineupEngine/Tests/LineupEngineTests/RenewalWorthTests.swift` (new), `EngineParametersTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct DeclineStep: Equatable, Sendable { public var fromAge: Int; public var points: Double }
  public struct DeclineRules: Equatable, Sendable { public var steps: [DeclineStep]; public var seasons: Int }
  public var declineRules: Parameter<DeclineRules>   // EngineParameters
  public struct SquadStandard: Equatable, Sendable { public let rating: Double?; public let ability: Double? }
  public enum Renewal {
      static func problems(in rules: DeclineRules) -> [String]
      /// The points lost in a season begun at `age`: the last step whose `fromAge` is at or under it, else 0.
      static func fall(at age: Int, rules: DeclineRules) -> Double
      /// Ability after `rules.seasons` seasons begun at `age`, `age + 1`, …; never below 0.
      static func abilityAfterDecline(_ ability: Int, age: Int, rules: DeclineRules) -> Double
      public static func standard(elevens: ElevensReport, depth: DepthReport, players: [Player],
                                  parameters: EngineParameters) -> SquadStandard
  }
  ```
- `standard`: over `elevens.first`, the places whose slot is not the goalkeeper's (`SlotDepth.ipPosition == .goalkeeper` for that slot in `depth.slots`) and are not `isOutOfPosition`, in `depth.slots`' order: `rating` is the mean of `place.rating.value`, `ability` the mean of `ratingAbilityOffset + currentAbility`; both nil with no such place. It is the computation `Scouting.needs` does inline today (lines 222 to 234); `needs` calls it with its own staying elevens and depth, and its results must not change.
- The parameter's value: steps `(30, 3)`, `(32, 6)`, `(35, 9)`, seasons 2; label `.derived`; source: "docs/Research/fm27-age-decline.md: decline from about 30, steep after 31 (an FM24 test of ten seasons and the FM26 notes, carried over); the sizes and the two seasons are this tool's estimate, with no test in any version behind them".

- [ ] **Step 1: Write the failing tests** in `RenewalWorthTests.swift`:
  - `theFallIsTheLastStepAtOrUnderTheAge`: with the standard parameters, `fall(at:)` is 0 at 29, 3 at 30 and 31, 6 at 32 and 34, 9 at 35 and 40.
  - `abilityAfterDeclineTakesEachSeasonAtItsAge`: (70, age 28) → 70; (70, 29) → 67; (70, 30) → 64; (70, 31) → 61; (70, 34) → 55; (70, 35) → 52; (5, 35) → 0, never below.
  - `problemsAreFoundInTheDeclineRules`: steps not rising in age, a size below 0 or not finite, seasons 0, and no steps each give one sentence naming `declineRules`; the standard parameters give none, and `FitnessModel.problems(in:)` carries them.
  - `theStandardIsTheOutfieldFirstChoicesInPosition`: on the captured squad (`first-team.tsv`, sample 4-2-3-1, as `ScoutingNeedsTests` builds it), `standard(...)` equals `ScoutingNeeds.outfieldAverageRating` and `outfieldAverageAbility` for the same players with nobody going; with a squad of one goalkeeper both are nil.
  - In `EngineParametersTests`: the entry is derived, and the whole set is still under 1 KB.
- [ ] **Step 2: Run** `swift test --filter RenewalWorthTests`. Expected: does not build (`Renewal` not defined).
- [ ] **Step 3: Implement** the types, the parameter, `problems` and its call in `FitnessModel.problems`, and `standard`; make `Scouting.needs` use it.
- [ ] **Step 4: Run** `cd LineupEngine && swift test`. Expected: all pass, the Scouting suites unchanged.
- [ ] **Step 5: Commit.**

### Task 2: A player's worth, and its words

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/RenewalWorth.swift`
- Create: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Renewal.swift`
- Test: `RenewalWorthTests.swift`, `LineupEngine/Tests/LineupEngineTests/AdvisorTextRenewalTests.swift` (new)

**Interfaces:**
- Consumes: Task 1's `SquadStandard`, `Renewal.standard`, `abilityAfterDecline`; `Reach.estimate(for:parameters:)`; `Scouting.clearsWeakLine(_:average:parameters:)`; `DepthReport.slots` (`options` and `onLoan` hold every player with familiarity 10 or over in both phases at the slot, with his full-fitness `rating`).
- Produces:
  ```swift
  public enum WorthAhead: Equatable, Sendable {
      case today                      // 24 or over with no fall expected
      case reach(Double)              // 23 or under: his reach
      case decline(to: Double)        // a fall expected over the seasons
  }
  public struct RenewalWorth: Equatable, Sendable {
      public let player: PlayerID
      public let slot: SlotID
      public let isGoalkeeperSlot: Bool
      public let age: Int
      public let ability: Int
      public let ahead: WorthAhead
      /// His share of the standard today, at `slot`: 0.936 for 6.4% under.
      public let shareToday: Double
      /// His share over a new contract: what he is ordered and judged by.
      public let share: Double
      public let meetsStandard: Bool
      public let basis: Evidence
  }
  extension Renewal {
      /// For every player of the club's own, here or out on loan, who can play a slot. Empty with no standard.
      public static func worths(players: [Player], ownClub: String?, elevens: ElevensReport, depth: DepthReport,
                                parameters: EngineParameters) throws -> [PlayerID: RenewalWorth]
  }
  extension AdvisorText { public static func worthLine(_ worth: RenewalWorth) -> String }
  ```
- The rule, for a player's slot with rating `r`, ability `a`, offset `o` (`ratingAbilityOffset`) and ability over a new contract `x` (his reach at `developingUpToAge` or under; else `abilityAfterDecline`, which is `a` when nothing falls):
  - outfield slot: by rating, `r × (o + x) ÷ (o + a) ÷ standard.rating`; when `x > a`, also by ability, `(o + x) ÷ standard.ability`, and the share is the lower of the two; otherwise the share is by rating.
  - goalkeeper's slot: `(o + x) ÷ standard.ability`.
  - `shareToday` is the same with `x = a`.
  - His worth is at the slot with the highest `share`, the earlier in `depth.slots` on a tie. `ahead` is `.reach` at 23 or under, `.decline` when `x < a`, else `.today`.
  - `meetsStandard` is `Scouting.clearsWeakLine(share, average: 1, parameters:)`.
  - `basis` is the weakest of `scoutingWeakShare` and `ratingAbilityOffset`, with `growthPerSeason` and `growthProfessionalismRates` for a reach, and `declineRules` for a decline.
  - Players on loan at the club get none. `Reach.estimate`'s error for a missing attribute is thrown on.
- The words, exact (percentages by `Display.onePercentDecimal`, the place by `PositionText.plain(slot)`, abilities as whole numbers):
  - today, above or level: "Rates 2.9% above the average of your first eleven, at centre-back."; under: "Rates 10.6% under the average of your first eleven, at right defensive midfield."
  - reach: "Ability 79, could reach about 109 (this tool's estimate): that would rate 7.8% above the average of your first eleven, at left attacking midfield."
  - decline: "He is 30. This tool expects him to lose about 6 points of ability over the next two seasons, from 70 to about 64 (its own estimate: no test measures decline): that would rate 10.4% under the average of your first eleven, at right defensive midfield. Rates 6.4% under it today." (the number of seasons from the rules, in words up to ten).
  - at the goalkeeper's slot the comparison is by ability and says so: "…the average of your first eleven by ability, at goalkeeper." in each of the three.

- [ ] **Step 1: Write the failing tests.** Build small squads with `Player.fixture` as `ContractsTests` does, with a tactic whose elevens are known.
  - `aPlayerOfTwentyFourToTwentyNineIsMeasuredAsHeIsToday`: `ahead == .today`, `share == shareToday`.
  - `aYoungPlayerIsMeasuredAtHisReachByRatingAndByAbility`: one whose scaled rating clears the line and whose reach as ability does not is under the standard (the share is the lower); one who clears both meets it.
  - `anOlderPlayerIsMeasuredAfterTheFallExpected`: at 30 with ability 70 `ahead == .decline(to: 64)` and `share < shareToday`; at 28 the two are equal.
  - `anOlderPlayerFarAboveTheStandardStillMeetsIt`: a 36-year-old whose share after the fall is over 0.95 has `meetsStandard`.
  - `theGoalkeeperIsMeasuredByAbility`, `theBestSlotIsHisAndTheEarlierWinsATie`, `aPlayerOnLoanHereHasNoWorthAndOneOutOnLoanHasOne`.
  - `exactlyFivePercentUnderDoesNotMeetTheStandardAndJustOverItDoes`.
  - Review Focus 1 and 4: `withNoStandardNobodyHasAWorth`; `anAbilityOfZeroAndAPotentialBelowTheAbilityAreMeasuredWithoutGoingBelowTodayOrZero`.
  - `aYoungPlayerMissingAnAttributeIsAnErrorNamingHimAndIt`.
  - In `AdvisorTextRenewalTests`: each sentence above, exactly, from a `RenewalWorth` built by hand, with the goalkeeper's variants.
- [ ] **Step 2: Run** `swift test --filter Renewal`. Expected: does not build.
- [ ] **Step 3: Implement** `worths` and `worthLine`.
- [ ] **Step 4: Run** `cd LineupEngine && swift test`. Expected: pass.
- [ ] **Step 5: Commit.**

### Task 3: Player Removal: a replacement first, in place of the points for thin cover

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Removal.swift` (`Reasons.addThinCover`, `advice(for:)`, `review(of:)`, `RemovalAdvice`, `LoanReview`)
- Modify: `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift` (remove `removalThinCoverPoints`)
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText.swift` (the sentence), `LineupEngine/Sources/lineup-cli/Report.swift` (print it under a row)
- Test: `RemovalTests.swift`, `EngineParametersTests.swift`, `TrainingTests.swift`, `AdvisorsTests.swift`, `EndToEndTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum RemovalNeedKind: String, CaseIterable, Sendable { case firstChoiceWhereThin, cover, standIn }
  public struct RemovalNeed: Equatable, Sendable { public let slot: SlotID; public let kind: RemovalNeedKind }
  // RemovalAdvice and LoanReview each gain:
  public let neededAt: RemovalNeed?
  /// `neededAt` when he is advised to go (critical or high, to be released, terminated or sold; for a loan, `endEarly`),
  /// else nil: what the row shows.
  public var replaceBeforeGoing: RemovalNeed? { get }
  extension AdvisorText { public static func replaceFirst(_ need: RemovalNeed) -> String }
  ```
- `neededAt` is found by today's three tests in today's order (first choice of a thin slot; counts as cover where the slot's cover is at most `depthThinBelow`; a stand-in not counted as cover where the stand-ins are at most it), at the first slot in slot order. It adds no reason and no points. `youngAction`'s `thinCover` is `neededAt != nil`.
- The sentences, exact: "Sign a replacement at goalkeeper before he goes: he is first choice there and cover is thin."; "Sign a replacement at left back before he goes: cover there would be thin without him."; "Sign a replacement at left back before he goes: too few players can step in there without him."

- [ ] **Step 1: Rewrite the thin-cover tests in `RemovalTests`** to the new rule, keeping each case:
  - `theFirstChoiceOfAThinSlotGetsNoPointsAndIsNeededThere`, and the same for cover and for a stand-in: `neededAt` is the slot and kind, no reason mentions cover, and the score is what the other rules give.
  - `aPlayerAdvisedToGoWhoIsNeededIsStillAdvisedToGo`: the captured squad's only goalkeeper case (the test that led to the parameter): he is in `advisedToLeave`, with `neededAt` and `replaceBeforeGoing` set.
  - `aPlayerNeededWhoIsKeptHasNothingToShow`: `neededAt` set, `replaceBeforeGoing` nil.
  - `aPlayerNotNeededHasNoNeed`.
  - `aYoungPlayerNeededForCoverIsStillWatchedAndNotLoaned` (unchanged outcome).
  - The loan review: `aLoanNeededForCoverGetsNoPointsAndIsNeededThere`.
  - `AdvisorText.replaceFirst` gives each of the three sentences.
  - `EngineParametersTests`: `removalThinCoverPoints` is gone.
- [ ] **Step 2: Run** `swift test --filter RemovalTests`. Expected: does not build.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `cd LineupEngine && swift test`, then fix each test elsewhere that held the old points (`TrainingTests`, `AdvisorsTests`, `EndToEndTests`): each expectation changes only where a protected player is now advised to go. For each, check by hand that the new value is what the rule gives, and say so in the commit.
- [ ] **Step 5: Run the three commands of `CLAUDE.md`** (`plan`, `advise`, `scout` on the captured squad) and keep their output before and after in the scratchpad; note who moved (the goalkeeper, at least) for Task 9's notes. The `advise` rows now carry the sentence.
- [ ] **Step 6: Commit.**

### Task 4: Player Removal: the contract's own points follow his worth

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Removal.swift` (`report(players:…depth:…)`, `advice(for:)`)
- Test: `RemovalTests.swift`

**Interfaces:**
- Consumes: `Renewal.worths(players:ownClub:elevens:depth:parameters:)` (Task 2), called once in the inner `report` with the elevens and depth it is handed.
- Produces: `RemovalAdvice.worth: RenewalWorth?` (nil when he has none).
- The rule: a player whose worth meets the standard gets, at no points, "Contract ends in 8 months: renew it" where the ending-contract points would apply, and "No contract: offer him one" in place of both no-contract reasons ("No contract: 0 months left", "Not on a full-time contract"). Anyone else keeps today's words and points. `isWorthDeveloping` no longer decides the first; it is unchanged elsewhere. The advice's `basis` takes the worth's when the rule fires.

- [ ] **Step 1: Write the failing tests:**
  - `aPlayerWhoMeetsTheStandardIsToldToRenewAtNoPoints`: 27, first-eleven standard, 8 months left: the reason is "…: renew it" with 0 points.
  - `aPlayerUnderTheStandardKeepsThePointsForAnEndingContract`: 15 at 8 months, 25 at 6.
  - `aYoungPlayerWorthDevelopingButUnderTheStandardKeepsThePoints` (the design's call 10) and `aYoungPlayerNotWorthDevelopingWhoMeetsTheStandardIsToldToRenew`.
  - `aPlayerWithNoContractWhoMeetsTheStandardIsToldToOfferOneAtNoPoints`, and one under it keeps the 50.
  - `theOwnersCase`: a 22-year-old on 15 for cover at best, 20 for his wage and 15 for his contract, whose reach meets the standard, is not in `advisedToLeave` (Josh Lewis, by fixture, not by name).
- [ ] **Step 2: Run** `swift test --filter RemovalTests`. Expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `cd LineupEngine && swift test`; fix what held the old lines, checking each by hand as in Task 3.
- [ ] **Step 5: Commit.**

### Task 5: Contracts: recommended, not recommended, and the reasons

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Contracts.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Contracts.swift`
- Test: `ContractsTests.swift`, `AdvisorTextContractsTests.swift`

**Interfaces:**
- Consumes: `Renewal.worths`, `AdvisorText.worthLine`, `RemovalAdvice.neededAt`.
- Produces:
  ```swift
  public enum ContractReason: Equatable, Sendable {
      case markedToSell
      case advisedToLeave(RemovalAction)
      case underStandard(RenewalWorth)
      case noSlot            // he can play no slot of the tactic
      case noStandard        // the first eleven has no outfield player in position
      case replaceFirst(slot: SlotID, why: ReplaceWhy)
  }
  public enum ReplaceWhy: String, CaseIterable, Sendable { case firstChoice, secondChoice, cover, standIn }
  // ContractEntry gains:
  public let worth: RenewalWorth?
  /// Why the tool does not recommend renewing him, in the design's order; empty when it does.
  public let reasons: [ContractReason]
  /// The owner chose "Renew anyway" and the tool does not recommend him.
  public let isWanted: Bool
  public struct ContractsReport {
      public let listed: [ContractEntry]          // recommended, or wanted
      public let notRecommended: [ContractEntry]
      public let dismissed: [ContractEntry]       // recommended or wanted, and set aside by the owner
      public let basis: Evidence
      /// `notRecommended` and `dismissed`: the players Scouting counts as going.
      public var notBeingRenewed: Set<PlayerID> { get }
  }
  public static func report(players: [Player], ownClub: String?, marks: [PlayerID: SaleMark],
                            removal: RemovalReport, elevens: ElevensReport, depth: DepthReport, tactic: Tactic,
                            dismissed: Set<PlayerID>, wanted: Set<PlayerID>, today: Day, catalog: RoleCatalog,
                            profile: RatingProfile, parameters: EngineParameters) throws -> ContractsReport
  ```
- `replaceFirst`, the last reason, only for a player with another reason: first or second choice by his tier; else, for a player at the club, Player Removal's `neededAt` of kind `cover` or `standIn`; none for a player out on loan.
- Who is where: every player of the club's own with a part (the three parts, unchanged; never one on loan here) is in exactly one list. He is recommended when his worth meets the standard, he is not marked to sell, and he is not in `removal.advisedToLeave`. Not recommended and not in `wanted`: `notRecommended`, whatever `dismissed` holds. Otherwise in `dismissed` when the owner set him aside, else `listed`. `isWanted` only for one not recommended.
- What goes: the gate for a youth contract or none; `leftOutAsGoing`; the mark to loan out as a reason to leave a player off.
- Order of each list: the higher `worth.share` first (no worth last), then the earlier end day, then fewer months left, then the order handed in.
- The words, exact: "You have marked him to sell."; "Player Removal advises selling him." (the action's name by `AdvisorText.name`, lower case, as a verb: selling, releasing, terminating his contract); the worth line; "He can play no slot of this tactic."; "Your first eleven has no outfield player in position, so nobody can be measured against it."; "He is first choice at right defensive midfield: sign a replacement before he goes." (second choice; "He counts as cover at …"; "Too few players can step in at … without him: sign a replacement before he goes."); the closed line "1 player not recommended for renewal" / "21 players not recommended for renewal"; on a wanted row "The tool does not recommend renewing him; he is listed at your choice."; the intro becomes "Players worth renewing whose contracts are running down, most important first, with what your own squad is paid as a guide to a reasonable wage."; the empty line "Nobody worth renewing is in the last year of his contract." `contractPartHeading` and `leftOutAsGoingLine` are removed.

- [ ] **Step 1: Rewrite `ContractsTests`' listing tests and add:**
  - `aPlayerWhoMeetsTheStandardIsListedAndOneUnderItIsNotRecommended`, with the reason `.underStandard`.
  - `theListsAreOrderedByWorthThenEndDay`.
  - `aPlayerMarkedToSellIsNotRecommendedAndOneMarkedToLoanOutIsJudgedLikeAnyone`.
  - `aPlayerAdvisedToLeaveIsNotRecommendedWithTheAction`.
  - `everyReasonThatAppliesIsGivenInOrder`: marked, advised, under the standard and first choice at once.
  - `aFirstChoiceNotRecommendedIsToReplaceFirstAndOneInNeitherElevenIsNot`.
  - `aYouthContractPlayerIsJudgedOnHisWorthAlone` (the gate is gone: one in neither eleven whose reach meets the standard is listed; one in an eleven under it is not).
  - `renewAnywayListsHimAsWantedWithHisReasons`; `aWantedPlayerTheToolNowRecommendsIsAnOrdinaryRow`; `aDismissedPlayerTheToolNoLongerRecommendsIsUnderNotRecommended` (Review Focus 3).
  - `withNoStandardEveryoneIsNotRecommendedAndSaysWhy` (Review Focus 1); `aYoungPlayerOutOnLoanMissingAnAttributeStopsTheListNamingHim` (Review Focus 2).
  - `notBeingRenewedIsTheNotRecommendedAndTheDismissed`.
  - `AdvisorTextContractsTests`: each sentence above, exactly.
- [ ] **Step 2: Run** `swift test --filter Contracts`. Expected: does not build.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `cd LineupEngine && swift test`. Expected: pass. (`LineupApp` does not build until Task 7; that is expected.)
- [ ] **Step 5: Commit.**

### Task 6: Scouting: a player not being renewed is going

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Scouting.swift` (`GoingReason`, `going`, `rank`)
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Scouting.swift` (`name(_ reason:)`: "not being renewed")
- Test: `ScoutingNeedsTests.swift`, `ScoutingTextTests.swift`

**Interfaces:**
- Produces: `GoingReason.notBeingRenewed`, last in the order; `Scouting.going(players:ownClub:marks:advisedToLeave:notBeingRenewed: Set<PlayerID> = [])`. The command line passes none.

- [ ] **Step 1: Write the failing tests:** `aPlayerNotBeingRenewedIsGoingUnderTheLastReason` (one who is also marked keeps the earlier reason); `withNobodyNotBeingRenewedTheGoingAreAsBefore`; `aFirstChoiceNotBeingRenewedMakesHisSlotANeed` (through `Scouting.needs`: the need names him as going); the reason's words.
- [ ] **Step 2: Run** `swift test --filter Scouting`. Expected: fail.
- [ ] **Step 3: Implement**, with every `switch` over `GoingReason` made exhaustive again.
- [ ] **Step 4: Run** `cd LineupEngine && swift test`. Expected: pass.
- [ ] **Step 5: Commit.**

### Task 7: The app's state, actions and rows

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/ContractsState.swift` (`wanted: [PlayerID: Day]`, read as empty when absent)
- Modify: `LineupApp/Sources/LineupAppCore/AppModel+Contracts.swift`, `ContractsPresentation.swift`, `Navigation.swift`, `AppModel+Scouting.swift`, `RemovalPresentation.swift`, `SampleData.swift`
- Test: `ContractsStateTests.swift`, `ContractsPresentationTests.swift`, `ScoutingTests.swift`, `RemovalPresentationTests.swift`, `StoreTests.swift`

**Interfaces:**
- Consumes: Task 5's `Contracts.report` and words; Task 6's `going`; Task 3's `AdvisorText.replaceFirst`.
- Produces:
  ```swift
  // AppModel
  public func renewAnyway(_ player: PlayerID)      // sets wanted today, clears a dismissal of his
  public func followAdvice(_ player: PlayerID)     // removes wanted
  var notBeingRenewed: Set<PlayerID>               // from the Contracts report for the primary tactic; empty when it is not ready or fails
  // ContractsSheet: `parts` and `leftOutLine` go; it gains
  public let rows: [ContractRow]
  public let notRecommendedLine: String?           // nil for none
  public let notRecommended: [ContractRow]
  // ContractRow gains
  public let worthLine: String?
  public let reasonLines: [String]                 // the engine's, in order; empty for a recommended row
  public let wantedLine: String?                   // the engine's sentence on a row listed at his choice
  // Navigation
  public var contractsNotRecommendedOpen = false   // in memory only
  // ContractsPresentation labels
  public static let renewAnywayButton = "Renew anyway", followAdviceButton = "Follow the advice"
  public static let notRecommendedHeading = "Not recommended for renewal"
  // RemovalRow and the loan row gain
  public let replaceFirstText: String?             // `AdvisorText.replaceFirst` of `replaceBeforeGoing`; nil with none
  ```
- A not-recommended row carries his name, facts, standing and reasons, and no wage lines or figure field; a wanted row is a full row with `wantedLine` and `reasonLines`. The timing line stays on listed rows, a caution in the part other clubs can approach now. `contractsCount` is `rows.count`, nil at 0.
- The two new actions share `contractsActionInterval`'s clock with the two there are. All four, and any change of today's date in the game, clear the kept Scouting needs and candidates (`adviceCache?.scoutingNeeds`, `.candidates`), since who is going now turns on them (Review Focus 5). `dropSpentContractEntries` drops a `wanted` entry by the rule that drops a dismissal.
- `workedOutScoutingNeeds`, and wherever the candidates' going are worked out, pass `notBeingRenewed`.
- The samples: `modelWithContracts` must still show a full list. Work out who the rule recommends in the capture `first-team-with-expiry` on 30 June 2028, keep `contractsFigureName` and `contractsDismissedName` on players the rule recommends (change them if it does not), and add `contractsWantedName`, a not-recommended player kept with "Renew anyway". The sample's own check (`SampleDataError`) says so when a name stops fitting.

- [ ] **Step 1: Write the failing tests:**
  - `ContractsStateTests`: `renewAnywayIsSavedWithTodaysDayAndClearsADismissal`; `followAdviceRemovesIt`; `theFourActionsShareOneClock`; `aWantedEntryIsDroppedAtAnImportOnceHeIsRenewedOrGone`; `aFileFromBeforeWantedOpensWithNoNoticeAndNobodyWanted`.
  - `ContractsPresentationTests`: `theListIsInTheEnginesOrderWithEachRowsWorthLine`; `theNotRecommendedRowsCarryTheirReasonsAndNoWageLines`; `theClosedLineCountsThem`; `aWantedRowSaysSoAndKeepsItsReasons`; `thePillCountsTheListOnly`; the sample's expectations.
  - `ScoutingTests`: `aPlayerNotBeingRenewedIsCountedAsGoingOnTheNeedsTab`; `dismissingAndShowingAgainWorkTheNeedsOutAgain`; `movingTheDateWorksTheNeedsOutAgain` (a player enters his last year and becomes going with no import).
  - `RemovalPresentationTests`: `aRowAdvisedToGoWhoIsNeededCarriesTheReplacementSentence`, and one not needed carries none.
- [ ] **Step 2: Run** `tools/test_app.sh --filter Contracts`. Expected: does not build.
- [ ] **Step 3: Implement.** The views will not compile against the new sheet until Task 8: change `ContractsScreen` only as far as it builds (rows in place of parts), and finish it there.
- [ ] **Step 4: Run** `tools/test_app.sh`. Expected: pass.
- [ ] **Step 5: Commit.**

### Task 8: The screens

**Files:**
- Modify: `LineupApp/Sources/LineupAppUI/Advice/ContractsScreen.swift`, the Player Removal views in `LineupApp/Sources/LineupAppUI/Advice/` (the opened row and the loan review), `LineupApp/Sources/LineupAppUI/RootView.swift` (`ContractsStart` gains `notRecommendedOpen`), `LineupApp/Sources/LineupApp/main.swift` (the pictures)

**Interfaces:**
- Consumes: Task 7's sheet, rows and labels.

- [ ] **Step 1: Contracts.** From the top, as now: heading, intro, the three figures. Then the rows in one list, with no part headings: name with "Not renewing" at the trailing end; facts; standing; timing; `wantedLine` in the caution style with `reasonLines` under it and "Follow the advice" in place of "Not renewing"; `worthLine`; the wage lines; the agent's figure and verdicts. Then the engine's empty line when there are no rows. Then "Not recommended for renewal", closed behind `notRecommendedLine` (`RestToggle`, `navigation.contractsNotRecommendedOpen`): each row his name with "Renew anyway" at the trailing end, facts, standing, and `reasonLines`, the sentence that says to sign a replacement in the caution style. Then "Not renewing" as now, and the evidence note. The rows stay in the lazy stack.
- [ ] **Step 2: Player Removal.** `replaceFirstText` as a caution line in the opened row, above the reasons, and under a loan's verdict.
- [ ] **Step 3: Pictures.** Add to the picture run: `contracts-notrecommended-open-*` (the closed section opened), `contracts-wanted-*` (the sample's wanted row), and a Player Removal picture with a row that carries the replacement sentence (a sample where the only goalkeeper is advised to go; add `SampleData` for it in this step if the standard sample has none). Draw them from the optimized build (the command is in `CLAUDE.md`, "An unoptimized picture run…") into `LineupApp/.build/pictures-renewal`, and look at each: `contracts-*`, `contracts-tall-*`, `contracts-small-*`, the three new ones, `removal-*` and `scouting-needs-going-*`.
- [ ] **Step 4: Run** `tools/test_app.sh`. Expected: pass, no warnings.
- [ ] **Step 5: Commit.**

### Task 9: The check on the owner's squad, the full runs and the notes

**Files:**
- Modify: `CLAUDE.md`, this plan (its closing sections), the spec (mark anything revised during the build "revised")

- [ ] **Step 1: The owner's squad.** Copy the app's saved state to the session's scratchpad (never into the repository), run the built `Contracts.report` over it through a throwaway test as the design's trial did, and compare with the design's list: 13 recommended (Harry McGlinchey first), 20 not, Christian N'Guessan not recommended with the decline sentence, Josh Lewis recommended and not advised to go. Record every difference and its cause in the closing sections; a difference the rule does not explain is a fault to fix before going on. Delete the throwaway test and the copy.
- [ ] **Step 2: The full runs.** `cd LineupEngine && swift test`; `tools/test_app.sh`; `cd LineupApp && swift test` in the background (it takes ten minutes or more). All pass with no warnings.
- [ ] **Step 3: The notes.** In `CLAUDE.md`: a new entry in the list at the top; the Advisors passage on thin cover and on the short contract's "renew it"; the Contracts passages in the engine and app sections (who is listed, the order, the three places, the words, `wanted`); Scouting's reasons a player is going; the test counts and the pictures checked. In this plan: "What the build showed on the captured squads and the owner's", "What changed during the build", "Limits and small faults left".
- [ ] **Step 4: Commit.**

---

## What the build showed on the captured squads and the owner's

**The captured squad (`first-team` and `u21`, the sample 4-2-3-1).** The sample plan's lineups did not change at any step.

- Without the points for thin cover (Task 3): Jonny Maxted, the only goalkeeper, goes from keep to high and is advised "sell" on 65 points, with "Sign a replacement at goalkeeper before he goes: he is first choice there and cover is thin." Scott Pollock goes from 85 to 115 and carries the sentence for central attacking midfield. Five young players' scores rose by 30 with no change of advice, and one player the command does not name moved from keep to medium.
- Scouting follows: Maxted now counts as going, so the goalkeeper's slot reads "nobody" in the squad that stays, an outfield player fills in there out of position (Zac McEachran), and that takes him out of the cover at central and right attacking midfield, which moved those needs and two pasted candidates (Max Treml, Brayden Daniel). The rule gives this; it reads oddly, and is a limit below.
- With the contract's points following the worth (Task 4): Fernando Forestieri, 36 and out of contract, meets the standard after the fall expected and goes from medium to keep, the 50 points for no contract gone. Six others lost 15 points with no change of level. Nobody joined or left those advised to leave.

**The owner's squad**, by a throwaway run of the built rule on a copy of his saved state, dated 25 November 2028 in his game (Task 9; the copy and the test were deleted): 32 players in a part. **12 listed**, Harry McGlinchey first (his reach would rate 22.9% above) and Kieran Petrie last (4.7% under on his reach). **20 not recommended**: Christian N'Guessan (30: 6.4% under today, 10.8% under after two seasons), with "He is first choice at right defensive midfield: sign a replacement before he goes."; Darnell Johnson; Sammy Henia-Kamau; Dejan Tetek, second choice there, with the same caution; and sixteen young players, one of them marked to sell and advised to be released. Josh Lewis is listed and watched, not sold. Against the design's 13 and 20: Aimar Govea and Ayman Benarous are in no part now, their contracts ending on 30 June 2030, renewed in his game since. Nothing differed that the rule does not explain. Nobody in his squad is advised to go while needed, so no row of his carries the replacement sentence on Player Removal today. Scouting counts twenty-one players as going, nineteen of them as not being renewed.

## What changed during the build

1. **The line is exclusive.** A worth exactly 5% under the standard does not meet it: the plan uses Scouting's own rule for the weak line, where the design said "at or above 0.95".
2. **A young player is never worth less over a contract than today** (Task 2's review). By the design's rule the ability test applied only once the reach was above the ability, so one more point of potential could lower a share. His share is now the higher of today's and the lower of the two tests, and one whose reach is not above his ability is measured as he is today.
3. **The seasons travel with the decline** (`WorthAhead.decline(to:seasons:)`), so the sentence needs only the worth; and the worth carries the line (`RenewalWorth.line`) for the two-decimal edge.
4. **A player of 29 loses 3 points**, by the table (the plan's test name said 24 to 29 were measured as today; it covers 24 to 28).
5. **Player Removal is handed the worths of the club's own at the club and of those on loan here** (Task 4), so that its standard is the same as Contracts'; a player out on loan is left out, so his missing data cannot stop Player Removal. Contracts hands in everyone but the players out on loan who are in no part (Task 5), for the same reason.
6. **`depthThinBelow` counts in the evidence of Player Removal's advice only where the need is shown**: a replacement to sign first, or a young player watched for cover (Task 3's own call, tested after the whole-branch review).
7. **"Ending his contract by agreement"** for a termination, where the plan had "terminating his contract".
8. **With no standard, a mark to sell and Player Removal's advice still come before "Your first eleven has no outfield player in position…"**.
9. **A change of today's date clears the kept Scouting needs and candidates in `update(_:)`** (Task 7): a date change does not replan, as the dispatch had wrongly said.
10. **A wanted row shows his worth sentence once**, among his reasons.
11. **`ContractRow.replaceFirstText`** holds the sentence that says to sign a replacement, apart from `reasonLines`, so the view never reads a sentence's words to draw it as a caution (Task 8); the reason sentences come from the engine's `AdvisorText.contractReasonLines`.
12. **The samples.** `contractsDismissedName` is Sammy Henia-Kamau, since the rule no longer recommends Dejan Tetek, who is `contractsWantedName`; both samples' pills read "Contracts 14" (17 and 22 before).

## What the whole-branch review found

No wrong advice, no circle among Player Removal, Contracts and Scouting, and nothing stale. Three wording faults the owner would have met first, and a short list of small ones, fixed in one round (commit 9878f95):

- Nothing said where the line is: a sentence under the intro now does (`AdvisorText.contractsRuleLine`).
- "Renew it" or "offer him one" on a row advised to go: the line now reads "…: not counted against him, as he meets the standard of your first eleven" there.
- "0.0% under" (Josh Lewis's row on the owner's squad) reads "level with"; a gap that reads as the line's own is written to two decimals.
- Player Removal's advice said twice on a not-recommended row, and "he can play no slot" said twice for a player out on loan: each now once.
- The replacement sentence is left off a row the owner chose to renew anyway.
- A young player held at today's share says so.
- The tests the rules lacked (the evidence call of point 6 above, the candidates after a change of date, one player both advised to leave and not being renewed); the standard worked out once in `Contracts.report`; the pill's count read from the report's list; the loan block's spoken text; three doc comments that stated a rule that is gone.

## Limits and small faults left

For the owner:

- **The sizes of the fall are this tool's estimate.** No test in any version measures decline. A reading of every player's ability at each import would measure it in his own save (`docs/Research/fm27-age-decline.md`); it is not built.
- **One line.** A backup of 24 or over who is under the first eleven's standard is not recommended, whatever the second eleven's level.
- **A goalkeeper is measured by ability** against the outfield first choices', as Scouting measures one, since his rating is on its own scale. A goalkeeper whose ability is well above the outfield's comes out far above the standard and at the top of the list (the sample's first row, at 24.6% above).
- **A rating at one slot is set against an average across every outfield slot and role.**
- **Player Removal and Contracts can differ on a young player.** One Player Removal would keep and develop, whose reach is under the standard, is not recommended; one it calls cover at best, whose reach meets the standard, is (Josh Lewis). Each row shows its working.
- **Scouting's going line can be long.** Every player in his last year who is not recommended is counted as going, most of them young players out on loan.
- **Contracts is for the primary tactic.** A player who can play no slot of it is not recommended, and Scouting counts him as going under whatever tactic it shows.
- **On a squad whose only goalkeeper is advised to go**, Scouting judges the squad that stays with an outfield player in goal, which moves needs elsewhere.
- **A young player needed as a stand-in who is markedly lower** is now advised "sell" with the replacement sentence, where the points for thin cover kept him at medium; "watched and not loaned" holds only below high.
- **"Renew anyway" stays saved while the tool recommends him**, and holds again if it stops recommending him, until an import finds him renewed or gone.
- **When the Contracts list cannot be worked out**, Scouting counts nobody as not being renewed and says nothing of it; the Contracts screen shows the failure.
- **Training, Mentoring and the planner do not count a player not being renewed as going**; only Scouting does.
- Not checked in a live window: "Renew anyway", "Follow the advice", the closed section's line, and the look of the buttons.

Small faults:

- The evidence on a Player Removal row follows the worth only when the worth spares him the contract's points, not when he keeps them.
- `Renewal.worths` divides by zero with `ratingAbilityOffset` 0 and an ability of 0 (`Development.scaled` has the same risk; the offset is 70). A decline step under half a point would read "lose about 0 points".
- The goalkeeper-slot test is spelt in `RenewalWorth.swift` and in `Scouting.swift`, on different types.
- A fixture that is out of contract with months left above 0 gets two contract lines; no paste can produce it.
- Tests: the "standard equals needs" test is circular now that `needs` calls the helper; no test of an out-of-position first choice left out of the standard, nor of exactly 5% under at an outfield slot; `aPlayerWithNoWorthKeepsThePointsForAnEndingContract` does not assert the basis; `everyReasonThatAppliesIsGivenInOrder` puts a player with a staying action among those advised to leave by hand; `coverReasons` filters loosely; the app's test of a file from before `wanted` checks only one notice's words (`StoreTests` checks the file itself); `ContractsSample`'s helper copies the production split.
- The view picks a row's button with `if row.wantedLine == nil`; the ink reason line starts at the caution triangle's left edge, not at its text.
- The pill can show a count while the sheet fails, which only a wage guide throwing on a report that worked out could cause; bad parameters stop the report first.
- Two shares within 0.005 of a percentage point either side of the line both read "5.00% under".
