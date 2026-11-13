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
        WindowGroup("FM27 Lineup Optimizer") {
            RootView(model: model)
        }
        .defaultSize(Theme.Layout.defaultWindow)
    }
}

/// Started with `swift run` the app is not a bundle, so it makes itself a regular app with a
/// Dock icon and a menu bar, and comes to the front.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
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
        }
    } catch {
        fail("\(error)")
    }
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
        if let root = sampleDataRoot {
            try ScreenPictures.write(model: sampleModel(root), to: directory, size: size,
                                     screens: Screen.allCases.filter { $0 != .tactics })
            // With an unsaved change, the left inside forward made a winger and selected, so the role menu,
            // "Remove", what he becomes and the marks for unsaved changes are all shown.
            try ScreenPictures.write(model: sampleModel(root, .unsavedTacticChange), to: directory, size: size,
                                     screens: [.tactics], tacticSlot: TacticSlot(.AM_L, in: .inPossession))
            try ScreenPictures.write(model: SampleData.emptyModel(), to: directory, size: size, variant: "empty",
                                     screens: [.squad, .tactics, .fixtures])
            try ScreenPictures.write(model: sampleModel(root, .pastFixtures), to: directory, size: size,
                                     variant: "past", screens: [.fixtures])
            // The editor for the confirmed fixture, so the note about its confirmed lineup is shown.
            let past = sampleModel(root, .pastFixtures)
            guard let confirmed = past.fixtures.first else { fail("The sample model has no fixtures.") }
            try ScreenPictures.writeFixtureEditor(model: past, draft: FixtureDraft(confirmed), to: directory)
            // The striker nothing turns into, selected out of possession.
            try ScreenPictures.write(model: sampleModel(root, .tacticProblem), to: directory, size: size,
                                     variant: "problem", screens: [.tactics],
                                     tacticSlot: TacticSlot(.ST_C, in: .outOfPossession))
            try ScreenPictures.write(model: sampleModel(root, .failedImport), to: directory, size: size,
                                     variant: "failed", screens: [.squad])
            try ScreenPictures.write(model: sampleModel(root, .afterImport), to: directory, size: size,
                                     variant: "imported", screens: [.squad])
        } else {
            try ScreenPictures.write(model: SampleData.emptyModel(), to: directory, size: size)
        }
    } catch {
        fail("\(error)")
    }
    print("Wrote the pictures to \(directory.standardizedFileURL.path)")
    return 0
}

let options: LaunchOptions
do {
    options = try LaunchOptions.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    fail(error.description)
}

if let pictures = options.picturesDirectory {
    exit(drawPictures(to: pictures, sampleDataRoot: options.sampleDataRoot))
}
Startup.model = options.sampleDataRoot.map { sampleModel($0) }
    ?? AppModel(store: Store(directory: LiveEnvironment.storeDirectory), environment: LiveEnvironment.make())
LineupApplication.main()
