import LineupAppCore
import LineupEngine
import SwiftUI

/// Who is not in the eleven, under a heavy rule: the engine's omissions with their reasons, the players the owner left
/// out with a button to allow each again, and the owner's choices the engine could not use.
struct LeftOutList: View {
    let model: AppModel
    let plan: FixturePlan
    let omissions: [LeftOutRow]

    var body: some View {
        let rejected = model.rejectedRows(in: plan)
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HeavyRule()
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                BoardHeading("Left out")
                if omissions.isEmpty {
                    Text("Every first-choice player starts.")
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
                ForEach(omissions) { row in
                    Text("\(Text(row.name).font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold)).foregroundStyle(Theme.Colour.ink)) \(Text(row.slotText).font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .bold)).foregroundStyle(Theme.Colour.mutedInk))  \(Text(row.reason).foregroundStyle(Theme.Colour.mutedInk))")
                        .font(Theme.Typeface.text())
                        .lineSpacing(Theme.Spacing.xxs)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !rejected.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    BoardHeading("Left out by you")
                    ForEach(rejected) { row in
                        HStack(spacing: Theme.Spacing.m) {
                            Text(row.name)
                                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                            Spacer(minLength: Theme.Spacing.m)
                            Button("Allow him in this match") { model.allow(row.player, in: plan.id) }
                                .buttonStyle(.secondary)
                        }
                    }
                }
            }

            if !plan.ignoredOverrides.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    BoardHeading("Your choices not used")
                    ForEach(plan.ignoredOverrides) { ignored in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            CautionLine(ignored.sentence)
                            Button("Clear this choice") { model.setOverride(nil, at: ignored.slot, in: plan.id) }
                                .buttonStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
