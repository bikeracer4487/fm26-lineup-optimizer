// FM27 Lineup Optimizer.
//
// Usage:
//   LineupApp                         opens the window
//   LineupApp --pictures <directory>  draws every screen, light and dark, to PNG files in
//                                     <directory>, then exits (0 on success, 1 on a problem)

import AppKit
import Foundation
import LineupAppUI
import LineupEngine
import SwiftUI

/// The app's window and its life as a regular Mac app.
struct LineupApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("FM27 Lineup Optimizer") {
            RootView()
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

/// Draws the pictures and returns the process's exit status.
@MainActor func drawPictures(arguments: [String]) -> Int32 {
    guard arguments.count == 2 else {
        FileHandle.standardError.write(Data("--pictures needs one directory, for example --pictures .build/pictures\n".utf8))
        return 1
    }
    do {
        // Loads the engine's resources once, so an app built without them stops here, before
        // anything is drawn.
        _ = try RoleCatalog.fm27()
    } catch {
        FileHandle.standardError.write(Data("The engine could not load its role catalogue: \(ErrorDescriptions.describe(error))\n".utf8))
        return 1
    }
    let directory = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    do {
        try ScreenPictures.write(to: directory, size: Theme.Layout.defaultWindow)
    } catch {
        FileHandle.standardError.write(Data("\(error)\n".utf8))
        return 1
    }
    print("Wrote the pictures to \(directory.standardizedFileURL.path)")
    return 0
}

let arguments = Array(CommandLine.arguments.dropFirst())
if let index = arguments.firstIndex(of: "--pictures") {
    exit(drawPictures(arguments: Array(arguments[index...])))
} else {
    LineupApplication.main()
}
