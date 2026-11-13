import Foundation
import LineupEngine

/// How Match Selection writes names and figures.
public enum MatchText {
    /// The surname a token on the pitch shows: the last word of the name, with up to two particles before it
    /// ("Dillon De Silva" is "De Silva", "Jan van der Berg" is "van der Berg"). A one-word name is itself.
    public static func surname(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace).map(String.init)
        guard var first = words.indices.last else { return name }
        while first > 0, words.count - first < 3, particles.contains(words[first - 1].lowercased()) {
            first -= 1
        }
        return words[first...].joined(separator: " ")
    }

    /// Words that belong to the surname after them.
    static let particles: Set<String> = ["de", "da", "di", "do", "dos", "del", "della", "van", "von", "der", "den",
                                         "la", "le", "el", "al", "bin", "ibn", "mac", "st"]

    /// Who a starter is when his name is not known: a confirmed lineup's player since removed from the squads.
    public static let unknownPlayer = "A player no longer in the squads"
    /// That player's token.
    public static let unknownSurname = "Unknown"

    /// What a figure shows when it is not known.
    public static let noFigure = "—"

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

    /// The engine's sentence for each phase he is out of position in. A rule overridden gets none: the engine's last
    /// reason already says "Chosen by you, overriding: …".
    public static func cautions(_ warnings: [PickWarning], parameters: EngineParameters, projected: Bool = false) -> [String] {
        warnings.compactMap { warning in
            switch warning {
            case .outOfPosition: ErrorDescriptions.describe(warning, parameters: parameters, projected: projected)
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
            .map { RejectedRow(player: $0, name: MatchText.unknownPlayer) }
        return known + gone
    }
}

/// One candidate in the picker.
public struct CandidateRow: Identifiable, Equatable, Sendable {
    public var id: PlayerID { player }
    public let player: PlayerID
    public let name: String
    public let squadText: String
    /// His full-fitness rating to one decimal place, or a dash when it cannot be worked out; nil when the picker shows
    /// no ratings, as for a missed fixture's remembered eleven.
    public let ratingText: String?
    /// Why he cannot play, in the engine's words.
    public let unavailable: String?
    /// He is the pick in the slot now.
    public let isCurrent: Bool
    /// Where he is in the eleven now, when that is another slot.
    public let note: String?
    public var canChoose: Bool { unavailable == nil }

    public init(player: PlayerID, name: String, squadText: String, ratingText: String?, unavailable: String?,
                isCurrent: Bool, note: String? = nil) {
        self.player = player; self.name = name; self.squadText = squadText; self.ratingText = ratingText
        self.unavailable = unavailable; self.isCurrent = isCurrent; self.note = note
    }

    public static func rows(_ candidates: [Candidate], current: PlayerID?) -> [CandidateRow] {
        candidates.map { candidate in
            CandidateRow(player: candidate.player, name: candidate.name, squadText: candidate.squad.displayName,
                         ratingText: candidate.rating.map(MatchText.oneDecimal) ?? "—",
                         unavailable: candidate.unavailable, isCurrent: candidate.player == current)
        }
    }

    /// Rows for a remembered eleven: no ratings; the one in `slot` marked, and those elsewhere in the eleven saying where.
    public static func rows(_ candidates: [Candidate], in eleven: PlannedEleven, slot: SlotID) -> [CandidateRow] {
        let slotOf = Dictionary(eleven.starters.map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return candidates.map { candidate in
            let at = slotOf[candidate.player]
            return CandidateRow(player: candidate.player, name: candidate.name, squadText: candidate.squad.displayName,
                                ratingText: nil, unavailable: nil, isCurrent: at == slot,
                                note: at.flatMap { $0 == slot ? nil : "At \($0.longName) in this eleven" })
        }
    }
}

/// What the candidate picker says above its list.
public struct PickerText: Equatable, Sendable {
    public let title: String
    public let explanation: String
    /// The heading over the ratings; nil when the picker shows none.
    public let ratingHeading: String?

    /// For a planned lineup: who can play, best first at full fitness.
    public static func planned(_ slot: SlotID) -> PickerText {
        PickerText(title: MatchPresentation.pickerTitle(slot),
                   explanation: "Those who can play, best first at full fitness; then those who cannot, with the reason. "
                       + "Choosing a player fixes him here for this match.",
                   ratingHeading: "Rating at full fitness")
    }

    /// For a missed fixture's remembered eleven: who really started there.
    public static func remembered(_ slot: SlotID) -> PickerText {
        PickerText(title: "Who started at \(slot.longName)?",
                   explanation: "Choose who played here. If he is elsewhere in this eleven, the two swap.",
                   ratingHeading: nil)
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

    public struct Cell: Equatable, Sendable {
        /// His slot, or a dash.
        public let text: String
        public let isStart: Bool
    }

    public struct Row: Identifiable, Equatable, Sendable {
        public var id: PlayerID { player }
        public let player: PlayerID
        public let name: String
        /// One per column.
        public let cells: [Cell]
        public let starts: Int
    }

    /// What a cell shows when he does not start.
    static let noStart = "–"

    public let columns: [Column]
    /// By the slot of each player's first start in `SlotID` order (goalkeeper first), then name, then key.
    public let rows: [Row]

    /// - Parameter names: names for starters a confirmed lineup did not record, such as the squads' now.
    public init(plans: [FixturePlan], names known: [PlayerID: String] = [:]) {
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
                    names[id] = record.names[id]
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
        /// The name the lineups recorded, else the squads' name, else the words for a player no longer in the squads.
        func name(_ player: PlayerID) -> String { names[player] ?? known[player] ?? MatchText.unknownPlayer }
        let players = firstSlot.keys.sorted {
            (order[firstSlot[$0]!]!, name($0), $0.key) < (order[firstSlot[$1]!]!, name($1), $1.key)
        }
        rows = players.map { player in
            let slots = lineups.map { starters in SlotID.allCases.first { starters[$0] == player } }
            return Row(player: player, name: name(player),
                       cells: slots.map { Cell(text: $0?.displayName ?? Self.noStart, isStart: $0 != nil) },
                       starts: slots.compactMap { $0 }.count)
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

/// The pick the owner selected: in which fixture, which slot, and who was in it then.
public struct PickSelection: Equatable, Sendable {
    public let fixture: FixtureID
    public let slot: SlotID
    public let player: PlayerID

    public init(fixture: FixtureID, slot: SlotID, player: PlayerID) {
        self.fixture = fixture; self.slot = slot; self.player = player
    }
}

public enum MatchPresentation {
    /// The fixture chosen when the screen opens: the first neither confirmed nor missed, else the last.
    public static func initialFixture(in plans: [FixturePlan]) -> FixtureID? {
        (plans.first { if case .planned = $0.body { true } else { false } } ?? plans.last)?.id
    }

    /// The fixture shown after confirming one: the next with a planned lineup, the one that can now be confirmed; or
    /// the confirmed one itself when none is left to plan.
    public static func fixtureAfterConfirming(_ confirmed: FixtureID, in plans: [FixturePlan]) -> FixtureID {
        plans.first { if case .planned = $0.body { true } else { false } }?.id ?? confirmed
    }

    /// The pick in `slot` of a planned lineup, to select; nil when the slot has no pick.
    public static func selection(at slot: SlotID, in plan: FixturePlan) -> PickSelection? {
        guard case .planned(let lineup, _) = plan.body, let pick = lineup.picks.first(where: { $0.slot == slot }) else {
            return nil
        }
        return PickSelection(fixture: plan.id, slot: slot, player: pick.player)
    }

    /// The selected slot in the fixture shown: the selection's while it is this fixture's and the same player is still
    /// in the slot; nil once another fixture is shown or a replan puts someone else there.
    public static func selectedSlot(_ selection: PickSelection?, in plan: FixturePlan) -> SlotID? {
        guard let selection, selection.fixture == plan.id,
              MatchPresentation.selection(at: selection.slot, in: plan) == selection else { return nil }
        return selection.slot
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
        case .failed(let failures, let screen):
            return NotReady(message: "The plan could not be worked out.", problems: failures, isFailure: true,
                            action: goTo(screen), screen: screen)
        }
    }

    /// The candidate picker's title.
    public static func pickerTitle(_ slot: SlotID) -> String { "Choose who plays at \(slot.longName)" }

    /// What a confirmed lineup is, with the tactic it was confirmed with; nil for any other.
    public static func confirmedLine(_ plan: FixturePlan) -> String? {
        guard case .confirmed(let record) = plan.body else { return nil }
        return "Confirmed as played, with \(record.tacticName)."
    }

    /// The button that confirms the fixture, and the line under it: for a planned lineup, "Confirm this lineup"; for a
    /// missed fixture's remembered eleven, "Confirm this eleven as played".
    public static func confirmButton(for plan: FixturePlan) -> (title: String, explanation: String) {
        switch plan.body {
        case .missed:
            ("Confirm this eleven as played", "Records who started. Later fixtures count their starts.")
        case .planned, .confirmed:
            ("Confirm this lineup", "Locks this eleven as played. Later fixtures count it.")
        }
    }

    /// The line beside a remembered eleven's pitch.
    public static let rememberedHint = "Click a player on the pitch to change who started there."
}

extension AppModel {
    /// A token for each starter: a planned lineup's picks with their values and marks, or a confirmed lineup's or a
    /// missed fixture's remembered starters with the names recorded; in `SlotID` order. None for a missed fixture with
    /// no remembered eleven.
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
            return namedTokens(record.lineup.starters, names: record.names)
        case .missed(let eleven?):
            return namedTokens(eleven.starters, names: eleven.names)
        case .missed(nil):
            return []
        }
    }

    /// Tokens with names only, in `SlotID` order: the recorded name, else the squads' name, else the words for a
    /// player no longer in the squads.
    private func namedTokens(_ starters: [SlotID: PlayerID], names: [PlayerID: String]) -> [TokenContent] {
        let current = namesByPlayer
        return SlotID.allCases.compactMap { slot in
            starters[slot].map { player in
                if let name = names[player] ?? current[player] {
                    return TokenContent(slot: slot, player: player, name: name, surname: MatchText.surname(name),
                                        value: nil, marks: [])
                }
                return TokenContent(slot: slot, player: player, name: MatchText.unknownPlayer,
                                    surname: MatchText.unknownSurname, value: nil, marks: [])
            }
        }
    }

    /// The detail for the pick in `slot` of a planned lineup; nil when the slot has no pick.
    public func pickDetail(at slot: SlotID, in plan: FixturePlan) -> PickDetail? {
        guard case .planned(let lineup, let fitness) = plan.body,
              let pick = lineup.picks.first(where: { $0.slot == slot }) else { return nil }
        let player = squad.book.allPlayers.first { $0.id == pick.player }
        // Only the plan's own figures for the day: without them a dash, never today's figures under its label.
        let onTheDay = fitness[pick.player]
        func label(_ name: String) -> String { plan.fitnessIsProjected ? "Projected " + name.lowercased() : name }

        var roles: [String] = []
        if let tactic = tactic(for: plan.fixture)?.tactic {
            if let role = tactic.inPossession[slot] {
                roles.append("In possession: \(role) (\(slot.longName))")
            }
            if let target = tactic.mapping[slot], let role = tactic.outOfPossession[target] {
                roles.append("Out of possession: \(role) (\(target.longName))")
            }
        }
        return PickDetail(
            slot: slot, player: pick.player, name: pick.name,
            squadText: player?.squad.displayName ?? "No longer in the squads", slotText: slot.displayName, roles: roles,
            figures: [
                PickFigure(label: "Rating", figure: MatchText.oneDecimal(pick.rating.value), factor: nil),
                PickFigure(label: label("Condition"), figure: onTheDay.map { MatchText.percent($0.condition) } ?? MatchText.noFigure,
                           factor: MatchText.factor(pick.fitness.condition)),
                PickFigure(label: label("Sharpness"), figure: onTheDay.map { MatchText.percent($0.sharpness) } ?? MatchText.noFigure,
                           factor: MatchText.factor(pick.fitness.sharpness)),
                PickFigure(label: label("Jadedness"), figure: onTheDay.map { "\(Int($0.jadedness.rounded()))" } ?? MatchText.noFigure,
                           factor: MatchText.factor(pick.fitness.jadedness)),
                PickFigure(label: "Match-day value", figure: MatchText.oneDecimal(pick.value), factor: nil),
            ],
            cautions: PickDetail.cautions(pick.warnings, parameters: planParameters, projected: plan.fitnessIsProjected),
            reasons: pick.reasons, isOverride: pick.isOverride)
    }

    /// The players the owner left out of the fixture, by name.
    public func rejectedRows(in plan: FixturePlan) -> [RejectedRow] {
        RejectedRow.rows(plan.fixture.rejected, names: namesByPlayer)
    }

    /// The plan as starts, naming a starter a confirmed lineup did not record by the squads' name for him.
    public func startsGrid(for plans: [FixturePlan]) -> StartsGrid {
        StartsGrid(plans: plans, names: namesByPlayer)
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

    /// The candidates for a slot of a missed fixture's remembered eleven, as the picker lists them.
    public func rememberedCandidateRows(for slot: SlotID, in fixture: FixtureID) -> [CandidateRow] {
        guard let eleven = fixtures.first(where: { $0.id == fixture })?.lastPlanned else { return [] }
        return CandidateRow.rows(rememberedCandidates(for: slot, in: fixture), in: eleven, slot: slot)
    }

    private var namesByPlayer: [PlayerID: String] {
        Dictionary(squad.book.allPlayers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private var squadsByPlayer: [PlayerID: Squad] {
        Dictionary(squad.book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })
    }
}
