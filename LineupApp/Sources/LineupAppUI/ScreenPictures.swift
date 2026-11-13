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

    /// Draws the candidate picker on its own for `slot` in `fixture`, as its popover shows it, in light and in dark:
    /// "match-picker-light.png" and "match-picker-dark.png". A popover cannot be drawn into a picture, so the picker
    /// is drawn as a window of its own.
    @MainActor public static func writeCandidatePicker(model: AppModel, fixture: FixtureID, slot: SlotID,
                                                       to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let name = "match-picker-\(suffix).png"
            let picker = CandidatePicker(title: MatchPresentation.pickerTitle(slot),
                                         rows: model.candidateRows(for: slot, in: fixture), choose: { _ in }, cancel: {})
                .tint(Theme.Colour.hoopBlue)
            let png = try draw(picker, size: Theme.Match.pickerSize, appearance: appearance, name: name)
            do {
                try png.write(to: directory.appendingPathComponent(name), options: .atomic)
            } catch {
                throw PictureError.couldNotWrite(name, underlying: error)
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

    /// Hosts `view` in a window that is never shown, lays it out and returns it as PNG data.
    @MainActor static func draw(_ view: some View, size: CGSize, appearance: NSAppearance.Name, name: String) throws -> Data {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        window.setContentSize(size)
        defer { window.close() }

        settle(window)
        // The frame view holds the title bar and toolbar as well as the content.
        let frameView = host.superview ?? host
        hideWindowServerViews(in: frameView)
        settle(window)

        guard let picture = compose(frameView, appearance: appearance),
              let png = picture.representation(using: .png, properties: [:]) else {
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

    /// Hides what only the window server can draw and which comes out wrong when a window that
    /// is never shown is drawn into a bitmap: a scroll view's edge effect ("NSScrollPocket")
    /// blanks out the whole scroll view, so the sidebar's list would be missing, and a backdrop
    /// ("BackdropView") draws solid black. The window is thrown away after the picture, so
    /// nothing is restored.
    @MainActor static func hideWindowServerViews(in view: NSView) {
        let className = String(describing: type(of: view))
        if className == "BackdropView" || (className == "NSScrollPocket" && view.superview is NSScrollView) {
            view.isHidden = true
            return
        }
        for subview in view.subviews {
            hideWindowServerViews(in: subview)
        }
    }

    /// The frame view drawn into a bitmap over the window background of `appearance`, so the
    /// parts the window server would have filled in (the window's corners, the sidebar's glass)
    /// are not transparent.
    ///
    /// A glass panel (the sidebar) draws itself as a solid white sheet over its content when
    /// it is drawn into a bitmap, so each panel's area is filled with the window background
    /// and its content is drawn into it separately. The title bar, which sits above the glass,
    /// is then drawn again on top.
    @MainActor static func compose(_ frameView: NSView, appearance: NSAppearance.Name) -> NSBitmapImageRep? {
        guard let drawingAppearance = NSAppearance(named: appearance),
              let window = snapshot(frameView),
              let result = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: window.pixelsWide,
                                            pixelsHigh: window.pixelsHigh, bitsPerSample: 8, samplesPerPixel: 4,
                                            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0, bitsPerPixel: 0) else {
            return nil
        }
        result.size = window.size
        guard let context = NSGraphicsContext(bitmapImageRep: result) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context

        drawingAppearance.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            frameView.bounds.fill()
        }
        window.draw(in: frameView.bounds, from: .zero, operation: .sourceOver, fraction: 1,
                    respectFlipped: false, hints: nil)

        for glass in glassPanels(in: frameView) {
            guard let content = glass.contentView else { continue }
            drawingAppearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill()
                NSBezierPath(roundedRect: area(of: glass, in: frameView),
                             xRadius: glass.cornerRadius, yRadius: glass.cornerRadius).fill()
            }
            // Vibrant text is drawn for a colour filter that only the window server applies;
            // without it, it comes out black. So it is left out of the panel's picture and
            // drawn on its own in the appearance's label colour.
            let vibrantText = vibrantLeaves(in: content)
            vibrantText.forEach { $0.isHidden = true }
            draw(content, in: frameView)
            vibrantText.forEach { $0.isHidden = false }
            for text in vibrantText {
                drawingAppearance.performAsCurrentDrawingAppearance {
                    draw(text, in: frameView, colour: .labelColor)
                }
            }
        }
        for titleBar in frameView.subviews where titleBar.className.hasPrefix("NSTitlebarContainerView") {
            draw(titleBar, in: frameView)
        }
        return result
    }

    /// `view` drawn into a bitmap of its own.
    @MainActor static func snapshot(_ view: NSView) -> NSBitmapImageRep? {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    /// Draws `view` into the current context, which holds a picture of `frameView`. With a
    /// colour, every pixel the view draws takes that colour, keeping its coverage.
    @MainActor static func draw(_ view: NSView, in frameView: NSView, colour: NSColor? = nil) {
        guard var bitmap = snapshot(view) else { return }
        if let colour, let tinted = tinted(bitmap, colour) {
            bitmap = tinted
        }
        bitmap.draw(in: area(of: view, in: frameView), from: .zero, operation: .sourceOver, fraction: 1,
                    respectFlipped: false, hints: nil)
    }

    /// A copy of `bitmap` in `colour`, with the bitmap's coverage.
    @MainActor static func tinted(_ bitmap: NSBitmapImageRep, _ colour: NSColor) -> NSBitmapImageRep? {
        guard let copy = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: bitmap.pixelsWide,
                                          pixelsHigh: bitmap.pixelsHigh, bitsPerSample: 8, samplesPerPixel: 4,
                                          hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0, bitsPerPixel: 0) else {
            return nil
        }
        copy.size = bitmap.size
        guard let context = NSGraphicsContext(bitmapImageRep: copy) else {
            return nil
        }
        let whole = CGRect(origin: .zero, size: bitmap.size)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        bitmap.draw(in: whole, from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: nil)
        colour.setFill()
        whole.fill(using: .sourceIn)
        return copy
    }

    /// Where `view` lies in a picture of `frameView`, whose origin is at the bottom left.
    @MainActor static func area(of view: NSView, in frameView: NSView) -> CGRect {
        var rect = view.convert(view.bounds, to: frameView)
        if frameView.isFlipped {
            rect.origin.y = frameView.bounds.height - rect.maxY
        }
        return rect
    }

    /// Every glass panel under `view`, outermost first.
    @MainActor static func glassPanels(in view: NSView) -> [NSGlassEffectView] {
        if let glass = view as? NSGlassEffectView {
            return [glass]
        }
        return view.subviews.flatMap(glassPanels(in:))
    }

    /// The views under `view` that draw in a vibrant appearance and hold no other views:
    /// the text of a sidebar's rows.
    @MainActor static func vibrantLeaves(in view: NSView) -> [NSView] {
        if view.isHidden { return [] }
        if view.subviews.isEmpty {
            let name = view.effectiveAppearance.name
            return name == .vibrantDark || name == .vibrantLight ? [view] : []
        }
        return view.subviews.flatMap(vibrantLeaves(in:))
    }
}
