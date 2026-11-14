import LineupAppCore
import SwiftUI

/// A suggested group on a card: who leads it, each member with what pulls him, the cautions, then the evidence note with
/// Record as set at the end of the row, or under the note when narrow.
struct SuggestedGroupCardView: View {
    let card: SuggestedGroupCard
    let record: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(card.leadText)
                    .font(Theme.Typeface.display(Theme.TypeSize.heading, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                // Straight into the stack, so a card with no cautions has no gap for them.
                MemberRows(members: card.members)
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

/// One of the owner's groups on a card: across the top, on a pink band, that it is doing harm or has stopped working
/// when it is; its members and since when; each member with what has changed; the warnings, marked in red; then the
/// evidence note with Edit and End group at the end of the row, or under the note when narrow.
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

/// A group's members, one row each, spaced by the stack they are put in: his name and age in a column, with the lead's
/// mark beside it, then what pulls him or what has changed, and the engine's notes on him under it in muted ink.
private struct MemberRows: View {
    let members: [MemberLine]

    var body: some View {
        ForEach(members) { member in
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(member.nameText)
                        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                        .lineLimit(Theme.Mentoring.nameLines)
                        .fixedSize(horizontal: false, vertical: true)
                    if let lead = member.leadText {
                        LeadMark(text: lead)
                    }
                }
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

/// "Lead" beside the lead's name: small, in marker blue, in an outline. The card's spoken text already says it.
private struct LeadMark: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .extraBold))
            .foregroundStyle(Theme.Colour.markerBlue)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Theme.Mentoring.leadMarkHorizontalPadding)
            .padding(.vertical, Theme.Stamp.verticalPadding)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Mentoring.leadMarkCornerRadius)
                    .strokeBorder(Theme.Colour.markerBlue, lineWidth: Theme.Stamp.lineWidth)
            }
            .accessibilityHidden(true)
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
