import Foundation
import LineupEngine

/// The settings as the Settings screen's controls read and change them.
extension AppSettings {
    /// The engine's own condition floor, used while the owner has not set one.
    public static var engineConditionFloor: Double { EngineParameters.fm27.conditionFloor.value }

    /// The figures the condition floor can be set to, in percent.
    public static let conditionFloorPercentRange = 50...100

    /// "Use the engine's 85%", with the engine's figure.
    public static var engineConditionFloorTitle: String {
        "Use the engine's \(percent(engineConditionFloor))%"
    }

    /// Whether the floor is the engine's. Turning this off starts from the engine's figure; turning it on forgets
    /// the owner's.
    public var usesEngineConditionFloor: Bool {
        get { conditionFloor == nil }
        set {
            if newValue {
                conditionFloor = nil
            } else if conditionFloor == nil {
                conditionFloor = Self.engineConditionFloor
            }
        }
    }

    /// The floor in use, in whole percent; setting it keeps it within `conditionFloorPercentRange`.
    public var conditionFloorPercent: Int {
        get { Self.percent(conditionFloor ?? Self.engineConditionFloor) }
        set {
            let range = Self.conditionFloorPercentRange
            conditionFloor = Double(min(max(newValue, range.lowerBound), range.upperBound)) / 100
        }
    }

    /// The saving-players weight, kept to tenths so a slider's steps save as the figures they show.
    public var savingPlayers: Double {
        get { plan.savingPlayers }
        set { plan.savingPlayers = (newValue * 10).rounded() / 10 }
    }

    /// "Off" for 0, else the weight to one decimal place.
    public static func savingPlayersText(_ value: Double) -> String {
        value == 0 ? "Off" : String(format: "%.1f", value)
    }

    /// "1 fixture", "5 fixtures".
    public static func horizonText(_ count: Int) -> String {
        count == 1 ? "1 fixture" : "\(count) fixtures"
    }

    /// The club name as typed; empty, or only spaces, means the club worked out from the squad.
    public var clubNameText: String {
        get { clubName ?? "" }
        set { clubName = Self.blankIsNil(newValue) }
    }

    /// The path to FMRTE's settings file as typed; empty means FMRTE's usual place.
    public var fmrteConfigPathText: String {
        get { fmrteConfigPath ?? "" }
        set { fmrteConfigPath = Self.blankIsNil(newValue) }
    }

    private static func percent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }

    private static func blankIsNil(_ text: String) -> String? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }
}
