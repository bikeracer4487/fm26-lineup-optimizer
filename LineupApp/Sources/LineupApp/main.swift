// FM27 Lineup Optimizer.
//
// Usage:
//   LineupApp                                  opens the window on the app's own files in
//                                              ~/Library/Application Support/FM27 Lineup Optimizer
//   LineupApp --sample-data <repository root>  opens the window on the engine's sample squads, tactic and
//                                              fixtures, in a temporary directory
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
//                                              its own for the first fixture's goalkeeper ("match-picker-…") and
//                                              for the remembered eleven's goalkeeper ("match-remembered-picker-…").
//                                              The advisor screens ("elevens-…", "rest-…", "training-…",
//                                              "removal-…") are drawn on the sample, empty ("<screen>-empty-…")
//                                              and with a primary tactic that has a problem
//                                              ("<screen>-problem-…"). The Elevens screen is drawn
//                                              on each of its views ("elevens-first-…",
//                                              "elevens-second-…", "elevens-depth-…"), Depth with the left
//                                              centre-back chosen ("elevens-depth-slot-…"), and Depth in the
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
//                                              ("rest-levels-small-…").
//                                              The Training screen ("training-…") is drawn on the sample
//                                              before its retraining is accepted, so its recommendations
//                                              show, and so tall enough for all four parts
//                                              ("training-tall-…", and "training-small-tall-…" in the
//                                              smallest window's width); with its retraining six weeks
//                                              under way, a second whose player has left and a pair turned
//                                              down, taller ("training-accepted-…"), and with nothing to list
//                                              ("training-none-…").
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
    case afterConfirmingFirst, choices, missedFixture, missedEleven, missedElevenWhileStopped, twoMatchesOnOneDay
    case jadedPlayers, nobodyNeedingRest, beforeRetraining, retrainingUnderWay, nothingToRetrain
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
        case .missedFixture: return try SampleData.modelWithMissedFixture(repositoryRoot: url)
        case .missedEleven: return try SampleData.modelWithMissedEleven(repositoryRoot: url)
        case .missedElevenWhileStopped: return try SampleData.modelWithMissedElevenWhileThePlanIsStopped(repositoryRoot: url)
        case .twoMatchesOnOneDay: return try SampleData.modelWithTwoMatchesOnOneDay(repositoryRoot: url)
        case .jadedPlayers: return try SampleData.modelWithJadedPlayers(repositoryRoot: url)
        case .nobodyNeedingRest: return try SampleData.modelWithNobodyNeedingRest(repositoryRoot: url)
        case .beforeRetraining: return try SampleData.modelBeforeRetraining(repositoryRoot: url)
        case .retrainingUnderWay: return try SampleData.modelWithRetrainingUnderWay(repositoryRoot: url)
        case .nothingToRetrain: return try SampleData.modelWithNothingToRetrain(repositoryRoot: url)
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
    let tall = CGSize(width: size.width, height: size.height * 1.75)
    try ScreenPictures.write(model: sampleModel(root, .choices), to: directory, size: tall, variant: "choices",
                             screens: [.matchSelection], matchStart: MatchStart(slot: .AM_C))
    let confirmed = sampleModel(root, .afterConfirmingFirst)
    guard let first = confirmed.fixtures.first else { fail("The sample model has no fixtures.") }
    try ScreenPictures.write(model: confirmed, to: directory, size: size, variant: "confirmed",
                             screens: [.matchSelection], matchStart: MatchStart(fixture: first.id))
    try ScreenPictures.write(model: confirmed, to: directory, size: size, variant: "after-confirm",
                             screens: [.matchSelection], matchStart: MatchStart(slot: .D_L))
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

    // The narrow and the smallest windows: the detail under the pitch, the pitches stacked, and scrolling; the other
    // screens narrow, so the pills wrap.
    try ScreenPictures.write(model: sampleModel(root, .afterImport), to: directory, size: narrowWindow, variant: "narrow",
                             screens: [.squad, .fixtures, .settings] + advisorScreens)
    try ScreenPictures.write(model: plain, to: directory, size: Theme.Layout.minimumWindow, variant: "small",
                             screens: [.fixtures] + advisorScreens)
    for (variant, small) in [("narrow", narrowWindow), ("small", Theme.Layout.minimumWindow)] {
        try ScreenPictures.write(model: plain, to: directory, size: small, variant: variant,
                                 screens: [.matchSelection], matchStart: MatchStart(slot: .D_L))
        try ScreenPictures.write(model: sampleModel(root, .unsavedTacticChange), to: directory, size: small,
                                 variant: variant, screens: [.tactics], tacticSlot: TacticSlot(.AM_L, in: .inPossession))
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
    try ScreenPictures.write(model: sampleModel(root, .nothingToRetrain), to: directory, size: size, variant: "none",
                             screens: [.training])
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
                                     screens: Screen.allCases.filter { $0 != .tactics && $0 != .training },
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
            try drawMatchSelection(root, to: directory, size: size)
            try drawElevens(root, to: directory, size: size)
            try drawRest(root, to: directory, size: size)
            try drawTraining(root, to: directory, size: size)
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
Startup.model = options.sampleDataRoot.map { sampleModel($0) }
    ?? AppModel(store: Store(directory: LiveEnvironment.storeDirectory), environment: LiveEnvironment.make())
if let typefaceNotice { Startup.model?.addNotice(typefaceNotice) }
LineupApplication.main()
