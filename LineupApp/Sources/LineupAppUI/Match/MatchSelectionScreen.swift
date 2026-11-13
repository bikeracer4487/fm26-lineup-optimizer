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

/// The planned elevens for the saved fixtures: a strip of fixtures, the chosen one's team sheet on a pitch with the
/// selected pick's reasons beside it and who was left out, and the owner's controls.
public struct MatchSelectionScreen: View {
    let model: AppModel
    /// The fixture shown: the one clicked in the strip; after confirming, `MatchPresentation.fixtureAfterConfirming`;
    /// after unlocking, the unlocked one. While nil, or once it has left the plan, `MatchPresentation.initialFixture`.
    @State private var chosen: FixtureID?
    /// Holds only while its fixture is shown and the same player is in its slot (`MatchPresentation.selectedSlot`).
    @State private var selection: PickSelection?
    @State private var view: MatchView

    public init(model: AppModel, start: MatchStart = MatchStart()) {
        self.model = model
        _chosen = State(initialValue: start.fixture)
        _view = State(initialValue: start.view)
        var selection: PickSelection?
        if let slot = start.slot, case .ready(let plans) = model.planState,
           let plan = MatchPresentation.chosen(start.fixture, in: plans) {
            selection = MatchPresentation.selection(at: slot, in: plan)
        }
        _selection = State(initialValue: selection)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(Screen.matchSelection.title)
                .font(Theme.Typeface.title())
            if case .ready(let plans) = model.planState, !plans.isEmpty {
                ready(plans)
            } else if let notReady = MatchPresentation.notReady(model.planState) {
                NotReadyView(notReady: notReady)
                Spacer(minLength: 0)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private func ready(_ plans: [FixturePlan]) -> some View {
        let plan = MatchPresentation.chosen(chosen, in: plans)
        FixtureStrip(cells: plans.map(FixtureCell.init), chosen: plan?.id) { chosen = $0 }
        if let note = model.fitnessNote {
            MarkedText(note, colour: Theme.Colour.amber)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let plan {
            header(plan)
            switch view {
            case .teamSheet:
                FixtureBody(model: model, plan: plan, selection: $selection) { chosen = $0 }
            case .starts:
                StartsGridView(grid: model.startsGrid(for: plans), chosen: plan.id)
            }
        }
    }

    /// The view switch, the chosen match in words and its tactic, and confirming or why not.
    private func header(_ plan: FixturePlan) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.l) {
            Picker("View", selection: $view) {
                ForEach(MatchView.allCases, id: \.self) { view in
                    Text(view.title).tag(view)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(MatchPresentation.heading(plan))
                    .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                if let tactic = MatchPresentation.tacticLine(plan) {
                    Text(tactic)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                }
                if let deleted = MatchPresentation.deletedTacticLine(plan) {
                    Text(deleted)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Theme.Spacing.m)
            ConfirmControl(model: model, plan: plan) {
                if case .ready(let plans) = model.planState {
                    chosen = MatchPresentation.fixtureAfterConfirming(plan.id, in: plans)
                }
            }
        }
    }
}

/// "Confirm this lineup" for the next fixture to play, why not for a later one, and nothing otherwise.
struct ConfirmControl: View {
    let model: AppModel
    let plan: FixturePlan
    /// Called after the lineup is confirmed and the plan worked out again.
    let confirmed: () -> Void

    var body: some View {
        if model.canConfirm(plan.id) {
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                Button("Confirm this lineup") {
                    model.confirm(plan.id)
                    confirmed()
                }
                    .buttonStyle(.borderedProminent)
                Text(MatchPresentation.confirmExplanation)
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
            }
        } else if let why = model.whyNotConfirm(plan.id) {
            Text(why)
                .font(Theme.Typeface.text())
                .foregroundStyle(.secondary)
        }
    }
}

/// The chosen fixture below the header: its team sheet and detail, its confirmed eleven, or what a missed fixture
/// means.
struct FixtureBody: View {
    let model: AppModel
    let plan: FixturePlan
    @Binding var selection: PickSelection?
    /// Shows a fixture: after unlocking, this one.
    let choose: (FixtureID) -> Void
    @State private var unlocking = false
    @Environment(\.showScreen) private var showScreen

    var body: some View {
        switch plan.body {
        case .planned(let lineup, _):
            let selected = MatchPresentation.selectedSlot(selection, in: plan)
            HStack(alignment: .top, spacing: Theme.Spacing.l) {
                TeamSheet(tokens: model.tokens(for: plan), unfilled: lineup.unfilled, selected: selected) { slot in
                    selection = MatchPresentation.selection(at: slot, in: plan)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        if let slot = selected, let detail = model.pickDetail(at: slot, in: plan) {
                            PickDetailView(model: model, fixture: plan.id, detail: detail)
                        } else {
                            Text("Click a player on the pitch to see why he is in the eleven, or to change him.")
                                .font(Theme.Typeface.text())
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Divider()
                        LeftOutList(model: model, plan: plan, omissions: LeftOutRow.rows(lineup.omissions))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: Theme.Match.detailWidth)
            }
        case .confirmed:
            let tokens = model.tokens(for: plan)
            HStack(alignment: .top, spacing: Theme.Spacing.l) {
                TeamSheet(tokens: tokens, unfilled: [], selected: nil, showsKey: false)
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    if let line = MatchPresentation.confirmedLine(plan) {
                        Text(line)
                            .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                    }
                    Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.m, verticalSpacing: Theme.Spacing.xs) {
                        ForEach(tokens) { token in
                            GridRow {
                                Text(token.slotText)
                                    .font(Theme.Typeface.number(Theme.TypeSize.step1))
                                Text(token.name)
                                    .font(Theme.Typeface.text())
                            }
                        }
                    }
                    Button("Unlock") { unlocking = true }
                    Spacer(minLength: 0)
                }
                .frame(width: Theme.Match.detailWidth, alignment: .leading)
            }
            .alert("Unlock this lineup?", isPresented: $unlocking) {
                Button("Unlock") {
                    model.unlock(plan.id)
                    choose(plan.id)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The match will be planned again.")
            }
        case .missed:
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if let note = plan.missedNote {
                    MarkedText(note, colour: Theme.Colour.amber)
                }
                Button(MatchPresentation.goTo(.fixtures)) { showScreen(.fixtures) }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
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
                    .font(Theme.Typeface.text(Theme.TypeSize.step1))
                    .foregroundStyle(.secondary)
                ForEach(notReady.problems, id: \.self) { problem in
                    if notReady.isFailure {
                        Text(problem)
                            .font(Theme.Typeface.text())
                            .foregroundStyle(Theme.Colour.claret)
                    } else {
                        MarkedText(problem, colour: Theme.Colour.amber)
                    }
                }
                Button(notReady.action) { showScreen(notReady.screen) }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
        }
    }
}
