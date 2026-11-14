import Foundation
import LineupEngine

/// One player the Rest screen lists: his level's stamp, his name and squad, his figures and the engine's reasons.
public struct RestRow: Identifiable, Equatable, Sendable {
    public let id: PlayerID
    public let name: String
    /// His squad as imported; nil when he is not in the squad book.
    public let squadText: String?
    public let stamp: StatusStamp
    /// The engine's words: "450 against a limit of 400".
    public let jadednessText: String
    /// Why his limit is not the standard one, in the engine's words; nil when it is.
    public let limitNotesText: String?
    public let conditionMeter: Meter
    public let conditionText: String
    public let startsText: String
    /// "Clear in about 3 days"; nil for watch.
    public let clearText: String?
    /// The engine's reasons, as written, each with the neutral dot.
    public let reasons: [MarkedReason]
    /// The evidence note in brackets: "(this tool's estimate)"; nil for FM27 evidence.
    public let noteText: String?
    /// "In the plan to start v Opponent A on Sat 14 Nov." when the plan starts him in its next planned fixture; nil
    /// otherwise, or without a plan.
    public let planText: String?

    /// The row as said to assistive technology.
    public var spokenText: String {
        let parts: [String?] = [stamp.text, name, squadText, "\(RestPresentation.jadednessLabel) \(jadednessText)",
                                limitNotesText, "\(RestPresentation.conditionLabel) \(conditionText)",
                                "\(RestPresentation.startsLabel) \(startsText)", clearText]
        return (parts.compactMap { $0 } + reasons.map(\.text) + [planText, spokenNote].compactMap { $0 })
            .joined(separator: ", ")
    }

    private let spokenNote: String?

    init(_ advice: RestAdvice, squad: Squad?, planText: String?) {
        id = advice.player
        name = advice.name
        squadText = squad?.displayName
        stamp = RestPresentation.stamp(advice.level)
        jadednessText = AdvisorText.jadedness(of: advice)
        limitNotesText = AdvisorText.limitNotes(of: advice)
        conditionMeter = Meter(fraction: advice.condition)
        conditionText = Display.percent(advice.condition)
        startsText = String(advice.consecutiveStarts)
        clearText = AdvisorText.clear(in: advice)
        reasons = advice.reasons.map { MarkedReason(text: $0, direction: .unchanged) }
        spokenNote = AdvisorText.note(for: advice.basis)
        noteText = spokenNote.map { "(\($0))" }
        self.planText = planText
    }
}

public enum RestPresentation {
    public static let explanation = "The planner decides who starts. This screen says who needs a break."
    public static let nobody = "Nobody needs rest today."
    public static let jadednessLabel = "Jadedness"
    public static let conditionLabel = "Condition"
    public static let startsLabel = "Starts in a row"

    /// The level's stamp, in the engine's word: holiday in red, rest in amber, watch in ink.
    public static func stamp(_ level: RestLevel) -> StatusStamp {
        let tone: StampTone
        switch level {
        case .holiday: tone = .red
        case .rest: tone = .amber
        case .watch: tone = .ink
        }
        return StatusStamp(text: AdvisorText.name(level), tone: tone)
    }

    /// A row for each piece of advice, in the engine's order, with the player's squad from `squads`, each saying when
    /// `next`, the plan's next planned fixture, starts him.
    public static func rows(_ advice: [RestAdvice], squads: [PlayerID: Squad], next: FixturePlan? = nil) -> [RestRow] {
        advice.map { RestRow($0, squad: squads[$0.player], planText: planText(for: $0.player, next: next)) }
    }

    /// "In the plan to start v Opponent A on Sat 14 Nov." when `next` is a planned fixture whose lineup starts the
    /// player; nil otherwise. A plain statement about the plan, so the Rest screen can show where the two differ.
    public static func planText(for player: PlayerID, next: FixturePlan?) -> String? {
        guard let next, case .planned(let lineup, _) = next.body,
              lineup.picks.contains(where: { $0.player == player }) else { return nil }
        return "In the plan to start v \(next.fixture.opponent) on \(DayText.short(next.fixture.date))."
    }

    /// "Nobody needs rest today." when there are no rows; nil otherwise.
    public static func emptyText(_ rows: [RestRow]) -> String? {
        rows.isEmpty ? nobody : nil
    }
}

extension AppModel {
    /// The Rest screen's rows for `report`, each player's squad as imported, each saying when the plan starts him in
    /// its next planned fixture.
    public func restRows(_ report: AdvisorsReport) -> [RestRow] {
        let squads = Dictionary(squad.book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })
        return RestPresentation.rows(report.rest, squads: squads, next: nextToPlay)
    }
}
