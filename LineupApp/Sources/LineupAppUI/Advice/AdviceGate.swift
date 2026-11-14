import LineupAppCore
import LineupEngine
import SwiftUI

/// An advisor screen's heading over the advice, or, while there is none, over what is missing or why the advisors
/// stopped, in the engine's sentences, with the button for the screen that puts it right, as Match Selection shows it.
/// While the advice is ready, the screen's own controls sit beside the heading, or under it when the row is narrow, and
/// one muted line under them says which day's import the advice rests on. A screen that draws its own heading row
/// asks for none: the controls and the import line then come first.
struct AdviceGate<Header: View, Content: View>: View {
    let screen: Screen
    let state: AdviceState
    /// The model's line naming the import day; nil while the advice is not ready.
    let importLine: String?
    /// Whether the gate writes the screen's title; false when the screen draws its own heading row.
    let showsHeading: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: (AdvisorsReport) -> Content

    init(screen: Screen, state: AdviceState, importLine: String?, showsHeading: Bool = true,
         @ViewBuilder header: @escaping () -> Header, @ViewBuilder content: @escaping (AdvisorsReport) -> Content) {
        self.screen = screen
        self.state = state
        self.importLine = importLine
        self.showsHeading = showsHeading
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if AdvicePresentation.report(state) != nil {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if showsHeading {
                        WrappingRow(alignment: .center, spacing: Theme.Spacing.m, pushesTrailing: false) {
                            BoardHeading(screen.title, size: Theme.TypeSize.title)
                                .padding(.trailing, Theme.Spacing.m)
                        } trailing: {
                            header()
                        }
                    } else {
                        header()
                    }
                    if let importLine {
                        AdviceImportLine(text: importLine)
                    }
                }
            } else if showsHeading {
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
    init(screen: Screen, state: AdviceState, importLine: String?, showsHeading: Bool = true,
         @ViewBuilder content: @escaping (AdvisorsReport) -> Content) {
        self.init(screen: screen, state: state, importLine: importLine, showsHeading: showsHeading,
                  header: { EmptyView() }, content: content)
    }
}

/// The muted line under an advisor screen's heading saying which day's import its figures come from.
struct AdviceImportLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.caption))
            .foregroundStyle(Theme.Colour.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}
