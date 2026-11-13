import LineupAppCore
import LineupEngine
import SwiftUI

/// The settings the planner and the imports use. Each change is saved as it is made.
public struct SettingsScreen: View {
    let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(Screen.settings.title)
                .font(Theme.Typeface.title())
            ScrollView {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Theme.Spacing.xl,
                     verticalSpacing: Theme.Spacing.l) {
                    heading("Planning")
                    trainingIntensity
                    stability
                    savingPlayers
                    horizon
                    conditionFloor
                    heading("Squad and FMRTE")
                    clubName
                    fmrteConfigPath
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A binding to one setting; each change is saved at once.
    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { model.settings[keyPath: keyPath] }, set: { value in
            var settings = model.settings
            settings[keyPath: keyPath] = value
            model.update(settings)
        })
    }

    private func heading(_ text: String) -> some View {
        GridRow {
            Text(text)
                .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                .padding(.top, Theme.Spacing.s)
                .gridCellColumns(2)
        }
    }

    private var trainingIntensity: some View {
        SettingRow("Training intensity",
                   "Set this to the intensity you train at in the game. Lower intensity lets players recover "
                   + "condition faster between matches.") {
            Picker("Training intensity", selection: setting(\.plan.trainingIntensity)) {
                ForEach(TrainingIntensity.allCases, id: \.self) { intensity in
                    Text(intensity.displayName).tag(intensity)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var stability: some View {
        SettingRow("Lineup stability",
                   "Higher keeps players in the slots they have been playing. Lower picks the best eleven each time.") {
            // The words at the ends are beside the slider rather than its own labels, which take the accent colour.
            HStack(alignment: .center, spacing: Theme.Spacing.s) {
                end("Pure optimisation")
                Slider(value: setting(\.plan.stability), in: 0...1) {
                    Text("Lineup stability")
                }
                .labelsHidden()
                .frame(maxWidth: Theme.Layout.settingControlWidth)
                end("Maximum stability")
            }
        }
    }

    private var savingPlayers: some View {
        SettingRow("Saving players for bigger fixtures",
                   "Higher rests more of your best players before a more important match soon after. "
                   + "Off picks each match on its own.") {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                end("Off")
                Slider(value: setting(\.savingPlayers), in: 0...2, step: 0.1) {
                    Text("Saving players for bigger fixtures")
                }
                .labelsHidden()
                .frame(maxWidth: Theme.Layout.settingControlWidth)
                end("2")
                number(AppSettings.savingPlayersText(model.settings.savingPlayers))
            }
        }
    }

    private var horizon: some View {
        SettingRow("Fixtures to plan",
                   "How far ahead each plan looks. Fixtures beyond it are not planned and nobody is saved for them.") {
            HStack(alignment: .center, spacing: Theme.Spacing.s) {
                Text(AppSettings.horizonText(model.settings.plan.horizon))
                    .font(Theme.Typeface.text())
                Stepper("Fixtures to plan", value: setting(\.plan.horizon), in: 1...10)
                    .labelsHidden()
            }
        }
    }

    private var conditionFloor: some View {
        SettingRow("Condition floor", AppSettings.conditionFloorExplanation) {
            HStack(alignment: .center, spacing: Theme.Spacing.s) {
                number("\(model.settings.conditionFloorPercent)%")
                    .foregroundStyle(model.settings.usesEngineConditionFloor ? .secondary : .primary)
                Stepper("Condition floor", value: setting(\.conditionFloorPercent),
                        in: AppSettings.conditionFloorPercentRange)
                    .labelsHidden()
                    .disabled(model.settings.usesEngineConditionFloor)
                Toggle(AppSettings.engineConditionFloorTitle, isOn: setting(\.usesEngineConditionFloor))
                    .toggleStyle(.checkbox)
                    .padding(.leading, Theme.Spacing.m)
            }
        }
    }

    private var clubName: some View {
        SettingRow("Your club",
                   "Leave empty to use the club most players belong to. The club tells your own players from those on loan.") {
            TextField("Your club", text: setting(\.clubNameText), prompt: Text("The club most players belong to"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(maxWidth: Theme.Layout.settingFieldWidth)
        }
    }

    private var fmrteConfigPath: some View {
        SettingRow("FMRTE's settings file",
                   "The file FMRTE keeps its column layouts in, which every import reads. "
                   + "Leave empty for FMRTE's usual place, shown in grey.") {
            TextField("FMRTE's settings file", text: setting(\.fmrteConfigPathText),
                      prompt: Text(LiveEnvironment.fmrteConfigFileForDisplay))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(maxWidth: Theme.Layout.settingFieldWidth)
        }
    }

    /// A word at one end of a slider.
    private func end(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text())
            .foregroundStyle(.secondary)
    }

    private func number(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.number(Theme.TypeSize.step1))
            .offset(y: Theme.Typeface.numberDrop(Theme.TypeSize.step1, besideTextOf: Theme.TypeSize.base))
    }
}

/// One setting as a row of the grid: its name, then its control with a line under it saying what it changes.
private struct SettingRow<Control: View>: View {
    let name: String
    let explanation: String
    let control: Control

    init(_ name: String, _ explanation: String, @ViewBuilder control: () -> Control) {
        self.name = name
        self.explanation = explanation
        self.control = control()
    }

    var body: some View {
        GridRow(alignment: .top) {
            Text(name)
                .font(Theme.Typeface.text(weight: .semibold))
                .frame(minHeight: Theme.Layout.controlRowHeight, alignment: .leading)
                .gridColumnAlignment(.leading)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                control
                    .frame(minHeight: Theme.Layout.controlRowHeight, alignment: .leading)
                Text(explanation)
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
            }
        }
    }
}
