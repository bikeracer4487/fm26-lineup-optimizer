import LineupAppCore
import LineupEngine
import SwiftUI

/// An advisor screen's heading over the advice, or, while there is none, over what is missing or why the advisors
/// stopped, in the engine's sentences, with the button for the screen that puts it right, as Match Selection shows it.
struct AdviceGate<Content: View>: View {
    let screen: Screen
    let state: AdviceState
    @ViewBuilder let content: (AdvisorsReport) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            BoardHeading(screen.title, size: Theme.TypeSize.title)
            if let notReady = AdvicePresentation.notReady(state) {
                NotReadyView(notReady: notReady)
            } else if let report = AdvicePresentation.report(state) {
                content(report)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// One muted line saying the advice is worked out, until the screen shows the advice itself.
struct AdviceReadyLine: View {
    let model: AppModel

    var body: some View {
        if let line = model.adviceLine {
            Text(line)
                .font(Theme.Typeface.text(Theme.TypeSize.body))
                .foregroundStyle(Theme.Colour.mutedInk)
        }
    }
}
