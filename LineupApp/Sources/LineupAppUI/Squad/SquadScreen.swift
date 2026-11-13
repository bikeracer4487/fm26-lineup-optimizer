import LineupAppCore
import LineupEngine
import SwiftUI

/// The squad as last imported from FMRTE: the import buttons, the club, and a table of every player.
public struct SquadScreen: View {
    let model: AppModel
    @State private var squadShown: Squad?
    @State private var search = ""
    @Environment(\.showScreen) private var showScreen

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(Screen.squad.title)
                .font(Theme.Typeface.title())
            ImportPanel(model: model)
            if model.players.isEmpty {
                EmptyState("No squad yet. Copy your first team in FMRTE, then import it here.")
                Spacer(minLength: 0)
            } else {
                club
                filters
                PlayerTable(rows: model.squadRows(in: squadShown, matching: search))
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var club: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            switch model.clubLine {
            case .known:
                Text(model.clubLine.text)
                    .font(Theme.Typeface.text(weight: .semibold))
            case .unknown:
                HStack(alignment: .center, spacing: Theme.Spacing.m) {
                    MarkedText(model.clubLine.text, colour: Theme.Colour.amber)
                        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
                    Button("Set your club's name") { showScreen(.settings) }
                }
            }
            ForEach(model.listedSquadWarnings, id: \.self) { warning in
                MarkedText(warning, colour: Theme.Colour.amber)
                    .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
            }
        }
    }

    private var filters: some View {
        HStack(spacing: Theme.Spacing.m) {
            Picker("Squad", selection: $squadShown) {
                Text("All squads").tag(Squad?.none)
                ForEach(Squad.allCases, id: \.self) { squad in
                    Text(squad.displayName).tag(Squad?.some(squad))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            TextField("Search by name", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(width: Theme.Layout.searchFieldWidth)
        }
    }
}
