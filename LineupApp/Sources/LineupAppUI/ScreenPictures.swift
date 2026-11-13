import AppKit
import LineupAppCore
import LineupEngine
import SwiftUI

/// Draws the app's screens to PNG files without showing a window, so a screen can be
/// checked from the command line.
public enum ScreenPictures {

    public enum PictureError: Error, CustomStringConvertible {
        case couldNotDraw(String)
        case couldNotWrite(String, underlying: Error)

        public var description: String {
            switch self {
            case let .couldNotDraw(name):
                "The picture \(name) could not be drawn."
            case let .couldNotWrite(name, underlying):
                "The picture \(name) could not be written: \(underlying.localizedDescription)"
            }
        }
    }

    /// Draws each of `screens` from `model` at the given size, in light and in dark, and writes
    /// "<screen>-light.png" and "<screen>-dark.png" into `directory`; with a variant,
    /// "<screen>-<variant>-light.png" and "<screen>-<variant>-dark.png". Match Selection's pictures are named
    /// "match-…". With a tactic slot, the Tactics editor is drawn with that slot selected; Match Selection is drawn
    /// as `matchStart` says.
    @MainActor public static func write(
        model: AppModel, to directory: URL, size: CGSize, variant: String? = nil, screens: [Screen] = Screen.allCases,
        tacticSlot: TacticSlot? = nil, matchStart: MatchStart = MatchStart()
    ) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let appearances: [(suffix: String, name: NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]
        for screen in screens {
            for appearance in appearances {
                let name = ([pictureName(of: screen)] + [variant].compactMap { $0 } + [appearance.suffix])
                    .joined(separator: "-") + ".png"
                let png = try draw(RootView(model: model, showing: screen, tacticSlot: tacticSlot, matchStart: matchStart),
                                   size: size, appearance: appearance.name, name: name)
                do {
                    try png.write(to: directory.appendingPathComponent(name), options: .atomic)
                } catch {
                    throw PictureError.couldNotWrite(name, underlying: error)
                }
            }
        }
    }

    /// Draws the fixture editor on its own, as its sheet shows it, for `draft` in `model`, in light and in dark:
    /// "fixtures-editor-light.png" and "fixtures-editor-dark.png". A sheet is not drawn with the screen under it,
    /// so the editor is drawn as a window of its own.
    @MainActor public static func writeFixtureEditor(model: AppModel, draft: FixtureDraft, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let name = "fixtures-editor-\(suffix).png"
            let editor = FixtureEditor(model: model, draft: draft) {}
                .tint(Theme.Colour.hoopBlue)
            let png = try draw(editor, size: Theme.Layout.fixtureEditorSize, appearance: appearance, name: name)
            do {
                try png.write(to: directory.appendingPathComponent(name), options: .atomic)
            } catch {
                throw PictureError.couldNotWrite(name, underlying: error)
            }
        }
    }

    /// Draws the candidate picker on its own with `text` and `rows`, as its popover or sheet shows it, in light and in
    /// dark: "<name>-light.png" and "<name>-dark.png". A popover cannot be drawn into a picture, so the picker is
    /// drawn as a window of its own.
    @MainActor public static func writeCandidatePicker(name: String, text: PickerText, rows: [CandidateRow],
                                                       to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let file = "\(name)-\(suffix).png"
            let picker = CandidatePicker(text: text, rows: rows, choose: { _ in }, cancel: {})
                .tint(Theme.Colour.hoopBlue)
            let png = try draw(picker, size: Theme.Match.pickerSize, appearance: appearance, name: file)
            do {
                try png.write(to: directory.appendingPathComponent(file), options: .atomic)
            } catch {
                throw PictureError.couldNotWrite(file, underlying: error)
            }
        }
    }

    /// The start of a screen's picture names.
    static func pictureName(of screen: Screen) -> String {
        switch screen {
        case .matchSelection: "match"
        case .squad, .tactics, .fixtures, .settings: screen.rawValue
        }
    }

    /// Hosts `view` in a window that is never shown, as the app's window is styled (its title bar transparent over
    /// the wall), lays it out and returns it as PNG data.
    @MainActor static func draw(_ view: some View, size: CGSize, appearance: NSAppearance.Name, name: String) throws -> Data {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: appearance)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        window.setContentSize(size)
        defer { window.close() }

        settle(window)
        // The frame view holds the title bar as well as the content.
        let frameView = host.superview ?? host
        guard let picture = snapshot(frameView), let png = picture.representation(using: .png, properties: [:]) else {
            throw PictureError.couldNotDraw(name)
        }
        return png
    }

    /// Lets SwiftUI and AppKit finish laying out and drawing before the picture is taken.
    @MainActor static func settle(_ window: NSWindow) {
        for _ in 0..<3 {
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    /// `view` drawn into a bitmap of its own.
    @MainActor static func snapshot(_ view: NSView) -> NSBitmapImageRep? {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }
}
