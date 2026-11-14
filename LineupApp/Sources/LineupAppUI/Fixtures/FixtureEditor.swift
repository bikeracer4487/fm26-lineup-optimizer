import LineupAppCore
import LineupEngine
import SwiftUI

/// The card on the board that adds a fixture or changes one: its date, opponent, the competition and how strong the
/// opponent is, importance and tactic. Under the importance, the importance the advice suggests for the fixture as it
/// is being edited, its reasons and evidence note, and "Use it" when it differs from the importance chosen.
struct FixtureEditor: View {
    let model: AppModel
    /// Held in the window's navigation, so a change of screen does not lose it.
    @Binding var draft: FixtureDraft
    let close: () -> Void

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
                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Theme.Spacing.m,
                             verticalSpacing: Theme.Spacing.xs) {
                            GridRow {
                                smallLabel(FixtureDraft.competitionLabel)
                                menu(FixtureDraft.competitionLabel, FixtureDraft.competitionChoices,
                                     selection: $draft.competition)
                            }
                            GridRow {
                                smallLabel(FixtureDraft.opponentStrengthLabel)
                                menu(FixtureDraft.opponentStrengthLabel, FixtureDraft.opponentChoices,
                                     selection: $draft.opponentStrength)
                            }
                        }
                        .padding(.top, Theme.Spacing.xs)
                    }
                }
                // Aligned at the top rather than by text baseline, which with the suggestion under the tabs leaves extra
                // room above the row; the label is as tall as a tab, so its word sits level with the tabs' words.
                GridRow(alignment: .top) {
                    label("Importance")
                        .frame(height: Theme.Tab.height)
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        BoardTabs(choices: Importance.allCases.map { ($0, $0.displayName) }, selection: $draft.importance)
                        if let suggestion = model.suggestionNote(for: draft) {
                            SuggestionBlock(note: suggestion) { draft.take(suggestion) }
                        }
                    }
                    // The column's whole width, so the reasons are measured at the width they are drawn at.
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private func smallLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
            .foregroundStyle(Theme.Colour.mutedInk)
            .gridColumnAlignment(.leading)
    }

    private func menu<Value: Hashable>(_ title: String, _ choices: [(value: Value, title: String)],
                                       selection: Binding<Value>) -> some View {
        Picker(title, selection: selection) {
            ForEach(choices, id: \.value) { choice in
                Text(choice.title).tag(choice.value)
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}

/// The importance the advice suggests, its reasons each on a line, the evidence note, and "Use it" when it differs
/// from the importance chosen.
private struct SuggestionBlock: View {
    let note: SuggestionNote
    let use: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Text(note.text)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .foregroundStyle(Theme.Colour.ink)
                if note.showsUseIt {
                    Button(SuggestionNote.useItTitle, action: use)
                        .buttonStyle(.secondary)
                }
            }
            SuggestionReasons(note: note)
        }
    }
}

/// A suggestion's reasons, each on its own line in the engine's words, then its evidence note.
struct SuggestionReasons: View {
    let note: SuggestionNote

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            // Keyed by place, so two identical reasons are both shown.
            ForEach(Array(note.reasons.enumerated()), id: \.offset) { _, reason in
                Text(reason)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let evidence = note.noteText {
                Text(evidence)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
        }
        .textSelection(.enabled)
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
