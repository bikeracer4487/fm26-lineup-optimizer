import Foundation
import LineupEngine

/// One of the club's three wage figures at the top of Contracts: its label, by the year as every wage is shown, and
/// what is kept in it.
public struct WageLimitRow: Equatable, Sendable {
    public var field: WageLimitField
    /// "Wage budget, a year", "Wages spent, a year", "Highest wage you can offer, a year".
    public var label: String
    /// The figure as kept, for a year, rounded to a whole unit, with a comma between each group of three digits:
    /// "1,560,000"; blank when none is.
    public var text: String
}

/// One player on Contracts: who he is, where he stands, when other clubs can approach him, his worth against the first
/// eleven's standard, the wage range for his tier and the agent's figure with what it says against the range. A player
/// renewed at the owner's choice also carries the engine's line saying so and the reasons the tool gave against it. A
/// player not recommended carries his facts, his standing and his reasons only; one not being renewed his facts and his
/// standing only.
public struct ContractRow: Equatable, Identifiable, Sendable {
    public let id: PlayerID
    public let name: String
    /// "Age 27 · D L · CA 92 · PA 120 · $68,820 a year · contract ends 30 Jun 2027". Where a player out on loan is,
    /// the standing line says, with where he would stand.
    public let detailsText: String
    /// The engine's sentence on where he stands: "First choice at left back."
    public let standingLine: String
    /// The engine's sentence on when other clubs can approach him; nil when there is none, or he is not in the list.
    public let timingLine: String?
    /// Whether the timing line is drawn as a caution: true when other clubs can approach him now, false otherwise and
    /// for a player not in the list.
    public let timingIsCaution: Bool
    /// The engine's sentence on his worth against the first eleven's standard (`AdvisorText.worthLine`), for a player
    /// in the list; nil when he has no worth, when his reasons already say it, and for a player not in the list.
    public let worthLine: String?
    /// The engine's sentence for each reason the tool does not recommend renewing him, in its order, the one that says
    /// to sign a replacement first left out; empty for a player it recommends and for one not being renewed.
    public let reasonLines: [String]
    /// The engine's sentence that he is needed until he is replaced ("He is first choice at central attacking midfield:
    /// sign a replacement before he goes."), the last of his reasons, drawn as a caution under the others; nil when he
    /// has no such reason, and on a row renewed at the owner's choice, since he is not going.
    public let replaceFirstText: String?
    /// The engine's sentence on a row listed at the owner's choice ("Renew anyway"); nil on any other.
    public let wantedLine: String?
    /// The engine's lines on the wage range for his tier; none for a player not in the list.
    public let guideLines: [String]
    /// "The agent's figure, a year".
    public let figureLabel: String
    /// The agent's figure as kept, for a year, with a comma between each group of three digits: "114,000"; blank when
    /// none is, and for a player not in the list.
    public let figureText: String
    /// "entered Wed 25 Nov": when the agent's figure was typed; nil when none is kept.
    public let figureEnteredText: String?
    /// The engine's sentence that the agent's figure is above the most the club can offer one player, drawn as a
    /// caution before the other verdicts; nil when that is not the first verdict, or there is no figure.
    public let cautionVerdictLine: String?
    /// The engine's other lines on the agent's figure against the range, in its order, the caution's sentence left out;
    /// none without a figure.
    public let verdictLines: [String]
}

/// Everything the Contracts screen shows.
public struct ContractsSheet: Equatable, Sendable {
    /// The engine's line under the heading.
    public let intro: String
    /// The engine's line under the intro, saying where the line for a recommendation is.
    public let ruleLine: String
    /// The club's three figures, in their order.
    public let limitRows: [WageLimitRow]
    /// "entered Wed 25 Nov": when a figure was last changed; nil with none kept.
    public let limitsEnteredText: String?
    /// The players worth renewing and those renewed at the owner's choice, in the engine's order: the higher worth
    /// first.
    public let rows: [ContractRow]
    /// The engine's line when nobody is in the list; nil otherwise.
    public let emptyLine: String?
    /// The line the players not recommended for renewal are closed behind, "21 players not recommended for renewal";
    /// nil for none.
    public let notRecommendedLine: String?
    /// The players the tool does not recommend renewing and the owner has not chosen to, in the engine's order, each
    /// with his facts, standing and reasons.
    public let notRecommended: [ContractRow]
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

    /// A club figure's label, in the period wages are shown by, a year: "Wage budget, a year".
    public static func label(_ field: WageLimitField, period: WagePeriod) -> String {
        switch field {
        case .wageBudget: "Wage budget, \(per(period))"
        case .wagesSpent: "Wages spent, \(per(period))"
        case .highestWage: "Highest wage you can offer, \(per(period))"
        }
    }

    /// "The agent's figure, a year".
    public static func figureLabel(period: WagePeriod) -> String { "The agent's figure, \(per(period))" }

    /// Over the line the players not recommended for renewal are closed behind.
    public static let notRecommendedHeading = "Not recommended for renewal"
    /// The button on a player not recommended, which lists him at once at the owner's choice.
    public static let renewAnywayButton = "Renew anyway"
    /// What VoiceOver says for it: "Renew Dejan Tetek anyway".
    public static func renewAnywayLabel(_ name: String) -> String { "Renew \(name) anyway" }
    /// The button on a row listed at the owner's choice, which takes him back to those not recommended.
    public static let followAdviceButton = "Follow the advice"
    /// What VoiceOver says for it: "Follow the advice on Dejan Tetek".
    public static func followAdviceLabel(_ name: String) -> String { "Follow the advice on \(name)" }
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

    /// A weekly figure as its field shows it: for the period, rounded to a whole unit, with a comma between each
    /// group of three digits; blank for none.
    static func text(perWeek: Double?, period: WagePeriod) -> String {
        perWeek.map { TypedNumber.grouped(Int(period.amount(perWeek: $0).rounded())) } ?? ""
    }

    /// His age, positions and Player Removal's facts on one line.
    static func details(of player: Player, money: MoneyStyle) -> String {
        ["Age \(player.age)", player.positionsText, PlayerFacts(player, money: money).line]
            .filter { !$0.isEmpty }.joined(separator: " · ")
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
                                text: text(perWeek: perWeek, period: money.period))
        }
    }

    /// The sheet for `report`: each listed player with his worth, the range for his tier from `wages` and `state`'s
    /// limits, and the agent's figure kept for him, and one renewed at the owner's choice with the engine's line and
    /// his reasons too; each player not recommended with his facts, standing and reasons; each player not being renewed
    /// with his facts and standing.
    static func sheet(_ report: ContractsReport, players: [PlayerID: Player],
                      wages: [WageTier: [PlayerWage]], state: ContractsState, money: MoneyStyle,
                      parameters: EngineParameters) throws -> ContractsSheet {
        let figureLabel = figureLabel(period: money.period)
        func details(_ entry: ContractEntry) -> String {
            players[entry.player].map { Self.details(of: $0, money: money) } ?? ""
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
            let reasons = AdvisorText.contractReasonLines(entry)
            let timingIsCaution: Bool
            switch entry.part {
            case .approachable: timingIsCaution = true
            case .lastYear, .noContract: timingIsCaution = false
            }
            return ContractRow(
                id: entry.player, name: entry.name, detailsText: details(entry),
                standingLine: AdvisorText.standingLine(entry), timingLine: AdvisorText.timingLine(entry),
                timingIsCaution: timingIsCaution, worthLine: worthLine(entry),
                // Renewed at his choice, he is not going: no replacement to sign first.
                reasonLines: reasons.lines, replaceFirstText: entry.isWanted ? nil : reasons.replaceFirst,
                wantedLine: entry.isWanted ? AdvisorText.listedAtYourChoice : nil,
                guideLines: AdvisorText.wageGuideLines(guide, money: money), figureLabel: figureLabel,
                figureText: text(perWeek: figure?.perWeek, period: money.period),
                figureEnteredText: figure.map { AdvisorText.enteredOn($0.entered) },
                cautionVerdictLine: caution, verdictLines: verdicts.map(line))
        }
        /// A player not in the list: his facts and standing, and his reasons when `withReasons`.
        func shortRow(_ entry: ContractEntry, withReasons: Bool) -> ContractRow {
            let reasons = withReasons ? AdvisorText.contractReasonLines(entry) : (lines: [], replaceFirst: nil)
            return ContractRow(id: entry.player, name: entry.name, detailsText: details(entry),
                               standingLine: AdvisorText.standingLine(entry), timingLine: nil, timingIsCaution: false,
                               worthLine: nil, reasonLines: reasons.lines, replaceFirstText: reasons.replaceFirst,
                               wantedLine: nil, guideLines: [], figureLabel: figureLabel, figureText: "",
                               figureEnteredText: nil, cautionVerdictLine: nil, verdictLines: [])
        }

        let rows = try report.listed.map(row)
        return ContractsSheet(
            intro: AdvisorText.contractsIntro,
            ruleLine: AdvisorText.contractsRuleLine(parameters),
            limitRows: limitRows(state.limits, money: money),
            limitsEnteredText: state.limitsEntered.map(AdvisorText.enteredOn),
            rows: rows,
            emptyLine: rows.isEmpty ? AdvisorText.nobodyInLastYear : nil,
            notRecommendedLine: report.notRecommended.isEmpty
                ? nil : AdvisorText.notRecommendedLine(report.notRecommended.count),
            notRecommended: report.notRecommended.map { shortRow($0, withReasons: true) },
            dismissedLine: report.dismissed.isEmpty ? nil : AdvisorText.notRenewingLine(report.dismissed.count),
            dismissed: report.dismissed.map { shortRow($0, withReasons: false) },
            evidenceNote: AdvisorText.contractsEvidenceNote(parameters.wageRangeRules.value))
    }

    /// His worth line, unless his reasons already give it (a player renewed at the owner's choice whose worth is under
    /// the standard), so the sentence stands once.
    static func worthLine(_ entry: ContractEntry) -> String? {
        let saidInReasons = entry.reasons.contains { reason in
            switch reason {
            case .underStandard: true
            case .markedToSell, .advisedToLeave, .noSlot, .noStandard, .replaceFirst: false
            }
        }
        return saidInReasons ? nil : entry.worth.map(AdvisorText.worthLine)
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
