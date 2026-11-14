import LineupAppCore
import LineupEngine
import SwiftUI

/// An advisor screen's heading over the advice, or, while there is none, over what is missing or why the advisors
/// stopped, in the engine's sentences, with the button for the screen that puts it right, as Match Selection shows it.
/// While the advice is ready, the screen's own controls sit beside the heading, or under it when the row is narrow.
struct AdviceGate<Header: View, Content: View>: View {
    let screen: Screen
    let state: AdviceState
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: (AdvisorsReport) -> Content

    init(screen: Screen, state: AdviceState, @ViewBuilder header: @escaping () -> Header,
         @ViewBuilder content: @escaping (AdvisorsReport) -> Content) {
        self.screen = screen
        self.state = state
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if AdvicePresentation.report(state) != nil {
                WrappingRow(alignment: .center, spacing: Theme.Spacing.m, pushesTrailing: false) {
                    BoardHeading(screen.title, size: Theme.TypeSize.title)
                        .padding(.trailing, Theme.Spacing.m)
                } trailing: {
                    header()
                }
            } else {
                BoardHeading(screen.title, size: Theme.TypeSize.title)
            }
            if let notReady = AdvicePresentation.notReady(state) {
                NotReadyView(notReady: notReady)
            } else if let report = AdvicePresentation.report(state) {
                content(report)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension AdviceGate where Header == EmptyView {
    init(screen: Screen, state: AdviceState, @ViewBuilder content: @escaping (AdvisorsReport) -> Content) {
        self.init(screen: screen, state: state, header: { EmptyView() }, content: content)
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
