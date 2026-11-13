import LineupAppCore
import LineupEngine
import SwiftUI

/// Where Match Selection starts: which fixture is chosen, which pick is selected and which view is shown. The app
/// starts with the defaults; the pictures choose.
public struct MatchStart: Sendable {
    public var fixture: FixtureID?
    public var slot: SlotID?
    public var view: MatchView

    public init(fixture: FixtureID? = nil, slot: SlotID? = nil, view: MatchView = .teamSheet) {
        self.fixture = fixture; self.slot = slot; self.view = view
    }
}

/// The planned elevens for the saved fixtures: the fixtures as sticky notes across the top, the chosen one's eleven
/// as magnets on a pitch with the selected pick's reasons written beside it and who was left out, and the owner's
/// controls. What is chosen is kept in the window's navigation, so it survives a change of screen. On a short window
/// the screen scrolls; on a narrow one the detail goes under the pitch.
public struct MatchSelectionScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation
    @State private var layout = PageLayout(Theme.Layout.defaultWindow)

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    /// The team sheet scrolls with the screen when it does not fit; the starts grid scrolls on its own.
    private var scrolls: Bool { layout.scrolls && navigation.matchView == .teamSheet }

    public var body: some View {
        Group {
            if scrolls {
                ScrollView(.vertical) { page }
            } else {
                page
            }
        }
        .onGeometryChange(for: PageLayout.self) { PageLayout($0.size) } action: { layout = $0 }
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if case .ready(let plans) = model.planState, !plans.isEmpty {
                ready(plans)
            } else if let notReady = MatchPresentation.notReady(model.planState) {
                BoardHeading(Screen.matchSelection.title, size: Theme.TypeSize.title)
                NotReadyView(notReady: notReady)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: scrolls ? nil : .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func ready(_ plans: [FixturePlan]) -> some View {
        let plan = MatchPresentation.chosen(navigation.matchFixture, in: plans)
        FixtureStrip(cells: plans.map(FixtureCell.init), chosen: plan?.id) { navigation.matchFixture = $0 }
        if let note = model.fitnessNote {
            CautionLine(note)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let plan {
            header(plan)
            switch navigation.matchView {
            case .teamSheet:
                FixtureBody(model: model, plan: plan, layout: layout, selection: $navigation.matchSelection) {
                    navigation.matchFixture = $0
                }
            case .starts:
                StartsGridView(grid: model.startsGrid(for: plans), chosen: plan.id)
            }
        }
    }

    /// The chosen match in words and its tactic, the view switch, and confirming or why not; the confirming goes under
    /// the rest when the row is too narrow for it.
    private func header(_ plan: FixturePlan) -> some View {
        WrappingRow(alignment: .top, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                BoardHeading(MatchPresentation.heading(plan))
                if let tactic = MatchPresentation.tacticLine(plan) {
                    Text(tactic)
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
                if let deleted = MatchPresentation.deletedTacticLine(plan) {
                    CautionLine(deleted)
                }
            }
            BoardTabs(choices: MatchView.allCases.map { ($0, $0.title) }, selection: $navigation.matchView)
        } trailing: {
            ConfirmControl(model: model, plan: plan) {
                if case .ready(let plans) = model.planState {
                    navigation.matchFixture = MatchPresentation.fixtureAfterConfirming(plan.id, in: plans)
                }
            }
        }
    }
}

/// The button that confirms the next fixture to play or a missed fixture's remembered eleven, why a later fixture
/// cannot be confirmed yet, and nothing otherwise.
struct ConfirmControl: View {
    let model: AppModel
    let plan: FixturePlan
    /// Called after the fixture is confirmed and the plan worked out again.
    let confirmed: () -> Void

    var body: some View {
        if model.canConfirm(plan.id) {
            let button = MatchPresentation.confirmButton(for: plan)
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                Text(button.explanation)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: Theme.Match.confirmExplanationWidth, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                Button(button.title) {
                    model.confirm(plan.id)
                    confirmed()
                }
                .buttonStyle(.main)
            }
        } else if let why = model.whyNotConfirm(plan.id) {
            Text(why)
                .font(Theme.Typeface.text(Theme.TypeSize.caption))
                .foregroundStyle(Theme.Colour.mutedInk)
                .frame(maxWidth: Theme.Match.detailMinimumWidth, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The pitch and what goes with it, laid out for the screen: beside it in a column of its own that scrolls when the
/// screen fills the window; beside it, scrolling with the screen, when the screen is short; under it when narrow.
struct PitchBeside<Pitch: View, Detail: View>: View {
    let layout: PageLayout
    @ViewBuilder let pitch: () -> Pitch
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        switch layout {
        case .filling:
            HStack(alignment: .top, spacing: Theme.Match.pitchGap) {
                // Offered first, so it takes the largest size its shape allows and the detail has the rest.
                pitch()
                    .layoutPriority(1)
                ScrollView {
                    detail()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, Theme.Spacing.xs)
                }
                .frame(minWidth: Theme.Match.detailMinimumWidth, maxWidth: .infinity)
            }
        case .scrolling:
            HStack(alignment: .top, spacing: Theme.Match.pitchGap) {
                pitch()
                    .frame(maxWidth: Theme.Pitch.scrollingMaximumWidth)
                    .layoutPriority(1)
                detail()
                    .frame(minWidth: Theme.Match.detailMinimumWidth, maxWidth: .infinity, alignment: .leading)
            }
        case .stacked:
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                pitch()
                    .frame(maxWidth: Theme.Pitch.scrollingMaximumWidth)
                detail()
                    .frame(maxWidth: Theme.Match.stackedDetailWidth, alignment: .leading)
            }
        }
    }
}

/// A slot of a missed fixture's remembered eleven whose starter is being chosen.
private struct RememberedSlot: Identifiable {
    let slot: SlotID
    var id: SlotID { slot }
}

/// The chosen fixture below the header: its team sheet and detail, its confirmed eleven, or a missed fixture's
/// remembered eleven to put right, or what a missed fixture with none means.
struct FixtureBody: View {
    let model: AppModel
    let plan: FixturePlan
    let layout: PageLayout
    @Binding var selection: PickSelection?
    /// Shows a fixture: after unlocking, this one.
    let choose: (FixtureID) -> Void
    @State private var unlocking = false
    @State private var choosingStarter: RememberedSlot?
    @Environment(\.showScreen) private var showScreen

    var body: some View {
        switch plan.body {
        case .planned(let lineup, _):
            let selected = MatchPresentation.selectedSlot(selection, in: plan)
            PitchBeside(layout: layout) {
                TeamSheet(tokens: model.tokens(for: plan), unfilled: lineup.unfilled, selected: selected) { slot in
                    selection = MatchPresentation.selection(at: slot, in: plan)
                }
            } detail: {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    if let slot = selected, let detail = model.pickDetail(at: slot, in: plan) {
                        PickDetailView(model: model, fixture: plan.id, detail: detail) { selection = $0 }
                    } else {
                        Text("Click a player on the pitch to see why he is in the eleven, or to change him.")
                            .font(Theme.Typeface.text(Theme.TypeSize.noteHeading))
                            .foregroundStyle(Theme.Colour.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    LeftOutList(model: model, plan: plan, omissions: LeftOutRow.rows(lineup.omissions))
                    MarkKey()
                }
            }
        case .confirmed:
            let tokens = model.tokens(for: plan)
            PitchBeside(layout: layout) {
                TeamSheet(tokens: tokens, unfilled: [], selected: nil)
            } detail: {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    if let line = MatchPresentation.confirmedLine(plan) {
                        BoardHeading(line)
                    }
                    NamesBySlot(tokens: tokens)
                    Button("Unlock") { unlocking = true }
                        .buttonStyle(.secondary)
                }
            }
            .alert(model.unlockNote(for: plan.id), isPresented: $unlocking) {
                Button("Unlock") {
                    model.unlock(plan.id)
                    choose(plan.id)
                }
                Button("Cancel", role: .cancel) {}
            }
        case .missed(.some):
            let tokens = model.tokens(for: plan)
            PitchBeside(layout: layout) {
                TeamSheet(tokens: tokens, unfilled: [], selected: choosingStarter?.slot,
                          select: { choosingStarter = RememberedSlot(slot: $0) })
            } detail: {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    if let note = plan.missedNote {
                        CautionLine(note)
                    }
                    Text(MatchPresentation.rememberedHint)
                        .foregroundStyle(Theme.Colour.mutedInk)
                    NamesBySlot(tokens: tokens)
                }
            }
            .sheet(item: $choosingStarter) { choice in
                CandidatePicker(text: PickerText.remembered(choice.slot),
                                rows: model.rememberedCandidateRows(for: choice.slot, in: plan.id)) { player in
                    model.setRemembered(player, at: choice.slot, in: plan.id)
                    choosingStarter = nil
                } cancel: {
                    choosingStarter = nil
                }
            }
        case .missed(.none):
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if let note = plan.missedNote {
                    CautionLine(note)
                }
                Button(MatchPresentation.goTo(.fixtures)) { showScreen(.fixtures) }
                    .buttonStyle(.primary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
        }
    }
}

/// Each starter's slot and full name, in slot order, his magnet before them.
struct NamesBySlot: View {
    let tokens: [TokenContent]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.m, verticalSpacing: Theme.Spacing.s) {
            ForEach(tokens) { token in
                GridRow {
                    Magnet.table(token.line)
                    Text(token.slotText)
                        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    Text(token.name)
                        .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                }
            }
        }
    }
}

/// What is missing before a plan can be made, or why it stopped, with the button to the screen that fixes it.
struct NotReadyView: View {
    let notReady: NotReady
    @Environment(\.showScreen) private var showScreen

    var body: some View {
        if notReady.problems.isEmpty {
            EmptyState(notReady.message, action: notReady.action) { showScreen(notReady.screen) }
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(notReady.message)
                    .font(Theme.Typeface.text(Theme.TypeSize.noteHeading))
                    .foregroundStyle(Theme.Colour.mutedInk)
                ForEach(notReady.problems, id: \.self) { problem in
                    if notReady.isFailure {
                        Text(problem)
                            .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                            .foregroundStyle(Theme.Colour.redText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        CautionLine(problem)
                    }
                }
                Button(notReady.action) { showScreen(notReady.screen) }
                    .buttonStyle(.primary)
            }
            .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
        }
    }
}
