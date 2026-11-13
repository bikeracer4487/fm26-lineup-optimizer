import SwiftUI

/// Two groups of controls on one row when they fit across, the second pushed to the trailing edge or right after the
/// first; otherwise the second under the first, so a narrow window cuts nothing off.
struct WrappingRow<Leading: View, Trailing: View>: View {
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat = Theme.Spacing.m
    /// Whether the second group sits at the trailing edge when on one row.
    var pushesTrailing = true
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: alignment, spacing: spacing) {
                leading()
                if pushesTrailing {
                    Spacer(minLength: spacing)
                }
                trailing()
                if !pushesTrailing {
                    Spacer(minLength: 0)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(alignment: alignment, spacing: spacing) { leading() }
                HStack(alignment: alignment, spacing: spacing) { trailing() }
            }
        }
    }
}
