import LineupAppCore
import LineupEngine
import SwiftUI

/// The sheet that adds a fixture or changes one: its date, opponent, importance and tactic.
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
            Text(draft.isNew ? "Add a fixture" : "Change the fixture")
                .font(Theme.Typeface.title(Theme.TypeSize.step3))
            if let note = model.confirmedNote(for: draft) {
                Text(note)
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Form {
                DayPicker("Date", day: $draft.date)
                LabeledContent("Opponent") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        TextField("Opponent", text: $draft.opponent, prompt: Text("Who the match is against"))
                            .labelsHidden()
                        if let problem = draft.shownProblem {
                            MarkedText(problem, colour: Theme.Colour.amber)
                        }
                    }
                }
                Picker("Importance", selection: $draft.importance) {
                    ForEach(Importance.allCases, id: \.self) { importance in
                        Text(importance.displayName).tag(importance)
                    }
                }
                Picker("Tactic", selection: $draft.tacticID) {
                    Text(model.primaryTacticText).tag(UUID?.none)
                    ForEach(model.tactics) { stored in
                        Text(stored.tactic.name).tag(UUID?.some(stored.id))
                    }
                }
            }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: close)
                    .keyboardShortcut(.cancelAction)
                Button(draft.saveButtonTitle) {
                    draft.noteSaveAttempt()
                    if model.save(draft) != nil { close() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: Theme.Layout.fixtureEditorSize.width, height: Theme.Layout.fixtureEditorSize.height,
               alignment: .topLeading)
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
