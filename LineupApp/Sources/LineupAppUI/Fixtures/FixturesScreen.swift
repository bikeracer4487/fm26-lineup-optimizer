import LineupAppCore
import LineupEngine
import SwiftUI

/// The matches to plan for, in date order, and the game's current date that says which are still to play.
public struct FixturesScreen: View {
    let model: AppModel
    @State private var editing: EditorRequest?
    @State private var deleting: StoredFixture?

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(Screen.fixtures.title)
                .font(Theme.Typeface.title())
            TodayControl(model: model)
            if model.fixtures.isEmpty {
                EmptyState("No fixtures yet. Add the next few matches to get a plan.",
                           action: "Add fixture", perform: add)
                Spacer(minLength: 0)
            } else {
                HStack {
                    Button("Add fixture", action: add)
                    Spacer()
                }
                table
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editing) { request in
            FixtureEditor(model: model, draft: request.draft) { editing = nil }
        }
        .alert(deleting.map { "Delete the fixture against \($0.opponent)?" } ?? "", isPresented: isDeleting,
               presenting: deleting) { fixture in
            Button("Delete", role: .destructive) { model.deleteFixture(fixture.id) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its confirmed lineup is deleted with it.")
        }
    }

    private var table: some View {
        Table(model.fixtures) {
            TableColumn("Date") { fixture in
                Text(DayText.short(fixture.date))
            }
            .width(Theme.TableColumnWidth.fixtureDate)
            TableColumn("Opponent") { fixture in
                Text(fixture.opponent)
                    .help(fixture.opponent)
            }
            .width(min: Theme.TableColumnWidth.opponentMinimum, ideal: Theme.TableColumnWidth.opponentIdeal)
            TableColumn("Importance") { fixture in
                ImportanceBadge(fixture.importance)
            }
            .width(Theme.TableColumnWidth.importance)
            TableColumn("Tactic") { fixture in
                Text(model.tacticText(for: fixture))
            }
            .width(min: Theme.TableColumnWidth.tacticMinimum, ideal: Theme.TableColumnWidth.tacticIdeal)
            TableColumn("State") { fixture in
                stateText(model.state(of: fixture))
            }
            .width(Theme.TableColumnWidth.fixtureState)
            TableColumn("") { fixture in
                HStack(spacing: Theme.Spacing.s) {
                    Button("Edit") { editing = EditorRequest(draft: FixtureDraft(fixture)) }
                    Button("Delete") { delete(fixture) }
                }
            }
            .width(Theme.TableColumnWidth.fixtureActions)
        }
        .frame(minHeight: Theme.Layout.tableMinimumHeight, idealHeight: Theme.Layout.tableMinimumHeight, maxHeight: .infinity)
    }

    private func stateText(_ state: FixtureState) -> some View {
        Text(state.text)
            .foregroundStyle(stateColour(state))
    }

    private func stateColour(_ state: FixtureState) -> Color {
        switch state {
        case .toPlay: .primary
        case .confirmed: .secondary
        case .pastNotConfirmed: Theme.Colour.amber
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

/// One opening of the fixture editor.
private struct EditorRequest: Identifiable {
    let id = UUID()
    let draft: FixtureDraft
}

/// The game's current date, written out, with the day before, the day after and a date picker to change it.
struct TodayControl: View {
    let model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            Text("Today in the game: \(DayText.long(model.settings.currentDate))")
                .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
            Button("Day before") { model.moveToday(by: -1) }
            Button("Day after") { model.moveToday(by: 1) }
            DayPicker("Today in the game", day: today)
                .labelsHidden()
                .fixedSize()
        }
        .help("Fixtures before this day count as played.")
    }

    private var today: Binding<Day> {
        Binding(get: { model.settings.currentDate }, set: { day in
            var settings = model.settings
            settings.currentDate = day
            model.update(settings)
        })
    }
}
