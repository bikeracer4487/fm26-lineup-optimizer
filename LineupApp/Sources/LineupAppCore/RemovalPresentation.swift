import Foundation
import LineupEngine

/// The colour of a reason's points: red for points against him, green for points for him, muted for none.
public enum PointsTone: Hashable, Sendable {
    case red, green, muted
}

/// One of the engine's removal or loan reasons, as written, with its points in the engine's words and their colour.
public struct PointedReason: Hashable, Sendable {
    public let text: String
    /// "+25", "−40" with a true minus sign, or "0".
    public let pointsText: String
    public let tone: PointsTone

    public init(text: String, pointsText: String, tone: PointsTone) {
        self.text = text; self.pointsText = pointsText; self.tone = tone
    }

    public init(_ reason: RemovalReason) {
        text = reason.text
        pointsText = AdvisorText.points(of: reason)
        tone = reason.points > 0 ? .red : reason.points < 0 ? .green : .muted
    }

    /// "+25 In neither eleven".
    var spokenText: String { "\(pointsText) \(text)" }
}

/// A column of the removal table, in its order.
public enum RemovalColumn: CaseIterable, Hashable, Sendable {
    case level, action, name, squad, age, score, costs

    public var title: String {
        switch self {
        case .level: "Level"
        case .action: "Action"
        case .name: "Name"
        case .squad: "Squad"
        case .age: "Age"
        case .score: RemovalPresentation.scoreLabel
        case .costs: "Costs"
        }
    }
}

/// Which levels the removal table shows.
public enum RemovalFilter: CaseIterable, Hashable, Sendable {
    case all, criticalAndHigh, medium, keep

    public var title: String {
        switch self {
        case .all: "All"
        case .criticalAndHigh: "Critical and high"
        case .medium: "Medium"
        case .keep: "Keep"
        }
    }

    public func includes(_ level: RemovalLevel) -> Bool {
        switch (self, level) {
        case (.all, _), (.criticalAndHigh, .critical), (.criticalAndHigh, .high), (.medium, .medium), (.keep, .keep): true
        case (.criticalAndHigh, .medium), (.criticalAndHigh, .keep), (.medium, .critical), (.medium, .high),
             (.medium, .keep), (.keep, .critical), (.keep, .high), (.keep, .medium): false
        }
    }
}

/// One player of the club's own as the removal table shows him: his level's stamp, the action, who he is, his score and
/// what releasing him costs; open, every reason with its points, why that action, and the evidence note.
public struct RemovalRow: Identifiable, Equatable, Sendable {
    public let id: PlayerID
    public let name: String
    public let level: RemovalLevel
    public let stamp: StatusStamp
    /// The engine's word: "Sell".
    public let actionText: String
    /// His squad as imported; nil when he is not in the squad book.
    public let squadText: String?
    /// His age as imported; nil when he is not in the squad book.
    public let ageText: String?
    public let scoreText: String
    /// The engine's sentence on what releasing him costs.
    public let costsText: String
    public let reasons: [PointedReason]
    /// The engine's sentence for why that action.
    public let whyText: String
    /// The evidence note in brackets: "(this tool's estimate)"; nil for FM27 evidence.
    public let noteText: String?

    /// Critical and high rows are open until the owner closes them; medium and keep rows closed until opened.
    public var opensByDefault: Bool {
        switch level {
        case .critical, .high: true
        case .medium, .keep: false
        }
    }

    /// The row as said to assistive technology.
    public var spokenText: String {
        let parts: [String?] = [stamp.text, actionText, name, squadText, ageText.map { "Age \($0)" },
                                "\(RemovalPresentation.scoreLabel) \(scoreText)", costsText]
        return parts.compactMap { $0 }.joined(separator: ", ")
    }

    init(_ advice: RemovalAdvice, squad: Squad?, age: Int?) {
        id = advice.player
        name = advice.name
        level = advice.level
        stamp = RemovalPresentation.stamp(advice.level)
        actionText = AdvisorText.name(advice.action)
        squadText = squad?.displayName
        ageText = age.map(String.init)
        scoreText = AdvisorText.score(advice.score)
        costsText = AdvisorText.costs(of: advice)
        reasons = advice.reasons.map(PointedReason.init)
        whyText = AdvisorText.why(advice.action, for: advice)
        noteText = AdvisorText.note(for: advice.basis).map { "(\($0))" }
    }
}

/// One player on loan at the club: the verdict's stamp, his name, his score and his reasons with their points.
public struct LoanBlock: Identifiable, Equatable, Sendable {
    public let id: PlayerID
    public let name: String
    public let stamp: StatusStamp
    public let scoreText: String
    public let reasons: [PointedReason]
    /// The evidence note in brackets; nil for FM27 evidence.
    public let noteText: String?

    /// The block as said to assistive technology.
    public var spokenText: String {
        ([stamp.text, name, "\(RemovalPresentation.scoreLabel) \(scoreText)"] + reasons.map(\.spokenText)
         + [spokenNote].compactMap { $0 }).joined(separator: ", ")
    }

    private let spokenNote: String?

    init(_ review: LoanReview) {
        id = review.player
        name = review.name
        stamp = RemovalPresentation.stamp(review.verdict)
        scoreText = AdvisorText.score(review.score)
        reasons = review.reasons.map(PointedReason.init)
        spokenNote = AdvisorText.note(for: review.basis)
        noteText = spokenNote.map { "(\($0))" }
    }
}

/// A figure on a card of its own over the removal table.
public struct RemovalFigure: Identifiable, Equatable, Sendable {
    public var id: String { label }
    public let label: String
    public let figure: String

    public init(label: String, figure: String) {
        self.label = label; self.figure = figure
    }
}

/// Which removal rows the owner has opened or closed while the app runs; any other row is open or closed as its level
/// says. Kept by player, so a row stays as the owner left it when the advice is worked out again.
public struct RemovalDisclosure: Equatable, Sendable {
    /// Rows closed by default that the owner opened.
    public var opened: Set<PlayerID> = []
    /// Rows open by default that the owner closed.
    public var closed: Set<PlayerID> = []

    public init() {}

    public func isOpen(_ row: RemovalRow) -> Bool {
        row.opensByDefault ? !closed.contains(row.id) : opened.contains(row.id)
    }

    /// Opens the row if it is closed, closes it if it is open.
    public mutating func toggle(_ row: RemovalRow) {
        if row.opensByDefault {
            if closed.remove(row.id) == nil { closed.insert(row.id) }
        } else {
            if opened.remove(row.id) == nil { opened.insert(row.id) }
        }
    }

    /// Every one of `rows` open.
    public static func allOpen(_ rows: [RemovalRow]) -> RemovalDisclosure {
        var disclosure = RemovalDisclosure()
        disclosure.opened = Set(rows.filter { !$0.opensByDefault }.map(\.id))
        return disclosure
    }
}

/// Everything the Player Removal screen shows from the report.
public struct RemovalSheet: Equatable, Sendable {
    public let figures: [RemovalFigure]
    /// In the engine's order: highest score first.
    public let rows: [RemovalRow]
    /// In the engine's order: highest score first.
    public let loans: [LoanBlock]

    public func rows(_ filter: RemovalFilter) -> [RemovalRow] {
        rows.filter { filter.includes($0.level) }
    }

    /// "Critical and high (2)".
    public func filterTitle(_ filter: RemovalFilter) -> String {
        "\(filter.title) (\(rows(filter).count))"
    }

    /// "There is nobody to assess." when there is no player of the club's own; nil otherwise.
    public var emptyText: String? {
        rows.isEmpty ? RemovalPresentation.nobody : nil
    }

    /// The line in place of the table when the filter leaves nobody but there are rows; nil otherwise.
    public func filteredEmptyText(_ filter: RemovalFilter) -> String? {
        !rows.isEmpty && rows(filter).isEmpty ? RemovalPresentation.nobodyAtLevel : nil
    }

    /// "Nobody is on loan here." when there are no loans to the club; nil otherwise.
    public var loansEmptyText: String? {
        loans.isEmpty ? RemovalPresentation.noLoans : nil
    }
}

public enum RemovalPresentation {
    public static let explanation = "The advice judges players against the primary tactic."
    public static let nobody = "There is nobody to assess."
    public static let nobodyAtLevel = "No player is at this level."
    public static let noLoans = "Nobody is on loan here."
    public static let loansHeading = "Loans to the club"
    public static let scoreLabel = "Score"
    public static let averageLabel = "First team's average ability"
    public static let wagesLabel = "Wages of the critical and high players"
    /// The table's headings, in its order.
    public static let columns = RemovalColumn.allCases.map(\.title)

    /// What a row says to assistive technology about whether its reasons show.
    public static func openText(_ isOpen: Bool) -> String {
        isOpen ? "Open" : "Closed"
    }

    /// What a click on a row does.
    public static func clickHelp(_ isOpen: Bool) -> String {
        isOpen ? "Hide the reasons" : "Show the reasons"
    }

    /// The level's stamp, in the engine's word: critical in red, high in amber, medium in ink, keep muted so it recedes.
    public static func stamp(_ level: RemovalLevel) -> StatusStamp {
        let tone: StampTone
        switch level {
        case .critical: tone = .red
        case .high: tone = .amber
        case .medium: tone = .ink
        case .keep: tone = .muted
        }
        return StatusStamp(text: AdvisorText.name(level), tone: tone)
    }

    /// The verdict's stamp, in the engine's words: ending early in red, not extending in amber, making permanent in
    /// ink, keeping to the end muted so it recedes.
    public static func stamp(_ verdict: LoanVerdict) -> StatusStamp {
        let tone: StampTone
        switch verdict {
        case .endEarly: tone = .red
        case .doNotExtend: tone = .amber
        case .keepToEnd: tone = .muted
        case .makePermanent: tone = .ink
        }
        return StatusStamp(text: AdvisorText.name(verdict), tone: tone)
    }

    /// The sheet for `report`, with each player's squad and age from `squads` and `ages`. The average ability is shown
    /// to the nearest whole number, and only when the report has one.
    public static func sheet(_ report: RemovalReport, squads: [PlayerID: Squad], ages: [PlayerID: Int]) -> RemovalSheet {
        let average = report.squadAverageAbility.map {
            RemovalFigure(label: averageLabel, figure: String(Int($0.rounded())))
        }
        let wages = RemovalFigure(label: wagesLabel, figure: Display.perWeek(report.weeklyWagesAtStake))
        return RemovalSheet(
            figures: [average].compactMap { $0 } + [wages],
            rows: report.advice.map { RemovalRow($0, squad: squads[$0.player], age: ages[$0.player]) },
            loans: report.loans.map(LoanBlock.init))
    }
}

extension AppModel {
    /// The Player Removal screen's sheet for `report`, each player's squad and age as imported.
    public func removalSheet(_ report: AdvisorsReport) -> RemovalSheet {
        let players = Dictionary(squad.book.allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return RemovalPresentation.sheet(report.removal, squads: players.mapValues(\.squad), ages: players.mapValues(\.age))
    }
}
