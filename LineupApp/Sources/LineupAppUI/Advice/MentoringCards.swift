import LineupAppCore
import SwiftUI

/// A suggested group on a card: its members' names, each arrow on a line and the cautions; then, at the start of the
/// last row, the prompt to record its arrows over the evidence note, with Record arrows (while it rests on a guess) and
/// Record as set at the end of the row, or under them when narrow. A group of a regrouping has neither button.
struct SuggestedGroupCardView: View {
    let card: SuggestedGroupCard
    let recordArrows: () -> Void
    let record: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(card.titleText)
                    .font(Theme.Typeface.display(Theme.TypeSize.heading, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                // Straight into the stack, so a card with no cautions has no gap for them.
                ArrowRows(arrows: card.arrows)
                ForEach(Array(card.cautions.enumerated()), id: \.offset) { CautionLine($0.element) }
            }
            .foregroundStyle(Theme.Colour.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(card.spokenText)
            CardFooter(prompt: card.promptText, note: card.noteText) {
                HStack(spacing: Theme.Spacing.s) {
                    if let title = card.recordArrowsTitle {
                        Button(title, action: recordArrows)
                            .buttonStyle(.secondary)
                    }
                    if let title = card.recordTitle {
                        Button(title, action: record)
                            .buttonStyle(.main)
                    }
                }
            }
        }
        .padding(Theme.Card.padding + Theme.Spacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardCard()
    }
}

/// One of the owner's groups on a card: across the top, on a pink band, that it is doing harm, shows no influence, gives
/// nobody anything or has stopped working when it is, and that a regrouping would break it up; its members and since when; each arrow on a line; each member with what has changed; the
/// warnings, marked in red; then, at the start of the last row, the prompt to record its arrows over the evidence note,
/// with Arrows, which opens all six, Edit and End group at the end of the row, or under them when narrow.
struct RecordedGroupCardView: View {
    let card: RecordedGroupCard
    let arrows: () -> Void
    let edit: () -> Void
    let end: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !card.noticeTexts.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(Array(card.noticeTexts.enumerated()), id: \.offset) { notice in
                        Text(notice.element)
                            .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
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
                    MemberRows(members: card.members)
                    ForEach(Array(card.warnings.enumerated()), id: \.offset) {
                        CautionLine($0.element, isWarning: true)
                    }
                }
                .foregroundStyle(Theme.Colour.ink)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(card.spokenText)
                CardFooter(prompt: card.arrowsPromptText, note: card.noteText) {
                    HStack(spacing: Theme.Spacing.s) {
                        Button(MentoringPresentation.arrowsTitle, action: arrows)
                            .buttonStyle(.secondary)
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

/// A group's arrows, one row each, spaced by the stack they are put in: who to whom, then its strength and whether it
/// was read, then what it gives, on columns every card shares at a width. A read arrow's strength is in bold ink, a
/// guess's in plain muted ink.
private struct ArrowRows: View {
    let arrows: [ArrowLine]

    var body: some View {
        ForEach(arrows) { arrow in
            ArrowLineLayout {
                Text(arrow.titleText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                Text(arrow.strengthText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: arrow.isGuess ? .regular : .bold))
                    .foregroundStyle(arrow.isGuess ? Theme.Colour.mutedInk : Theme.Colour.ink)
                Text(arrow.detailText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body))
            }
        }
    }
}

/// An arrow's three parts, its two names, its strength and what it gives, at the top of three columns of fixed widths,
/// what it gives taking the rest of the width; when that would leave it less than its least, it goes under the
/// strength. The columns depend only on the width, so they line up from card to card.
private struct ArrowLineLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        frames(width: proposal.width ?? .infinity, subviews).reduce(CGRect.zero) { $0.union($1) }.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews)) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    /// Each part's frame, in the order given: the names, the strength, what it gives.
    private func frames(width: CGFloat, _ subviews: Subviews) -> [CGRect] {
        let gap = Theme.Spacing.m
        let titleWidth = min(Theme.Mentoring.arrowTitleWidth, width)
        let strengthX = titleWidth + gap
        let strengthWidth = max(0, min(Theme.Mentoring.arrowStrengthWidth, width - strengthX))
        let detailX = strengthX + strengthWidth + gap
        func height(_ index: Int, _ columnWidth: CGFloat) -> CGFloat {
            subviews.indices.contains(index)
                ? subviews[index].sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height : 0
        }
        let title = CGRect(x: 0, y: 0, width: titleWidth, height: height(0, titleWidth))
        let strength = CGRect(x: strengthX, y: 0, width: strengthWidth, height: height(1, strengthWidth))
        let detail: CGRect
        if width - detailX >= Theme.Mentoring.arrowDetailMinimum {
            let detailWidth = width.isFinite ? width - detailX : Theme.Mentoring.arrowDetailMinimum
            detail = CGRect(x: detailX, y: 0, width: detailWidth, height: height(2, detailWidth))
        } else {
            let detailWidth = max(0, width - strengthX)
            let top = strength.maxY + Theme.Spacing.xxs
            detail = CGRect(x: strengthX, y: top, width: detailWidth, height: height(2, detailWidth))
        }
        return [title, strength, detail]
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

/// A recorded group's members, one row each, spaced by the stack they are put in: his name and age in the column the
/// arrows' names take, so what has changed starts where an arrow's strength does, and the engine's notes on him under
/// it in muted ink.
private struct MemberRows: View {
    let members: [MemberLine]

    var body: some View {
        ForEach(members) { member in
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Text(member.nameText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .lineLimit(Theme.Mentoring.nameLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: Theme.Mentoring.arrowTitleWidth, alignment: .leading)
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

/// The prompt to record the group's arrows over the evidence note at the start of a card's last row, and the card's
/// buttons at its end, or under them when the row is narrow. The card's spoken text already says both.
private struct CardFooter<Buttons: View>: View {
    let prompt: String?
    let note: String?
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        WrappingRow(alignment: .center, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if let prompt {
                    PromptLine(text: prompt)
                }
                if let note {
                    Text(note)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
            }
            .accessibilityHidden(true)
        } trailing: {
            buttons()
                .fixedSize()
        }
    }
}
