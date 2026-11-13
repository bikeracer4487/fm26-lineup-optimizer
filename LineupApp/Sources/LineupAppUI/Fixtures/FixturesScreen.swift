import LineupAppCore
import LineupEngine
import SwiftUI

/// The matches to plan for, in date order, as rows on the board with a small sticky note for each one's importance;
/// the editor for adding or changing one is a card on the board above them.
public struct FixturesScreen: View {
    let model: AppModel
    @State private var editing: EditorRequest?
    @State private var deleting: StoredFixture?

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .center, spacing: Theme.Spacing.l) {
                BoardHeading(Screen.fixtures.title, size: Theme.TypeSize.title)
                if !model.fixtures.isEmpty && editing == nil {
                    Button("Add fixture", action: add)
                        .buttonStyle(.primary)
                }
            }
            if let editing {
                FixtureEditor(model: model, draft: editing.draft) { self.editing = nil }
                    .id(editing.id)
            }
            if model.fixtures.isEmpty {
                if editing == nil {
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

    /// The table, scrolling sideways when the board is narrower than its columns.
    private var table: some View {
        ViewThatFits(in: .horizontal) {
            rows
            ScrollView(.horizontal) {
                rows.frame(width: Self.leastWidth)
            }
        }
        .frame(minHeight: Theme.Layout.tableMinimumHeight, maxHeight: .infinity, alignment: .top)
    }

    /// The width every column needs.
    static let leastWidth: CGFloat = {
        typealias C = Theme.Column
        return C.fixtureDate + C.opponentMinimum + C.importance + C.tacticMinimum + C.fixtureState + C.fixtureActions
    }()

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                heading("Date").frame(width: Theme.Column.fixtureDate, alignment: .leading)
                heading("Opponent").frame(minWidth: Theme.Column.opponentMinimum, maxWidth: .infinity, alignment: .leading)
                heading("Importance").frame(width: Theme.Column.importance, alignment: .leading)
                heading("Tactic").frame(minWidth: Theme.Column.tacticMinimum, maxWidth: .infinity, alignment: .leading)
                heading("State").frame(width: Theme.Column.fixtureState, alignment: .leading)
                Color.clear.frame(width: Theme.Column.fixtureActions, height: 0)
            }
            .frame(height: Theme.Table.headingHeight)
            HeavyRule()
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.fixtures.enumerated()), id: \.element.id) { index, fixture in
                        row(fixture, index: index)
                        FaintRule()
                    }
                }
            }
        }
        .frame(minWidth: Self.leastWidth)
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
    }

    private func row(_ fixture: StoredFixture, index: Int) -> some View {
        HStack(spacing: 0) {
            Text(DayText.short(fixture.date))
                .font(Theme.Typeface.display(Theme.TypeSize.noteHeading))
                .frame(width: Theme.Column.fixtureDate, alignment: .leading)
            Text(fixture.opponent)
                .lineLimit(1)
                .help(fixture.opponent)
                .frame(minWidth: Theme.Column.opponentMinimum, maxWidth: .infinity, alignment: .leading)
            ImportanceNote(importance: fixture.importance, tilt: NoteTilt.degrees(at: index))
                .frame(width: Theme.Column.importance, alignment: .leading)
            Text(model.tacticText(for: fixture))
                .lineLimit(1)
                .frame(minWidth: Theme.Column.tacticMinimum, maxWidth: .infinity, alignment: .leading)
            stateText(model.state(of: fixture))
                .frame(width: Theme.Column.fixtureState, alignment: .leading)
            HStack(spacing: Theme.Spacing.s) {
                Button("Edit") { editing = EditorRequest(draft: model.fixtureDraft(for: fixture)) }
                Button("Delete") { delete(fixture) }
            }
            .buttonStyle(.secondary)
            .frame(width: Theme.Column.fixtureActions, alignment: .trailing)
        }
        .frame(minHeight: Theme.Table.rowHeight + Theme.Spacing.s)
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
        editing = EditorRequest(draft: model.newFixtureDraft())
    }

    private func delete(_ fixture: StoredFixture) {
        if model.asksBeforeDeleting(fixture) {
            deleting = fixture
        } else {
            model.deleteFixture(fixture.id)
        }
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

/// One opening of the fixture editor.
private struct EditorRequest: Identifiable {
    let id = UUID()
    let draft: FixtureDraft
}
