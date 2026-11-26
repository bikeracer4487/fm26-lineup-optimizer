// FM27 Lineup Optimizer.
//
// Usage:
//   LineupApp                                  opens the window on the app's own files in
//                                              ~/Library/Application Support/FM27 Lineup Optimizer
//   LineupApp --sample-data <repository root>  opens the window on the engine's sample squads, tactic and
//                                              fixtures, in a temporary directory, on the Mac's own clock
//                                              (the pictures use a scripted one)
//   LineupApp --pictures <directory>           draws every screen, light and dark, to PNG files in
//                                              <directory>, then exits (0 on success, 1 on a problem).
//                                              Without --sample-data it draws an empty model; with it,
//                                              the sample model, and the Squad screen empty, after a
//                                              failed import and after a good one as well ("squad-empty-…",
//                                              "squad-failed-…", "squad-imported-…"), and the Tactics screen
//                                              empty and with a tactic that has a problem ("tactics-empty-…",
//                                              "tactics-problem-…"). The Tactics editor is drawn with a slot
//                                              selected, and "tactics-…" with an unsaved change. The Fixtures
//                                              screen is drawn empty ("fixtures-empty-…"), five days on with one
//                                              past fixture confirmed and one not ("fixtures-past-…"), and its
//                                              editor on its own for the confirmed fixture ("fixtures-editor-…").
//                                              The Fixtures screen itself ("fixtures-…", "fixtures-narrow-…",
//                                              "fixtures-small-…") is drawn with the second fixture made high
//                                              importance, so its suggested importance differs and shows; so
//                                              with that suggestion's reasons shown ("fixtures-reasons-…", and
//                                              "fixtures-reasons-small-…" in the smallest window); and
//                                              the editor on its own for that fixture
//                                              ("fixture-editor-suggestion-…"). The Fixtures screen is drawn
//                                              again with the league situation "Nothing to play for", so its
//                                              league fixtures' suggestions differ ("fixtures-situation-…");
//                                              later in a season in the smallest window, with twelve fixtures
//                                              and the first six confirmed, so the table scrolls and opens
//                                              with the next match in the middle ("fixtures-midseason-…");
//                                              and the editor on its own for the second fixture after its
//                                              opponent's squad was pasted ("fixtures-editor-reading-…") and
//                                              after the sample's own first team was pasted and refused
//                                              ("fixtures-editor-refused-…").
//                                              Match Selection ("match-…") is drawn on the first fixture with the
//                                              left back selected; as starts ("match-starts-…"); with the owner's
//                                              choices in the first fixture, in a taller window
//                                              ("match-choices-…"); after confirming the
//                                              first fixture, on it ("match-confirmed-…") and on the next
//                                              ("match-after-confirm-…"); on a missed fixture with nothing
//                                              remembered ("match-missed-…") and with its eleven remembered
//                                              ("match-missed-eleven-…"), and so while two matches on one day
//                                              stop the plan ("match-missed-stopped-…"); empty ("match-empty-…"); with two
//                                              matches on one day ("match-failed-…"); and its candidate picker on
//                                              its own for the first fixture's goalkeeper ("match-picker-…"),
//                                              for the end of that list, where those a rule leaves out can
//                                              still be chosen ("match-picker-ruled-out-…"), and
//                                              for the remembered eleven's goalkeeper ("match-remembered-picker-…").
//                                              It is drawn again later in a season, with twelve fixtures and
//                                              the first six confirmed, so the notes do not fit and open at the
//                                              next match to play ("match-midseason-…", and as starts
//                                              "match-midseason-starts-…"), and on the fixture against a much
//                                              stronger side with no pick selected, so the whole game plan
//                                              part shows ("match-gameplan-…"). With three of the first
//                                              eleven banned it is drawn on the first fixture, which leaves
//                                              them out ("match-bans-…"); and, once the owner has said their
//                                              bans are not for that match, on it ("match-bans-off-…") and on
//                                              the second fixture, which then leaves them out
//                                              ("match-bans-next-…").
//                                              The advisor screens ("elevens-…", "rest-…", "training-…",
//                                              "removal-…") are drawn on the sample, empty ("<screen>-empty-…")
//                                              and with a primary tactic that has a problem
//                                              ("<screen>-problem-…"). The Elevens screen is drawn
//                                              on each of its views ("elevens-first-…",
//                                              "elevens-second-…", "elevens-depth-…"), Depth with the left
//                                              centre-back chosen ("elevens-depth-slot-…", and taller so its
//                                              players too far below the first choice to count as cover show,
//                                              "elevens-depth-below-…"), and Depth in the
//                                              smallest window ("elevens-depth-small-…") and, to see
//                                              the lists under the pitch, in a window as narrow and
//                                              taller ("elevens-first-tall-…", and "elevens-depth-tall-…"
//                                              on the right attacking midfielder), and with the primary
//                                              tactic changed but not saved ("elevens-unsaved-…").
//                                              The Rest screen is drawn with nobody to list
//                                              ("rest-nobody-…"), tall enough for the whole
//                                              sample list ("rest-tall-…"), and with two players' jadedness
//                                              raised so a holiday and a rest over the limit show
//                                              ("rest-levels-…"), that also in the smallest window
//                                              ("rest-levels-small-…"). With six weeks of sample readings it
//                                              is drawn with the first team's drift falling ("rest-trend-…",
//                                              also in the smallest window, "rest-trend-small-…", and tall
//                                              enough for the regulars and the foot, "rest-trend-tall-…"), with it
//                                              rising and its caution ("rest-trend-rising-…"), and with two
//                                              readings of each player, so nothing is measured yet
//                                              ("rest-unmeasured-…"). Match Selection is drawn, taller, with a
//                                              player the plan rests from the first fixture before he passes
//                                              the jaded line ("match-restdue-…").
//                                              The Training screen ("training-…") is drawn on the sample
//                                              before its retraining is accepted, so its recommendations
//                                              show, and so tall enough for all four parts
//                                              ("training-tall-…", and "training-small-tall-…" in the
//                                              smallest window's width); with its retraining six weeks
//                                              under way, a second whose player has left and a pair turned
//                                              down, taller ("training-accepted-…"); with its retraining
//                                              twenty-one weeks under way and well behind its estimate, and a
//                                              second that no thin slot needs ("training-behind-…"); and with
//                                              nothing to list ("training-none-…"). Its Mentoring tab is drawn, taller, with the
//                                              first team's hierarchy entered so its groups are suggested
//                                              ("training-mentoring-…"), on the sample with no hierarchy
//                                              ("training-mentoring-no-hierarchy-…"), with the hierarchy entered
//                                              five weeks ago ("training-mentoring-stale-…"), empty
//                                              ("training-mentoring-empty-…"), on the U21s
//                                              ("training-mentoring-u21-…"), with a group recorded five weeks ago
//                                              and a member risen since ("training-mentoring-recorded-…"), the same
//                                              with a harmful arrow from its Team Leader into a junior
//                                              ("training-mentoring-warning-…"), with a group fourteen weeks old
//                                              that has stopped working ("training-mentoring-stopped-…"), with a
//                                              first-team player missing a Pressure value
//                                              ("training-mentoring-failed-…"), the warning's state in the
//                                              smallest window's width, tall ("training-mentoring-small-…"),
//                                              with the arrows of the first suggested group read so it rests on
//                                              readings beside suggestions on guesses
//                                              ("training-mentoring-arrows-read-…"), with the recorded group's
//                                              harmful arrow read as Significant
//                                              ("training-mentoring-arrows-harm-…"), with its six arrows
//                                              read as None ("training-mentoring-arrows-none-…"), with the three
//                                              seniors recorded as a group, which is expected to give nobody
//                                              anything and which a regrouping would break up
//                                              ("training-mentoring-regroup-…", and "…-regroup-small-…" in the
//                                              smallest window's width), the same with its arrows read
//                                              ("training-mentoring-spent-…"), and with a group ended while it
//                                              was doing harm, whose three are not suggested again
//                                              ("training-mentoring-ended-…").
//                                              Its editors are drawn on their own: the first team's hierarchy
//                                              as entered ("training-mentoring-hierarchy-editor-…"), the U21s'
//                                              ("training-mentoring-hierarchy-editor-u21-…"), a new group
//                                              with two ticked beside a player in the recorded group
//                                              ("training-mentoring-group-editor-…"), and the arrows of the
//                                              three first-team players with the longest names, two of them set
//                                              ("training-mentoring-arrows-sheet-…").
//                                              The Player Removal screen ("removal-…", its critical and high
//                                              rows open) is drawn with every row open, tall enough for a
//                                              medium and a keep row's reasons ("removal-all-open-…"), and
//                                              with a U21 player on loan here so the loan review shows
//                                              ("removal-loanee-…"), and with its first two players marked,
//                                              one to sell and one to loan out ("removal-marked-…"), and
//                                              with young players to develop, release and loan out, tall
//                                              enough for the whole Young players part ("removal-young-…"),
//                                              and the same with every row open, so a youth-contract row
//                                              shows its two-entry mark control and the note that he cannot
//                                              be loaned out ("removal-young-open-…"),
//                                              and in the narrow window's width ("removal-young-narrow-…").
//                                              The Scouting screen ("scouting-…") is drawn on its Needs tab
//                                              ("scouting-needs-…", and "scouting-needs-small-…" in the
//                                              smallest window), with a U21 player on loan here and an outfield
//                                              first choice marked to sell, so both are counted as going
//                                              ("scouting-needs-going-…"), and with no squad
//                                              ("scouting-notready-…"); its Candidates tab with nothing pasted
//                                              ("scouting-candidates-empty-…"), holding the sample candidates,
//                                              one of them the sample's own U21 and left out, tall enough for
//                                              every part ("scouting-candidates-…"), in the Later order, which
//                                              turns the two starters at right attacking midfield round
//                                              ("scouting-candidates-later-…"), with every row and
//                                              the rest open ("scouting-candidates-open-…"), in the smallest
//                                              window ("scouting-candidates-small-…"), and after the sample's own
//                                              U21s were pasted over them and refused
//                                              ("scouting-candidates-refused-…"); holding one group of the
//                                              owner's captured search, over five, so its best five and the
//                                              line the others are behind show
//                                              ("scouting-candidates-crowded-…"), and with that line open
//                                              ("scouting-candidates-crowded-open-…"); and holding the sample
//                                              candidates with two hidden, the line they are behind closed
//                                              ("scouting-candidates-hidden-…") and open
//                                              ("scouting-candidates-hidden-open-…").
//                                              The League screen ("league-…") is drawn with the owner's table and
//                                              format, empty ("league-empty-…"), with the table and no format
//                                              ("league-noformat-…"), after a squad was pasted over the table and
//                                              refused ("league-refused-…"), with a league match confirmed since
//                                              and more league fixtures than the table has matches left
//                                              ("league-stale-…"), with the situation chosen by hand differing
//                                              ("league-byhand-…") and in the smallest window
//                                              ("league-small-…"); Fixtures with the menu on "From the table" and
//                                              the league suggestions ("fixtures-fromtable-…"); and the fixture
//                                              editor with the opponent menu ("fixtures-editor-league-…"), for
//                                              an opponent not in the table ("fixtures-editor-league-unmatched-…")
//                                              and for a side within the margin in a fixture the table speaks for,
//                                              whose suggestion carries the table's base and the battling line
//                                              ("fixtures-editor-league-battling-…").
//                                              The Offers screen is drawn with nobody marked ("offers-empty-…");
//                                              with two players marked to sell, one with a value, an ask and a
//                                              deal with Barnet whose last round is Barnet's bid, one with no
//                                              value, and one marked to loan out, tall enough for the three
//                                              blocks and the foot ("offers-…"); with Barnet typed for the player
//                                              marked to sell with no deal, given a value, and a budget that
//                                              covers the whole fee ("offers-club-all-…"), that leaves part of it
//                                              for later ("offers-club-…") and that is nothing
//                                              ("offers-nothing-now-…"); with the loan switched to moving his
//                                              wage and a club typed for it ("offers-loan-wage-…"); with ten sale
//                                              deals recorded for a player no longer marked, so a line is measured
//                                              ("offers-measured-…"); with the first seller switched to loan
//                                              terms, his sale deal with Barnet still in his block
//                                              ("offers-toggled-…"); with the player marked to sell with no
//                                              value out on loan, so he is offered sale terms alone with the
//                                              engine's sentence ("offers-onloan-…"); with the first seller's mark taken off and
//                                              "Earlier offers" open ("offers-earlier-…"); and in the smallest
//                                              window ("offers-small-…"). Its sheet is drawn on its own, for a
//                                              proposal in the Barnet deal ("offers-editor-sale-…") and for the
//                                              loan's ask ("offers-editor-loan-…").
//                                              Every screen is drawn again in a narrow window, 800 by 700
//                                              ("<screen>-narrow-…"), and Match Selection, Tactics, Fixtures
//                                              and the advisor screens in the smallest window
//                                              ("match-small-…", "tactics-small-…", "fixtures-small-…",
//                                              "elevens-small-…" and so on). Both
//                                              typefaces are drawn at each weight ("type-…").

import AppKit
import Foundation
import LineupAppCore
import LineupAppUI
import LineupEngine
import SwiftUI

/// The model the window shows, made before the app starts.
@MainActor enum Startup {
    static var model: AppModel?
}

/// The app's window and its life as a regular Mac app.
struct LineupApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let model: AppModel

    init() {
        guard let model = Startup.model else {
            fatalError("The app started without its model.")
        }
        self.model = model
    }

    var body: some Scene {
        // One window: a second over the same model would show the same state twice.
        Window("FM27 Lineup Optimizer", id: "main") {
            RootView(model: model)
        }
        // The wall runs up under the window's buttons.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(Theme.Layout.defaultWindow)
    }
}

/// Started with `swift run` the app is not a bundle, so it makes itself a regular app with a
/// Dock icon and a menu bar, and comes to the front.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppIcon.apply()
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

/// Which state of the sample data to start from.
enum SampleState {
    case plain, failedImport, afterImport, tacticProblem, unsavedTacticChange, pastFixtures
    case afterConfirmingFirst, midSeason, earlierSeason, summer, bans, bansNotForTheFirst, choices, missedFixture, missedEleven, missedElevenWhileStopped, twoMatchesOnOneDay
    case jadedPlayers, nobodyNeedingRest, beforeRetraining, retrainingUnderWay, retrainingBehind, nothingToRetrain, loanee
    case differingSuggestion
    case hierarchy, staleHierarchy, mentoringGroup, mentoringWarning, stoppedGroup, mentoringFailure
    case arrowsRead, harmfulArrow, noInfluence, regrouping, spentGroup, endedGroup, youngPlayers
    case candidates, refusedCandidates, crowdedCandidates, hiddenCandidates
    case offers, offersMeasured, offerOutOnLoan
    case league, leagueNoFormat, leagueRefused, leagueStale, leagueByHand
    case fallingTrends, risingTrends, beforeTrends, restedBeforeLine
}

/// The sample model from the repository at `root`, or the reason it could not be built.
@MainActor func sampleModel(_ root: String, _ state: SampleState = .plain) -> AppModel {
    let url = URL(fileURLWithPath: root, isDirectory: true)
    do {
        switch state {
        case .plain: return try SampleData.model(repositoryRoot: url)
        case .failedImport: return try SampleData.modelWithFailedImport(repositoryRoot: url)
        case .afterImport: return try SampleData.modelAfterImport(repositoryRoot: url)
        case .tacticProblem: return try SampleData.modelWithTacticProblem(repositoryRoot: url)
        case .unsavedTacticChange: return try SampleData.modelWithUnsavedTacticChange(repositoryRoot: url)
        case .pastFixtures: return try SampleData.modelWithPastFixtures(repositoryRoot: url)
        case .afterConfirmingFirst: return try SampleData.modelAfterConfirmingFirst(repositoryRoot: url)
        case .choices: return try SampleData.modelWithChoices(repositoryRoot: url)
        case .midSeason: return try SampleData.modelMidSeason(repositoryRoot: url)
        case .earlierSeason: return try SampleData.modelWithEarlierSeason(repositoryRoot: url)
        case .summer: return try SampleData.modelInTheSummer(repositoryRoot: url)
        case .bans: return try SampleData.modelWithBans(repositoryRoot: url)
        case .bansNotForTheFirst: return try SampleData.modelWithBans(repositoryRoot: url, notForTheFirstMatch: true)
        case .missedFixture: return try SampleData.modelWithMissedFixture(repositoryRoot: url)
        case .missedEleven: return try SampleData.modelWithMissedEleven(repositoryRoot: url)
        case .missedElevenWhileStopped: return try SampleData.modelWithMissedElevenWhileThePlanIsStopped(repositoryRoot: url)
        case .twoMatchesOnOneDay: return try SampleData.modelWithTwoMatchesOnOneDay(repositoryRoot: url)
        case .jadedPlayers: return try SampleData.modelWithJadedPlayers(repositoryRoot: url)
        case .nobodyNeedingRest: return try SampleData.modelWithNobodyNeedingRest(repositoryRoot: url)
        case .beforeRetraining: return try SampleData.modelBeforeRetraining(repositoryRoot: url)
        case .retrainingUnderWay: return try SampleData.modelWithRetrainingUnderWay(repositoryRoot: url)
        case .retrainingBehind: return try SampleData.modelWithRetrainingBehind(repositoryRoot: url)
        case .nothingToRetrain: return try SampleData.modelWithNothingToRetrain(repositoryRoot: url)
        case .loanee: return try SampleData.modelWithLoanee(repositoryRoot: url)
        case .differingSuggestion: return try SampleData.modelWithDifferingSuggestion(repositoryRoot: url)
        case .hierarchy: return try SampleData.modelWithHierarchy(repositoryRoot: url)
        case .staleHierarchy: return try SampleData.modelWithStaleHierarchy(repositoryRoot: url)
        case .mentoringGroup: return try SampleData.modelWithMentoringGroup(repositoryRoot: url)
        case .mentoringWarning: return try SampleData.modelWithMentoringWarning(repositoryRoot: url)
        case .stoppedGroup: return try SampleData.modelWithStoppedGroup(repositoryRoot: url)
        case .mentoringFailure: return try SampleData.modelWithMentoringFailure(repositoryRoot: url)
        case .league: return try SampleData.modelWithLeague(repositoryRoot: url)
        case .leagueNoFormat: return try SampleData.modelWithLeague(repositoryRoot: url, format: false)
        case .leagueRefused: return try SampleData.modelWithRefusedLeaguePaste(repositoryRoot: url)
        case .leagueStale: return try SampleData.modelWithStaleLeague(repositoryRoot: url)
        case .leagueByHand: return try SampleData.modelWithLeagueChosenByHand(repositoryRoot: url)
        case .arrowsRead: return try SampleData.modelWithArrowsRead(repositoryRoot: url)
        case .harmfulArrow: return try SampleData.modelWithHarmfulArrow(repositoryRoot: url)
        case .noInfluence: return try SampleData.modelWithNoInfluence(repositoryRoot: url)
        case .regrouping: return try SampleData.modelWithRegrouping(repositoryRoot: url)
        case .endedGroup: return try SampleData.modelWithEndedGroup(repositoryRoot: url)
        case .spentGroup: return try SampleData.modelWithSpentGroup(repositoryRoot: url)
        case .youngPlayers: return try SampleData.modelWithYoungPlayers(repositoryRoot: url)
        case .candidates: return try SampleData.modelWithCandidates(repositoryRoot: url)
        case .refusedCandidates: return try SampleData.modelWithRefusedCandidates(repositoryRoot: url)
        case .crowdedCandidates: return try SampleData.modelWithCrowdedGroup(repositoryRoot: url)
        case .hiddenCandidates: return try SampleData.modelWithHiddenCandidates(repositoryRoot: url)
        case .offers: return try SampleData.modelWithOffers(repositoryRoot: url)
        case .offersMeasured: return try SampleData.modelWithMeasuredOffers(repositoryRoot: url)
        case .offerOutOnLoan: return try SampleData.modelWithOfferOutOnLoan(repositoryRoot: url)
        case .fallingTrends: return try SampleData.modelWithFallingTrends(repositoryRoot: url)
        case .risingTrends: return try SampleData.modelWithRisingTrends(repositoryRoot: url)
        case .beforeTrends: return try SampleData.modelBeforeTrends(repositoryRoot: url)
        case .restedBeforeLine: return try SampleData.modelWithPlayerRestedBeforeLine(repositoryRoot: url)
        }
    } catch {
        fail("\(error)")
    }
}

/// The screens that show the advisors' reports.
let advisorScreens: [Screen] = [.elevens, .rest, .training, .removal]

/// The narrow window the pictures are drawn in: beside the game on a laptop's screen.
let narrowWindow = CGSize(width: 800, height: 700)

/// Match Selection's pictures beyond the first: see the usage at the top.
@MainActor func drawMatchSelection(_ root: String, to directory: URL, size: CGSize) throws {
    try ScreenPictures.write(model: sampleModel(root), to: directory, size: size, variant: "starts",
                             screens: [.matchSelection], matchStart: MatchStart(view: .starts))
    // The youth player fixed at AM C selected, so the pin, the youth mark and "Clear override" show; in a taller
    // window, so the left-out list, "Left out by you" and the override not used show below the detail.
    let tall = CGSize(width: size.width, height: size.height * 2)
    try ScreenPictures.write(model: sampleModel(root, .choices), to: directory, size: tall, variant: "choices",
                             screens: [.matchSelection], matchStart: MatchStart(slot: .AM_C))
    let confirmed = sampleModel(root, .afterConfirmingFirst)
    guard let first = confirmed.fixtures.first else { fail("The sample model has no fixtures.") }
    try ScreenPictures.write(model: confirmed, to: directory, size: size, variant: "confirmed",
                             screens: [.matchSelection], matchStart: MatchStart(fixture: first.id))
    try ScreenPictures.write(model: confirmed, to: directory, size: size, variant: "after-confirm",
                             screens: [.matchSelection], matchStart: MatchStart(slot: .D_L))
    // Twelve fixtures with the first six confirmed: the notes scroll, and open at the next match to play.
    let midSeason = sampleModel(root, .midSeason)
    try ScreenPictures.write(model: midSeason, to: directory, size: size, variant: "midseason", screens: [.matchSelection])
    try ScreenPictures.write(model: midSeason, to: directory, size: size, variant: "midseason-starts",
                             screens: [.matchSelection], matchStart: MatchStart(view: .starts))
    // A season behind the sample's five fixtures: the six matches from before the days the advice reads are left out
    // of the notes and of the starts grid. Then the summer, with every match earlier and none to play.
    let earlierSeason = sampleModel(root, .earlierSeason)
    try ScreenPictures.write(model: earlierSeason, to: directory, size: size, variant: "earlier", screens: [.matchSelection])
    try ScreenPictures.write(model: earlierSeason, to: directory, size: size, variant: "earlier-starts",
                             screens: [.matchSelection], matchStart: MatchStart(view: .starts))
    try ScreenPictures.write(model: sampleModel(root, .summer), to: directory, size: size, variant: "summer",
                             screens: [.matchSelection])
    // The third fixture, against a much stronger side, with no pick selected: the game plan part with all three sentences.
    let sample = sampleModel(root)
    guard let strong = sample.fixtures.first(where: { $0.opponentStrength == .muchStronger }) else {
        fail("The sample model has no fixture against a much stronger side.")
    }
    try ScreenPictures.write(model: sample, to: directory, size: size, variant: "gameplan", screens: [.matchSelection],
                             matchStart: MatchStart(fixture: strong.id))
    // A player rested from the first fixture before he passes the jaded line, in a taller window so the left-out list
    // with the planner's reason shows below the detail.
    try ScreenPictures.write(model: sampleModel(root, .restedBeforeLine), to: directory, size: tall, variant: "restdue",
                             screens: [.matchSelection])
    // Three of the first eleven banned: left out of the first fixture, with the button that says their bans are not
    // for it; then after pressing it, on the first fixture, where they are picked, and on the second, where they are
    // left out.
    try ScreenPictures.write(model: sampleModel(root, .bans), to: directory, size: size, variant: "bans",
                             screens: [.matchSelection])
    let bansOff = sampleModel(root, .bansNotForTheFirst)
    try ScreenPictures.write(model: bansOff, to: directory, size: size, variant: "bans-off", screens: [.matchSelection])
    if let second = bansOff.fixtures.dropFirst().first {
        try ScreenPictures.write(model: bansOff, to: directory, size: size, variant: "bans-next", screens: [.matchSelection],
                                 matchStart: MatchStart(fixture: second.id))
    }
    let missed = sampleModel(root, .missedFixture)
    guard let early = missed.fixtures.first else { fail("The sample model has no fixtures.") }
    try ScreenPictures.write(model: missed, to: directory, size: size, variant: "missed",
                             screens: [.matchSelection], matchStart: MatchStart(fixture: early.id))
    let missedEleven = sampleModel(root, .missedEleven)
    guard let unconfirmed = missedEleven.fixtures.first else { fail("The sample model has no fixtures.") }
    try ScreenPictures.write(model: missedEleven, to: directory, size: size, variant: "missed-eleven",
                             screens: [.matchSelection], matchStart: MatchStart(fixture: unconfirmed.id))
    let stopped = sampleModel(root, .missedElevenWhileStopped)
    try ScreenPictures.write(model: stopped, to: directory, size: size, variant: "missed-stopped",
                             screens: [.matchSelection], matchStart: MatchStart(fixture: unconfirmed.id))
    try ScreenPictures.writeCandidatePicker(
        name: "match-remembered-picker", text: PickerText.remembered(.GK),
        rows: missedEleven.rememberedCandidateRows(for: .GK, in: unconfirmed.id), to: directory)
    try ScreenPictures.write(model: sampleModel(root, .twoMatchesOnOneDay), to: directory, size: size,
                             variant: "failed", screens: [.matchSelection])
    let plain = sampleModel(root)
    guard let next = plain.fixtures.first else { fail("The sample model has no fixtures.") }
    try ScreenPictures.writeCandidatePicker(
        name: "match-picker", text: PickerText.planned(.GK), rows: plain.candidateRows(for: .GK, in: next.id),
        to: directory)
    // The end of the same list: the last two who can play, then those a rule leaves out, who can still be chosen.
    let keepers = plain.candidateRows(for: .GK, in: next.id)
    let canPlay = keepers.prefix { $0.unavailable == nil }
    try ScreenPictures.writeCandidatePicker(
        name: "match-picker-ruled-out", text: PickerText.planned(.GK),
        rows: Array(canPlay.suffix(2) + keepers.dropFirst(canPlay.count)), to: directory)

    // The narrow and the smallest windows: the detail under the pitch, the pitches stacked, and scrolling; the other
    // screens narrow, so the pills wrap.
    try ScreenPictures.write(model: sampleModel(root, .afterImport), to: directory, size: narrowWindow, variant: "narrow",
                             screens: [.squad, .settings] + advisorScreens)
    try ScreenPictures.write(model: plain, to: directory, size: Theme.Layout.minimumWindow, variant: "small",
                             screens: advisorScreens)
    for (variant, small) in [("narrow", narrowWindow), ("small", Theme.Layout.minimumWindow)] {
        try ScreenPictures.write(model: plain, to: directory, size: small, variant: variant,
                                 screens: [.matchSelection], matchStart: MatchStart(slot: .D_L))
        try ScreenPictures.write(model: sampleModel(root, .unsavedTacticChange), to: directory, size: small,
                                 variant: variant, screens: [.tactics], tacticSlot: TacticSlot(.AM_L, in: .inPossession))
    }
}

/// The Fixtures screen with a suggestion that differs, its reasons, and the editor with it: see the usage at the top.
@MainActor func drawFixtures(_ root: String, to directory: URL, size: CGSize) throws {
    let model = sampleModel(root, .differingSuggestion)
    guard let differing = model.fixtures.first(where: { model.suggestionLine(for: $0) != nil }) else {
        fail("No sample fixture has a suggested importance that differs from its own.")
    }
    for (variant, window) in [(String?.none, size), ("narrow", narrowWindow), ("small", Theme.Layout.minimumWindow)] {
        try ScreenPictures.write(model: model, to: directory, size: window, variant: variant, screens: [.fixtures])
    }
    for (variant, window) in [("reasons", size), ("reasons-small", Theme.Layout.minimumWindow)] {
        try ScreenPictures.write(model: model, to: directory, size: window, variant: variant, screens: [.fixtures],
                                 fixturesStart: FixturesStart(reasonsOf: differing.id))
    }
    try ScreenPictures.writeFixtureEditor(model: model, draft: model.fixtureDraft(for: differing), to: directory,
                                          name: "fixture-editor-suggestion",
                                          size: Theme.Layout.fixtureEditorSuggestionPicture)

    // Nothing to play for in the league, so the league fixtures' suggestions differ and "Use it" shows on them.
    let situation = sampleModel(root)
    situation.setLeagueSituation(.nothingToPlayFor)
    try ScreenPictures.write(model: situation, to: directory, size: size, variant: "situation", screens: [.fixtures])

    // Twelve fixtures with the first six confirmed, in the smallest window: the table scrolls, and opens with the next
    // match in the middle.
    try ScreenPictures.write(model: sampleModel(root, .midSeason), to: directory, size: Theme.Layout.minimumWindow,
                             variant: "midseason", screens: [.fixtures])

    // A season behind the sample's five fixtures: the line saying six matches are not shown; the same with them shown;
    // and the summer, with every match earlier, so the table has the line and no rows.
    try ScreenPictures.write(model: sampleModel(root, .earlierSeason), to: directory, size: size, variant: "earlier",
                             screens: [.fixtures])
    let shown = sampleModel(root, .earlierSeason)
    shown.setShowsEarlierMatches(true)
    try ScreenPictures.write(model: shown, to: directory, size: size, variant: "earlier-shown", screens: [.fixtures])
    try ScreenPictures.write(model: sampleModel(root, .summer), to: directory, size: size, variant: "summer",
                             screens: [.fixtures])

    // The editor after the opponent's squad was pasted, after the owner's own squad was pasted and refused, and for a
    // new league fixture that carries a saved reading.
    let url = URL(fileURLWithPath: root, isDirectory: true)
    for (name, make) in [("fixtures-editor-reading", { try SampleData.draftWithOpponentReading(repositoryRoot: $0) }),
                         ("fixtures-editor-refused", { try SampleData.draftWithRefusedPaste(repositoryRoot: $0) }),
                         ("fixtures-editor-carried", { try SampleData.draftWithCarriedReading(repositoryRoot: $0) })] {
        let pasted: (model: AppModel, draft: FixtureDraft)
        do { pasted = try make(url) } catch { fail("\(error)") }
        try ScreenPictures.writeFixtureEditor(model: pasted.model, draft: pasted.draft, to: directory, name: name,
                                              size: Theme.Layout.fixtureEditorSuggestionPicture)
    }
}

/// The League screen, the Fixtures screen's menu on the table and the editor's opponent menu: see the usage at the top.
@MainActor func drawLeague(_ root: String, to directory: URL, size: CGSize) throws {
    // Tall enough for the whole table of 24 teams.
    let tall = CGSize(width: size.width, height: size.height * 2.3)
    try ScreenPictures.write(model: sampleModel(root, .league), to: directory, size: tall, variant: nil, screens: [.league])
    try ScreenPictures.write(model: SampleData.emptyModel(), to: directory, size: size, variant: "empty", screens: [.league])
    for (variant, state) in [("noformat", SampleState.leagueNoFormat), ("refused", .leagueRefused),
                             ("stale", .leagueStale), ("byhand", .leagueByHand)] {
        try ScreenPictures.write(model: sampleModel(root, state), to: directory, size: tall, variant: variant,
                                 screens: [.league])
    }
    try ScreenPictures.write(model: sampleModel(root, .league), to: directory, size: Theme.Layout.minimumWindow,
                             variant: "small", screens: [.league])
    try ScreenPictures.write(model: sampleModel(root, .league), to: directory, size: size, variant: "fromtable",
                             screens: [.fixtures])
    let url = URL(fileURLWithPath: root, isDirectory: true)
    for (name, opponent) in [("fixtures-editor-league", "Chester"), ("fixtures-editor-league-unmatched", "Buxton FC"),
                             ("fixtures-editor-league-battling", "Buxton")] {
        let made: (model: AppModel, draft: FixtureDraft)
        do { made = try SampleData.draftWithLeagueOpponent(repositoryRoot: url, opponent: opponent) } catch { fail("\(error)") }
        try ScreenPictures.writeFixtureEditor(model: made.model, draft: made.draft, to: directory, name: name,
                                              size: Theme.Layout.fixtureEditorSuggestionPicture)
    }
}

/// The Elevens screen's views: see the usage at the top.
@MainActor func drawElevens(_ root: String, to directory: URL, size: CGSize) throws {
    let plain = sampleModel(root)
    for (variant, view) in [("first", ElevensView.first), ("second", .second), ("depth", .depth)] {
        try ScreenPictures.write(model: plain, to: directory, size: size, variant: variant, screens: [.elevens],
                                 elevensStart: ElevensStart(view: view))
    }
    // The left centre-back chosen: options who count as cover and one needed at another slot.
    try ScreenPictures.write(model: plain, to: directory, size: size, variant: "depth-slot", screens: [.elevens],
                             elevensStart: ElevensStart(view: .depth, slot: .D_CL))
    // The same slot in a taller window, so the two solid players too far below the first choice to count show.
    try ScreenPictures.write(model: plain, to: directory, size: CGSize(width: size.width, height: size.height * 1.5),
                             variant: "depth-below", screens: [.elevens], elevensStart: ElevensStart(view: .depth, slot: .D_CL))
    try ScreenPictures.write(model: plain, to: directory, size: Theme.Layout.minimumWindow, variant: "depth-small",
                             screens: [.elevens], elevensStart: ElevensStart(view: .depth))
    // The primary with an unsaved change, so the line saying the saved version is shown appears.
    try ScreenPictures.write(model: sampleModel(root, .unsavedTacticChange), to: directory, size: size,
                             variant: "unsaved", screens: [.elevens])
    let tall = CGSize(width: Theme.Layout.minimumWindow.width, height: Theme.Layout.minimumWindow.height * 3)
    // Depth on the right attacking midfielder, whose options include the longest name in the sample.
    for (variant, start) in [("first-tall", ElevensStart(view: .first)), ("depth-tall", ElevensStart(view: .depth, slot: .AM_R))] {
        try ScreenPictures.write(model: plain, to: directory, size: tall, variant: variant, screens: [.elevens],
                                 elevensStart: start)
    }
}

/// The Rest screen with nobody to list, and with every level: see the usage at the top.
@MainActor func drawRest(_ root: String, to directory: URL, size: CGSize) throws {
    try ScreenPictures.write(model: sampleModel(root, .nobodyNeedingRest), to: directory, size: size, variant: "nobody",
                             screens: [.rest])
    // Tall enough for the whole sample list, down to the regulars to watch.
    try ScreenPictures.write(model: sampleModel(root), to: directory, size: CGSize(width: size.width, height: size.height * 2),
                             variant: "tall", screens: [.rest])
    let jaded = sampleModel(root, .jadedPlayers)
    try ScreenPictures.write(model: jaded, to: directory, size: size, variant: "levels", screens: [.rest])
    try ScreenPictures.write(model: jaded, to: directory, size: Theme.Layout.minimumWindow, variant: "levels-small",
                             screens: [.rest])
    // The trends measured from six weeks of readings, falling and rising; and with two readings each, measuring nothing.
    let falling = sampleModel(root, .fallingTrends)
    try ScreenPictures.write(model: falling, to: directory, size: size, variant: "trend", screens: [.rest])
    try ScreenPictures.write(model: falling, to: directory, size: Theme.Layout.minimumWindow, variant: "trend-small",
                             screens: [.rest])
    // Tall enough to reach the regulars whose trends are measured, and the foot note under them.
    try ScreenPictures.write(model: falling, to: directory, size: CGSize(width: size.width, height: size.height * 3),
                             variant: "trend-tall", screens: [.rest])
    try ScreenPictures.write(model: sampleModel(root, .risingTrends), to: directory, size: size, variant: "trend-rising",
                             screens: [.rest])
    try ScreenPictures.write(model: sampleModel(root, .beforeTrends), to: directory, size: size, variant: "unmeasured",
                             screens: [.rest])
}

/// The Training screen whole, under way and with nothing to list: see the usage at the top.
@MainActor func drawTraining(_ root: String, to directory: URL, size: CGSize) throws {
    let tall = CGSize(width: size.width, height: size.height * 2.5)
    let smallTall = CGSize(width: Theme.Layout.minimumWindow.width, height: Theme.Layout.minimumWindow.height * 4)
    let open = sampleModel(root, .beforeRetraining)
    try ScreenPictures.write(model: open, to: directory, size: size, screens: [.training])
    try ScreenPictures.write(model: open, to: directory, size: tall, variant: "tall", screens: [.training])
    try ScreenPictures.write(model: open, to: directory, size: smallTall, variant: "small-tall", screens: [.training])
    try ScreenPictures.write(model: sampleModel(root, .retrainingUnderWay), to: directory,
                             size: CGSize(width: size.width, height: size.height * 3.5), variant: "accepted",
                             screens: [.training])
    // A retraining well behind its estimate, and one no thin slot needs.
    try ScreenPictures.write(model: sampleModel(root, .retrainingBehind), to: directory,
                             size: CGSize(width: size.width, height: size.height * 3), variant: "behind",
                             screens: [.training])
    try ScreenPictures.write(model: sampleModel(root, .nothingToRetrain), to: directory, size: size, variant: "none",
                             screens: [.training])
    try drawMentoring(root, to: directory, size: size)
}

/// The Training screen's Mentoring tab: see the usage at the top.
@MainActor func drawMentoring(_ root: String, to directory: URL, size: CGSize) throws {
    let mentoring = TrainingStart(view: .mentoring)
    let tall = CGSize(width: size.width, height: size.height * 2)
    let pictures: [(String, AppModel, CGSize, TrainingStart)] = [
        ("mentoring", sampleModel(root, .hierarchy), tall, mentoring),
        ("mentoring-no-hierarchy", sampleModel(root), tall, mentoring),
        ("mentoring-stale", sampleModel(root, .staleHierarchy), tall, mentoring),
        ("mentoring-empty", SampleData.emptyModel(), size, mentoring),
        ("mentoring-u21", sampleModel(root, .hierarchy), size, TrainingStart(view: .mentoring, squad: .u21)),
        ("mentoring-recorded", sampleModel(root, .mentoringGroup), tall, mentoring),
        ("mentoring-warning", sampleModel(root, .mentoringWarning), tall, mentoring),
        ("mentoring-stopped", sampleModel(root, .stoppedGroup), tall, mentoring),
        ("mentoring-failed", sampleModel(root, .mentoringFailure), size, mentoring),
        ("mentoring-small", sampleModel(root, .mentoringWarning),
         CGSize(width: Theme.Layout.minimumWindow.width, height: Theme.Layout.minimumWindow.height * 4), mentoring),
        ("mentoring-arrows-read", sampleModel(root, .arrowsRead), tall, mentoring),
        ("mentoring-arrows-harm", sampleModel(root, .harmfulArrow), tall, mentoring),
        ("mentoring-arrows-none", sampleModel(root, .noInfluence), tall, mentoring),
        ("mentoring-regroup", sampleModel(root, .regrouping), tall, mentoring),
        ("mentoring-spent", sampleModel(root, .spentGroup), tall, mentoring),
        ("mentoring-ended", sampleModel(root, .endedGroup), tall, mentoring),
        ("mentoring-regroup-small", sampleModel(root, .regrouping),
         CGSize(width: Theme.Layout.minimumWindow.width, height: Theme.Layout.minimumWindow.height * 4), mentoring),
    ]
    for (variant, model, window, start) in pictures {
        try ScreenPictures.write(model: model, to: directory, size: window, variant: variant, screens: [.training],
                                 trainingStart: start)
    }

    // The editors on their own: the first team's hierarchy as entered, the U21s' with nothing entered, and a new
    // first-team group beside the recorded one, two ticked next to a player in that group.
    let entered = sampleModel(root, .hierarchy)
    try ScreenPictures.writeMentoringEditor(model: entered, editing: .hierarchy(.firstTeam), to: directory,
                                            name: "training-mentoring-hierarchy-editor")
    try ScreenPictures.writeMentoringEditor(model: entered, editing: .hierarchy(.u21), to: directory,
                                            name: "training-mentoring-hierarchy-editor-u21")
    let recorded = sampleModel(root, .mentoringGroup)
    var draft = MentoringGroupDraft(squad: .firstTeam)
    let choices = recorded.memberChoices(for: draft)
    guard let taken = choices.firstIndex(where: { $0.unavailableText != nil }) else {
        fail("The sample's recorded group has no member in the first team's list.")
    }
    for choice in choices.suffix(from: max(0, taken - 2)).filter(\.canToggle).prefix(2) { draft.toggle(choice.id) }
    try ScreenPictures.writeMentoringEditor(model: recorded, editing: .group(draft), to: directory,
                                            name: "training-mentoring-group-editor")

    // The arrows of the three first-team players with the longest names, so the longest pair shows, the first two set.
    let longest = (entered.squad.book.current[.firstTeam] ?? []).sorted {
        ($1.name.count, $0.name) < ($0.name.count, $1.name)
    }.prefix(3).map(\.id)
    var arrows = entered.arrowsDraft(for: .firstTeam, members: longest)
    for (row, strength) in zip(entered.arrowRows(for: arrows), [ArrowStrength.light, .average]) {
        arrows.strengths[row.id] = strength
    }
    try ScreenPictures.writeMentoringEditor(model: entered, editing: .arrows(arrows), to: directory,
                                            name: "training-mentoring-arrows-sheet")
}

/// The Player Removal screen with every row open, with a loanee, with two players marked, and with young players: see
/// the usage at the top.
@MainActor func drawRemoval(_ root: String, to directory: URL, size: CGSize) throws {
    try ScreenPictures.write(model: sampleModel(root), to: directory, size: CGSize(width: size.width, height: size.height * 4),
                             variant: "all-open", screens: [.removal], removalStart: RemovalStart(allOpen: true))
    // Tall enough for the Young players part above the loans.
    try ScreenPictures.write(model: sampleModel(root, .loanee), to: directory,
                             size: CGSize(width: size.width, height: size.height * 5), variant: "loanee", screens: [.removal])
    let marked = sampleModel(root)
    if case .ready(let report) = marked.adviceState {
        for (player, mark) in zip(report.removal.advice.map(\.player), SaleMark.allCases) {
            marked.setMark(mark, for: player)
        }
    }
    try ScreenPictures.write(model: marked, to: directory, size: CGSize(width: size.width, height: size.height * 2),
                             variant: "marked", screens: [.removal])
    try ScreenPictures.write(model: sampleModel(root, .youngPlayers), to: directory,
                             size: CGSize(width: size.width, height: size.height * 5), variant: "young",
                             screens: [.removal])
    try ScreenPictures.write(model: sampleModel(root, .youngPlayers), to: directory,
                             size: CGSize(width: size.width, height: size.height * 10), variant: "young-open",
                             screens: [.removal], removalStart: RemovalStart(allOpen: true))
    try ScreenPictures.write(model: sampleModel(root, .youngPlayers), to: directory,
                             size: CGSize(width: narrowWindow.width, height: narrowWindow.height * 7),
                             variant: "young-narrow", screens: [.removal])
}

/// The Scouting screen's two tabs: see the usage at the top.
@MainActor func drawScouting(_ root: String, to directory: URL, size: CGSize) throws {
    let small = Theme.Layout.minimumWindow
    let tall = CGSize(width: size.width, height: size.height * 2)
    // Tall enough for the fine slots and the evidence note under the needs.
    let needsTall = CGSize(width: size.width, height: size.height * 1.6)
    try ScreenPictures.write(model: sampleModel(root), to: directory, size: needsTall, variant: "needs",
                             screens: [.scouting])
    try ScreenPictures.write(model: sampleModel(root), to: directory, size: small, variant: "needs-small",
                             screens: [.scouting])
    // A U21 player on loan here, and an outfield first choice marked to sell, so both are counted as going.
    let going = sampleModel(root, .loanee)
    guard case .ready(let report) = going.adviceState,
          let first = report.elevens.first.first(where: { $0.slot != .GK }) else {
        fail("The sample's advice has no outfield first choice.")
    }
    going.setMark(.toSell, for: first.player)
    // Taller again: four going, so more depth needs, each naming who is going or injured.
    try ScreenPictures.write(model: going, to: directory, size: CGSize(width: size.width, height: size.height * 2),
                             variant: "needs-going", screens: [.scouting])

    let candidates = ScoutingStart(view: .candidates)
    try ScreenPictures.write(model: sampleModel(root), to: directory, size: size, variant: "candidates-empty",
                             screens: [.scouting], scoutingStart: candidates)
    let held = sampleModel(root, .candidates)
    try ScreenPictures.write(model: held, to: directory, size: tall, variant: "candidates", screens: [.scouting],
                             scoutingStart: candidates)
    try ScreenPictures.write(model: held, to: directory, size: tall, variant: "candidates-later", screens: [.scouting],
                             scoutingStart: ScoutingStart(view: .candidates, order: .later))
    try ScreenPictures.write(model: held, to: directory, size: CGSize(width: size.width, height: size.height * 3),
                             variant: "candidates-open", screens: [.scouting],
                             scoutingStart: ScoutingStart(view: .candidates, allOpen: true))
    try ScreenPictures.write(model: held, to: directory, size: small, variant: "candidates-small", screens: [.scouting],
                             scoutingStart: candidates)
    try ScreenPictures.write(model: sampleModel(root, .refusedCandidates), to: directory, size: size,
                             variant: "candidates-refused", screens: [.scouting], scoutingStart: candidates)
    // One group of the owner's captured search, over five: its best five and the line the others are behind, then the
    // same with the line open, tall enough for them all.
    let crowded = sampleModel(root, .crowdedCandidates)
    try ScreenPictures.write(model: crowded, to: directory, size: tall, variant: "candidates-crowded",
                             screens: [.scouting], scoutingStart: candidates)
    try ScreenPictures.write(model: crowded, to: directory, size: CGSize(width: size.width, height: size.height * 5),
                             variant: "candidates-crowded-open", screens: [.scouting],
                             scoutingStart: ScoutingStart(view: .candidates, moreOpen: true))
    // Two of the sample candidates hidden: the line they are behind, then the list.
    let hidden = sampleModel(root, .hiddenCandidates)
    try ScreenPictures.write(model: hidden, to: directory, size: tall, variant: "candidates-hidden",
                             screens: [.scouting], scoutingStart: candidates)
    try ScreenPictures.write(model: hidden, to: directory, size: tall, variant: "candidates-hidden-open",
                             screens: [.scouting], scoutingStart: ScoutingStart(view: .candidates, hiddenOpen: true))
    try ScreenPictures.write(model: SampleData.emptyModel(), to: directory, size: size, variant: "notready",
                             screens: [.scouting])
}

/// The key of the sample's player of this name, or the reason the pictures stop.
@MainActor func samplePlayer(_ name: String, in model: AppModel) -> PlayerID {
    guard let player = model.players.first(where: { $0.name == name }) else { fail("The sample has no \(name).") }
    return player.id
}

/// The Offers screen and its sheet: see the usage at the top.
@MainActor func drawOffers(_ root: String, to directory: URL, size: CGSize) throws {
    // Tall enough for the three players' blocks, what the offers have shown and the evidence note; taller with a club's
    // figures and terms in a block; shorter with the first seller's block moved under "Earlier offers".
    let tall = CGSize(width: size.width, height: size.height * 2.9)
    let taller = CGSize(width: size.width, height: size.height * 3.4)
    let shorter = CGSize(width: size.width, height: size.height * 2.3)
    try ScreenPictures.write(model: sampleModel(root), to: directory, size: size, variant: "empty", screens: [.offers])
    try ScreenPictures.write(model: sampleModel(root, .offers), to: directory, size: tall, variant: nil, screens: [.offers])

    // Barnet typed for the player marked to sell with no deal, given a value, with a budget that covers the whole fee,
    // part of it, and none of it. The club's wage figures are entered too, so all four fields show a figure.
    for (variant, budget) in [("club-all", "60000"), ("club", "15000"), ("nothing-now", "0")] {
        let model = sampleModel(root, .offers)
        let player = samplePlayer(SampleData.offerNoValueName, in: model)
        model.setOfferValue(text: "25000", for: player)
        let club = SampleData.offerDealClub
        model.setClubFigure(.transferBudget, text: budget, club: club)
        model.setClubFigure(.wageBudget, text: "9000", club: club)
        model.setClubFigure(.wagesSpent, text: "8200", club: club)
        model.setClubFigure(.highestWage, text: "900", club: club)
        try ScreenPictures.write(model: model, to: directory, size: taller, variant: variant, screens: [.offers],
                                 offersStart: OffersStart(clubs: [player: club]))
    }

    // The loan switched to moving his wage, with a club typed for it whose wage figures are entered.
    let wage = sampleModel(root, .offers)
    let loanee = samplePlayer(SampleData.offerLoaneeName, in: wage)
    wage.setLoanPurpose(.wage, for: loanee)
    wage.setClubFigure(.wageBudget, text: "6000", club: "Wealdstone")
    wage.setClubFigure(.wagesSpent, text: "5600", club: "Wealdstone")
    wage.setClubFigure(.highestWage, text: "700", club: "Wealdstone")
    try ScreenPictures.write(model: wage, to: directory, size: taller, variant: "loan-wage", screens: [.offers],
                             offersStart: OffersStart(clubs: [loanee: "Wealdstone"]))

    try ScreenPictures.write(model: sampleModel(root, .offersMeasured), to: directory, size: tall, variant: "measured",
                             screens: [.offers])

    // The first seller switched to loan terms: his loan terms and the loan's purpose menu, his sale ask and his sale deal
    // with Barnet still in his block.
    let toggled = sampleModel(root, .offers)
    toggled.setOfferKind(.loan, for: samplePlayer(SampleData.offerSellerName, in: toggled))
    try ScreenPictures.write(model: toggled, to: directory, size: tall, variant: "toggled", screens: [.offers])

    // The player marked to sell with no value out on loan: sale terms alone, with the engine's sentence under them.
    try ScreenPictures.write(model: sampleModel(root, .offerOutOnLoan), to: directory, size: tall, variant: "onloan",
                             screens: [.offers])

    // The first seller's mark taken off: his deal and his ask move under "Earlier offers", opened.
    let earlier = sampleModel(root, .offers)
    earlier.setMark(nil, for: samplePlayer(SampleData.offerSellerName, in: earlier))
    try ScreenPictures.write(model: earlier, to: directory, size: shorter, variant: "earlier", screens: [.offers],
                             offersStart: OffersStart(earlierOpen: true))

    try ScreenPictures.write(model: sampleModel(root, .offers), to: directory, size: Theme.Layout.minimumWindow,
                             variant: "small", screens: [.offers])

    // The sheet for the owner's proposal in the Barnet deal, filled with the next step; and for the loan's ask.
    let offers = sampleModel(root, .offers)
    let seller = samplePlayer(SampleData.offerSellerName, in: offers)
    let sheet = offers.offersSheet(clubs: [:])
    guard let deal = sheet.toSell.first(where: { $0.id == seller })?.deals.first,
          let sale = offers.offerDraft(for: seller, club: deal.club, purpose: .mine, filledWith: deal.next?.terms) else {
        fail("The offers sample has no deal for \(SampleData.offerSellerName).")
    }
    try ScreenPictures.writeOfferEditor(model: offers, draft: sale, to: directory, name: "offers-editor-sale")
    let loanID = samplePlayer(SampleData.offerLoaneeName, in: offers)
    guard let general = sheet.toLoanOut.first(where: { $0.id == loanID })?.general,
          let loan = offers.offerDraft(for: loanID, club: "", purpose: .ask, filledWith: general.terms) else {
        fail("The offers sample has no terms for \(SampleData.offerLoaneeName).")
    }
    try ScreenPictures.writeOfferEditor(model: offers, draft: loan, to: directory, name: "offers-editor-loan")
}

/// Draws the pictures and returns the process's exit status.
@MainActor func drawPictures(to path: String, sampleDataRoot: String?) -> Int32 {
    do {
        // Loads the engine's resources once, so an app built without them stops here, before
        // anything is drawn.
        _ = try RoleCatalog.fm27()
    } catch {
        fail("The engine could not load its role catalogue: \(ErrorDescriptions.describe(error))")
    }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    let size = Theme.Layout.defaultWindow
    do {
        try ScreenPictures.writeTypeSpecimen(to: directory)
        if let root = sampleDataRoot {
            // The left back has the most reasons in the first fixture.
            try ScreenPictures.write(model: sampleModel(root), to: directory, size: size,
                                     screens: Screen.allCases.filter { ![.tactics, .training, .fixtures, .scouting, .offers].contains($0) },
                                     matchStart: MatchStart(slot: .D_L))
            // With an unsaved change, the left inside forward made a winger and selected, so the role menu,
            // "Remove", what he becomes and the marks for unsaved changes are all shown.
            try ScreenPictures.write(model: sampleModel(root, .unsavedTacticChange), to: directory, size: size,
                                     screens: [.tactics], tacticSlot: TacticSlot(.AM_L, in: .inPossession))
            try ScreenPictures.write(model: SampleData.emptyModel(), to: directory, size: size, variant: "empty",
                                     screens: [.squad, .tactics, .fixtures, .matchSelection] + advisorScreens)
            try ScreenPictures.write(model: sampleModel(root, .pastFixtures), to: directory, size: size,
                                     variant: "past", screens: [.fixtures])
            // The editor for the confirmed fixture, so the note about its confirmed lineup is shown.
            let past = sampleModel(root, .pastFixtures)
            guard let confirmed = past.fixtures.first else { fail("The sample model has no fixtures.") }
            try ScreenPictures.writeFixtureEditor(model: past, draft: past.fixtureDraft(for: confirmed), to: directory)
            // The striker nothing turns into, selected out of possession.
            try ScreenPictures.write(model: sampleModel(root, .tacticProblem), to: directory, size: size,
                                     variant: "problem", screens: [.tactics] + advisorScreens,
                                     tacticSlot: TacticSlot(.ST_C, in: .outOfPossession))
            try ScreenPictures.write(model: sampleModel(root, .failedImport), to: directory, size: size,
                                     variant: "failed", screens: [.squad])
            try ScreenPictures.write(model: sampleModel(root, .afterImport), to: directory, size: size,
                                     variant: "imported", screens: [.squad])
            try drawFixtures(root, to: directory, size: size)
            try drawMatchSelection(root, to: directory, size: size)
            try drawElevens(root, to: directory, size: size)
            try drawRest(root, to: directory, size: size)
            try drawTraining(root, to: directory, size: size)
            try drawRemoval(root, to: directory, size: size)
            try drawScouting(root, to: directory, size: size)
            try drawLeague(root, to: directory, size: size)
            try drawOffers(root, to: directory, size: size)
        } else {
            try ScreenPictures.write(model: SampleData.emptyModel(), to: directory, size: size)
        }
    } catch {
        fail("\(error)")
    }
    print("Drew with the typefaces in \(Theme.Typeface.folder?.path ?? "no folder")")
    print("Wrote the pictures to \(directory.standardizedFileURL.path)")
    return 0
}

/// Loads the two typefaces for this process, and the sentence for any that could not be loaded.
func loadTypefaces() -> String? {
    BoardText.fontNotice(missing: Theme.Typeface.missingFaces.map(\.rawValue))
}

let options: LaunchOptions
do {
    options = try LaunchOptions.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    fail(error.description)
}

let typefaceNotice = loadTypefaces()
if let pictures = options.picturesDirectory {
    if let typefaceNotice { fail(typefaceNotice) }
    exit(drawPictures(to: pictures, sampleDataRoot: options.sampleDataRoot))
}
// The window on the sample data reads the Mac's clock, so the training actions' guard against a second click works
// there as in the real app.
Startup.model = options.sampleDataRoot.map { root in
    do {
        return try SampleData.interactiveModel(repositoryRoot: URL(fileURLWithPath: root, isDirectory: true))
    } catch {
        fail("\(error)")
    }
} ?? AppModel(store: Store(directory: LiveEnvironment.storeDirectory), environment: LiveEnvironment.make())
if let typefaceNotice { Startup.model?.addNotice(typefaceNotice) }
LineupApplication.main()
