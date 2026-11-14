import LineupAppCore
import LineupEngine
import SwiftUI

/// The squad as last imported from FMRTE: the three imports as cards on the board with what the last one did on a
/// note beside them, then the squad table with its filter and search. The whole screen scrolls, the table's headings
/// staying in view; when the board is narrower than the table, the table scrolls sideways and its headings go with it.
public struct SquadScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation
    @State private var fitsTable = true
    @Environment(\.showScreen) private var showScreen

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        if model.players.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                ImportPanel(model: model)
                BoardHeading(Screen.squad.title, size: Theme.TypeSize.title)
                EmptyState("No squad yet. Copy your first team in FMRTE, then import it here.")
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView(.vertical) {
                if fitsTable {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        top
                        Section {
                            PlayerTable.Rows(rows: rows, sort: navigation.squadSort)
                        } header: {
                            PlayerTable.Headings(sort: $navigation.squadSort)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        top
                        ScrollView(.horizontal) {
                            VStack(alignment: .leading, spacing: 0) {
                                PlayerTable.Headings(sort: $navigation.squadSort)
                                PlayerTable.Rows(rows: rows, sort: navigation.squadSort)
                            }
                            .frame(width: PlayerTable.leastWidth)
                        }
                    }
                }
            }
            .onGeometryChange(for: Bool.self) { $0.size.width >= PlayerTable.leastWidth } action: { fitsTable = $0 }
        }
    }

    private var rows: [SquadRow] {
        model.squadRows(in: navigation.squadShown, matching: navigation.squadSearch)
    }

    /// Everything above the table.
    private var top: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            ImportPanel(model: model)
            warnings
            titleRow
        }
        .padding(.bottom, Theme.Spacing.m)
    }

    /// The club when it is not known, with the way to set it, and the squad's warnings, on a pink note.
    @ViewBuilder private var warnings: some View {
        let listed = model.listedSquadWarnings
        if model.clubLine.needsSettings || !listed.isEmpty {
            WarningNote(tilt: NoteTilt.degrees(at: 1)) {
                if model.clubLine.needsSettings {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                        Text(model.clubLine.text)
                            .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Set your club's name") { showScreen(.settings) }
                            .buttonStyle(.onNote)
                    }
                }
                ForEach(listed, id: \.self) { warning in
                    Text(warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: Theme.Sticky.noticeMaximumWidth, alignment: .leading)
        }
    }

    /// The title, the squads to show, and the search.
    private var titleRow: some View {
        WrappingRow(alignment: .center, spacing: Theme.Spacing.m) {
            BoardHeading(Screen.squad.title, size: Theme.TypeSize.title)
                .padding(.trailing, Theme.Spacing.m)
            BoardTabs(choices: [(Squad?.none, "All squads")] + Squad.allCases.map { (Squad?.some($0), $0.displayName) },
                      selection: $navigation.squadShown)
        } trailing: {
            HStack(spacing: Theme.Spacing.s) {
                Text("Find")
                    .foregroundStyle(Theme.Colour.mutedInk)
                TextField("Find", text: $navigation.squadSearch, prompt: Text("A player's name"))
                    .labelsHidden()
                    .boardField()
                    .frame(width: Theme.Layout.searchFieldWidth)
            }
        }
    }
}
