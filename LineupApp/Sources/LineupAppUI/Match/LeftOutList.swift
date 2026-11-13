import LineupAppCore
import LineupEngine
import SwiftUI

/// Who is not in the eleven: the engine's omissions with their reasons, the players the owner left out with a button
/// to allow each again, and the owner's choices the engine could not use.
struct LeftOutList: View {
    let model: AppModel
    let plan: FixturePlan
    let omissions: [LeftOutRow]

    var body: some View {
        let rejected = model.rejectedRows(in: plan)
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Left out")
                    .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                if omissions.isEmpty {
                    Text("Every first-choice player starts.")
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                }
                ForEach(omissions) { row in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                        HStack(spacing: Theme.Spacing.s) {
                            Text(row.name)
                                .font(Theme.Typeface.text(weight: .semibold))
                            Text(row.slotText)
                                .font(Theme.Typeface.number(Theme.TypeSize.base))
                                .foregroundStyle(.secondary)
                        }
                        Text(row.reason)
                            .font(Theme.Typeface.text())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !rejected.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Left out by you")
                        .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                    ForEach(rejected) { row in
                        HStack(spacing: Theme.Spacing.m) {
                            Text(row.name)
                                .font(Theme.Typeface.text())
                            Spacer(minLength: Theme.Spacing.m)
                            Button("Allow") { model.allow(row.player, in: plan.id) }
                        }
                    }
                }
            }

            if !plan.ignoredOverrides.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Your choices not used")
                        .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                    ForEach(plan.ignoredOverrides, id: \.self) { sentence in
                        MarkedText(sentence, colour: Theme.Colour.amber)
                    }
                }
            }
        }
    }
}
