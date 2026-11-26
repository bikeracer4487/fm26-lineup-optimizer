import Foundation
import LineupEngine

/// One of the club's three wage figures at the top of Contracts: its label in FMRTE's wage period, what is kept in it
/// and how the tool reads it.
public struct WageLimitRow: Equatable, Sendable {
    public var field: WageLimitField
    /// "Wage budget, a month", "Wages spent, a month", "Highest wage you can offer, a month".
    public var label: String
    /// The figure as kept, in plain digits in FMRTE's period, rounded to a whole unit; blank when none is.
    public var text: String
    /// The figure in the money style, shown beside the field: "$16,000 a month"; nil when none is kept.
    public var reading: String?
}

/// One player on Contracts: who he is, why he is listed, when other clubs can approach him, the wage range for his tier
/// and the agent's figure with what it says against the range. A player not being renewed carries his facts and his
/// standing only.
public struct ContractRow: Equatable, Identifiable, Sendable {
    public let id: PlayerID
    public let name: String
    /// "Age 27 · D L · CA 92 · PA 120 · $68,820 a year · contract ends 30 Jun 2027", with "Out on loan at Merthyr"
    /// last for a player who is.
    public let detailsText: String
    /// The engine's sentence on where he stands: "First choice at left back."
    public let standingLine: String
    /// The engine's sentence on when other clubs can approach him; nil when there is none, or he is not being renewed.
    public let timingLine: String?
    /// Whether the timing line is drawn as a caution: true in the part "Other clubs can approach them now", false in the
    /// other parts and for a player not being renewed.
    public let timingIsCaution: Bool
    /// The engine's lines on the wage range for his tier; none for a player not being renewed.
    public let guideLines: [String]
    /// "The agent's figure, a month", in FMRTE's wage period.
    public let figureLabel: String
    /// The agent's figure as kept, in plain digits in FMRTE's period; blank when none is.
    public let figureText: String
    /// The agent's figure in the money style: "$9,500 a month"; nil when none is kept.
    public let figureReading: String?
    /// "entered Wed 25 Nov": when the agent's figure was typed; nil when none is kept.
    public let figureEnteredText: String?
    /// The engine's sentence that the agent's figure is above the most the club can offer one player, drawn as a
    /// caution before the other verdicts; nil when that is not the first verdict, or there is no figure.
    public let cautionVerdictLine: String?
    /// The engine's other lines on the agent's figure against the range, in its order, the caution's sentence left out;
    /// none without a figure.
    public let verdictLines: [String]
}

/// One part of Contracts: its heading in the engine's words and its players, soonest end first.
public struct ContractsPartRows: Equatable, Sendable {
    public let heading: String
    public let rows: [ContractRow]
}

/// Everything the Contracts screen shows.
public struct ContractsSheet: Equatable, Sendable {
    /// The engine's line under the heading.
    public let intro: String
    /// The club's three figures, in their order.
    public let limitRows: [WageLimitRow]
    /// "entered Wed 25 Nov": when a figure was last changed; nil with none kept.
    public let limitsEnteredText: String?
    /// In the engine's order, only the parts with players in them.
    public let parts: [ContractsPartRows]
    /// The engine's line when no part has a player; nil otherwise.
    public let emptyLine: String?
    /// The engine's line counting the players in their last year marked or advised to go; nil for none.
    public let leftOutLine: String?
    /// The line the players not being renewed are closed behind, "1 player you are not renewing"; nil for none.
    public let dismissedLine: String?
    /// The players not being renewed, in the engine's order, each with his facts and standing only.
    public let dismissed: [ContractRow]
    /// The engine's evidence note, a sentence a line.
    public let evidenceNote: [String]
}

/// What the Contracts screen can show.
public enum ContractsSheetState: Equatable, Sendable {
    /// No squad, or no usable primary tactic, or the advice stopped: as the advice says.
    case notReady(AdviceState)
    /// The engine's sentences for why the list cannot be worked out.
    case failed([String])
    case ready(ContractsSheet)
}

/// What the Contracts screen shows, in the engine's words; Core holds only the labels.
public enum ContractsPresentation {
    /// "a week", "a month", "a year".
    static func per(_ period: WagePeriod) -> String {
        switch period {
        case .weekly: "a week"
        case .monthly: "a month"
        case .yearly: "a year"
        }
    }

    /// A club figure's label, in FMRTE's wage period: "Wage budget, a month".
    public static func label(_ field: WageLimitField, period: WagePeriod) -> String {
        switch field {
        case .wageBudget: "Wage budget, \(per(period))"
        case .wagesSpent: "Wages spent, \(per(period))"
        case .highestWage: "Highest wage you can offer, \(per(period))"
        }
    }

    /// "The agent's figure, a month".
    public static func figureLabel(period: WagePeriod) -> String { "The agent's figure, \(per(period))" }

    /// The button at the trailing end of a listed player's name, which sets him aside at once.
    public static let notRenewingButton = "Not renewing"
    /// What VoiceOver says for it: "Not renewing Evan Humphries".
    public static func notRenewingLabel(_ name: String) -> String { "Not renewing \(name)" }
    /// Over the line the players not being renewed are closed behind.
    public static let notRenewingHeading = "Not renewing"
    public static let showAgainButton = "Show again"
    /// What VoiceOver says for a set-aside player's "Show again": "Show Dejan Tetek again".
    public static func showAgainLabel(_ name: String) -> String { "Show \(name) again" }
    /// Over the engine's sentences when the list cannot be worked out.
    public static let failedLead = "Contracts cannot be worked out."

    /// "Out on loan at Merthyr".
    static func outOnLoanText(_ club: String) -> String { "Out on loan at \(club)" }

    /// A weekly figure in plain digits in FMRTE's period, rounded to a whole unit; blank for none.
    static func text(perWeek: Double?, period: WagePeriod) -> String {
        perWeek.map { String(Int(period.amount(perWeek: $0).rounded())) } ?? ""
    }

    /// His age, positions and Player Removal's facts on one line, then where he is out on loan when he is.
    static func details(of player: Player, ownClub: String?, money: MoneyStyle) -> String {
        var parts = ["Age \(player.age)", player.positionsText, PlayerFacts(player, money: money).line]
        switch LoanStatus.of(player, ownClub: ownClub) {
        case .loanedOut(let club): parts.append(outOnLoanText(club))
        case .own, .loanedIn: break
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func limitRows(_ limits: WageLimits, money: MoneyStyle) -> [WageLimitRow] {
        WageLimitField.allCases.map { field in
            let perWeek: Double?
            switch field {
            case .wageBudget: perWeek = limits.wageBudgetPerWeek
            case .wagesSpent: perWeek = limits.wagesSpentPerWeek
            case .highestWage: perWeek = limits.highestWagePerWeek
            }
            return WageLimitRow(field: field, label: label(field, period: money.period),
                                text: text(perWeek: perWeek, period: money.period),
                                reading: perWeek.map { Display.wage(perWeek: $0, money) })
        }
    }

    /// The sheet for `report`: each listed player with the range for his tier from `wages` and `state`'s limits, and
    /// the agent's figure kept for him; each player not being renewed with his facts and standing.
    static func sheet(_ report: ContractsReport, players: [PlayerID: Player], ownClub: String?,
                      wages: [WageTier: [PlayerWage]], state: ContractsState, money: MoneyStyle,
                      parameters: EngineParameters) throws -> ContractsSheet {
        let figureLabel = figureLabel(period: money.period)
        func details(_ entry: ContractEntry) -> String {
            players[entry.player].map { Self.details(of: $0, ownClub: ownClub, money: money) } ?? ""
        }
        func row(_ entry: ContractEntry) throws -> ContractRow {
            let guide = try WageRange.guide(tier: entry.tier, slot: entry.slot, wages: wages, excluding: entry.player,
                                            presentWagePerWeek: entry.presentWagePerWeek, limits: state.limits,
                                            parameters: parameters)
            let figure = state.figures[entry.player]
            var verdicts = figure.map {
                WageRange.verdict(figurePerWeek: $0.perWeek, guide: guide, presentWagePerWeek: entry.presentWagePerWeek)
            } ?? []
            func line(_ verdict: WageVerdict) -> String {
                AdvisorText.wageVerdictLine(verdict, figure: .agents, guide: guide, money: money)
            }
            var caution: String?
            if case .overHighestWage? = verdicts.first { caution = line(verdicts.removeFirst()) }
            let timingIsCaution: Bool
            switch entry.part {
            case .approachable: timingIsCaution = true
            case .lastYear, .noContract: timingIsCaution = false
            }
            return ContractRow(
                id: entry.player, name: entry.name, detailsText: details(entry),
                standingLine: AdvisorText.standingLine(entry), timingLine: AdvisorText.timingLine(entry),
                timingIsCaution: timingIsCaution,
                guideLines: AdvisorText.wageGuideLines(guide, money: money), figureLabel: figureLabel,
                figureText: text(perWeek: figure?.perWeek, period: money.period),
                figureReading: figure.map { Display.wage(perWeek: $0.perWeek, money) },
                figureEnteredText: figure.map { AdvisorText.enteredOn($0.entered) },
                cautionVerdictLine: caution, verdictLines: verdicts.map(line))
        }
        func dismissedRow(_ entry: ContractEntry) -> ContractRow {
            ContractRow(id: entry.player, name: entry.name, detailsText: details(entry),
                        standingLine: AdvisorText.standingLine(entry), timingLine: nil, timingIsCaution: false,
                        guideLines: [], figureLabel: figureLabel, figureText: "", figureReading: nil,
                        figureEnteredText: nil, cautionVerdictLine: nil, verdictLines: [])
        }

        var parts: [ContractsPartRows] = []
        for part in ContractPart.allCases {
            let rows = try report.listed.filter { $0.part == part }.map(row)
            if !rows.isEmpty { parts.append(ContractsPartRows(heading: AdvisorText.contractPartHeading(part), rows: rows)) }
        }
        return ContractsSheet(
            intro: AdvisorText.contractsIntro,
            limitRows: limitRows(state.limits, money: money),
            limitsEnteredText: state.limitsEntered.map(AdvisorText.enteredOn),
            parts: parts,
            emptyLine: parts.isEmpty ? AdvisorText.nobodyInLastYear : nil,
            leftOutLine: report.leftOutAsGoing > 0 ? AdvisorText.leftOutAsGoingLine(report.leftOutAsGoing) : nil,
            dismissedLine: report.dismissed.isEmpty ? nil : AdvisorText.notRenewingLine(report.dismissed.count),
            dismissed: report.dismissed.map(dismissedRow),
            evidenceNote: AdvisorText.contractsEvidenceNote(parameters.wageRangeRules.value))
    }
}

extension AppModel {
    /// The Contracts pill's name: "Contracts 3" with players listed; any other pill, or no count, its own name.
    public static func pillTitle(_ screen: Screen, count: Int?) -> String {
        switch screen {
        case .contracts: count.map { "\(screen.pillTitle) \($0)" } ?? screen.pillTitle
        case .squad, .tactics, .fixtures, .league, .matchSelection, .elevens, .rest, .training, .removal, .scouting,
             .offers, .settings: screen.pillTitle
        }
    }

    /// What the pill says to assistive technology: "Contracts, 3 players"; any other pill, or no count, its own name.
    public static func pillAccessibilityLabel(_ screen: Screen, count: Int?) -> String {
        switch screen {
        case .contracts: count.map { "\(screen.pillTitle), \($0) \($0 == 1 ? "player" : "players")" } ?? screen.pillTitle
        case .squad, .tactics, .fixtures, .league, .matchSelection, .elevens, .rest, .training, .removal, .scouting,
             .offers, .settings: screen.pillTitle
        }
    }
}
