import LineupAppCore
import LineupEngine
import SwiftUI

/// How much a fixture matters, in its colour: claret for high, amber for medium, the system's grey for low and teal
/// for sharpness.
public struct ImportanceBadge: View {
    let importance: Importance

    public init(_ importance: Importance) {
        self.importance = importance
    }

    public var body: some View {
        let colour = Self.colour(of: importance)
        Text(importance.displayName)
            .font(Theme.Typeface.text(weight: .semibold))
            .foregroundStyle(colour)
            .padding(.horizontal, Theme.Badge.horizontalPadding)
            .padding(.vertical, Theme.Badge.verticalPadding)
            .background(colour.opacity(Theme.Badge.fillOpacity),
                        in: RoundedRectangle(cornerRadius: Theme.Badge.cornerRadius))
    }

    static func colour(of importance: Importance) -> Color {
        switch importance {
        case .high: Theme.Colour.claret
        case .medium: Theme.Colour.amber
        case .low: Theme.Colour.lowImportance
        case .sharpness: Theme.Colour.teal
        }
    }
}
