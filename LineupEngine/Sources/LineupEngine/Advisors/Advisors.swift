import Foundation

/// Everything the advisors need, in one place.
public struct AdvisorsRequest: Sendable {
    /// Elevens, Depth and Player Removal judge against it.
    public var primary: Tactic
    /// Every saved tactic, for Training's needs. The primary is considered whether or not it is listed.
    public var tactics: [Tactic]
    public var players: [Player]
    public var ownClub: String?
    public var history: StartHistory
    public var asOf: Day
    public var intensity: TrainingIntensity
    public var accepted: [Retraining]
    public var rejected: Set<RetrainingChoice>
    /// What the readings kept at each import show, for Rest; `.none` when nothing is measured.
    public var trends: FitnessTrends

    public init(primary: Tactic, tactics: [Tactic], players: [Player], ownClub: String?, history: StartHistory,
                asOf: Day, intensity: TrainingIntensity, accepted: [Retraining], rejected: Set<RetrainingChoice>,
                trends: FitnessTrends = .none) {
        self.primary = primary
        self.tactics = tactics
        self.players = players
        self.ownClub = ownClub
        self.history = history
        self.asOf = asOf
        self.intensity = intensity
        self.accepted = accepted
        self.rejected = rejected
        self.trends = trends
    }
}

/// Every advisor's report for one squad.
public struct AdvisorsReport: Equatable, Sendable {
    public let elevens: ElevensReport
    public let depth: DepthReport
    public let rest: [RestAdvice]
    public let removal: RemovalReport
    /// Never recommends a player in `removal.advisedToLeave`.
    public let training: TrainingReport
    /// The trends the request was handed, for the Rest screen's squad lines.
    public let trends: FitnessTrends
}

public enum Advisors {
    /// Every advisor at once, each giving what it gives when called alone. The squad's elevens are solved once for the
    /// primary tactic and once for each other saved tactic, and shared. Player Removal runs before Training, and Training
    /// is handed `advisedToLeave`. Training's tactics are the primary first, then the saved tactics in the order given,
    /// each once. Player Removal writes money in `money`, the style of the squads the players came from, and is handed
    /// the history, the date and the accepted retrainings for the young players' outlooks and matches. Throws
    /// `PlanError.badParameters` when `FitnessModel.problems(in:)` finds problems, before anything else, and otherwise
    /// what the advisors throw.
    public static func report(_ request: AdvisorsRequest, money: MoneyStyle, catalog: RoleCatalog, profile: RatingProfile,
                              parameters: EngineParameters) throws -> AdvisorsReport {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let players = request.players
        let ownClub = request.ownClub

        func solve(_ tactic: Tactic) throws -> (elevens: ElevensReport, depth: DepthReport) {
            let elevens = try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                             profile: profile, parameters: parameters)
            let depth = try Depth.report(tactic: tactic, players: players, ownClub: ownClub, elevens: elevens,
                                         catalog: catalog, profile: profile, parameters: parameters)
            return (elevens, depth)
        }

        let primary = try solve(request.primary)
        let rest = try Rest.advice(players: players, ownClub: ownClub, history: request.history, asOf: request.asOf,
                                   intensity: request.intensity, trends: request.trends, parameters: parameters)
        let removal = try Removal.report(players: players, ownClub: ownClub, money: money, history: request.history,
                                         asOf: request.asOf, retraining: request.accepted,
                                         assignments: try request.primary.assignments(catalog: catalog),
                                         elevens: primary.elevens, depth: primary.depth, parameters: parameters)

        var tactics = [request.primary]
        for tactic in request.tactics where !tactics.contains(tactic) { tactics.append(tactic) }
        let training = try Training.report(
            tactics: tactics, players: players, ownClub: ownClub, accepted: request.accepted, rejected: request.rejected,
            leaving: removal.advisedToLeave, catalog: catalog, profile: profile, parameters: parameters
        ) { tactic in
            tactic == request.primary ? primary : try solve(tactic)
        }

        return AdvisorsReport(elevens: primary.elevens, depth: primary.depth, rest: rest, removal: removal,
                              training: training, trends: request.trends)
    }
}
