import Foundation
import LineupEngine

/// What the advisor screens can show: what is missing before the advisors can run, why they stopped, or their report.
public enum AdviceState: Equatable, Sendable {
    case needsSquad
    /// Empty when no tactic is saved; otherwise the sentences for why the primary tactic cannot be used.
    case needsTactic([String])
    /// The engine's sentences for why the advisors stopped, and the screen where it is put right.
    case failed([String], fix: Screen)
    case ready(AdvisorsReport)
}

/// The first and second elevens and the cover for one tactic.
public enum ElevensState: Equatable, Sendable {
    /// No squad, or no usable primary tactic, or the advice stopped: as the advice says.
    case notReady(AdviceState)
    /// The engine's sentences for why this tactic cannot be used.
    case failed([String])
    case ready(ElevensReport, DepthReport)
}

/// The Elevens screen's three views of one tactic.
public enum ElevensView: CaseIterable, Hashable, Sendable {
    case first, second, depth

    public var title: String {
        switch self {
        case .first: "First XI"
        case .second: "Second XI"
        case .depth: "Depth"
        }
    }
}

/// The mentoring advice for one squad. Worked out apart from the other advisors: it needs no tactic, and one squad's
/// failing stops neither the other squads nor any other advisor screen.
public enum MentoringAdvice: Equatable, Sendable {
    /// This squad has not been imported.
    case needsSquad
    /// The engine's sentences for why the advice for this squad stopped.
    case failed([String])
    case ready(MentoringReport)
}

/// The Training screen's two tabs.
public enum TrainingView: CaseIterable, Hashable, Sendable {
    case retraining, mentoring

    public var title: String {
        switch self {
        case .retraining: "Retraining"
        case .mentoring: "Mentoring"
        }
    }
}

/// The advice worked out since the last change, and what has been worked out from it so far. Each part is worked out
/// when first read.
struct AdviceCache {
    var state: AdviceState
    var suggestions: [FixtureID: ImportanceSuggestion]?
    /// By tactic id, for saved tactics other than the primary.
    var elevens: [UUID: ElevensState] = [:]
    /// The planner's tiers by tactic id; nil for a tactic the engine refused.
    var tiers: [UUID: SquadTiers?] = [:]
}
