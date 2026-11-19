import LineupAppCore
import LineupEngine
import SwiftUI

/// Where the Scouting screen starts: which tab, the order of the candidates, and whether every candidate's row and the
/// rest part are open. The app starts with the defaults; the pictures choose.
public struct ScoutingStart: Sendable {
    public var view: ScoutingView
    public var order: CandidateOrder
    public var allOpen: Bool

    public init(view: ScoutingView = .needs, order: CandidateOrder = .today, allOpen: Bool = false) {
        self.view = view; self.order = order; self.allOpen = allOpen
    }
}

/// What to look for in the market, and how pasted players would answer it: the tactic menu and the two tabs beside the
/// heading, the import line under them, then the chosen tab, scrolling down. All of it stands behind the advisor
/// screens' gate.
public struct ScoutingScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        ScrollView(.vertical) {
            AdviceGate(screen: .scouting, state: model.adviceState, importLine: model.adviceImportLine) {
                controls
            } content: { _ in
                Group {
                    switch navigation.scoutingView {
                    case .needs: ScoutingNeedsTab(model: model, navigation: navigation)
                    case .candidates: ScoutingCandidatesTab(model: model, navigation: navigation)
                    }
                }
                .frame(maxWidth: Theme.Scouting.columnMaximumWidth, alignment: .leading)
            }
            .padding(.bottom, Theme.Spacing.l)
        }
    }

    /// The tactic menu, as the Elevens screen's, and the two tabs.
    private var controls: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.l) {
            Picker(ElevensPresentation.tacticMenuLabel, selection: Binding(
                get: { model.scoutingTacticShown(navigation.scoutingTacticID) },
                set: { picked in navigation.scoutingTacticID = picked.flatMap(model.elevensTacticChoice) })) {
                ForEach(model.elevensTacticChoices, id: \.id) { choice in
                    Text(choice.title)
                        .tag(UUID?.some(choice.id))
                }
            }
            .font(Theme.Typeface.text())
            .fixedSize()
            BoardTabs(choices: ScoutingView.allCases.map { ($0, $0.title) }, selection: $navigation.scoutingView)
        }
    }
}

/// Why the needs, and so the candidates, cannot be worked out for the tactic shown: the engine's sentences.
struct ScoutingFailed: View {
    let problems: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(ScoutingPresentation.failedLead)
                .font(Theme.Typeface.text(Theme.TypeSize.noteHeading))
                .foregroundStyle(Theme.Colour.mutedInk)
            ForEach(problems, id: \.self) { CautionLine($0) }
        }
        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
    }
}

/// A slot's token: its magnet in its line's colour, or idle grey when muted, and "D L" beside it.
struct ScoutingSlotLabel: View {
    let slotText: String
    let line: PitchLine
    var isMuted = false

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            Magnet(fill: isMuted ? Theme.Colour.idleMagnet : Theme.Colour.magnet(line).fill,
                   diameter: Theme.Magnet.tableDiameter, shadowOffset: Theme.Magnet.tableShadowOffset,
                   shadowOpacity: Theme.Magnet.tableShadowOpacity)
                .accessibilityHidden(true)
            Text(slotText)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                .foregroundStyle(isMuted ? Theme.Colour.mutedInk : Theme.Colour.ink)
                .fixedSize()
        }
    }
}

/// A muted sentence that wraps.
struct ScoutingMutedLine: View {
    let text: String
    var size: CGFloat = Theme.TypeSize.body

    var body: some View {
        Text(text)
            .font(Theme.Typeface.text(size))
            .foregroundStyle(Theme.Colour.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}
