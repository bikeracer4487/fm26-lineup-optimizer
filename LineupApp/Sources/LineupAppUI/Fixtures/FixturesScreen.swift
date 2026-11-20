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
/// the owner's; a click on it shows its reasons under the row, one fixture's at a time, and "Use it" under it takes it.
/// While there are fixtures, the league situation's menu sits at the heading's trailing edge. The table opens scrolled
/// so the next match with no lineup confirmed is in the middle. Matches from before the days the advice reads are left
/// out, and a line under the column headings says how many, with a button to show them. The rows always fit the board:
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
                if !model.fixtures.isEmpty {
                    Spacer(minLength: 0)
                    situationMenu
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

    /// Where the club stands in the league, as the editor's menus are drawn: a small muted label, then the menu.
    private var situationMenu: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(AppModel.leagueSituationLabel)
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize()
            Picker(AppModel.leagueSituationLabel,
                   selection: Binding(get: { model.leagueSituationSelection }, set: { model.setLeagueSituation($0) })) {
                ForEach(model.leagueSituationChoices, id: \.value) { choice in
                    Text(choice.title).tag(choice.value)
                }
            }
            .labelsHidden()
            .fixedSize()
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
            if let line = model.earlierMatchesLine {
                EarlierMatchesNote(line: line) { model.setShowsEarlierMatches(line.showsWhenPressed) }
                FaintRule()
            }
            // The rows open with the next match in the middle, so the matches already played are above it; when
            // another becomes the next match they scroll only as far as it takes to show it.
            ScrollViewReader { scroller in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(model.listedFixtures.enumerated()), id: \.element.id) { index, fixture in
                            VStack(alignment: .leading, spacing: 0) {
                                row(fixture, index: index, actionsBeside: actionsBeside)
                                FaintRule()
                            }
                            .id(fixture.id)
                        }
                    }
                }
                .onAppear {
                    if let next = model.nextMatch?.id { scroller.scrollTo(next, anchor: .center) }
                }
                .onChange(of: model.nextMatch?.id) { _, next in
                    if let next { withAnimation { scroller.scrollTo(next) } }
                }
            }
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
    }

    private func row(_ fixture: StoredFixture, index: Int, actionsBeside: Bool) -> some View {
        FixtureRow(model: model, navigation: navigation, fixture: fixture, index: index, actionsBeside: actionsBeside,
                   edit: { navigation.fixtureEditing = FixtureEditing(draft: model.fixtureDraft(for: fixture)) },
                   delete: { delete(fixture) })
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

/// One fixture's row: date, opponent, importance with the suggestion under it, tactic, state and, when they fit, Edit
/// and Delete. A suggestion's reasons, once shown, sit under the row starting at the importance note's left edge and
/// wrap before the row's end; where that leaves too little room they take the row's whole width.
private struct FixtureRow: View {
    let model: AppModel
    let navigation: Navigation
    let fixture: StoredFixture
    let index: Int
    let actionsBeside: Bool
    let edit: () -> Void
    let delete: () -> Void
    /// Where the importance column starts in the row, and the row's width, as last laid out.
    @State private var importanceLeading: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    private nonisolated static let space = "fixture row"

    var body: some View {
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
                        SuggestionLine(note: suggestion, shown: showsReasons,
                                       offersUseIt: model.offersUseIt(for: fixture,
                                                                      editing: navigation.fixtureEditing?.draft.id),
                                       useItLabel: SuggestionNote.useItLabel(opponent: fixture.opponent),
                                       toggle: { navigation.toggleReasons(of: fixture.id) },
                                       use: { model.useSuggestion(for: fixture.id) })
                    }
                }
                .padding(.trailing, Theme.Spacing.s)
                .frame(width: Theme.Column.importance, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).minX } action: {
                    importanceLeading = $0
                }
                Text(model.tacticText(for: fixture))
                    .lineLimit(Theme.Table.wrappedLines)
                    .padding(.trailing, Theme.Spacing.s)
                    .frame(minWidth: Theme.Column.tacticMinimum, maxWidth: .infinity, alignment: .leading)
                stateText(model.state(of: fixture))
                    .lineLimit(Theme.Table.wrappedLines)
                    .frame(width: Theme.Column.fixtureState, alignment: .leading)
                if actionsBeside {
                    actions
                        .frame(width: Theme.Column.fixtureActions, alignment: .trailing)
                }
            }
            if let suggestion, showsReasons {
                SuggestionReasons(note: suggestion)
                    .padding(.leading, reasonsLeading)
                    .padding(.bottom, Theme.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !actionsBeside {
                actions
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .frame(minHeight: Theme.Table.rowHeight + Theme.Spacing.s)
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
    }

    /// The importance note's left edge, unless the reasons would then have less than their least width.
    private var reasonsLeading: CGFloat {
        rowWidth - importanceLeading >= Theme.Column.suggestionReasonsMinimum ? importanceLeading : 0
    }

    private var actions: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button("Edit", action: edit)
            Button("Delete", action: delete)
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
}

/// How many earlier matches the table leaves out, or is showing, in muted ink, with "Show" or "Hide" beside it written
/// in ink and underlined, as "Use it" is. It stands under the column headings and does not scroll with the rows.
private struct EarlierMatchesNote: View {
    let line: EarlierMatchesLine
    let press: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Text(line.text)
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            Button(line.action, action: press)
                .buttonStyle(.onNote)
                .foregroundStyle(Theme.Colour.ink)
                .fixedSize()
                .accessibilityLabel(line.actionLabel)
            Spacer(minLength: 0)
        }
        .frame(minHeight: Theme.Table.headingHeight)
    }
}

/// "Suggested: High" in muted ink with a mark saying whether its reasons are shown, a click on it showing or hiding
/// them; then, when offered, "Use it" written in ink and underlined, a button of its own that takes the suggestion.
/// "Use it" goes under the line, at its left edge: beside it there is no room in the importance column for even the
/// shortest suggestion, and every row then shows it in the same place.
private struct SuggestionLine: View {
    let note: SuggestionNote
    let shown: Bool
    let offersUseIt: Bool
    let useItLabel: String
    let toggle: () -> Void
    let use: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            line
            if offersUseIt {
                useIt
            }
        }
    }

    private var useIt: some View {
        Button(SuggestionNote.useItTitle, action: use)
            .buttonStyle(.onNote)
            .foregroundStyle(Theme.Colour.ink)
            .fixedSize()
            .accessibilityLabel(useItLabel)
    }

    private var line: some View {
        Button(action: toggle) {
            // The mark is part of the text, after a space that does not break, so when "Suggested: Sharpness" wraps
            // the mark stays with the last word.
            Text("\(note.text)\u{00A0}\(mark)")
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Theme.Colour.mutedInk)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(SuggestionNote.clickHelp(shown))
        .accessibilityHint(SuggestionNote.clickHelp(shown))
    }

    /// Whether the reasons are shown: a chevron down when they are, else right.
    private var mark: Text {
        Text(Image(systemName: shown ? "chevron.down" : "chevron.right"))
            .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .bold))
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

