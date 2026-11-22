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
    /// What the readings show of him, in the engine's sentences, as written: his trend or that it is not measured yet,
    /// when he passes the line, what a match off would do.
    public let trendLines: [String]
    /// The trend's evidence note in brackets, shown after its lines, so a measured rate is never read as a fact:
    /// "(this tool's estimate)"; nil when no measured line is shown, as when his only line says his trend is not
    /// measured yet.
    public let trendNoteText: String?

    /// The row as said to assistive technology, in the order the screen shows it: his figures, his reasons, what the
    /// plan does with him, then his trend lines with their note.
    public var spokenText: String {
        let parts: [String?] = [stamp.text, name, squadText, "\(RestPresentation.jadednessLabel) \(jadednessText)",
                                limitNotesText, "\(RestPresentation.conditionLabel) \(conditionText)",
                                "\(RestPresentation.startsLabel) \(startsText)", clearText]
        return (parts.compactMap { $0 } + reasons.map(\.text) + [planText].compactMap { $0 } + trendLines
                + [spokenTrendNote, spokenNote].compactMap { $0 })
            .joined(separator: ", ")
    }

    private let spokenNote: String?
    private let spokenTrendNote: String?

    init(_ advice: RestAdvice, squad: Squad?, planText: String?, parameters: EngineParameters) {
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
        trendLines = AdvisorText.trendLines(of: advice, parameters: parameters)
        // With no trend as seen the first line says so and estimates nothing; any line after it is a measured one.
        let measuredLines = trendLines.count - (advice.trend.seen == nil ? 1 : 0)
        spokenTrendNote = measuredLines > 0 ? AdvisorText.note(for: advice.trend.basis) : nil
        trendNoteText = spokenTrendNote.map { "(\($0))" }
    }
}

/// One squad's drift above the Rest screen's rows, in the engine's words, with its caution when leaving players out of
/// matches cannot bring jadedness down.
public struct RestSquadLine: Identifiable, Equatable, Sendable {
    /// Its place among the squad lines.
    public let id: Int
    public let text: String
    public let caution: String?
}

/// What the Rest screen shows above its rows about the trends: a line for each measured squad, the club's line, the day
/// the trend is measured from, and whether "Measure again from today" is offered.
public struct RestTrendHeader: Equatable, Sendable {
    public let squadLines: [RestSquadLine]
    public let clubLine: String?
    /// "Trend measured from Tue 24 Aug."; nil when the engine has no day to measure from.
    public let measuredFromText: String?
    /// Offered once any reading is kept.
    public let offersMeasureAgain: Bool

    /// Whether the line with the day measured from and the button is shown: with either of them.
    public var showsMeasuredLine: Bool { measuredFromText != nil || offersMeasureAgain }
}

public enum RestPresentation {
    public static let explanation = "The planner decides who starts. This screen says who needs a break."
    public static let nobody = "Nobody needs rest today."
    public static let jadednessLabel = "Jadedness"
    public static let conditionLabel = "Condition"
    public static let startsLabel = "Starts in a row"
    public static let measureAgainTitle = "Measure again from today"
    public static let measureAgainConfirm = "Measure again"
    public static let cancelTitle = "Cancel"
    /// The engine's heading over what the game's fitness messages mean.
    public static let gameMessagesHeading = AdvisorText.gameMessagesHeading

    /// The question "Measure again from today" asks first, since nothing is measured until each squad has `imports`
    /// imports from today on (an import made today counts as one).
    public static func measureAgainQuestion(imports: Int) -> String {
        "Measure the trend again from today? Each squad then needs \(imports) imports from today on before anything is "
            + "measured."
    }

    /// What the game's fitness messages mean, in the engine's words, each with its evidence.
    public static func gameMessages(_ parameters: EngineParameters) -> [String] {
        AdvisorText.gameMessages(parameters: parameters)
    }

    /// The lines above the rows for `trends`, in the engine's words; "Measure again from today" is offered when
    /// `readingsKept`.
    public static func trendHeader(_ trends: FitnessTrends, readingsKept: Bool, parameters: EngineParameters)
        -> RestTrendHeader {
        let lines = AdvisorText.squadTrendLines(trends, parameters: parameters).enumerated()
            .map { RestSquadLine(id: $0.offset, text: $0.element.text, caution: $0.element.caution) }
        return RestTrendHeader(squadLines: lines, clubLine: AdvisorText.clubGainLine(trends),
                               measuredFromText: AdvisorText.trendMeasuredFrom(trends), offersMeasureAgain: readingsKept)
    }

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
    /// `next`, the plan's next planned fixture, starts him, and with his trend lines in the engine's words for
    /// `parameters`.
    public static func rows(_ advice: [RestAdvice], squads: [PlayerID: Squad], next: FixturePlan? = nil,
                            parameters: EngineParameters) -> [RestRow] {
        advice.map {
            RestRow($0, squad: squads[$0.player], planText: planText(for: $0.player, next: next), parameters: parameters)
        }
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
        return RestPresentation.rows(report.rest, squads: squads, next: nextToPlay, parameters: planParameters)
    }

    /// The lines above the Rest screen's rows for `report`'s trends; "Measure again from today" is offered once the
    /// fitness file holds any reading.
    public func restTrendHeader(_ report: AdvisorsReport) -> RestTrendHeader {
        RestPresentation.trendHeader(report.trends, readingsKept: fitness.readings.values.contains { !$0.isEmpty },
                                     parameters: planParameters)
    }

    /// The question "Measure again from today" asks, with the number of imports the engine's parameters need.
    public var restMeasureAgainQuestion: String {
        RestPresentation.measureAgainQuestion(imports: planParameters.jadednessTrendRules.value.fewestOwnIntervals + 1)
    }

    /// What the game's fitness messages mean, for the foot of the Rest screen.
    public var restGameMessages: [String] {
        RestPresentation.gameMessages(planParameters)
    }
}
