import Foundation
import LineupEngine

/// One recommended retraining as its card shows it: who, what to learn, what it covers and how long it takes, in the
/// engine's words, with the engine's reasons and cautions.
public struct RecommendationCard: Identifiable, Equatable, Sendable {
    public var id: RetrainingChoice { choice }
    public let choice: RetrainingChoice
    public let name: String
    /// "Age 22".
    public let ageText: String
    /// The engine's words: "Learn left back".
    public let headline: String
    /// The engine's words: "Covers left back in Sample 4-2-3-1"; nil when it names no slot.
    public let coversText: String?
    /// His familiarity at the position now, beside `TrainingPresentation.familiarityLabel`.
    public let familiarityText: String
    /// The engine's words: "About 21 weeks: a structural change from right back".
    public let timeText: String
    /// The engine's reasons, as written, each with the green plus.
    public let reasons: [MarkedReason]
    /// The engine's cautions, as written.
    public let cautions: [String]
    /// The evidence note in brackets: "(FM26-era numbers)"; nil for FM27 evidence.
    public let noteText: String?

    /// The card as said to assistive technology.
    public var spokenText: String {
        let parts: [String?] = [name, ageText, headline, coversText,
                                "\(TrainingPresentation.familiarityLabel) \(familiarityText)", timeText]
        return (parts.compactMap { $0 } + reasons.map(\.text) + cautions.map { "Caution: \($0)" }
                + [spokenNote].compactMap { $0 }).joined(separator: ", ")
    }

    private let spokenNote: String?

    init(_ recommendation: RetrainingRecommendation) {
        choice = recommendation.choice
        name = recommendation.name
        ageText = "Age \(recommendation.age)"
        headline = AdvisorText.learn(recommendation.choice.position)
        coversText = AdvisorText.covers(recommendation.needs)
        familiarityText = String(recommendation.currentFamiliarity)
        timeText = AdvisorText.timeToLearn(recommendation)
        reasons = recommendation.reasons.map { MarkedReason(text: $0, direction: .raised) }
        cautions = recommendation.cautions
        spokenNote = AdvisorText.note(for: recommendation.basis)
        noteText = spokenNote.map { "(\($0))" }
    }
}

/// Where a retraining under way stands on the game's familiarity scale: where he started, where he is now and the
/// line at which he counts as solid.
public struct RetrainingTrack: Equatable, Sendable {
    public static let lowest = 1
    public static let highest = 20

    /// His familiarity at the first counted observation; nil without one.
    public let start: Int?
    /// His familiarity at the latest counted observation; nil without one.
    public let latest: Int?
    /// The familiarity from which he counts as solid.
    public let solid: Int

    public init(start: Int?, latest: Int?, solid: Int) {
        self.start = start; self.latest = latest; self.solid = solid
    }

    /// How far along the track a familiarity sits, from 0 at `lowest` to 1 at `highest`; a figure outside the scale
    /// sits at its end.
    public static func fraction(_ value: Int) -> Double {
        let share = Double(value - lowest) / Double(highest - lowest)
        return min(max(share, 0), 1)
    }

    /// Where each mark sits along the track; nil for a mark without an observation.
    public var startFraction: Double? { start.map(Self.fraction) }
    public var latestFraction: Double? { latest.map(Self.fraction) }
    public var solidFraction: Double { Self.fraction(solid) }

    /// The stretch from the start to now, drawn as his gain; nil when he has gained nothing.
    public var gained: ClosedRange<Double>? {
        guard let start, let latest, latest > start else { return nil }
        return Self.fraction(start)...Self.fraction(latest)
    }

    public var lowestText: String { String(Self.lowest) }
    public var highestText: String { String(Self.highest) }
    /// "Started at 8"; nil without an observation.
    public var startText: String? { start.map { "Started at \($0)" } }
    /// "Now 12"; nil without an observation.
    public var latestText: String? { latest.map { "Now \($0)" } }
    /// "Solid at 15".
    public var solidText: String { "Solid at \(solid)" }
}

/// One accepted retraining: who, what, since when, and how it is going; a player no longer in any squad is shown as
/// such, with nothing about how it is going.
public struct RetrainingRow: Identifiable, Equatable, Sendable {
    public var id: RetrainingChoice { choice }
    public let choice: RetrainingChoice
    public let name: String
    /// The engine's words: "Learning left back".
    public let positionText: String
    /// "Accepted on 13 Nov".
    public let acceptedText: String
    /// Nil when he is in no squad.
    public let track: RetrainingTrack?
    /// The engine's sentence on how it is going; nil when he is in no squad.
    public let progressText: String?
    /// "No longer in the squad" when he is in no squad; nil otherwise.
    public let departedStamp: StatusStamp?

    /// The row as said to assistive technology.
    public var spokenText: String {
        let parts: [String?] = [name, positionText, acceptedText, departedStamp?.text, track?.startText,
                                track?.latestText, track?.solidText, progressText]
        return parts.compactMap { $0 }.joined(separator: ", ")
    }
}

/// A retraining the owner turned down.
public struct TurnedDownRow: Identifiable, Equatable, Sendable {
    public var id: RetrainingChoice { choice }
    public let choice: RetrainingChoice
    public let name: String
    /// The engine's words: "Learn left back".
    public let positionText: String
}

/// One of the Training screen's four parts, in the order the screen shows them.
public enum TrainingPart: Identifiable, Equatable, Sendable {
    case recommended([RecommendationCard])
    case underWay([RetrainingRow])
    /// The engine's sentence for each need nobody suits, and its sentence for those already being retrained for.
    case recruit(needs: [String], alreadyRetraining: String?)
    case turnedDown([TurnedDownRow])

    public var id: String { heading }

    public var heading: String {
        switch self {
        case .recommended: "Recommended"
        case .underWay: "Being retrained"
        case .recruit: "Recruit instead"
        case .turnedDown: "Turned down"
        }
    }

    /// The muted line the part shows in place of rows when it has none; nil when it has some.
    public var emptyText: String? {
        switch self {
        case .recommended(let cards): cards.isEmpty ? "No retraining is recommended today." : nil
        case .underWay(let rows): rows.isEmpty ? "Nobody is being retrained." : nil
        case .recruit(let needs, _): needs.isEmpty ? "Every thin slot has someone who could learn it." : nil
        case .turnedDown(let rows): rows.isEmpty ? "Nothing has been turned down." : nil
        }
    }
}

public enum TrainingPresentation {
    public static let explanation =
        "Accepting a retraining records it and reads his familiarity there at each import. Set it up in the game as well."
    public static let familiarityLabel = "Familiarity now"
    public static let acceptTitle = "Accept"
    public static let notHimTitle = "Not him"
    public static let stopTitle = "Stop"
    public static let offerAgainTitle = "Offer again"
    static let departed = StatusStamp(text: "No longer in the squad", isOut: true)
    /// For a player whose name was never saved, which accepting or turning down always does.
    static let unnamed = "A player no longer in the squad"

    /// A card for each recommendation, in the engine's order.
    public static func cards(_ report: TrainingReport) -> [RecommendationCard] {
        report.recommendations.map(RecommendationCard.init)
    }

    /// A row for each accepted retraining, in the saved order, with each player's name from `inSquads` (the players in
    /// any squad), else as saved. The track runs from the first counted observation to the latest, with the solid line
    /// at `depthSolidFamiliarity`.
    public static func underWay(_ state: TrainingState, inSquads names: [PlayerID: String],
                                parameters: EngineParameters) -> [RetrainingRow] {
        state.accepted.map { retraining in
            let choice = TrainingState.choice(retraining)
            let inSquad = names[retraining.player] != nil
            let progress = RetrainingTracker.progress(of: retraining, observations: state.observations[choice] ?? [],
                                                      parameters: parameters)
            return RetrainingRow(
                choice: choice, name: name(of: retraining.player, inSquads: names, saved: state.names),
                positionText: AdvisorText.learning(retraining.position),
                acceptedText: "Accepted on \(DayText.dayAndMonth(retraining.acceptedOn))",
                track: inSquad ? RetrainingTrack(start: progress.start, latest: progress.latest,
                                                 solid: parameters.depthSolidFamiliarity.value) : nil,
                progressText: inSquad ? AdvisorText.progress(progress, toward: retraining.position, parameters: parameters) : nil,
                departedStamp: inSquad ? nil : departed)
        }
    }

    /// A row for each turned-down pair, in the saved order, named as `underWay` names them.
    public static func turnedDown(_ state: TrainingState, inSquads names: [PlayerID: String]) -> [TurnedDownRow] {
        state.rejected.sorted(by: TrainingState.order).map { choice in
            TurnedDownRow(choice: choice, name: name(of: choice.player, inSquads: names, saved: state.names),
                          positionText: AdvisorText.learn(choice.position))
        }
    }

    /// The needs nobody suits, then those already being retrained for, in the engine's words.
    public static func recruit(_ report: TrainingReport) -> TrainingPart {
        .recruit(needs: report.needsWithoutCandidates.map(AdvisorText.need),
                 alreadyRetraining: AdvisorText.alreadyBeingRetrained(report.needsBeingRetrained))
    }

    /// With the advice ready, all four parts; without it, only the parts kept in the saved state that have entries.
    public static func parts(report: TrainingReport?, underWay: [RetrainingRow],
                             turnedDown: [TurnedDownRow]) -> [TrainingPart] {
        guard let report else {
            return (underWay.isEmpty ? [] : [.underWay(underWay)]) + (turnedDown.isEmpty ? [] : [.turnedDown(turnedDown)])
        }
        return [.recommended(cards(report)), .underWay(underWay), recruit(report), .turnedDown(turnedDown)]
    }

    private static func name(of player: PlayerID, inSquads names: [PlayerID: String], saved: [PlayerID: String]) -> String {
        names[player] ?? saved[player] ?? unnamed
    }
}

extension AppModel {
    /// The Training screen's parts for the advice and the saved retraining choices.
    public var trainingParts: [TrainingPart] {
        let names = Dictionary(squad.book.allPlayers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return TrainingPresentation.parts(
            report: AdvicePresentation.report(adviceState)?.training,
            underWay: TrainingPresentation.underWay(training, inSquads: names, parameters: planParameters),
            turnedDown: TrainingPresentation.turnedDown(training, inSquads: names))
    }
}
