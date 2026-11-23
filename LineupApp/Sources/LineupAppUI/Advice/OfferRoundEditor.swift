import LineupAppCore
import LineupEngine
import SwiftUI

/// The sheet a round or an ask is recorded in, opened filled with the suggestion, as the fixture editor is laid out: its
/// title and whose round it is, then the fields of its kind, each after its label (a sale's money now, money later and
/// share of the next fee; a loan's share of the wage, fee a month, playing time with what a starting place means under
/// it, the recall and a fee to buy him), the engine's sentence when the last Save was refused, and "Cancel" and "Save".
/// The changes are held here until Save, which records them and closes the sheet; Cancel drops them.
struct OfferRoundEditor: View {
    let model: AppModel
    let close: () -> Void
    @State private var draft: OfferRoundDraft
    @State private var refusal: String?

    init(model: AppModel, draft: OfferRoundDraft, close: @escaping () -> Void) {
        self.model = model
        self.close = close
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                BoardHeading(draft.title, size: Theme.TypeSize.boardTitle)
                Text(model.offerEditorLine(draft))
                    .font(Theme.Typeface.text())
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Theme.Spacing.l,
                 verticalSpacing: Theme.Spacing.m) {
                switch draft.kind {
                case .sale:
                    amountRow(OffersPresentation.feeNowLabel, draft.now, .feeNow)
                    amountRow(OffersPresentation.feeLaterLabel, draft.later, .feeLater)
                    amountRow(OffersPresentation.nextFeeLabel, draft.nextFee, .nextFeePercent)
                case .loan:
                    amountRow(OffersPresentation.wagePercentLabel, draft.wagePercent, .wagePercent)
                    amountRow(OffersPresentation.feePerMonthLabel, draft.feePerMonth, .feePerMonth)
                    if draft.showsPlayingTime {
                        GridRow {
                            label(OffersPresentation.playingTimeLabel)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Picker(OffersPresentation.playingTimeLabel, selection: $draft.playingTime) {
                                    ForEach(OffersPresentation.playingTimeChoices, id: \.value) { choice in
                                        Text(choice.title).tag(PlayingTime?.some(choice.value))
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()
                                Text(AdvisorText.startingPlaceMeans)
                                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                                    .foregroundStyle(Theme.Colour.mutedInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    GridRow {
                        label(OffersPresentation.recallLabel)
                        Toggle(OffersPresentation.recallLabel, isOn: $draft.recall)
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                    }
                    amountRow(OffersPresentation.futureFeeLabel, draft.futureFee, .futureFee)
                }
            }
            if let refusal {
                CautionLine(refusal)
            }
            HStack(spacing: Theme.Spacing.s) {
                Spacer()
                Button(OffersPresentation.cancelTitle, role: .cancel, action: close)
                    .buttonStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                Button(OffersPresentation.saveTitle) {
                    switch model.record(draft) {
                    case .recorded: close()
                    case .refused(let sentence): refusal = sentence
                    case .ignored: break
                    }
                }
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Card.padding + Theme.Spacing.xs)
        .frame(width: Theme.Offers.editorWidth, alignment: .topLeading)
        .background(Theme.Colour.board)
        .boardAppearance()
    }

    /// A row of the grid: its label, then a field whose digits go into the draft at each keystroke.
    private func amountRow(_ title: String, _ text: String, _ field: OfferField) -> some View {
        GridRow {
            label(title)
            TextField(title, text: Binding(get: { text }, set: { draft.set(field, text: $0) }), prompt: Text(""))
                .labelsHidden()
                .boardField()
                .multilineTextAlignment(.trailing)
                .frame(width: Theme.Offers.editorFieldWidth)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
            .foregroundStyle(Theme.Colour.ink)
            .gridColumnAlignment(.leading)
    }
}
