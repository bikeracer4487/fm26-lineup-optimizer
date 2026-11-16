import LineupAppCore
import SwiftUI

/// Why that game plan if the match is simulated, under a heavy rule in the column beside the pitch: the engine's
/// sentences as written, with its evidence note after the last. The line naming the plan heads the column.
struct GamePlanPart: View {
    let note: GamePlanNote

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HeavyRule()
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                BoardHeading(GamePlanNote.heading)
                ForEach(note.sentences, id: \.self) { sentence in
                    Text(sentence)
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .lineSpacing(Theme.Spacing.xxs)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let evidence = note.noteText {
                    Text(evidence)
                        .font(Theme.Typeface.text(Theme.TypeSize.caption))
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
            }
        }
        .font(Theme.Typeface.text())
    }
}
