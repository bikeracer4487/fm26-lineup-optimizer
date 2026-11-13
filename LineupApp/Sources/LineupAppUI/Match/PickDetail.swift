import LineupAppCore
import LineupEngine
import SwiftUI

/// The selected pick: who he is, his roles, his figures on the day, every reason the engine gave in full, and the
/// owner's controls for the slot.
struct PickDetailView: View {
    let model: AppModel
    let fixture: FixtureID
    let detail: PickDetail
    /// Selects the slot's pick after the owner changes it, as Core works it out.
    let select: (PickSelection?) -> Void
    @State private var choosing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(detail.name)
                    .font(Theme.Typeface.text(Theme.TypeSize.step2, weight: .semibold))
                HStack(spacing: Theme.Spacing.s) {
                    Text(detail.slotText)
                        .font(Theme.Typeface.number(Theme.TypeSize.step1))
                    Text(detail.squadText)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                }
                ForEach(detail.roles, id: \.self) { role in
                    Text(role)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                }
            }

            figures

            if !detail.cautions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(detail.cautions, id: \.self) { caution in
                        MarkedText(caution, colour: Theme.Colour.amber)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Why he starts")
                    .font(Theme.Typeface.text(weight: .semibold))
                ForEach(Array(detail.reasons.enumerated()), id: \.offset) { _, reason in
                    Text(reason)
                        .font(Theme.Typeface.text())
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            actions
        }
    }

    /// Rating, fitness on the day with its factors, and the match-day value, the numbers in columns.
    private var figures: some View {
        Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.m, verticalSpacing: Theme.Spacing.xs) {
            ForEach(detail.figures) { figure in
                GridRow {
                    Text(figure.label)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                        .frame(width: Theme.Match.figureLabelWidth, alignment: .leading)
                    number(figure.figure ?? "")
                    number(figure.factor ?? "")
                }
            }
        }
    }

    private func number(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.number(Theme.TypeSize.step1))
            .offset(y: Theme.Typeface.numberDrop(Theme.TypeSize.step1))
            .frame(width: Theme.Match.figureWidth, alignment: .trailing)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button("Choose someone else…") { choosing = true }
                .popover(isPresented: $choosing, arrowEdge: .leading) {
                    CandidatePicker(text: PickerText.planned(detail.slot),
                                    rows: model.candidateRows(for: detail.slot, in: fixture)) { player in
                        select(model.choose(player, at: detail.slot, in: fixture))
                        choosing = false
                    } cancel: {
                        choosing = false
                    }
                }
            if detail.isOverride {
                Button("Clear this choice") { select(model.clearChoice(at: detail.slot, in: fixture)) }
            }
            Button("Leave him out of this match") { model.reject(detail.player, in: fixture) }
        }
    }
}
