import Foundation
import LineupEngine

/// How Match Selection writes names and figures.
public enum MatchText {
    /// The last word of a full name, as a token on the pitch shows it: "Dillon De Silva" is "Silva". A one-word name is
    /// itself. Particles are not looked for.
    public static func surname(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? name
    }

    /// A rating or a value: "124.4", as the engine writes them in its reasons.
    public static func oneDecimal(_ x: Double) -> String { String(format: "%.1f", x) }

    /// A fitness factor: "×0.95", as the engine writes them in its reasons.
    public static func factor(_ x: Double) -> String { "×" + String(format: "%.2f", x) }

    /// Condition or sharpness: a whole percentage rounded down.
    public static func percent(_ fraction: Double) -> String { Display.percent(fraction) }
}

/// The two views of a plan on Match Selection.
public enum MatchView: CaseIterable, Hashable, Sendable {
    case teamSheet, starts

    public var title: String {
        switch self {
        case .teamSheet: "Team sheet"
        case .starts: "Starts"
        }
    }
}

// MARK: Tokens

/// A mark on a player's token.
public enum TokenMark: Hashable, Sendable {
    /// The owner fixed him in the slot.
    case override
    /// Out of position, or chosen over a rule.
    case caution
    /// From a youth squad.
    case youth(Squad)

    /// What a youth mark says on the token.
    public var badgeText: String {
        switch self {
        case .override, .caution, .youth(.firstTeam): ""
        case .youth(.u21): "U21"
        case .youth(.u18): "U18"
        }
    }

    /// The marks for a pick, in the order a token shows them: override, caution, youth.
    public static func marks(isOverride: Bool, warnings: [PickWarning], squad: Squad?) -> [TokenMark] {
        var marks: [TokenMark] = []
        if isOverride { marks.append(.override) }
        if !warnings.isEmpty { marks.append(.caution) }
        switch squad {
        case .u21?: marks.append(.youth(.u21))
        case .u18?: marks.append(.youth(.u18))
        case .firstTeam?, nil: break
        }
        return marks
    }

    /// One line of the key under the pitch.
    public struct KeyEntry: Hashable, Sendable {
        public let mark: TokenMark
        public let text: String
    }

    /// What each kind of mark means, in the order a token shows them.
    public static let key: [KeyEntry] = [
        KeyEntry(mark: .override, text: "Chosen by you"),
        KeyEntry(mark: .caution, text: "Out of position, or a rule overridden"),
        KeyEntry(mark: .youth(.u21), text: "From the U21s or U18s"),
    ]
}

/// What a token on the pitch shows for one starter.
public struct TokenContent: Identifiable, Equatable, Sendable {
    public var id: SlotID { slot }
    public let slot: SlotID
    public var slotText: String { slot.displayName }
    public let player: PlayerID
    /// His full name, for the token's help.
    public let name: String
    public let surname: String
    /// His match-day value to one decimal place; nil for a confirmed lineup.
    public let value: String?
    public let marks: [TokenMark]
}

// MARK: The selected pick

/// One figure in a pick's detail: a label, the figure, and for fitness the factor it gives.
public struct PickFigure: Equatable, Sendable, Identifiable {
    public var id: String { label }
    public let label: String
    public let figure: String?
    public let factor: String?

    public init(label: String, figure: String?, factor: String?) {
        self.label = label; self.figure = figure; self.factor = factor
    }
}

/// Everything the detail beside the pitch shows for one pick.
public struct PickDetail: Equatable, Sendable {
    public let slot: SlotID
    public let player: PlayerID
    public let name: String
    public let squadText: String
    public let slotText: String
    /// The role in each phase, and where he plays it.
    public let roles: [String]
    /// Rating, condition, sharpness and jadedness on the day with their factors, then the match-day value.
    public let figures: [PickFigure]
    /// A sentence for each way he is out of position.
    public let cautions: [String]
    /// The engine's reasons, as written.
    public let reasons: [String]
    public let isOverride: Bool

    /// A line for each phase he is out of position in. A rule overridden gets none: the engine's last reason already
    /// says "Chosen by you, overriding: …".
    public static func cautions(_ warnings: [PickWarning]) -> [String] {
        warnings.compactMap { warning in
            switch warning {
            case .outOfPosition(let phase, let familiarity):
                "Out of position \(phase == .inPossession ? "in possession" : "out of possession"): familiarity \(familiarity)."
            case .overridesRule: nil
            }
        }
    }
}

// MARK: Lists

/// One player the engine left out, with his slot and its reason.
public struct LeftOutRow: Identifiable, Equatable, Sendable {
    public var id: PlayerID { player }
    public let player: PlayerID
    public let name: String
    public let slotText: String
    /// The engine's reason, as written.
    public let reason: String

    public static func rows(_ omissions: [Omission]) -> [LeftOutRow] {
        omissions.map { LeftOutRow(player: $0.player, name: $0.name, slotText: $0.slot.displayName, reason: $0.reason) }
    }
}

/// One player the owner left out of the fixture.
public struct RejectedRow: Identifiable, Equatable, Sendable {
    public var id: PlayerID { player }
    public let player: PlayerID
    public let name: String

    /// The players by name, then key; one no longer in the squads is called so, after the others.
    public static func rows(_ rejected: Set<PlayerID>, names: [PlayerID: String]) -> [RejectedRow] {
        let known = rejected.compactMap { id in names[id].map { RejectedRow(player: id, name: $0) } }
            .sorted { ($0.name, $0.player.key) < ($1.name, $1.player.key) }
        let gone = rejected.filter { names[$0] == nil }.sorted { $0.key < $1.key }
            .map { RejectedRow(player: $0, name: "A player no longer in the squads") }
        return known + gone
    }
}

/// One candidate in the picker.
public struct CandidateRow: Identifiable, Equatable, Sendable {
    public var id: PlayerID { player }
    public let player: PlayerID
    public let name: String
    public let squadText: String
    /// His full-fitness rating to one decimal place, or a dash when it cannot be worked out.
    public let ratingText: String
    /// Why he cannot play, in the engine's words.
    public let unavailable: String?
    /// He is the pick in the slot now.
    public let isCurrent: Bool
    public var canChoose: Bool { unavailable == nil }

    public static func rows(_ candidates: [Candidate], current: PlayerID?) -> [CandidateRow] {
        candidates.map { candidate in
            CandidateRow(player: candidate.player, name: candidate.name, squadText: candidate.squad.displayName,
                         ratingText: candidate.rating.map(MatchText.oneDecimal) ?? "—",
                         unavailable: candidate.unavailable, isCurrent: candidate.player == current)
        }
    }
}

// MARK: The fixture strip

/// One fixture in the strip across the top.
public struct FixtureCell: Identifiable, Equatable, Sendable {
    public enum State: Equatable, Sendable { case planned, confirmed, missed }

    public let id: FixtureID
    public let dateText: String
    public let opponentText: String
    public let importance: Importance
    public let state: State
    /// "Confirmed" or "Missed"; nil for a planned fixture.
    public let stateText: String?

    public init(_ plan: FixturePlan) {
        id = plan.id
        dateText = DayText.short(plan.fixture.date)
        opponentText = "v \(plan.fixture.opponent)"
        importance = plan.fixture.importance
        switch plan.body {
        case .planned: state = .planned; stateText = nil
        case .confirmed: state = .confirmed; stateText = "Confirmed"
        case .missed: state = .missed; stateText = "Missed"
        }
    }
}

// MARK: Starts

/// The plan as a grid: a row for each player who starts at least once, a column for each fixture with a lineup.
public struct StartsGrid: Equatable, Sendable {
    public struct Column: Identifiable, Equatable, Sendable {
        public let id: FixtureID
        public let dateText: String
        public let opponentText: String
        public let isConfirmed: Bool
    }

    public struct Row: Identifiable, Equatable, Sendable {
        public var id: PlayerID { player }
        public let player: PlayerID
        public let name: String
        /// His slot in each column, or a dash.
        public let cells: [String]
        public let starts: Int
    }

    /// What a cell shows when he does not start.
    public static let noStart = "–"

    public let columns: [Column]
    /// By the slot of each player's first start in `SlotID` order (goalkeeper first), then name, then key.
    public let rows: [Row]

    public init(plans: [FixturePlan]) {
        var columns: [Column] = []
        var lineups: [[SlotID: PlayerID]] = []
        var names: [PlayerID: String] = [:]
        for plan in plans {
            let starters: [SlotID: PlayerID]
            switch plan.body {
            case .planned(let lineup, _):
                starters = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.player) })
                for pick in lineup.picks where names[pick.player] == nil { names[pick.player] = pick.name }
            case .confirmed(let record):
                starters = record.lineup.starters
                for id in SlotID.allCases.compactMap({ starters[$0] }) where names[id] == nil {
                    names[id] = record.names[id] ?? id.key
                }
            case .missed:
                continue
            }
            columns.append(Column(id: plan.id, dateText: DayText.short(plan.fixture.date),
                                  opponentText: "v \(plan.fixture.opponent)", isConfirmed: plan.body.isConfirmed))
            lineups.append(starters)
        }

        var firstSlot: [PlayerID: SlotID] = [:]
        for starters in lineups {
            for slot in SlotID.allCases {
                if let player = starters[slot], firstSlot[player] == nil { firstSlot[player] = slot }
            }
        }
        let order = Dictionary(uniqueKeysWithValues: SlotID.allCases.enumerated().map { ($1, $0) })
        let players = firstSlot.keys.sorted {
            (order[firstSlot[$0]!]!, names[$0] ?? "", $0.key) < (order[firstSlot[$1]!]!, names[$1] ?? "", $1.key)
        }
        rows = players.map { player in
            let slots = lineups.map { starters in SlotID.allCases.first { starters[$0] == player } }
            return Row(player: player, name: names[player] ?? player.key,
                       cells: slots.map { $0?.displayName ?? Self.noStart }, starts: slots.compactMap { $0 }.count)
        }
        self.columns = columns
    }
}

extension FixturePlan.Body {
    var isConfirmed: Bool {
        if case .confirmed = self { true } else { false }
    }
}

// MARK: The screen

/// What Match Selection shows instead of a plan: what is missing or why the plan stopped, and where to fix it.
public struct NotReady: Equatable, Sendable {
    public let message: String
    /// Sentences to show as written: the tactics' problems, or the plan's failures.
    public let problems: [String]
    /// The problems are failures, shown in claret; otherwise cautions.
    public let isFailure: Bool
    public let action: String
    public let screen: Screen
}

public enum MatchPresentation {
    /// The fixture chosen when the screen opens: the first neither confirmed nor missed, else the last.
    public static func initialFixture(in plans: [FixturePlan]) -> FixtureID? {
        (plans.first { if case .planned = $0.body { true } else { false } } ?? plans.last)?.id
    }

    /// The plan for the chosen fixture while it is in the plan, else for the one `initialFixture` chooses.
    public static func chosen(_ id: FixtureID?, in plans: [FixturePlan]) -> FixturePlan? {
        plans.first { $0.id == id } ?? plans.first { $0.id == initialFixture(in: plans) }
    }

    /// "v Opponent A, Saturday 14 November 2026".
    public static func heading(_ plan: FixturePlan) -> String {
        "v \(plan.fixture.opponent), \(DayText.long(plan.fixture.date))"
    }

    /// "Tactic: <name>", or nil when the fixture has none.
    public static func tacticLine(_ plan: FixturePlan) -> String? {
        plan.tacticName.isEmpty ? nil : "Tactic: \(plan.tacticName)"
    }

    public static func deletedTacticLine(_ plan: FixturePlan) -> String? {
        plan.usesPrimaryBecauseItsTacticWasDeleted ? "This match's tactic was deleted, so the primary tactic is used." : nil
    }

    /// The screen that fixes a failed plan: Fixtures for two matches on one day, which the app itself reports;
    /// Settings for anything the engine reports.
    public static func screenToFix(_ failure: String) -> Screen {
        failure.hasSuffix(AppModel.sameDayAdvice) ? .fixtures : .settings
    }

    /// "Go to Fixtures".
    public static func goTo(_ screen: Screen) -> String { "Go to \(screen.title)" }

    /// What to show in place of a plan; nil when the plan is ready.
    public static func notReady(_ state: PlanState) -> NotReady? {
        switch state {
        case .ready:
            return nil
        case .needsSquad:
            return NotReady(message: "No squad yet. Import your first team on the Squad screen to get a lineup.",
                            problems: [], isFailure: false, action: goTo(.squad), screen: .squad)
        case .needsTactic(let problems) where problems.isEmpty:
            return NotReady(message: "No tactic yet. Add one on the Tactics screen to get a lineup.",
                            problems: [], isFailure: false, action: goTo(.tactics), screen: .tactics)
        case .needsTactic(let problems):
            return NotReady(message: "A tactic the fixtures use cannot be used, so nothing is planned.",
                            problems: problems, isFailure: false, action: goTo(.tactics), screen: .tactics)
        case .needsFixtures:
            return NotReady(message: "No fixtures yet. Add the next few matches on the Fixtures screen.",
                            problems: [], isFailure: false, action: goTo(.fixtures), screen: .fixtures)
        case .failed(let failures):
            let screen: Screen = failures.contains { screenToFix($0) == .fixtures } ? .fixtures : .settings
            return NotReady(message: "The plan could not be worked out.", problems: failures, isFailure: true,
                            action: goTo(screen), screen: screen)
        }
    }

    /// The candidate picker's title.
    public static func pickerTitle(_ slot: SlotID) -> String { "Choose who plays at \(slot.displayName)" }

    /// What a confirmed lineup is, with the tactic it was confirmed with; nil for any other.
    public static func confirmedLine(_ plan: FixturePlan) -> String? {
        guard case .confirmed(let record) = plan.body else { return nil }
        return "Confirmed as played, with \(record.tacticName)."
    }

    /// The line under "Confirm this lineup".
    public static let confirmExplanation = "Locks this eleven as played. Later fixtures count it."
}

extension AppModel {
    /// A token for each starter: a planned lineup's picks with their values and marks, or a confirmed lineup's
    /// starters with the names it was confirmed with; in `SlotID` order. None for a missed fixture.
    public func tokens(for plan: FixturePlan) -> [TokenContent] {
        switch plan.body {
        case .planned(let lineup, _):
            let squads = squadsByPlayer
            return lineup.picks.map { pick in
                TokenContent(slot: pick.slot, player: pick.player, name: pick.name, surname: MatchText.surname(pick.name),
                             value: MatchText.oneDecimal(pick.value),
                             marks: TokenMark.marks(isOverride: pick.isOverride, warnings: pick.warnings,
                                                    squad: squads[pick.player]))
            }
        case .confirmed(let record):
            return SlotID.allCases.compactMap { slot in
                record.lineup.starters[slot].map { player in
                    let name = record.names[player] ?? player.key
                    return TokenContent(slot: slot, player: player, name: name, surname: MatchText.surname(name),
                                        value: nil, marks: [])
                }
            }
        case .missed:
            return []
        }
    }

    /// The detail for the pick in `slot` of a planned lineup; nil when the slot has no pick.
    public func pickDetail(at slot: SlotID, in plan: FixturePlan) -> PickDetail? {
        guard case .planned(let lineup, let fitness) = plan.body,
              let pick = lineup.picks.first(where: { $0.slot == slot }) else { return nil }
        let player = squad.book.allPlayers.first { $0.id == pick.player }
        let onTheDay = fitness[pick.player] ?? player.map(ProjectedFitness.init)
        func label(_ name: String) -> String { plan.fitnessIsProjected ? "Projected " + name.lowercased() : name }

        var roles: [String] = []
        if let tactic = tactic(for: plan.fixture)?.tactic {
            if let role = tactic.inPossession[slot] {
                roles.append("In possession: \(role) at \(slot.displayName)")
            }
            if let target = tactic.mapping[slot], let role = tactic.outOfPossession[target] {
                roles.append("Out of possession: \(role) at \(target.displayName)")
            }
        }
        return PickDetail(
            slot: slot, player: pick.player, name: pick.name,
            squadText: player?.squad.displayName ?? "No longer in the squads", slotText: slot.displayName, roles: roles,
            figures: [
                PickFigure(label: "Rating", figure: MatchText.oneDecimal(pick.rating.value), factor: nil),
                PickFigure(label: label("Condition"), figure: onTheDay.map { MatchText.percent($0.condition) },
                           factor: MatchText.factor(pick.fitness.condition)),
                PickFigure(label: label("Sharpness"), figure: onTheDay.map { MatchText.percent($0.sharpness) },
                           factor: MatchText.factor(pick.fitness.sharpness)),
                PickFigure(label: label("Jadedness"), figure: onTheDay.map { "\(Int($0.jadedness.rounded()))" },
                           factor: MatchText.factor(pick.fitness.jadedness)),
                PickFigure(label: "Match-day value", figure: MatchText.oneDecimal(pick.value), factor: nil),
            ],
            cautions: PickDetail.cautions(pick.warnings), reasons: pick.reasons, isOverride: pick.isOverride)
    }

    /// The players the owner left out of the fixture, by name.
    public func rejectedRows(in plan: FixturePlan) -> [RejectedRow] {
        RejectedRow.rows(plan.fixture.rejected, names: Dictionary(squad.book.allPlayers.map { ($0.id, $0.name) },
                                                                  uniquingKeysWith: { first, _ in first }))
    }

    /// The candidates for the slot, best first, with the pick there now marked.
    public func candidateRows(for slot: SlotID, in fixture: FixtureID) -> [CandidateRow] {
        let current: PlayerID? = {
            guard case .ready(let plans) = planState, let plan = plans.first(where: { $0.id == fixture }),
                  case .planned(let lineup, _) = plan.body else { return nil }
            return lineup.picks.first { $0.slot == slot }?.player
        }()
        return CandidateRow.rows(candidates(for: slot, in: fixture), current: current)
    }

    private var squadsByPlayer: [PlayerID: Squad] {
        Dictionary(squad.book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })
    }
}
