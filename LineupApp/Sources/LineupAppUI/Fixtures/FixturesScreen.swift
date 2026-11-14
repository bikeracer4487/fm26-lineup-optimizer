import LineupAppCore
import LineupEngine
import SwiftUI

/// How the Fixtures screen opens: with no fixture's reasons shown, or with one fixture's.
public struct FixturesStart: Sendable {
    public var reasonsOf: FixtureID?

    public init(reasonsOf: FixtureID? = nil) {
        self.reasonsOf = reasonsOf
    }
}

/// The matches to plan for, in date order, as rows on the board with a small sticky note for each one's importance;
/// the editor for adding or changing one is a card on the board above them, its draft kept in the window's navigation
/// so it survives a change of screen. Under a fixture's note, the importance the advice suggests when it differs from
/// the owner's; a click on it shows its reasons under the row, one fixture's at a time. The rows always fit the board:
/// the opponent, tactic, state and suggestion wrap, and when there is still no room, Edit and Delete go on a line of
/// their own under each fixture.
public struct FixturesScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation
    @State private var deleting: StoredFixture?

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .center, spacing: Theme.Spacing.l) {
                BoardHeading(Screen.fixtures.title, size: Theme.TypeSize.title)
                if !model.fixtures.isEmpty && navigation.fixtureEditing == nil {
                    Button("Add fixture", action: add)
                        .buttonStyle(.primary)
                }
            }
            if let editing = navigation.fixtureEditing {
                FixtureEditor(model: model, draft: draftBinding(editing)) { navigation.fixtureEditing = nil }
                    .id(editing.id)
            }
            if model.fixtures.isEmpty {
                if navigation.fixtureEditing == nil {
                    EmptyState("No fixtures yet. Add the next few matches to get a plan.",
                               action: "Add fixture", perform: add)
                }
                Spacer(minLength: 0)
            } else {
                table
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(deleting.map { "Delete the fixture against \($0.opponent)?" } ?? "", isPresented: isDeleting,
               presenting: deleting) { fixture in
            Button("Delete", role: .destructive) { model.deleteFixture(fixture.id) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its confirmed lineup is deleted with it.")
        }
    }

    /// The draft being edited, changed in the navigation.
    private func draftBinding(_ editing: FixtureEditing) -> Binding<FixtureDraft> {
        Binding(get: { navigation.fixtureEditing?.draft ?? editing.draft },
                set: { navigation.fixtureEditing?.draft = $0 })
    }

    /// The table with Edit and Delete in a column of their own when it fits the board, else under each fixture.
    private var table: some View {
        ViewThatFits(in: .horizontal) {
            rows(actionsBeside: true)
            rows(actionsBeside: false)
        }
        .frame(minHeight: Theme.Layout.tableMinimumHeight, maxHeight: .infinity, alignment: .top)
    }

    private func rows(actionsBeside: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                heading("Date").frame(width: Theme.Column.fixtureDate, alignment: .leading)
                heading("Opponent").frame(minWidth: Theme.Column.opponentMinimum, maxWidth: .infinity, alignment: .leading)
                heading("Importance").frame(width: Theme.Column.importance, alignment: .leading)
                heading("Tactic").frame(minWidth: Theme.Column.tacticMinimum, maxWidth: .infinity, alignment: .leading)
                heading("State").frame(width: Theme.Column.fixtureState, alignment: .leading)
                if actionsBeside {
                    Color.clear.frame(width: Theme.Column.fixtureActions, height: 0)
                }
            }
            .frame(height: Theme.Table.headingHeight)
            HeavyRule()
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.fixtures.enumerated()), id: \.element.id) { index, fixture in
                        row(fixture, index: index, actionsBeside: actionsBeside)
                        FaintRule()
                    }
                }
            }
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
    }

    private func row(_ fixture: StoredFixture, index: Int, actionsBeside: Bool) -> some View {
        let suggestion = model.suggestionLine(for: fixture)
        let showsReasons = suggestion != nil && navigation.showsReasons(of: fixture.id)
        return VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
            HStack(spacing: 0) {
                Text(DayText.short(fixture.date))
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading))
                    .frame(width: Theme.Column.fixtureDate, alignment: .leading)
                Text(fixture.opponent)
                    .lineLimit(Theme.Table.wrappedLines)
                    .help(fixture.opponent)
                    .padding(.trailing, Theme.Spacing.s)
                    .frame(minWidth: Theme.Column.opponentMinimum, maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ImportanceNote(importance: fixture.importance, tilt: NoteTilt.degrees(at: index))
                    if let suggestion {
                        SuggestionLine(note: suggestion, shown: showsReasons) {
                            navigation.toggleReasons(of: fixture.id)
                        }
                    }
                }
                .padding(.trailing, Theme.Spacing.s)
                .frame(width: Theme.Column.importance, alignment: .leading)
                Text(model.tacticText(for: fixture))
                    .lineLimit(Theme.Table.wrappedLines)
                    .padding(.trailing, Theme.Spacing.s)
                    .frame(minWidth: Theme.Column.tacticMinimum, maxWidth: .infinity, alignment: .leading)
                stateText(model.state(of: fixture))
                    .lineLimit(Theme.Table.wrappedLines)
                    .frame(width: Theme.Column.fixtureState, alignment: .leading)
                if actionsBeside {
                    actions(fixture)
                        .frame(width: Theme.Column.fixtureActions, alignment: .trailing)
                }
            }
            if let suggestion, showsReasons {
                SuggestionReasons(note: suggestion)
                    .padding(.leading, Theme.Column.fixtureDate)
                    .padding(.bottom, Theme.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !actionsBeside {
                actions(fixture)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .frame(minHeight: Theme.Table.rowHeight + Theme.Spacing.s)
    }

    private func actions(_ fixture: StoredFixture) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Button("Edit") { navigation.fixtureEditing = FixtureEditing(draft: model.fixtureDraft(for: fixture)) }
            Button("Delete") { delete(fixture) }
        }
        .buttonStyle(.secondary)
        .fixedSize()
    }

    private func stateText(_ state: FixtureState) -> some View {
        Text(state.text)
            .font(Theme.Typeface.text(Theme.TypeSize.body, weight: state == .pastNotConfirmed ? .bold : .regular))
            .foregroundStyle(stateColour(state))
    }

    private func stateColour(_ state: FixtureState) -> Color {
        switch state {
        case .toPlay: Theme.Colour.ink
        case .confirmed: Theme.Colour.mutedInk
        case .pastNotConfirmed: Theme.Colour.amberText
        }
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func add() {
        navigation.fixtureEditing = FixtureEditing(draft: model.newFixtureDraft())
    }

    private func delete(_ fixture: StoredFixture) {
        if model.asksBeforeDeleting(fixture) {
            deleting = fixture
        } else {
            model.deleteFixture(fixture.id)
        }
    }
}

/// "Suggested: High" in muted ink with a mark saying whether its reasons are shown; a click shows or hides them.
private struct SuggestionLine: View {
    let note: SuggestionNote
    let shown: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(note.text)
                    .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: shown ? "chevron.down" : "chevron.right")
                    .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .bold))
            }
            .foregroundStyle(Theme.Colour.mutedInk)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(SuggestionNote.clickHelp(shown))
    }
}

/// How much a fixture matters, on a small sticky note in its colour.
struct ImportanceNote: View {
    let importance: Importance
    let tilt: Double

    var body: some View {
        Text(importance.noteText)
            .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .stickyNote(Theme.Note.fixture(importance), tilt: tilt)
    }
}

