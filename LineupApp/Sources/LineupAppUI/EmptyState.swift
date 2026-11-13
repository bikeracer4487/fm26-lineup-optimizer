import SwiftUI

/// What a screen shows when it has nothing to show: a sentence saying what is missing and,
/// when there is one, the button that fixes it.
public struct EmptyState: View {
    let message: String
    let action: String?
    let perform: (() -> Void)?

    public init(_ message: String, action: String? = nil, perform: (() -> Void)? = nil) {
        self.message = message
        self.action = action
        self.perform = perform
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(message)
                .font(Theme.Typeface.text(Theme.TypeSize.step1))
                .foregroundStyle(.secondary)
            if let action, let perform {
                Button(action, action: perform)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colour.hoopBlue)
            }
        }
        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
    }
}
