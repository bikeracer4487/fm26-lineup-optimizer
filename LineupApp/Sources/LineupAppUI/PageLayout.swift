import CoreGraphics

/// How a screen with pitches lays itself out for the space it has: filling it, scrolling, or stacked for a narrow
/// window. Worked out from the screen's size alone.
enum PageLayout: Equatable {
    /// Everything fits: the pitches fill the height left for them.
    case filling
    /// Too short: the screen scrolls and each pitch is sized by its width.
    case scrolling
    /// Too narrow for things side by side: one above the other, scrolling.
    case stacked

    init(_ size: CGSize) {
        if size.width < Theme.Layout.narrowScreenWidth {
            self = .stacked
        } else if size.height < Theme.Layout.shortScreenHeight {
            self = .scrolling
        } else {
            self = .filling
        }
    }

    var scrolls: Bool { self != .filling }
}
