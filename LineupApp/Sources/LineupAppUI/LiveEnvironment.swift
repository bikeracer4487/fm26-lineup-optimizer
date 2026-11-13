import AppKit
import Foundation
import LineupAppCore
import LineupEngine

/// The world outside the app's files, as the running app sees it: the Mac's clock, the clipboard (read only)
/// and FMRTE's settings file.
public enum LiveEnvironment {
    /// Where the app keeps its files: `~/Library/Application Support/FM27 Lineup Optimizer/`.
    public static var storeDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("FM27 Lineup Optimizer", isDirectory: true)
    }

    /// Where FMRTE keeps its settings: `~/Library/Application Support/FMRTE27/config.json`.
    public static var fmrteConfigFile: URL {
        URL.applicationSupportDirectory.appendingPathComponent("FMRTE27/config.json")
    }

    /// `fmrteConfigFile` with the home folder written as "~".
    public static var fmrteConfigFileForDisplay: String {
        NSString(string: fmrteConfigFile.path).abbreviatingWithTildeInPath
    }

    public static func make() -> AppEnvironment {
        AppEnvironment(
            today: { today() },
            clipboard: { NSPasteboard.general.string(forType: .string) },
            fmrteConfig: { path in
                let file = path.map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) } ?? fmrteConfigFile
                // A missing file throws Cocoa's file-not-found error, which the model turns into a sentence naming the path.
                return try Data(contentsOf: file)
            })
    }

    /// Today in the Mac's own calendar and time zone.
    static func today() -> Day {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let today = Day(year: year, month: month, day: day) else {
            fatalError("The Mac's calendar gave a date that does not exist.")
        }
        return today
    }
}
