import LineupAppCore
import LineupEngine
import SwiftUI

/// The card on the board that adds a fixture or changes one: its date, opponent, importance and tactic.
struct FixtureEditor: View {
    let model: AppModel
    @State private var draft: FixtureDraft
    let close: () -> Void

    init(model: AppModel, draft: FixtureDraft, close: @escaping () -> Void) {
        self.model = model
        _draft = State(initialValue: draft)
        self.close = close
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            BoardHeading(draft.isNew ? "Add a fixture" : "Change the fixture", size: Theme.TypeSize.boardTitle)
            if let note = model.confirmedNote(for: draft) {
                Text(note)
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Theme.Spacing.l,
                 verticalSpacing: Theme.Spacing.m) {
                GridRow {
                    label("Date")
                    DayPicker("Date", day: $draft.date)
                        .labelsHidden()
                        .fixedSize()
                }
                GridRow {
                    label("Opponent")
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        TextField("Opponent", text: $draft.opponent, prompt: Text("Who the match is against"))
                            .labelsHidden()
                            .boardField()
                        if let problem = draft.shownProblem {
                            CautionLine(problem)
                        }
                    }
                }
                GridRow {
                    label("Importance")
                    BoardTabs(choices: Importance.allCases.map { ($0, $0.displayName) }, selection: $draft.importance)
                }
                GridRow {
                    label("Tactic")
                    Picker("Tactic", selection: $draft.tacticID) {
                        Text(model.primaryTacticText).tag(UUID?.none)
                        ForEach(model.tactics) { stored in
                            Text(stored.tactic.name).tag(UUID?.some(stored.id))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            HStack(spacing: Theme.Spacing.s) {
                Spacer()
                Button("Cancel", role: .cancel, action: close)
                    .buttonStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                Button(draft.saveButtonTitle) {
                    draft.noteSaveAttempt()
                    if model.save(draft) != nil { close() }
                }
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Card.padding + Theme.Spacing.xs)
        .frame(width: Theme.Layout.fixtureEditorWidth, alignment: .topLeading)
        .boardCard()
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
            .gridColumnAlignment(.leading)
    }
}

/// A date picker for an engine `Day`, shown in the calendar `DayDate` converts with, so the day it shows is the day
/// saved whatever the Mac's time zone: a field, or a calendar when `graphical`.
struct DayPicker: View {
    let title: String
    @Binding var day: Day
    let graphical: Bool

    init(_ title: String, day: Binding<Day>, graphical: Bool = false) {
        self.title = title
        _day = day
        self.graphical = graphical
    }

    var body: some View {
        Group {
            if graphical {
                picker.datePickerStyle(.graphical)
            } else {
                picker.datePickerStyle(.field)
            }
        }
        .tint(Theme.Colour.markerBlue)
        .environment(\.calendar, DayDate.calendar)
        .environment(\.timeZone, DayDate.calendar.timeZone)
    }

    private var picker: some View {
        DatePicker(title, selection: Binding(get: { DayDate.date(day) }, set: { day = DayDate.day($0) }),
                   displayedComponents: .date)
    }
}
