# FM27 Mentoring From The Game's Arrows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The owner records the influence arrows the game shows between the three players of a mentoring group, and the mentoring advice rests on those arrows wherever one has been read and on a stated guess where none has.

**Architecture:** The engine gains an arrow (who to whom, None to Significant), a reading of one, a guess for a pair with no reading, and a rule for a player who takes nothing. Suggested groups are rebuilt on arrows: any three players with no harmful arrow and something to gain, the most valuable first. A recorded group is read from its six arrows. The app keeps the readings in the mentoring file, records them through a sheet, and shows every card as a list of arrows that says which were read and which are guesses.

**Tech Stack:** Swift 6, macOS 26, SwiftUI and Observation, Swift Testing, Foundation only. Same packages and conventions as the mentoring plan.

**Spec:** `docs/superpowers/specs/2026-11-14-fm27-mentoring-arrows-design.md` (approved 14 November 2026). It amends `docs/superpowers/specs/2026-11-14-fm27-mentoring-design.md` ("the first design"); where they differ the arrows design wins. The look: `docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md`. The plan this one follows: `docs/superpowers/plans/2026-11-14-fm27-mentoring.md`.

**Order of the tasks.** The design's section 13 puts the fixture fourth. Here it is second, because the check of the guess against the readings needs only Task 1, and because Tasks 3 and 4 change types the app reads: **from the end of Task 3 until the end of Task 5 the app package does not build.** Tasks 3 and 4 run the engine's suite only; Task 5 makes the app build and pass again. Nothing is installed and no inserted work touches the app between those points.

## Global Constraints

- Work on branch `fm27-native`. Never commit to `main`, merge, open a pull request or push. Stage files by name; commit messages say why.
- The engine decides; the app shows. A view never computes an arrow, a guess, a gain, a warning or a rule. Every word about advice (strength names, "expected, not read", warnings, states, reasons, the standing note) comes from the engine's `AdvisorText`; `LineupAppCore` holds only plain labels and headings ("Record arrows", "Arrows", "Not read", "read" before a day, a sheet's title).
- Logic for a screen lives in `LineupAppCore` with tests written first. Views hold layout only. Every colour, typeface and measure comes from `Theme`. Nothing the owner reads is an id, a key or a code.
- Every tunable number is in `EngineParameters` with an evidence label and a source. The exact values:
  - strengths: None 0, Light 1, Average 2, Significant 3 (`.derived`: they only order the choices);
  - the guess, by the source's level, for a target of 23 or younger: Team Leader Average, Highly Influential Light, Influential Light, Others None; for a target of 24 or older: None from every level; and None whenever the target stands at the source's level or above it, or takes nothing (`.derived`);
  - a player takes nothing with readings of None from at least **3** different sources at Influential or above and no reading above None (`.derived`);
  - the age line of the guess, 23, is the existing `mentoringMenteeMaxAge`; its evidence becomes `.fm27Observation` and its source names the owner's readings of 14 November 2026;
  - worth is unchanged: weights Professionalism 3, Pressure 2, Determination 1, Ambition 1; ceilings 20, 6, 10, 10; thirteen weeks before a group is called stopped; a hierarchy is stale after 28 days.
- A candidate's gain in a group is the greatest gain of any one arrow into him, never the sum. A group is exactly three players (`Mentoring.groupSize`).
- No number that reads like a forecast is shown: no gain, no value, no score. A card shows the strength in the game's word and the two values, "Professionalism 10, towards 12".
- A guess is never shown as if it had been read: every arrow line says "read" and its day, or "expected, not read".
- Every rule gets a test where it changes an outcome and a test where it does not. The same inputs give the same report whatever the order of the input arrays. Every `switch` over an engine enum is exhaustive, with no `default`.
- Saved state is versioned JSON under the Store's directory. A mentoring file written by the installed app (hierarchy entries with their squad, groups, personality readings, names, and no arrows) opens with no notice and loses nothing.
- No task reads `~/Library/Application Support`, the real clipboard or FMRTE's settings file. Tests, picture runs and sample-data runs use temporary directories. No player data goes anywhere but `LineupEngine/Tests/LineupEngineTests/Fixtures/`; pictures go under `LineupApp/.build/`. Existing fixtures are not changed.
- No build warnings. Engine: `cd LineupEngine && swift test`, the 594-case reference check unchanged. App, from Task 5 on: `cd LineupApp && swift build && swift test`.
- A screen is not done until its pictures have been looked at (every light picture and its dark twin are the same file in this app, so one of each pair is enough), at the default size and at 760 points wide.
- No task runs `tools/build_app.sh` or opens the app. The controller installs after the final review.
- Do not modify Python, `ui/`, `.bat` files or the rating resource files.

## Review Focus

Conditions the design implies but no rule's own test covers, most likely first. Each has a test in the task named.

1. **The installed app's mentoring file.** It has `hierarchy`, `dynamicsUpdatedOn`, `groups`, `readings` and `names`, and no arrows. Expected: it opens with no notice, every entry, group and reading is still there, and the next save keeps them and adds an empty list of arrows. (Task 6)
2. **A reading whose player has moved squad, gone out on loan or left.** Expected: the reading stays in the file and is not used; no arrow into or out of him is shown for that squad; the takes-nothing count for the squad ignores readings whose other player has gone; the arrows sheet for a trio with a gone member cannot be saved and says why; nothing throws. (Tasks 3, 4, 6)
3. **The owner changes a level after arrows were read.** Expected: readings stand as read; guesses and who takes nothing follow the levels as they now are (a source demoted to Others no longer counts towards the three), with no stale result kept. (Tasks 1, 3)
4. **Arrows above None both ways between two players, or a ring of three.** Expected: both arrows are shown; harm is judged for each arrow on its own; a recorded group watches every member with an arrow into him; nothing loops or throws. (Tasks 3, 4)
5. **Fewer than three free players**: a squad of two, or a squad whose players are all in recorded groups or out on loan. Expected: no suggestion, each candidate left with a reason, nothing thrown. (Task 3)

## File Structure

Engine (`LineupEngine/Sources/LineupEngine/`):

- `Advisors/MentoringModel.swift`: gains `ArrowStrength` and `ArrowReading`; loses who-stands-above-whom and the social-group comparison in Task 4.
- `Advisors/MentoringArrows.swift` (new): an arrow between two players, the guess, who takes nothing.
- `Advisors/Mentoring.swift`: the request gains the readings; the suggestions and the not-placed list are rebuilt on arrows.
- `Advisors/MentoringReview.swift`: a recorded group read from its six arrows.
- `Reporting/AdvisorText+Mentoring.swift`: every new sentence; the old ones about leads, age alone and social groups go.
- `Parameters/EngineParameters.swift`: three parameters added, two removed, one relabelled.
- `Sources/lineup-cli/Report.swift`, `main.swift`: `advise` prints groups as arrows. The command line takes no arrow readings.

Engine tests (`LineupEngine/Tests/LineupEngineTests/`): `MentoringArrowsTests.swift` (new), `MentoringFixtureTests.swift` (new), `Support/MentoringFixture.swift` (new), and the existing `MentoringTests.swift`, `MentoringReviewTests.swift`, `MentoringModelTests.swift`, `MentoringTextTests.swift`, `EngineParametersTests.swift`, `EndToEndTests.swift`.

App (`LineupApp/Sources/`):

- `LineupAppCore/MentoringState.swift`: the readings, and the draft of an arrows sheet.
- `LineupAppCore/AppModel+Mentoring.swift`: recording arrows; the request handed the readings.
- `LineupAppCore/MentoringPresentation.swift`: arrow lines on both kinds of card; the sheet's rows and labels.
- `LineupAppCore/Navigation.swift`: the arrows sheet as something the tab has open.
- `LineupAppCore/SampleData.swift`: samples with arrows read.
- `LineupAppUI/Advice/MentoringCards.swift`, `MentoringTab.swift`, `MentoringEditors.swift`, `Theme.swift`; `Sources/LineupApp/main.swift` (the picture run).

App tests (`LineupApp/Tests/LineupAppCoreTests/`): `MentoringStateTests.swift`, `AppModelMentoringTests.swift`, `MentoringPresentationTests.swift`.

---

### Task 1: Arrows, readings, the guess, and who takes nothing

Adds to the engine and removes nothing, so both packages still build.

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/MentoringModel.swift`
- Create: `LineupEngine/Sources/LineupEngine/Advisors/MentoringArrows.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift`
- Test: create `LineupEngine/Tests/LineupEngineTests/MentoringArrowsTests.swift`; modify `MentoringModelTests.swift` (`problemsAreFound`), `EngineParametersTests.swift` (`theMentoringParametersAreListedWithEvidenceAndSource`)

**Interfaces:**
- Consumes: `Standing`, `Squad`, `PlayerID`, `Day`, `Mentoring.problems(in:)` as built.
- Produces:
  ```swift
  /// The game's four strengths, weakest first, so `<` reads "is weaker".
  public enum ArrowStrength: String, Codable, CaseIterable, Comparable, Sendable { case none, light, average, significant }

  /// An arrow the owner read in the game: one for an ordered pair in a squad.
  public struct ArrowReading: Equatable, Codable, Sendable {
      public var from: PlayerID; public var to: PlayerID
      public var squad: Squad
      public var strength: ArrowStrength
      public var readOn: Day
      public init(from: PlayerID, to: PlayerID, squad: Squad, strength: ArrowStrength, readOn: Day)
  }

  /// One way between two players, as the advice uses it: read, or guessed.
  public struct Arrow: Equatable, Sendable {
      public let from: PlayerID; public let to: PlayerID
      public let strength: ArrowStrength
      public let readOn: Day?                 // nil: a guess
      public var isRead: Bool { readOn != nil }
  }

  extension Mentoring {
      /// What a guess reads about a player.
      public struct Party: Equatable, Sendable {
          public let id: PlayerID; public let standing: Standing; public let age: Int
          public init(id: PlayerID, standing: Standing, age: Int)
      }
      /// The guess for a pair with no reading (the design's section 8.2).
      public static func guess(from: Party, to: Party, toTakesNothing: Bool, parameters: EngineParameters) -> ArrowStrength
      /// Readings of None into him from at least `mentoringTakesNothingAfter` different sources whose level, in
      /// `standings`, is Influential or above, and no reading into him above None. Only readings of `squad` count.
      public static func takesNothing(_ player: PlayerID, in squad: Squad, readings: [ArrowReading],
                                      standings: [PlayerID: Standing], parameters: EngineParameters) -> Bool
      /// The reading for the pair in `squad` when there is one, otherwise the guess.
      public static func arrow(from: Party, to: Party, in squad: Squad, readings: [ArrowReading],
                               standings: [PlayerID: Standing], parameters: EngineParameters) -> Arrow
  }
  ```
  Parameters, in `EngineParameters` beside the other mentoring ones and set in `fm27`:
  - `mentoringGuess: Parameter<[Standing: ArrowStrength]>` = `[.teamLeader: .average, .highlyInfluential: .light, .influential: .light, .others: .none]`, `.derived`, source: `the owner's readings of the game's mentoring arrows, 14 November 2026 (Fixtures/mentoring/arrow-readings-2026-11-14.json): 6 of the 8 arrows his two Team Leaders gave were Average or Significant, 1 of 18 from every other senior was, and a player at Others gave none; the guess for a pair not read is this design's`.
  - `mentoringStrengthWeights: Parameter<[ArrowStrength: Int]>` = `[.none: 0, .light: 1, .average: 2, .significant: 3]`, `.derived`, source: `this design's choice: they only order which group is suggested first`.
  - `mentoringTakesNothingAfter: Parameter<Int>` = `3`, `.derived`, source: `this design's choice; in the owner's readings of 14 November 2026 one player took nothing from four seniors and another from four`.
  - `mentoringMenteeMaxAge` keeps 23; its evidence becomes `.fm27Observation` and its source: `the owner's readings of 14 November 2026: of four players of 24 and over, one took Light from two seniors and the others nothing in eight tries; the line at 23 is this design's`.

Decisions:

- A player with no entry in `standings` is at Others.
- `takesNothing` counts sources, not readings, and reads each source's level as `standings` now has it, so a level changed after the reading changes the count.
- `problems(in:)` gains: `mentoringGuess` has no entry for a level; `mentoringStrengthWeights` has no entry for a strength; gives None a weight other than 0; has a weight below 0; has a stronger arrow weighing less than a weaker one; `mentoringTakesNothingAfter` is not above 0. Each as a plain sentence in the style of the ones there, sorted as they are.

- [ ] **Step 1: Write the failing tests** in `MentoringArrowsTests` (a helper `party(_ name: String, _ standing: Standing, _ age: Int)`):
  - `theGuessCellByCell`: Team Leader to a 23-year-old at Others `.average`; to a 24-year-old `.none`. Highly Influential to 23 `.light`; to 24 `.none`. Influential to 23 `.light`; to 24 `.none`. Others (aged 30) to an 18-year-old `.none`.
  - `noGuessIntoAPlayerAtTheSameLevelOrAbove`: Influential to Influential aged 20 `.none`; Influential to Team Leader `.none`; Team Leader to Team Leader `.none`; Highly Influential to Influential aged 20 `.light`.
  - `aPlayerWhoTakesNothingIsGuessedNone`: Team Leader to a 20-year-old with `toTakesNothing: true` is `.none`; with `false` `.average`.
  - `takingNothingNeedsThreeSeniorsAndNoArrow`: three readings of `.none` into him from three sources at Influential, Highly Influential and Team Leader: true. Two: false. Three where one source is at Others: false. Three Nones and a fourth reading of `.light` into him: false. Three Nones read in another squad: false. A source whose level is then set to Others in `standings`: false (Review Focus 3).
  - `aReadingStandsInForTheGuess`: with a reading of `.significant` on day D for the pair, `arrow` gives `.significant`, `readOn == D`, `isRead`; with none it gives the guess and `readOn == nil`; a reading for the same pair in another squad is not used; a reading of `.none` is returned as read, not replaced by the guess.
  - `strengthsAreOrderedAndStoredByTheirWords`: `ArrowStrength.allCases == [.none, .light, .average, .significant]`, `.light < .average`, and the JSON of `[ArrowStrength.none, .significant]` is `["none","significant"]`; an `ArrowReading` equals its own JSON round trip.
  - In `MentoringModelTests.problemsAreFound`: one case for each new problem above, each asserting the sentence.
  - In `EngineParametersTests`: the three new names listed with `.derived` and a source; `mentoringMenteeMaxAge` listed with `.fm27Observation`; the three values as given above.
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter "MentoringArrowsTests|MentoringModelTests|EngineParametersTests"`: expect a build failure (the new names do not exist).
- [ ] **Step 3: Implement** the types, the three functions, the parameters and the checks.
- [ ] **Step 4: Run** `cd LineupEngine && swift test`, then `cd ../LineupApp && swift build && swift test`: all pass, no warnings.
- [ ] **Step 5: Commit**: "Give mentoring the game's arrows: a reading, a guess where none is read, and who takes nothing".

---

### Task 2: The owner's readings as a fixture, and the guess checked against them

Tests only. Both packages still build.

**Files:**
- Create: `LineupEngine/Tests/LineupEngineTests/Support/MentoringFixture.swift`
- Create: `LineupEngine/Tests/LineupEngineTests/MentoringFixtureTests.swift`
- Read, not changed: `Fixtures/mentoring/arrow-readings-2026-11-14.json` (committed), `Fixtures/mentoring/README.md`, and `Fixtures/mentoring/first-team-2026-11-14.json` (see below)

**The two fixture files.**
- `arrow-readings-2026-11-14.json` exists. Its shape: `{"what", "readOn": "2026-11-14", "strengths": [...], "howToRead", "groups": [{"set", "members": [three names], "arrows": [{"from", "to", "strength"}], "note"?}], "confirmedOnReReading": [{"from", "to", "strength"}]}`. A strength is `none`, `light`, `average` or `significant`. Every ordered pair of a group's members that has no arrow listed was read as None.
- `first-team-2026-11-14.json` is made by the controller before this plan is run, if the owner agrees to those facts being copied from the app's saved state. Its shape: `{"players": [{"name", "age", "level", "socialGroup", "professionalism", "pressure", "determination", "ambition"}]}`, twenty players, where `level` is one of `teamLeader`, `highlyInfluential`, `influential`, `others`, and `socialGroup` is the `SocialGroup` code (`"core"`, `"others"`, `"secondary:A"`) or `null`.
- **If `first-team-2026-11-14.json` does not exist when this task starts**, two tests are dropped from the plan and nothing else changes: `theGuessAgainstEveryReading` here, and `theFirstTeamsSuggestionsFromTheReadingsHaveNoHarmfulArrow` in Task 3. Say so in the report. Do not make the file, and do not read the app's saved state to make it.

**Interfaces:**
- Consumes: Task 1; `Fixtures.data(_:)`, `Player.fixture(...)`, `PlayerID.normalise(_:)` in the test support.
- Produces (test support only):
  ```swift
  enum MentoringFixture {
      struct Group { let set: String; let members: [String]; let arrows: [(from: String, to: String, strength: ArrowStrength)] }
      static func groups() throws -> [Group]
      /// Every ordered pair of every group's members with the strength read; a pair read in two groups appears once.
      static func pairs() throws -> [(from: String, to: String, strength: ArrowStrength)]
      /// Every reading as the engine takes it: the first team's, read on 14 November 2026, players keyed by name.
      static func readings() throws -> [ArrowReading]
      /// The twenty players with their ages and four counted values, every other attribute 10; and their levels.
      static func squad() throws -> (players: [Player], dynamics: [PlayerID: PlayerDynamics])
  }
  ```

- [ ] **Step 1: Write the tests** in `MentoringFixtureTests`:
  - `theReadingsAreTwentyFourGroupsOfThree`: 24 groups; each has three different members; every arrow runs between two of its group's members; the arrows listed number 30.
  - `noPairWasReadTwoWays`: a pair that appears in more than one group has the same strength in each. `pairs()` has 124 entries, 27 of them above None.
  - `everyoneInTheReadingsIsInTheSquad`: every name in the readings is one of the twenty players.
  - `theGuessAgainstEveryReading`: for each of the 124 pairs, `Mentoring.guess` from the two players' levels and ages, with `toTakesNothing: false`. It agrees exactly with the reading for **104** pairs, and agrees on None against not-None for **111**. These two numbers were worked out from the readings when this plan was written. If the run gives others, stop and report both sets of numbers; do not change the pinned ones to match.
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter MentoringFixtureTests`: expect a build failure (`MentoringFixture` does not exist).
- [ ] **Step 3: Implement** `MentoringFixture`.
- [ ] **Step 4: Run** `cd LineupEngine && swift test`: all pass, no warnings.
- [ ] **Step 5: Commit**: "Check the guess against the arrows the owner read, so a change to it can be seen to help or not".

---

### Task 3: Suggested groups rebuilt on arrows

**From the end of this task the app package does not build; do not run it. It builds again at the end of Task 5.**

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/Mentoring.swift` (rewritten below the request)
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Mentoring.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/MentoringModel.swift` and `Parameters/EngineParameters.swift` (the social-group share goes)
- Modify: `LineupEngine/Sources/lineup-cli/Report.swift`, `main.swift`
- Test: rewrite `MentoringTests.swift`; modify `MentoringTextTests.swift`, `MentoringModelTests.swift`, `EngineParametersTests.swift`, `EndToEndTests.swift`, `MentoringReviewTests.swift` (its request helper), `MentoringFixtureTests.swift`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces:
  ```swift
  // MentoringRequest gains, after `readings`:
  public var arrows: [ArrowReading]                 // every reading; only this squad's, between two players present, are used

  /// An arrow of a group, with what its target would gain.
  public struct GroupArrow: Equatable, Sendable {
      public let arrow: Arrow
      public let fromName: String; public let toName: String
      /// The counted attributes in which the target is worth less than the source, in `counted` order; empty: nothing to gain.
      public let pulls: [Pull]
  }
  public enum MemberCaution: Equatable, Sendable { case onLoanHere(PlayerID), advisedToLeave(PlayerID) }
  public struct SuggestedMember: Equatable, Sendable { public let player: PlayerID; public let name: String; public let age: Int }
  public struct SuggestedGroup: Identifiable, Equatable, Sendable {
      public var id: String { members.map(\.player.key).joined(separator: "|") }
      public let members: [SuggestedMember]         // three, by key
      public let arrows: [GroupArrow]               // those above None: greatest gain first, then from key, then to key
      public let isRead: Bool                       // every arrow it rests on was read
      public let cautions: [MemberCaution]          // on loan here first, then advised to leave; within each by key
      public let basis: Evidence
  }
  public enum NotPlacedReason: Equatable, Sendable {
      case takesNothing, noInfluence, nothingToGain, wouldHarm, influencersTaken
  }
  public struct MentoringReport: Equatable, Sendable {
      public let squad: Squad
      public let needsHierarchy: Bool               // no player of the squad not out on loan stands above Others
      public let isStale: Bool
      public let suggestions: [SuggestedGroup]      // in the order they were formed
      public let notPlaced: [NotPlaced]             // by player key
      public let groups: [GroupReview]
      public let basis: Evidence
  }
  ```
  `Pull`, `NotPlaced` and `Mentoring.report(_:parameters:)`'s signature and what it throws are unchanged. `LeadCaution`, `SuggestedGroup.lead`, `leadName`, `leadAge`, `leadStanding`, `SuggestedMember.isMakingUp`, `pulls`, `inDifferentSocialGroup` and `MentoringReport.byAgeAlone` are removed. `EngineParameters.mentoringOtherSocialGroupShare` is removed with its check in `problems(in:)`.

Decisions:

- **The people** are the squad's players not out on loan, by key, as now. **The pool** is those in no live recorded group. **A candidate** is a pool player who belongs to the club, is not in `leaving`, and is below the ceiling in at least one counted attribute. There is no age line: age acts through the guess.
- **The arrows.** For every ordered pair of people, `Mentoring.arrow` with the request's readings and levels. A reading is used only when both its players are people of this squad.
- **Gain** of an arrow for its target: the strength's weight times the sum, over the counted attributes, of the source's worth less the target's. **Harmful**: its strength is above None and the source is worth less than the target in any one counted attribute.
- **A valid group** is three pool players with no harmful arrow among its six and at least one candidate with an arrow into him whose gain is above 0. **Its value** is the sum, over its candidates, of the greatest gain above 0 of any one arrow into him.
- **How the groups are found**: of every valid group among the pool players not yet used, take the one of greatest value; ties go to the group with fewer members whose level is above Others (so a senior is not spent where he adds nothing), then to the group with more of its six arrows read, then to the lowest keys compared in order. Set its three players aside and repeat until no valid group is left. A squad of twenty has 1,140 groups of three, so trying them all each round is fine.
- **What a suggestion rests on**: for each of its candidates with a gain, the arrow that gives it (of two with the same gain, a read one before a guessed one, then the lower source key). `isRead` is true when every one of those was read.
- **Cautions**: a member who is the source of an arrow a suggestion rests on, and who is on loan at the club or in `leaving`.
- **Not placed**: every candidate in no suggested group, with the first reason that applies, judged against every person, members of recorded groups included:
  1. `takesNothing`: he takes nothing by his readings.
  2. `noInfluence`: no arrow into him, read or guessed, is above None.
  3. `nothingToGain`: no arrow into him above None has a gain above 0. (The design's list has no reason for this case; this is the plan's.)
  4. `wouldHarm`: a pool player has an arrow into him with gain, yet no valid group among the whole pool holds him with a gain.
  5. `influencersTaken`: otherwise: the players who could influence him are in a suggested or recorded group.
- `needsHierarchy` is true when no person has a level above Others, whether or not readings produced a suggestion.
- `basis` is the weakest evidence of the weights, the ceilings, the strength weights, the guess and the takes-nothing number: `.derived`.
- **The words**, in `AdvisorText+Mentoring.swift`. Removed: `lead(_:)`, `makingUpTheGroup`, `caution(_:leadName:)`, `otherSocialGroup(leadName:)`, `mentoringByAgeAlone`. Added, with these exact texts:
  - `name(_ strength: ArrowStrength)`: `None`, `Light`, `Average`, `Significant`.
  - `arrowTitle(_ arrow: GroupArrow)`: `McEachran → Clark` (the two names with ` → ` between).
  - `expectedNotRead`: `expected, not read`.
  - `nothingToGain`: `nothing to gain`.
  - `setAndRecordArrows`: `Set this group in the game and record its arrows.`
  - `caution(_ caution: MemberCaution, names: [PlayerID: String])`: `Hart is on loan here: the group ends when he goes back.` and `Hart is advised to leave: the group ends when he goes.` A name it lacks is `A player`, never a key.
  - `mentoringNeedsHierarchy`: `Enter this squad's hierarchy first: mentoring needs each player's level, and age alone creates no influence.`
  - `mentoringNote` becomes: `How fast mentoring works in FM27 has not been measured. An arrow is the game's own where it has been read, and this tool's guess where it says expected.`
  - `notPlaced(_:)`, after `Name (age): `: `he has taken nothing from the players tried with him so far.`; `nobody in this squad is expected to influence him.`; `nobody who influences him is better where it counts.`; `every group that would help him would pull a player down.`; `the players who could influence him are already in a group.`
- **The command line.** `advise` builds each request with `arrows: []` and prints, for each suggestion, the three names joined with `, ` and the evidence mark, then a line for each arrow: its title, the strength's name, ` · ` and `expected, not read`, then the pulls joined with ` · ` or `nothing to gain`; then `setAndRecordArrows` when the suggestion is not read, and each caution. The line for age alone goes; `mentoringNeedsHierarchy` is printed when the report needs its hierarchy. The usage text at the top of `main.swift` says the command line takes no arrow readings.

- [ ] **Step 1: Write the failing tests.** `MentoringTests.swift` is rewritten. Its helpers gain `arrows: [ArrowReading]` on `request` and `report`, a `reading(_ from: String, _ to: String, _ strength: ArrowStrength)` for the first team on `today`, and `shape` becomes each suggestion's three keys. Kept, with their calls adapted: `aPlayerAtEveryCeilingAppearsNowhere`, `aMissingCountedValueIsAnErrorNamingThePlayer`, `badParametersThrow`, `onlyTheSquadAskedForIsLookedAt`, `inputOrderDoesNotMatter` (shuffle the readings too), `anInjuredPlayerIsTreatedLikeAnyOther`, `notPlacedIsByKey`, `membersOfARecordedGroupAreLeftOut`. Every other test there is deleted; these replace them:
  - `aTeamLeaderAndTwoYoungPlayersMakeAGroup`: a Team Leader aged 30 (Professionalism 17, Pressure 12, Determination 15, Ambition 10), a player of 18 (8, 4, 10, 10) and one of 19 (11, 12, 7, 10), everyone else absent. One group of the three. Its arrows, in order: Team Leader to the 18-year-old `.average`, not read, pulls Professionalism 8 towards 17 and Pressure 4 towards 12; Team Leader to the 19-year-old `.average`, not read, pulls Professionalism 11 towards 17 and Determination 7 towards 15. `isRead` false; no caution.
  - `aReadingStandsInForTheGuess`: the same squad with a reading of `.significant` from the Team Leader to the 18-year-old: that arrow is `.significant` and read. With a reading of `.none` instead: no arrow into him is listed, and the group still forms on the other.
  - `anInfluentialPlayerIsGuessedLightAndOthersNothing`: an Influential player of 30 with Professionalism 20 and two players of 20 at 10: one group, both arrows `.light`. The same senior at Others: no group, both juniors `noInfluence`, `needsHierarchy` true.
  - `aPlayerOf24ComesInOnlyByAReading`: a Team Leader (Professionalism 20) with players of 24 and 20 at 10: the group forms on the 20-year-old; no arrow into the 24-year-old. With a reading of `.light` into the 24-year-old, that arrow is listed with its pull.
  - `aCandidatesGainIsHisGreatestArrowNotTheSum`: a Team Leader and an Influential senior, both Professionalism 20, and two juniors of 20 at 10. The suggestion is the Team Leader with the two juniors, not the two seniors with one junior.
  - `noGroupHoldsAHarmfulArrow`: a Team Leader with Ambition 6 and a junior with Ambition 9: no group, the junior `wouldHarm` (add a second junior so three are free). With Ambition 11 against 14, both at the ceiling: grouped.
  - `aHarmfulArrowBetweenTheOtherTwoAlsoStopsTheGroup`: a Team Leader (Professionalism 20), an Influential player of 23 with Pressure 3, and a junior of 18 with Pressure 5, plus a second junior of 19 at 10. The suggestion holds the Team Leader and the two juniors, not the Influential player. With a reading of `.none` from the Influential player to the junior of 18, a group holding all of Team Leader, Influential player and that junior is valid.
  - `theMostValuableGroupIsFormedFirst`: one Team Leader (Professionalism 20) and three juniors with Professionalism 8, 12 and 16: the first two are grouped; the third is `influencersTaken`.
  - `tiesGoToFewerSeniorsThenMoreArrowsReadThenTheLowestKeys`: a lead and one junior with something to gain, and two possible third players who add nothing, one Influential and one at Others: the one at Others is taken, and the Influential player is then free to lead the next group. Two juniors of equal gain and a third player with nothing to gain or give: with no reading, the lowest keys win; with a reading (of the guessed strength) on one pair of the other choice, that choice wins.
  - `aSuggestionIsReadOnlyWhenEveryArrowItRestsOnWasRead`: read both arrows into the two juniors: `isRead`. Read one: not. A read arrow of `.none` elsewhere in the group changes nothing.
  - `aSourceWhoWillGoCarriesTheCaution`: the Team Leader on loan at the club: `.onLoanHere`; in `leaving`: `.advisedToLeave`; both: in that order. A third member who gives nothing and is in `leaving`: no caution.
  - `aLoaneeOrALeaverIsNeverACandidateAndALoanedOutPlayerIsNowhere`.
  - `aPlayerWhoTakesNothingSaysSo`: three readings of None into a junior from three seniors at Influential or above, and a fourth senior, a Team Leader, never read with him: no arrow into him is guessed, and he is `takesNothing`. Set one of the three sources to Others: he is grouped with the Team Leader (Review Focus 3).
  - `eachNotPlacedReason`: one case for each of the five.
  - `aSquadWithNoLevelsNeedsItsHierarchyButArrowsReadStillCount`: three players at Others, a reading of `.light` from the eldest (Professionalism 20) into a junior at 10: one group, `needsHierarchy` true.
  - `aReadingForAnotherSquadOrAPlayerWhoHasGoneIsNotUsed` (Review Focus 2): a reading in the U21s between two first-team players; a reading whose source is out on loan; a reading whose source is not among the players: none changes the first team's report, and nothing throws.
  - `arrowsBothWaysAndARingOfThree` (Review Focus 4): readings of `.light` each way between two players who are each better than the other in one attribute: both arrows are harmful, no group holds the pair. A ring of three `.light` readings among three players of equal worth: a valid group only if one of them is a candidate with gain; nothing loops.
  - `fewerThanThreeFreePlayers` (Review Focus 5): two players only; three players of whom one is in a recorded group; three of whom one is out on loan: no suggestion, each candidate has a reason, nothing thrown.
  - `staleAfterFourWeeks`: 29 days stale, 28 not, never entered not.
  - In `MentoringFixtureTests`: `theFirstTeamsSuggestionsFromTheReadingsHaveNoHarmfulArrow`: the fixture's squad, levels and readings give at least one suggestion; no player is in two; for every ordered pair in a suggested group whose reading is above None, the source is worth no less than the target in every counted attribute; every suggestion has an arrow with a pull. Write the groups it gives into your report.
  - `MentoringTextTests`: `theStandingSentences`, `aSuggestedGroupSentences` and `eachNotPlacedReasonHasItsOwnSentence` are rewritten to the texts above, each sentence asserted whole; a new `strengthsHaveTheGamesWords`; the caution with a name missing reads `A player is on loan here: the group ends when he goes back.`
  - `MentoringModelTests.problemsAreFound` and `EngineParametersTests` lose the social-group share. `EndToEndTests.mentoringRunsOnTheCapturedSquads`: with no levels and no readings both squads need their hierarchy and have no suggestion, and every candidate is on the not-placed list with `noInfluence`; with the first team's three eldest players set to Team Leader, at least one suggestion of exactly three different first-team players, no player in two (if the capture gives none, report what it gave; do not weaken the test).
  - `MentoringReviewTests`: its request helper passes `arrows: []`; no assertion changes.
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter "MentoringTests|MentoringTextTests|MentoringFixtureTests"`: expect a build failure.
- [ ] **Step 3: Implement** `report`, the words and the command line as decided.
- [ ] **Step 4: Run** `cd LineupEngine && swift test`: all pass, no warnings. Then `swift run -q lineup-cli advise` on the captured squads as `CLAUDE.md` gives it, and read the mentoring section: by itself it now says the hierarchy is needed. Do not build the app.
- [ ] **Step 5: Commit**: "Suggest mentoring groups from arrows: read where the owner has read them, guessed and said so where he has not".

---

### Task 4: A recorded group read from its six arrows

The app package still does not build.

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/MentoringReview.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/MentoringModel.swift` (`standsAbove` and `sameSocialGroup` go), `Parameters/EngineParameters.swift` (`mentoringSeniorityYears` goes)
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Mentoring.swift`
- Test: `MentoringReviewTests.swift`, `MentoringModelTests.swift`, `MentoringTextTests.swift`, `EngineParametersTests.swift`

**Interfaces:**
- Consumes: Tasks 1 and 3 (`Arrow`, `GroupArrow`, `Mentoring.arrow`, the request's `arrows`).
- Produces:
  ```swift
  public struct MemberReview: Equatable, Sendable {      // `isLead` and `pulls` are removed
      public let player: PlayerID; public let name: String; public let age: Int?
      public let changes: [AttributeChange]
  }
  public enum GroupWarning: Equatable, Sendable {
      /// An arrow above None whose source is worth less than its target in this counted attribute.
      case harmfulArrow(from: PlayerID, to: PlayerID, strength: ArrowStrength, isRead: Bool,
                        attribute: Attribute, fromValue: Int, toValue: Int)
      case notInSquad(PlayerID)
      case outOnLoan(PlayerID, club: String)
      case advisedToLeave(PlayerID)
  }
  public struct GroupReview: Identifiable, Equatable, Sendable {
      public var id: UUID { group.id }
      public let group: MentoringGroup
      public let members: [MemberReview]            // the current members, by player key
      public let arrows: [GroupArrow]               // above None, between present members: strongest first, then from key, then to key
      public let unreadArrows: Int                  // of the arrows between present members, how many are guesses
      public let hasNoInfluence: Bool               // all three present, all six read, all None
      public let warnings: [GroupWarning]
      public let isDoingHarm: Bool
      public let hasStoppedWorking: Bool
      public let basis: Evidence
  }
  ```
  `GroupReview.lead`, `GroupWarning.nobodyLeads`, `.mayBeDraggedDown` and `.differentSocialGroup`, `Mentoring.standsAbove`, `Mentoring.sameSocialGroup` and `EngineParameters.mentoringSeniorityYears` are removed.

Decisions:

- A member is present as now. Arrows are worked out between present members only, with the request's readings and levels; a member with no value for a counted attribute has arrows but no pulls and no harm judged.
- **Warnings**, in the order of the cases: one `harmfulArrow` for each arrow above None and each counted attribute in which its source is worth less (by the source's key, the target's key, then `counted` order); then the three about members who have gone, as now.
- **Watched** for "stopped": the current members with an arrow above None into them, read or guessed. With none watched the group is never called stopped. `hasNoInfluence` and `isDoingHarm` are each never set together with `hasStoppedWorking`. "Doing harm" still looks at every current member's readings.
- `basis`: the weakest of the weights, the ceilings, the strength weights, the guess and the thirteen weeks.
- **The words.** `warning(_:names:)` for `harmfulArrow`: read: `Ashby's influence on Nelson is Significant, and his Ambition is 6 against 13.`; guessed: `Ashby's influence on Nelson is expected to be Average, and his Ambition is 6 against 13.` The other three as now. The sentences for the removed cases go. `state(of:parameters:)`: doing harm as now; then, for no influence, `The game shows no influence in this group: all six arrows are None. Consider regrouping.`; then stopped: `This group has stopped working: nobody it influences has changed in 13 weeks. Consider regrouping.` New: `arrowsToRead(_ review: GroupReview) -> String?`: nil when none is unread, otherwise `Record this group's arrows from the game: 4 of them are still guesses.` (`1 of them is still a guess.`); and `socialGroupsNotUsed`: `Social groups are kept as entered. They do not change the advice.`

- [ ] **Step 1: Write the failing tests.** In `MentoringReviewTests`, deleted: `theLeadStandsAboveEveryOtherMember`, `nobodyLeadsWhenTwoAreLevel`, `pullsShowBothDirections`, `aDifferentSocialGroupIsACaution`, `aMemberWithAMissingValueHasNoPulls`. Rewritten: `stoppedAfterThirteenWeeksWithNoChange`, `everyWarningInOrder`, `aMemberWhoHasLeftIsAWarningNotAnError`, `inputOrderDoesNotMatter`. The rest keep their assertions. New:
  - `theSixArrowsAreReadOrGuessed`: a Team Leader and two juniors with one arrow read `.significant`: `arrows` lists it read and the other guessed `.average`; `unreadArrows == 5`. With all six read: 0.
  - `aHarmfulArrowIsAWarningWithItsStrength`: a read `.significant` arrow from a member with Ambition 6 into one with 13: one warning with those values and `isRead` true; guessed: `isRead` false. The same arrow read as `.none`: no warning.
  - `noInfluenceAtOnceWhenAllSixAreReadAsNone`: six readings of None: `hasNoInfluence`, not stopped whatever the dates. Five read: not. One member out on loan: not.
  - `stoppedWatchesTheMembersWithAnArrowIntoThem`: fourteen weeks, no change in the junior the arrow points at: stopped. The same with a change in him at week ten: not. With a change only in the source: stopped. With no arrow above None in the group and not all read: never stopped.
  - `arrowsBothWaysAreBothJudged` (Review Focus 4): each arrow harmful in its own attribute gives two warnings; both members are watched.
  - `aMemberWhoHasGoneHasNoArrows` (Review Focus 2): out on loan, moved squad, not imported: no arrow into or out of him, `unreadArrows` counts only the pair that is left, the warning for him as before, nothing throws.
  - `MentoringTextTests`: `eachWarningHasItsOwnSentence` and `aGroupDoingHarmOrStoppedSaysSoAndOtherwiseNothing` rewritten to the texts above; `arrowsToRead` for 0, 1 and 4; `socialGroupsNotUsed`.
  - `MentoringModelTests`: `aHigherStandingStandsAboveWhateverTheAge`, `theSameStandingNeedsFiveYears`, `aLowerStandingNeverStandsAbove` and `socialGroups` are deleted; `problemsAreFound` and `EngineParametersTests` lose the seniority years.
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter "MentoringReviewTests|MentoringTextTests|MentoringModelTests"`: expect a build failure.
- [ ] **Step 3: Implement** the review and the words.
- [ ] **Step 4: Run** `cd LineupEngine && swift test`: all pass, no warnings. `grep -rn "standsAbove\|sameSocialGroup\|mentoringSeniorityYears\|mentoringOtherSocialGroupShare\|byAgeAlone\|isMakingUp\|LeadCaution" LineupEngine/Sources` finds nothing.
- [ ] **Step 5: Commit**: "Read a recorded group from its six arrows: no influence said at once, and a strong arrow the wrong way warned of".

---

### Task 5: The app builds again: cards as lists of arrows

No arrows can be recorded yet: the request is handed none, so every arrow the app shows is a guess. The views get the smallest change that compiles and draws the new lines; their layout is Task 7's.

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/MentoringPresentation.swift`, `AppModel+Mentoring.swift`, `SampleData.swift`
- Modify: `LineupApp/Sources/LineupAppUI/Advice/MentoringCards.swift`, `MentoringTab.swift`, `MentoringEditors.swift`
- Modify: `LineupApp/Sources/LineupApp/main.swift` only if a sample's name changes
- Test: `LineupApp/Tests/LineupAppCoreTests/MentoringPresentationTests.swift`, `AppModelMentoringTests.swift`

**Interfaces:**
- Consumes: Tasks 3 and 4.
- Produces (Core):
  ```swift
  public struct ArrowLine: Identifiable, Equatable, Sendable {
      public let id: String                 // the two keys; never shown
      public let titleText: String          // the engine's "McEachran → Clark"
      public let strengthText: String       // "Significant · read Sat 14 Nov" or "Light · expected, not read"
      public let detailText: String         // the pulls joined with " · ", or the engine's "nothing to gain"
      public let isGuess: Bool
  }
  // SuggestedGroupCard: `id` is the suggestion's; `leadText` and `members` go; it gains
  public let titleText: String              // the three names in the suggestion's order, joined with ", "
  public let arrows: [ArrowLine]
  public let promptText: String?            // the engine's set-and-record sentence when the suggestion is not read
  // RecordedGroupCard gains
  public let arrows: [ArrowLine]
  public let arrowsPromptText: String?      // the engine's `arrowsToRead`
  // MemberLine loses `leadText`. MentoringSheet: `byAgeAloneText` becomes
  public let needsHierarchyText: String?    // the engine's sentence when the report needs its hierarchy
  ```
  `MentoringPresentation.leadTitle` is removed. New plain label: `MentoringPresentation.readOn(_ day: Day) -> String`, `read Sat 14 Nov`, the day as `DayText.short` writes it (as "Updated …" already does). `AppModel.recordGroup(_:in:)` takes the new `SuggestedGroup` and records its three members; `mentoringRequest` passes `arrows: []` for now.

Decisions:

- A recorded card's state line takes the engine's `state(of:parameters:)`, which now covers no influence. Its warnings are the engine's sentences with the saved names.
- A failed squad's sheet has `needsHierarchyText` when no level above Others is entered for its players not out on loan, the rule the engine uses.
- The spoken text of each card says its title, then each arrow's title, strength and detail, then the prompt, cautions, warnings and state.
- `MentoringEditors.swift`: the hierarchy editor's hint gains the engine's `socialGroupsNotUsed` as a second muted line. Nothing else changes there.
- `SampleData.modelWithMentoringWarning` kept its warning by a lead with a lower Ambition; it now needs a member whose guessed arrow into another is harmful: one first-team player set to Team Leader with Ambition below a junior's. Its test asserts a `harmfulArrow` warning and that the group is not doing harm.

- [ ] **Step 1: Write the failing tests.** `MentoringPresentationTests`: deleted: `theLeadOfARecordedGroupIsMarked`, `aGroupWithNobodyClearlyLeadingMarksNobody`. Rewritten: `aSquadOfYoungPlayersWithNothingEnteredGoesByAgeAloneAndPlacesNobody` (now: needs its hierarchy, nobody suggested), `theNoteIsTheEnginesStandingNote`, `aSuggestedCardHasTheLeadTheMembersAndTheCautions` (title, two arrow lines with `Average · expected, not read` and their pulls, the prompt, a caution), `aSuggestedCardIsSpokenWithEverythingOnIt`, `notPlacedAreTheEnginesSentences`, `aRecordedCardHasItsTitleSinceChangesWarningsAndState`, `aRecordedCardIsSpokenWithEverythingOnIt`, `aFailedSquadWithNothingEnteredSaysItGoesByAgeAlone`, `theLabels`. New: `anArrowLineSaysReadWithItsDayOrExpected` (a `GroupArrow` read on 14 November 2026 gives `Significant · read Sat 14 Nov`, `isGuess` false; a guess gives `Light · expected, not read`); `anArrowWithNothingToGainSaysSo`; `aRecordedCardAsksForItsArrowsUntilAllAreRead`; `noSentenceAboutAdviceIsWrittenInCore` (every arrow, prompt, warning, state and reason text on a sheet equals what `AdvisorText` gives for the same report). `AppModelMentoringTests`: `recordingASuggestionMakesAGroupFromToday`, `aSecondClickWithinHalfASecondIsDropped`, `recordingItAgainDoesNothingWhileAMemberIsInALiveGroup` and the five sample tests are adapted to the new suggestion and warning; no other assertion changes.
- [ ] **Step 2: Run** `cd LineupApp && swift build`: expect it to fail (the engine's types changed).
- [ ] **Step 3: Implement** the rows, the smallest view change that draws them (title, then each arrow's three texts on a line, then the prompt), and the sample.
- [ ] **Step 4: Run** `cd LineupApp && swift build && swift test`: all pass, no warnings. `cd ../LineupEngine && swift test` still passes.
- [ ] **Step 5: Draw** `swift run -q LineupApp --sample-data .. --pictures .build/pictures-arrows` and look at `training-mentoring-light.png` and `training-mentoring-recorded-light.png`: every text is there and legible. Layout is not judged yet.
- [ ] **Step 6: Commit**: "Show mentoring groups as their arrows, so the app builds on the engine's new advice".

---

### Task 6: Arrows kept and recorded

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/MentoringState.swift`, `AppModel+Mentoring.swift`, `Navigation.swift`, `MentoringPresentation.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/MentoringStateTests.swift`, `AppModelMentoringTests.swift`, `MentoringPresentationTests.swift`

**Interfaces:**
- Consumes: Tasks 1, 3 and 5.
- Produces:
  ```swift
  // MentoringState gains, read with decodeIfPresent and empty when absent:
  public var arrows: [ArrowReading]                 // by squad, then from key, then to key; one for an ordered pair in a squad
  /// Sets the pair's reading in the squad, or with nil takes it away. A strength equal to the one kept leaves its day alone.
  mutating func setArrow(from: PlayerID, to: PlayerID, in squad: Squad, strength: ArrowStrength?, on day: Day)

  /// The arrows of three players being recorded.
  public struct ArrowsDraft: Identifiable, Equatable, Sendable {
      public struct Pair: Hashable, Sendable { public let from: PlayerID; public let to: PlayerID }
      public let id: UUID
      public let squad: Squad
      public var members: [PlayerID]
      public var strengths: [Pair: ArrowStrength]   // a pair it lacks is not read
      public mutating func toggle(_ player: PlayerID)
  }
  // AppModel
  public func arrowsDraft(for squad: Squad, members: [PlayerID]) -> ArrowsDraft   // filled from the readings kept for those pairs
  public func arrowsProblem(of draft: ArrowsDraft) -> String?
  public func saveArrows(_ draft: ArrowsDraft)
  /// The arrows sheet to open after a new group is saved: its three members; nil for a change to a group.
  public func arrowsDraft(afterSaving draft: MentoringGroupDraft) -> ArrowsDraft?
  // Navigation
  MentoringEditing.arrows(ArrowsDraft)
  // MentoringPresentation
  public struct ArrowRow: Identifiable, Equatable, Sendable { public let id: ArrowsDraft.Pair; public let titleText: String; public let strength: ArrowStrength? }
  public static func arrowRows(_ draft: ArrowsDraft, names: [PlayerID: String]) -> [ArrowRow]   // six once three are chosen, in member order
  public static let strengthChoices: [(ArrowStrength?, String)]   // "Not read", then the engine's four names
  public static let recordArrowsTitle = "Record arrows"
  public static let arrowsTitle = "Arrows"
  public static func arrowsEditorTitle(_ squad: Squad) -> String   // "Record first-team arrows"
  public static let arrowsEditorHint = "Choose three players, then set each arrow as the game's Mentoring screen shows it."
  // RecordedGroupCard gains
  public let arrowsDraftMembers: [PlayerID]         // its current members, for its Arrows button
  ```
  `mentoringRequest` now passes `arrows: mentoring.arrows`.

Decisions:

- `saveArrows` does nothing while `arrowsProblem` gives a sentence. Otherwise, for each of the six ordered pairs of the three members: a strength in the draft becomes the reading, dated the game's current date unless the strength kept is the same; a pair the draft lacks loses its reading. Names are kept for the three, as for group members. It goes through `changeMentoring`, so the advice is worked out again and nothing is replanned. It is not under the half-second guard: the sheet closes on Save.
- `arrowsProblem`: exactly three different players; every one a current player of the draft's squad and not out on loan. Plain sentences held as labels beside `MentoringProblemLabel`, reusing its three that fit. A player in a recorded group can be in the sheet.
- `toggle` on an `ArrowsDraft` that takes a player out also drops his pairs' strengths; putting one in fills the new pairs from the readings kept, so `arrowsDraft(for:members:)` and the sheet agree. Core owns that: the view calls `model.arrowsDraft(for:members:)` after a toggle.
- The readings are sorted on every change, so saving the same readings in another order writes the same bytes.

- [ ] **Step 1: Write the failing tests.**
  - `MentoringStateTests`: `theStateEqualsItsOwnJSONRoundTrip` gains arrows; `settingAnArrowReplacesThePairsReading`; `theSameStrengthKeepsItsDay`; `notReadTakesTheReadingAway`; `readingsAreKeptInOrderWhateverOrderTheyWereSet`; `aPairHasOneReadingInEachSquad`.
  - `AppModelMentoringTests`: `aMentoringFileFromTheInstalledAppOpensWithNoNoticeAndLosesNothing` (Review Focus 1): save a state with hierarchy entries, a group, readings and names; rewrite the file without the `arrows` key; the reopened model has no notice, the same entries, group, readings and names, no arrows, and after its next change the file has the key. `savingTheSheetKeepsSixReadingsFromToday`; `savingItAgainUnchangedKeepsEveryDay` (Review Focus, re-save); `settingAnArrowBackToNotReadRemovesIt`; `theDraftIsFilledFromEarlierReadings`; `aTrioNeedsThreeCurrentPlayersNotOutOnLoan` (two players; a player of another squad; a player out on loan: each its sentence, and nothing saved); `aPlayerInAGroupCanStillHaveHisArrowsRecorded`; `aReadingStaysWhenItsPlayerMovesSquadAndIsNotUsed` (Review Focus 2: after the import that moves him the reading is in the file, the first team's advice shows no read arrow for him, and moved back it is used again); `theAdviceUsesTheReadings` (a read `.significant` arrow shows as read in the squad's sheet, and a read `.none` into a junior takes the guessed arrow away); `recordingArrowsDoesNotReplan`; `savingANewGroupLeadsToItsArrowsAndAChangeDoesNot`; `namesAreKeptForPlayersInReadings`.
  - `MentoringPresentationTests`: `theSheetHasSixRowsOnceThreeAreChosenAndNoneBefore` (titles `A → B` from the names, never a key); `theStrengthChoicesAreNotReadThenTheGamesFour`; `theArrowsLabels`; `aRecordedCardCarriesItsMembersForTheArrowsButton`.
- [ ] **Step 2: Run** `cd LineupApp && swift test --filter "MentoringStateTests|AppModelMentoringTests|MentoringPresentationTests"`: expect a build failure.
- [ ] **Step 3: Implement** the state, the actions, the navigation case and the rows. The view's `switch` over `MentoringEditing` needs the new case to compile: show the group editor's panel with the title for now; Task 7 draws the sheet.
- [ ] **Step 4: Run** `cd LineupApp && swift build && swift test`: all pass, no warnings.
- [ ] **Step 5: Commit**: "Keep the arrows the owner reads, one for each pair, and hand them to the advice".

---

### Task 7: The arrows sheet, the cards, and the pictures

**Files:**
- Modify: `LineupApp/Sources/LineupAppUI/Advice/MentoringEditors.swift` (the arrows sheet), `MentoringCards.swift`, `MentoringTab.swift`, `LineupApp/Sources/LineupAppUI/Theme.swift`
- Modify: `LineupApp/Sources/LineupAppCore/SampleData.swift`, `LineupApp/Sources/LineupApp/main.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/AppModelMentoringTests.swift` (the samples)

**Interfaces:**
- Consumes: Tasks 5 and 6.
- Produces:
  ```swift
  // LineupAppUI
  struct ArrowsEditor: View { init(model: AppModel, draft: ArrowsDraft, done: @escaping () -> Void) }
  // SampleData, each built with the model's own actions
  static func modelWithArrowsRead(repositoryRoot: URL) throws -> AppModel       // the hierarchy sample, with the arrows of its first suggestion read so that it is a read suggestion
  static func modelWithHarmfulArrow(repositoryRoot: URL) throws -> AppModel     // a recorded group with a read Significant arrow from a member with a lower Ambition
  static func modelWithNoInfluence(repositoryRoot: URL) throws -> AppModel      // a recorded group whose six arrows are read as None
  ```

What is drawn:

- **The tab.** "Record arrows" beside "Add a group" in the Your groups heading, opening the sheet on no members. In the hierarchy part, the engine's needs-hierarchy sentence where the age-alone line was.
- **A suggested card**: its title; a line for each arrow, the title in the name's weight, the strength text beside it (muted when the arrow is a guess), the detail under or beside it as the width allows; the prompt; cautions; the evidence note and "Record as set". When the suggestion is not read, a "Record arrows" button beside "Record as set", opening the sheet on its three members.
- **A recorded card**: the state band and warnings as now; the arrow lines; the arrows prompt; the members' changes; "Arrows", "Edit" and "End group". The mark for the lead is gone.
- **The arrows sheet**: the title and hint; the member chooser as the group editor has it, without the in-another-group bar; once three are chosen, six rows, each `A → B` with a menu of Not read, None, Light, Average, Significant; the problem sentence; Cancel and Save, Save unavailable while there is a problem. After a new group is saved in the group editor, the sheet opens on its members (`model.arrowsDraft(afterSaving:)`).
- The view asks Core for everything: no `if` about data beyond showing or hiding a text Core gave as optional.

Pictures, drawn in `main.swift` where the other mentoring variants are, and named in its usage text. New: `training-mentoring-arrows-sheet` (three chosen, some arrows set), `training-mentoring-arrows-read` (a suggestion resting on readings), `training-mentoring-arrows-harm` (a recorded group with a harmful strong arrow), `training-mentoring-arrows-none` (a recorded group with no influence). Changed by this plan, and looked at again: `training-mentoring` (now a suggestion resting on guesses, with its prompt), `training-mentoring-no-hierarchy` (now the needs-hierarchy state), `training-mentoring-stale`, `training-mentoring-u21`, `training-mentoring-recorded`, `training-mentoring-warning`, `training-mentoring-stopped`, `training-mentoring-small`, and the two hierarchy-editor pictures (one more hint line). Unchanged: `training-mentoring-empty`, `training-mentoring-failed`, `training-mentoring-group-editor`.

- [ ] **Step 1: Write the failing tests** for the three samples in `AppModelMentoringTests`, each on the engine's report: the read sample's first suggestion `isRead` with every arrow it rests on read; the harm sample's group has a `harmfulArrow` warning with `isRead` true and strength `.significant`, and is not doing harm; the no-influence sample's group `hasNoInfluence` and is not stopped.
- [ ] **Step 2: Run** `cd LineupApp && swift test --filter AppModelMentoringTests`: expect a build failure.
- [ ] **Step 3: Implement** the samples, then the sheet, the cards and the tab, then the picture variants.
- [ ] **Step 4: Run** `cd LineupApp && swift build && swift test`: all pass, no warnings.
- [ ] **Step 5: Draw and look.** `swift run -q LineupApp --sample-data .. --pictures .build/pictures-arrows`. Open every new and changed picture named above (the light one of each pair). Check: a read arrow and a guess are told apart at a glance; nothing is clipped or overlaps at 760 points (`training-mentoring-small`); a card with six arrows still reads top to bottom; the sheet's six rows fit with their menus and Save is where the other editors have it; the needs-hierarchy state reads as an instruction, not an error. Fix what is wrong and draw again. Say in the report which pictures were opened and what changed after looking.
- [ ] **Step 6: Commit**: "Record the game's arrows in a sheet and show each group as who influences whom".

---

### Task 8: Documents, and the plan closed

Documents only. If source code seems to need changing, stop and report it.

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/plans/2026-11-14-fm27-mentoring.md` (its "After this plan" note only)
- Modify: `docs/superpowers/specs/2026-11-14-fm27-mentoring-arrows-design.md` (its Status line only)
- Modify: this plan (its closing sections)

- [ ] **Step 1: Run everything**: `cd LineupEngine && swift test`; `cd LineupApp && swift build && swift test`; the full picture run to `LineupApp/.build/pictures-arrows`. Put the three results in the report: test counts, no warnings, the picture run finished.
- [ ] **Step 2: Update `CLAUDE.md`**, reading the code as built, not this plan. In the list of plans: this plan and its design, complete. In the engine's "Advisors" paragraph, the mentoring sentences: groups are suggested from arrows, read by the owner or guessed from the source's level and the target's age and said to be guesses; a group is any three with no harmful arrow; a candidate's gain is his strongest arrow's; a recorded group with six arrows read as None is called out; who takes nothing; that standing above by age, the lead and the social-group halving are gone. In the app section: "Record arrows" and the arrows sheet, readings kept in the mentoring file, social groups kept and not used, `training-mentoring-arrows-*` among the checked pictures. The fixture under `Fixtures/mentoring/` and what it is. Match the file's plain style and keep each addition as short as its neighbours.
- [ ] **Step 3: The first mentoring plan's "After this plan"**: one line saying its rules for who influences whom were replaced by this plan, with the path.
- [ ] **Step 4: Close this plan**: fill "What the advice showed on the owner's readings", "Changes made while building" and "Known limits and small faults left" below, from what the tasks reported, in plain sentences; mark the design built. Record that the hands-on check and the install are left to the owner and the controller.
- [ ] **Step 5: Commit**: "Close the mentoring arrows plan: record what changed and what is left".

---

## After this plan

- Whether an arrow changes the longer a group stays together (design, open item 2): if it does, ask for arrows to be read again after a time.
- Whether injury is what stops a player receiving (design, open item 3).
- Fitting rates from the personality readings, as the first design left it.

## What the advice showed on the owner's readings

(Filled in by Task 3's report and Task 8.)

## Changes made while building

(Filled in as the plan is built.)

## Known limits and small faults left

Known before building:

- The groups are still found one at a time, most valuable first; a different set could have a greater total.
- The guess agrees exactly with 104 of the owner's 124 readings. It is a guess, and says so on every line.
- Who takes nothing is judged from the levels as they now stand, so changing a senior's level can bring a player back in.
- The command line takes no arrow readings: `lineup-cli advise` shows guesses only.
- A reading is kept for a pair, not for a group, on the strength of two pairs read twice and every re-reading agreeing.
- Whether an arrow changes with time is not known; the day each was read is shown, and nothing asks for a re-reading.
- Social groups are still entered and kept, and change nothing.
