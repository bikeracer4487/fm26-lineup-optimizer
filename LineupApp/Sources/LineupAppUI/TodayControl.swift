import LineupAppCore
import LineupEngine
import SwiftUI

/// The game's current date, written out, with the day before, the day after and a date picker to change it; under
/// it, when given, a line saying what the date is used for. Fixtures and Squad both show it.
struct TodayControl: View {
    let model: AppModel
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                Text(model.todayInTheGameText)
                    .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                Button("Day before") { model.moveToday(by: -1) }
                Button("Day after") { model.moveToday(by: 1) }
                DayPicker("Today in the game", day: today)
                    .labelsHidden()
                    .fixedSize()
            }
            .help("Fixtures before this day count as played.")
            if let caption {
                Text(caption)
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var today: Binding<Day> {
        Binding(get: { model.settings.currentDate }, set: { day in
            var settings = model.settings
            settings.currentDate = day
            model.update(settings)
        })
    }
}
