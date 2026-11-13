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
//                                              the sample model, and the Squad screen empty and after a
//                                              failed import as well ("squad-empty-…", "squad-failed-…").

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

/// The sample model from the repository at `root`, or the reason it could not be built.
@MainActor func sampleModel(_ root: String, failedImport: Bool = false) -> AppModel {
    let url = URL(fileURLWithPath: root, isDirectory: true)
    do {
        return failedImport ? try SampleData.modelWithFailedImport(repositoryRoot: url) : try SampleData.model(repositoryRoot: url)
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
            try ScreenPictures.write(model: sampleModel(root), to: directory, size: size)
            try ScreenPictures.write(model: SampleData.emptyModel(), to: directory, size: size, variant: "empty", screens: [.squad])
            try ScreenPictures.write(model: sampleModel(root, failedImport: true), to: directory, size: size,
                                     variant: "failed", screens: [.squad])
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
