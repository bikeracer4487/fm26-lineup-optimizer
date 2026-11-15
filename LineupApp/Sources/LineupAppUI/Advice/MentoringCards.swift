import LineupAppCore
import SwiftUI

/// A suggested group on a card: its members' names, each arrow on a line, the prompt to record its arrows, the
/// cautions, then the evidence note with Record as set at the end of the row, or under the note when narrow.
struct SuggestedGroupCardView: View {
    let card: SuggestedGroupCard
    let record: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(card.titleText)
                    .font(Theme.Typeface.display(Theme.TypeSize.heading, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                // Straight into the stack, so a card with no prompt or cautions has no gap for them.
                ArrowRows(arrows: card.arrows)
                if let prompt = card.promptText {
                    PromptLine(text: prompt)
                }
                ForEach(Array(card.cautions.enumerated()), id: \.offset) { CautionLine($0.element) }
            }
            .foregroundStyle(Theme.Colour.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(card.spokenText)
            CardFooter(note: card.noteText) {
                Button(MentoringPresentation.recordTitle, action: record)
                    .buttonStyle(.main)
            }
        }
        .padding(Theme.Card.padding + Theme.Spacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardCard()
    }
}

/// One of the owner's groups on a card: across the top, on a pink band, that it is doing harm, shows no influence or has
/// stopped working when it is; its members and since when; each arrow on a line and the prompt to record them; each
/// member with what has changed; the warnings, marked in red; then the evidence note with Edit and End group at the end
/// of the row, or under the note when narrow.
struct RecordedGroupCardView: View {
    let card: RecordedGroupCard
    let edit: () -> Void
    let end: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let state = card.stateText {
                Text(state)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Card.padding + Theme.Spacing.xxs)
                    .padding(.vertical, Theme.Sticky.verticalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .stickyNote(Theme.Mentoring.stateNote, tilt: 0)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(card.titleText)
                            .font(Theme.Typeface.display(Theme.TypeSize.heading, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(card.sinceText)
                            .font(Theme.Typeface.text(Theme.TypeSize.body))
                            .foregroundStyle(Theme.Colour.mutedInk)
                    }
                    // Straight into the stack, so a group named from its saved state has no gap for them.
                    ArrowRows(arrows: card.arrows)
                    if let prompt = card.arrowsPromptText {
                        PromptLine(text: prompt)
                    }
                    MemberRows(members: card.members)
                    ForEach(Array(card.warnings.enumerated()), id: \.offset) {
                        CautionLine($0.element, isWarning: true)
                    }
                }
                .foregroundStyle(Theme.Colour.ink)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(card.spokenText)
                CardFooter(note: card.noteText) {
                    HStack(spacing: Theme.Spacing.s) {
                        Button(MentoringPresentation.editTitle, action: edit)
                            .buttonStyle(.secondary)
                        Button(MentoringPresentation.endTitle, action: end)
                            .buttonStyle(.secondary)
                    }
                }
            }
            .padding(Theme.Card.padding + Theme.Spacing.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Card.cornerRadius))
        .boardCard()
    }
}

/// A group's arrows, one row each, spaced by the stack they are put in: who to whom in a column, then its strength and
/// whether it was read, then what it gives. A guess is in muted ink.
private struct ArrowRows: View {
    let arrows: [ArrowLine]

    var body: some View {
        ForEach(arrows) { arrow in
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Text(arrow.titleText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .lineLimit(Theme.Mentoring.nameLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: Theme.Mentoring.memberNameWidth, alignment: .leading)
                Text(arrow.strengthText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                    .foregroundStyle(arrow.isGuess ? Theme.Colour.mutedInk : Theme.Colour.ink)
                    .fixedSize()
                Text(arrow.detailText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The engine's prompt to record a group's arrows from the game, in muted ink.
private struct PromptLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.body))
            .foregroundStyle(Theme.Colour.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A recorded group's members, one row each, spaced by the stack they are put in: his name and age in a column, then
/// what has changed, and the engine's notes on him under it in muted ink.
private struct MemberRows: View {
    let members: [MemberLine]

    var body: some View {
        ForEach(members) { member in
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Text(member.nameText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .lineLimit(Theme.Mentoring.nameLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: Theme.Mentoring.memberNameWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    if let detail = member.detailText {
                        Text(detail)
                            .font(Theme.Typeface.text(Theme.TypeSize.body))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(member.notes.enumerated()), id: \.offset) { note in
                        Text(note.element)
                            .font(Theme.Typeface.text(Theme.TypeSize.small))
                            .foregroundStyle(Theme.Colour.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The evidence note at the start of a card's last row and the card's buttons at its end, or under the note when the
/// row is narrow. The card's spoken text already says the note.
private struct CardFooter<Buttons: View>: View {
    let note: String?
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        WrappingRow(alignment: .center, spacing: Theme.Spacing.m) {
            if let note {
                Text(note)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .accessibilityHidden(true)
            }
        } trailing: {
            buttons()
                .fixedSize()
        }
    }
}
