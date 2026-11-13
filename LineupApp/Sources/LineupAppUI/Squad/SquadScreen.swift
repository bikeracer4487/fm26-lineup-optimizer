import LineupAppCore
import LineupEngine
import SwiftUI

/// The squad as last imported from FMRTE: the game's date each import is dated with, the import buttons, the club,
/// and a table of every player.
public struct SquadScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation
    @Environment(\.showScreen) private var showScreen

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(Screen.squad.title)
                .font(Theme.Typeface.title())
            TodayControl(model: model, caption: ImportReport.datingLine)
            ImportPanel(model: model)
            if model.players.isEmpty {
                EmptyState("No squad yet. Copy your first team in FMRTE, then import it here.")
                Spacer(minLength: 0)
            } else {
                club
                filters
                PlayerTable(rows: model.squadRows(in: navigation.squadShown, matching: navigation.squadSearch))
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
            Picker("Squad", selection: $navigation.squadShown) {
                Text("All squads").tag(Squad?.none)
                ForEach(Squad.allCases, id: \.self) { squad in
                    Text(squad.displayName).tag(Squad?.some(squad))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            TextField("Search by name", text: $navigation.squadSearch)
                .textFieldStyle(.roundedBorder)
                .frame(width: Theme.Layout.searchFieldWidth)
        }
    }
}
