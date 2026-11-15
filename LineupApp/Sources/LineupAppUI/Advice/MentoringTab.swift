import LineupAppCore
import LineupEngine
import SwiftUI

/// The Training screen's Mentoring tab for the squad the menu shows: the engine's standing note, then four parts down
/// the screen (the hierarchy as entered, the suggested groups, the owner's own groups, and the players not placed when
/// there are any), or, while the squad has not been imported, only that. A squad whose advice stopped shows the
/// engine's sentences where the suggested groups would be.
struct MentoringTab: View {
    let model: AppModel
    @Bindable var navigation: Navigation
    @Environment(\.showScreen) private var showScreen

    var body: some View {
        let sheet = model.mentoringSheet(for: MentoringPresentation.squadShown(navigation.mentoringSquad,
                                                                               imported: model.importedSquads))
        VStack(alignment: .leading, spacing: Theme.Training.partGap) {
            Text(sheet.noteText)
                .font(Theme.Typeface.text(Theme.TypeSize.body))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            if let notReady = sheet.notReady {
                EmptyState(notReady, action: MatchPresentation.goTo(.squad)) { showScreen(.squad) }
            } else {
                HierarchyPart(sheet: sheet) { navigation.mentoringEditing = .hierarchy(sheet.squad) }
                SuggestedPart(sheet: sheet, recordArrows: { openArrows(of: $0, in: sheet.squad) }) {
                    model.recordGroup($0, in: sheet.squad)
                }
                YourGroupsPart(sheet: sheet, recordArrows: { openArrows(of: [], in: sheet.squad) }, add: {
                    navigation.mentoringEditing = .group(MentoringGroupDraft(squad: sheet.squad))
                }, arrows: { openArrows(of: $0, in: sheet.squad) },
                edit: { navigation.mentoringEditing = .group($0) }, end: { model.endGroup($0) })
                if let heading = MentoringPresentation.notPlacedHeading(sheet) {
                    NotPlacedPart(heading: heading, lines: sheet.notPlaced)
                }
            }
        }
        .frame(maxWidth: Theme.Training.columnMaximumWidth, alignment: .leading)
        .sheet(item: $navigation.mentoringEditing) { editing in
            MentoringEditorSheet(model: model, editing: editing, close: { navigation.mentoringEditing = nil },
                                 open: { navigation.mentoringEditing = $0 })
        }
    }

    /// Opens the arrows sheet on the players, filled from the readings kept.
    private func openArrows(of members: [PlayerID], in squad: Squad) {
        navigation.mentoringEditing = .arrows(model.arrowsDraft(for: squad, members: members))
    }
}

/// A part's heading, with its control at the end of the row, or under the heading when narrow.
private struct PartHeading<Control: View>: View {
    let title: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        WrappingRow(alignment: .center, spacing: Theme.Spacing.m) {
            BoardHeading(title, size: Theme.TypeSize.boardTitle)
        } trailing: {
            control()
        }
    }
}

/// The levels as entered, one line each, how many have a social group, when it was updated and the Update button; and
/// on a sticky note, that the entries are old or that the advice needs the hierarchy.
private struct HierarchyPart: View {
    let sheet: MentoringSheet
    let update: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PartHeading(title: MentoringPresentation.headings.hierarchy) {
                HStack(alignment: .center, spacing: Theme.Spacing.m) {
                    if let updated = sheet.updatedText {
                        Text(updated)
                            .font(Theme.Typeface.text(Theme.TypeSize.caption))
                            .foregroundStyle(Theme.Colour.mutedInk)
                    }
                    Button(MentoringPresentation.updateTitle, action: update)
                        .buttonStyle(.secondary)
                }
                .fixedSize()
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(Array(sheet.hierarchyLines.enumerated()), id: \.offset) { line in
                    Text(line.element)
                        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                        .foregroundStyle(Theme.Colour.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let social = sheet.socialGroupsLine {
                    Text(social)
                        .font(Theme.Typeface.text(Theme.TypeSize.body))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let stale = sheet.staleText {
                HierarchyNote(text: stale, tilt: NoteTilt.degrees(at: 0))
            }
            if let needed = sheet.needsHierarchyText {
                HierarchyNote(text: needed, tilt: NoteTilt.degrees(at: 1))
            }
        }
    }
}

/// A yellow sticky note pinned to the board with a blue magnet.
private struct HierarchyNote: View {
    let text: String
    let tilt: Double

    var body: some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Sticky.horizontalPadding)
            .padding(.vertical, Theme.Sticky.verticalPadding)
            .overlay(alignment: .top) {
                Magnet.pin(Theme.Colour.markerBlue)
                    .offset(y: -Theme.Magnet.noteDiameter / 2)
                    .accessibilityHidden(true)
            }
            .stickyNote(Theme.Note.yellow, tilt: tilt)
            .frame(maxWidth: Theme.Mentoring.noteMaximumWidth, alignment: .leading)
            .padding(.top, Theme.Magnet.noteDiameter / 2)
    }
}

/// A card for each suggested group; the engine's sentence when there is none; or, when the advice for the squad
/// stopped, the engine's sentences saying why.
private struct SuggestedPart: View {
    let sheet: MentoringSheet
    let recordArrows: ([PlayerID]) -> Void
    let record: (SuggestedGroup) -> Void

    var body: some View {
        // Everything straight into one stack, so what is not there leaves no gap.
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            BoardHeading(MentoringPresentation.headings.suggested, size: Theme.TypeSize.boardTitle)
            ForEach(Array(sheet.failures.enumerated()), id: \.offset) { failure in
                Text(failure.element)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                    .foregroundStyle(Theme.Colour.redText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
            }
            if let none = MentoringPresentation.noSuggestionsText(sheet) {
                Text(none)
                    .font(Theme.Typeface.text(Theme.TypeSize.body))
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
            ForEach(sheet.suggested) { card in
                SuggestedGroupCardView(card: card, recordArrows: { recordArrows(card.arrowsDraftMembers) },
                                       record: { record(card.suggestion) })
            }
        }
    }
}

/// A card for each of the owner's groups, or a muted line saying there is none, with Record arrows and Add a group
/// beside the heading.
private struct YourGroupsPart: View {
    let sheet: MentoringSheet
    let recordArrows: () -> Void
    let add: () -> Void
    let arrows: ([PlayerID]) -> Void
    let edit: (MentoringGroupDraft) -> Void
    let end: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            PartHeading(title: MentoringPresentation.headings.yours) {
                HStack(spacing: Theme.Spacing.s) {
                    Button(MentoringPresentation.recordArrowsTitle, action: recordArrows)
                        .buttonStyle(.secondary)
                    Button(MentoringPresentation.addTitle, action: add)
                        .buttonStyle(.secondary)
                }
                .fixedSize()
            }
            if let none = MentoringPresentation.noRecordedGroupsText(sheet) {
                Text(none)
                    .font(Theme.Typeface.text(Theme.TypeSize.body))
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
            ForEach(sheet.yours) { card in
                RecordedGroupCardView(card: card, arrows: { arrows(card.arrowsDraftMembers) },
                                      edit: { edit(card.draft) }, end: { end(card.id) })
            }
        }
    }
}

/// The engine's sentence for each player not placed, each over a faint rule.
private struct NotPlacedPart: View {
    let heading: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            BoardHeading(heading, size: Theme.TypeSize.boardTitle)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { line in
                    Text(line.element)
                        .font(Theme.Typeface.text(Theme.TypeSize.body))
                        .foregroundStyle(Theme.Colour.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, Theme.Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    FaintRule()
                }
            }
        }
    }
}
