import LineupAppCore
import LineupEngine
import SwiftUI

/// The Needs tab: who is counted as going, the slots that need a better player and those that need more depth, each
/// with its token and the engine's lines, then the fine slots on one wrapping row and how far to trust it all.
struct ScoutingNeedsTab: View {
    let model: AppModel
    let navigation: Navigation

    var body: some View {
        switch model.scoutingNeeds(for: navigation.scoutingTacticID) {
        case .notReady:
            // The gate shows why while the advice is not ready.
            EmptyView()
        case .failed(let problems):
            ScoutingFailed(problems: problems)
        case .ready(let needs):
            NeedsSheetView(sheet: model.needsSheet(needs))
        }
    }
}

private struct NeedsSheetView: View {
    let sheet: NeedsSheet

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Scouting.partGap) {
            if let going = sheet.goingLine {
                Text(going)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                    .foregroundStyle(Theme.Colour.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !sheet.betterPlayers.isEmpty {
                NeedList(heading: ScoutingPresentation.betterPlayersHeading, rows: sheet.betterPlayers)
            }
            if !sheet.moreDepth.isEmpty {
                NeedList(heading: ScoutingPresentation.moreDepthHeading, rows: sheet.moreDepth)
            }
            if !sheet.fine.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    BoardHeading(ScoutingPresentation.fineHeading, size: Theme.TypeSize.boardTitle)
                    FlowLayout(spacing: Theme.Scouting.fineTokenGap, lineSpacing: Theme.Spacing.s) {
                        ForEach(sheet.fineTokens) { token in
                            ScoutingSlotLabel(slotText: token.slotText, line: token.line)
                        }
                    }
                }
            }
            if let note = sheet.evidenceNote {
                ScoutingMutedLine(text: note, size: Theme.TypeSize.small)
            }
        }
    }
}

/// One list of needs under its heading, a faint rule under each row.
private struct NeedList: View {
    let heading: String
    let rows: [NeedRow]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            BoardHeading(heading, size: Theme.TypeSize.boardTitle)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    NeedRowView(row: row)
                    FaintRule()
                }
            }
        }
    }
}

/// One need: the slot's token, then the engine's lines beside it; muted when a young player could bring the slot level.
private struct NeedRowView: View {
    let row: NeedRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ScoutingSlotLabel(slotText: row.slotText, line: row.line, isMuted: row.isEased)
                .frame(width: Theme.Scouting.tokenColumn, alignment: .leading)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Keyed by place, so two identical lines are both shown.
                ForEach(Array(row.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(row.isEased ? Theme.Colour.mutedInk : Theme.Colour.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.Spacing.m)
        .textSelection(.enabled)
        .accessibilityElement(children: .combine)
    }
}
