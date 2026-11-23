import LineupAppCore
import LineupEngine
import SwiftUI

/// One marked player: his name over what is known of him, with the control for sale or loan terms beside it, the menu of
/// what his loan is for beside that when it shows loan terms, and the engine's sentence under them when only a sale can
/// be worked out; his value,
/// typed straight into the model, with the hint, the day it was entered and the caution; the terms to ask of clubs in
/// general with "Record this ask", and his asks; "To a club", the club's name and its four figures, then the terms for
/// it, or the sentence naming the figure they need, or the line saying his open deal there is below; then his deals.
struct OfferPlayerBlockView: View {
    let block: OfferPlayerBlock
    let valueHint: String
    let valueCaution: String
    let model: AppModel
    @Bindable var navigation: Navigation
    let actions: OfferActions

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            WrappingRow(alignment: .top, spacing: Theme.Spacing.l) {
                identity
            } trailing: {
                kindControl
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                value
                if let needs = block.needsValue {
                    CautionLine(needs)
                        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
                }
                general
                club
                ForEach(block.deals) { card in
                    OfferDealCardView(card: card, model: model, actions: actions)
                }
            }
            .padding(.leading, Theme.Offers.partIndent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(block.name)
                .font(Theme.Typeface.display(Theme.TypeSize.heading, weight: .bold))
                .foregroundStyle(Theme.Colour.ink)
                .lineLimit(Theme.Offers.nameLines)
                .fixedSize(horizontal: false, vertical: true)
            Text(block.details)
                .font(Theme.Typeface.text(Theme.TypeSize.small))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// Sale terms or loan terms, from Core's choices, with the loan's purpose menu beside it and the sentence under it.
    private var kindControl: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                BoardTabs(choices: block.kindChoices.map { ($0.kind, $0.title) },
                          selection: Binding(get: { block.kind }, set: { model.setOfferKind($0, for: block.id) }))
                purposeMenu
            }
            if let note = block.kindNote {
                Text(note)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
            }
        }
    }

    /// What his loan is for, as a menu; nothing while his block shows sale terms.
    @ViewBuilder private var purposeMenu: some View {
        if let purpose = block.purpose {
            Picker(OffersPresentation.loanPurposeLabel, selection: Binding(
                get: { purpose },
                set: { model.setLoanPurpose($0, for: block.id) })) {
                ForEach(OffersPresentation.loanPurposeChoices, id: \.value) { choice in
                    Text(choice.title).tag(choice.value)
                }
            }
            .labelsHidden()
            .font(Theme.Typeface.text())
            .fixedSize()
        }
    }

    /// "His value", its field and how it is read, the hint and the day it was entered after it; the caution under them.
    private var value: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                FieldLabel(text: OffersPresentation.valueLabel)
                AmountField(label: OffersPresentation.valueLabel, text: block.valueText) {
                    model.setOfferValue(text: $0, for: block.id)
                }
                AmountReading(reading: block.valueReading)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    MutedLines(lines: [valueHint] + [block.valueNote].compactMap { $0 }, size: Theme.TypeSize.small)
                }
            }
            MutedLines(lines: [valueCaution], size: Theme.TypeSize.small)
        }
    }

    /// The terms to ask of clubs in general with "Record this ask", then his asks; nothing with neither.
    @ViewBuilder private var general: some View {
        if block.showsGeneral {
            OfferSection(title: OffersPresentation.generalHeading) {
                if let general = block.general {
                    OfferSuggestionLines(lines: general.lines)
                    Button(OffersPresentation.recordAskTitle) {
                        actions.open(model.offerDraft(for: block.id, club: "", purpose: .ask, filledWith: general.terms))
                    }
                    .buttonStyle(.secondary)
                    .fixedSize()
                }
                ForEach(block.asks) { ask in
                    OfferAskRowView(row: ask, noBid: { model.noBidCame(ask.id) }) { actions.delete(.ask(ask.id)) }
                }
            }
        }
    }

    /// "To a club": the club's name, and once one is named its four figures and the day they were entered; then the
    /// terms for it, the sentence naming the figure they need, or the line saying his open deal there is below.
    private var club: some View {
        OfferSection(title: OffersPresentation.clubLabel) {
            TextField(OffersPresentation.clubLabel, text: Binding(
                get: { navigation.offerClub[block.id] ?? "" },
                set: { navigation.offerClub[block.id] = $0 }), prompt: Text(OffersPresentation.clubPrompt))
                .labelsHidden()
                .boardField()
                .frame(width: Theme.Offers.clubFieldWidth)
            if block.showsClubFields {
                ClubFigureFields(rows: block.clubFields) { field, text in
                    model.setClubFigure(field, text: text, club: block.clubName)
                }
                if let note = block.clubNote {
                    MutedLines(lines: [note], size: Theme.TypeSize.small)
                }
            }
            if let suggestion = block.clubBlock {
                OfferSuggestionLines(lines: suggestion.lines)
            }
            if let problem = block.clubProblem {
                CautionLine(problem)
                    .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
            }
            if let open = block.clubHasOpenDeal {
                MutedLines(lines: [open])
            }
            if block.offersClubRecording {
                RecordButtons { purpose in
                    actions.open(model.offerDraft(for: block.id, club: block.clubName, purpose: purpose,
                                                  filledWith: block.clubBlock?.terms))
                }
            }
        }
    }
}

/// A part of a player's block: its small heading over what it holds.
private struct OfferSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                .foregroundStyle(Theme.Colour.ink)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// A suggestion as the engine words it: the advice first, in ink; the notes after it, in muted ink.
struct OfferSuggestionLines: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Keyed by place, so two identical lines are both shown.
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(Theme.Typeface.text())
                    .foregroundStyle(index == 0 ? Theme.Colour.ink : Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
    }
}

/// "Record my proposal" and "Record their bid", each opening the sheet for its side.
private struct RecordButtons: View {
    let record: (OfferRoundDraft.Purpose) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            Button(OffersPresentation.recordMineTitle) { record(.mine) }
                .buttonStyle(.secondary)
                .fixedSize()
            Button(OffersPresentation.recordTheirsTitle) { record(.theirs) }
                .buttonStyle(.secondary)
                .fixedSize()
        }
    }
}

/// One deal on a card: its heading with "Delete"; each round's line, with the club's three answers under the owner's
/// round that waits for one, and "I accepted" under the club's; the next step in the suggestion's style, or the
/// sentence naming the figure it needs; then, while it is open, "Record my proposal", "Record their bid" and "End".
struct OfferDealCardView: View {
    let card: OfferDealCard
    let model: AppModel
    let actions: OfferActions

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Text(card.heading)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .foregroundStyle(Theme.Colour.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(OffersPresentation.deleteTitle) { actions.delete(.deal(card.id)) }
                    .buttonStyle(.secondary)
                    .fixedSize()
            }
            ForEach(Array(card.rounds.enumerated()), id: \.offset) { _, round in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(round.line)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(Theme.Colour.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if round.offersAnswers {
                        HStack(alignment: .center, spacing: Theme.Spacing.s) {
                            answerButton(OffersPresentation.acceptedTitle, .accepted)
                            answerButton(OffersPresentation.refusedTitle, .refused)
                            answerButton(OffersPresentation.noReplyTitle, .noReply)
                        }
                    }
                    if round.offersAccept {
                        Button(OffersPresentation.iAcceptedTitle) { model.acceptTheirs(deal: card.id) }
                            .buttonStyle(.secondary)
                            .fixedSize()
                    }
                }
            }
            if let next = card.next {
                OfferSuggestionLines(lines: next.lines)
                    .padding(.top, Theme.Spacing.xs)
            }
            if let problem = card.problem {
                CautionLine(problem)
                    .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
            }
            if card.isOpen {
                HStack(alignment: .center, spacing: Theme.Spacing.s) {
                    RecordButtons { purpose in
                        actions.open(model.offerDraft(for: card.player, club: card.club, purpose: purpose,
                                                      filledWith: card.next?.terms, kind: card.kind))
                    }
                    Button(OffersPresentation.endTitle) { model.endDeal(card.id) }
                        .buttonStyle(.secondary)
                        .fixedSize()
                }
            }
        }
        .padding(Theme.Card.padding)
        .frame(maxWidth: Theme.Offers.cardMaximumWidth, alignment: .leading)
        .boardCard(cornerRadius: Theme.Card.smallCornerRadius)
    }

    private func answerButton(_ title: String, _ answer: RoundAnswer) -> some View {
        Button(title) { model.answer(answer, deal: card.id) }
            .buttonStyle(.secondary)
            .fixedSize()
    }
}

/// One ask to clubs in general: its line, "No bid came" while it waits for one, and "Delete".
struct OfferAskRowView: View {
    let row: OfferAskRow
    let noBid: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Text(row.line)
                .font(Theme.Typeface.text())
                .foregroundStyle(Theme.Colour.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
            if row.offersNoBid {
                Button(OffersPresentation.noBidTitle, action: noBid)
                    .buttonStyle(.secondary)
                    .fixedSize()
            }
            Button(OffersPresentation.deleteTitle, action: delete)
                .buttonStyle(.secondary)
                .fixedSize()
            Spacer(minLength: 0)
        }
    }
}

/// A club's four figures, each label in a column before its field and how it is read after it, so the fields line up:
/// two to a row when they fit across, one under another when not.
private struct ClubFigureFields: View {
    let rows: [OfferFieldRow]
    let set: @MainActor @Sendable (ClubField, String) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            grid(perRow: 2)
            grid(perRow: 1)
        }
    }

    private func grid(perRow: Int) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Theme.Spacing.s,
             verticalSpacing: Theme.Spacing.s) {
            ForEach(Array(stride(from: 0, to: rows.count, by: perRow)), id: \.self) { start in
                GridRow {
                    ForEach(rows[start..<min(start + perRow, rows.count)], id: \.field) { row in
                        FieldLabel(text: row.label, small: true)
                        AmountField(label: row.label, text: row.text) { set(row.field, $0) }
                        AmountReading(reading: row.reading)
                            .padding(.trailing, Theme.Offers.figureGap)
                    }
                }
            }
        }
        .fixedSize()
    }
}

/// A field's label: bold in ink beside a field of the block, small and muted beside a club's figure.
private struct FieldLabel: View {
    let text: String
    var small = false

    var body: some View {
        Text(text)
            .font(small ? Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold) : Theme.Typeface.text(weight: .bold))
            .foregroundStyle(small ? Theme.Colour.mutedInk : Theme.Colour.ink)
            .fixedSize()
    }
}

/// How the tool reads an amount, beside its field in the muted ink: "£40,000"; nothing beside a blank field. It keeps
/// its least width either way, so the fields do not move as digits are typed.
struct AmountReading: View {
    let reading: String?

    var body: some View {
        Text(reading ?? "")
            .font(Theme.Typeface.text())
            .foregroundStyle(Theme.Colour.mutedInk)
            .fixedSize()
            .frame(minWidth: Theme.Offers.readingMinimumWidth, alignment: .leading)
    }
}

/// An amount typed as digits, each keystroke handed on, as the League screen's numbers are; the model keeps the digits
/// and gives them back.
struct AmountField: View {
    let label: String
    let text: String
    let set: @MainActor @Sendable (String) -> Void

    var body: some View {
        TextField(label, text: Binding(get: { text }, set: set), prompt: Text(""))
            .labelsHidden()
            .boardField()
            .multilineTextAlignment(.trailing)
            .frame(width: Theme.Offers.amountFieldWidth)
    }
}
