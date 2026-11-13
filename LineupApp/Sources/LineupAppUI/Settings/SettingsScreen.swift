import LineupAppCore
import LineupEngine
import SwiftUI

/// The settings the planner and the imports use. A menu, stepper or box is saved as it changes; a slider when it is
/// let go, and a text field on Return or when it loses focus, so the plan is not worked out again at every step.
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
            CommittingSlider(label: "Lineup stability", value: setting(\.plan.stability), range: 0...1,
                             low: "Pure optimisation", high: "Maximum stability")
        }
    }

    private var savingPlayers: some View {
        SettingRow("Saving players for bigger fixtures",
                   "Higher rests more of your best players before a more important match soon after. "
                   + "Off picks each match on its own.") {
            CommittingSlider(label: "Saving players for bigger fixtures", value: setting(\.savingPlayers), range: 0...2,
                             step: 0.1, low: "Off", high: "2",
                             readout: AppSettings.savingPlayersText)
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
            CommittingTextField(label: "Your club", text: setting(\.clubNameText), prompt: "The club most players belong to")
                .frame(maxWidth: Theme.Layout.settingFieldWidth)
        }
    }

    private var fmrteConfigPath: some View {
        SettingRow("FMRTE's settings file",
                   "The file FMRTE keeps its column layouts in, which every import reads. "
                   + "Leave empty for FMRTE's usual place, shown in grey.") {
            CommittingTextField(label: "FMRTE's settings file", text: setting(\.fmrteConfigPathText),
                                prompt: LiveEnvironment.fmrteConfigFileForDisplay)
                .frame(maxWidth: Theme.Layout.settingFieldWidth)
        }
    }

    private func number(_ text: String) -> some View {
        SettingNumber(text: text)
    }
}

/// A figure beside a setting's control, level with the words around it.
private struct SettingNumber: View {
    let text: String

    var body: some View {
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

/// A slider between two words, and the figure it stands at when given a readout. It shows its own value while it is
/// dragged and hands it to `value` only when let go; a change to `value` from elsewhere shows at once.
private struct CommittingSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    /// The words at the ends, beside the slider rather than its own labels, which take the accent colour.
    let low: String
    let high: String
    var readout: ((Double) -> String)?
    @State private var shown: Double?

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            end(low)
            slider
                .labelsHidden()
                .frame(maxWidth: Theme.Layout.settingControlWidth)
            end(high)
            if let readout {
                SettingNumber(text: readout(shown ?? value))
                    .padding(.leading, Theme.Spacing.xs)
            }
        }
    }

    private var local: Binding<Double> {
        Binding(get: { shown ?? value }, set: { shown = $0 })
    }

    @ViewBuilder private var slider: some View {
        if let step {
            Slider(value: local, in: range, step: step) { Text(label) } onEditingChanged: { commit(editing: $0) }
        } else {
            Slider(value: local, in: range) { Text(label) } onEditingChanged: { commit(editing: $0) }
        }
    }

    private func end(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text())
            .foregroundStyle(.secondary)
    }

    /// When the drag ends, the value shown becomes the setting.
    private func commit(editing: Bool) {
        guard !editing, let shown else { return }
        self.shown = nil
        if shown != value { value = shown }
    }
}

/// A text field that edits its own copy and hands it to `text` on Return or when it loses focus. A change to `text`
/// from elsewhere shows while the field is not being edited.
private struct CommittingTextField: View {
    let label: String
    @Binding var text: String
    let prompt: String
    @State private var draft: String?
    @FocusState private var focused: Bool

    var body: some View {
        TextField(label, text: Binding(get: { draft ?? text }, set: { draft = $0 }), prompt: Text(prompt))
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
    }

    private func commit() {
        guard let draft else { return }
        self.draft = nil
        if draft != text { text = draft }
    }
}
