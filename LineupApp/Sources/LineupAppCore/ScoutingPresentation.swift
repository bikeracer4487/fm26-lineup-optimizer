import Foundation
import LineupEngine

/// One need at one slot, as the Needs tab lists it: the slot's token and the engine's lines for the need.
public struct NeedRow: Identifiable, Equatable, Sendable {
    public var id: SlotID { slot }
    public let slot: SlotID
    /// The slot's token text: "D L".
    public var slotText: String { slot.displayName }
    /// The line the slot is in, for its magnet's colour.
    public var line: PitchLine { PitchLine(slot) }
    public let lines: [String]
    /// A young player who stays could bring the slot level in time, so the need is drawn muted.
    public let isEased: Bool
}

/// Everything the Needs tab shows for one tactic.
public struct NeedsSheet: Equatable, Sendable {
    /// The engine's line naming who is counted as going; nil for nobody.
    public let goingLine: String?
    /// In the engine's order.
    public let betterPlayers: [NeedRow]
    public let moreDepth: [NeedRow]
    /// The slots with neither need, in the tactic's order.
    public let fine: [SlotID]
    /// How well backed the needs are; nil for FM27 evidence.
    public let evidenceNote: String?

    /// The fine slots as tokens, in the tactic's order.
    public var fineTokens: [ScoutingSlotToken] { fine.map(ScoutingSlotToken.init) }
}

/// A slot's token on the Needs tab: its magnet's colour and "D L".
public struct ScoutingSlotToken: Identifiable, Equatable, Sendable {
    public var id: SlotID { slot }
    public let slot: SlotID
    public var slotText: String { slot.displayName }
    public var line: PitchLine { PitchLine(slot) }

    public init(_ slot: SlotID) {
        self.slot = slot
    }
}

/// One pasted player, as the Candidates tab shows him.
/// Named apart from Match Selection's `CandidateRow`, a player the picker offers for a slot.
public struct ScoutingCandidateRow: Identifiable, Equatable, Sendable {
    /// His key as pasted: two namesakes have a key each.
    public let id: PlayerID
    public let name: String
    public let age: Int
    /// As FMRTE writes them: "D/WB/M L".
    public let positions: String
    /// "Wrexham", "Free agent"; nil when the paste carried no club.
    public let club: String?
    /// "On loan at Barnet"; nil when he is not on loan.
    public let onLoan: String?
    /// "Asking £25,250"; nil when the paste carried no price.
    public let askingPrice: String?
    /// In the paste's currency and FMRTE's period: "£500 a week".
    public let wage: String
    public let isInjured: Bool
    /// How he would stand at his headline slot today; the engine's sentence that he can play no slot when he has none.
    public let todayLines: [String]
    public let laterLines: [String]
    /// "Injury Proneness 16".
    public let cautions: [String]
    /// Each other slot he can play, in the tactic's order, with its lines.
    public let otherSlots: [ScoutingOtherSlot]

    /// What the paste says of him, on one line under his name: "Age 19 · D/WB L · Banbury United · On loan at Barnet ·
    /// Asking £25,250 · £500 a week", leaving out what the paste did not carry.
    public var detailsText: String {
        ([ScoutingPresentation.ageText(age), positions] + [club, onLoan, askingPrice].compactMap { $0 } + [wage])
            .joined(separator: " · ")
    }

    /// Stamped beside his name: injured, which changes nothing else.
    public var stamps: [StatusStamp] { isInjured ? [ElevensPresentation.injuredStamp] : [] }

    /// The lines the row shows, open or closed: everything but his other slots, which show while it is open; in the
    /// rest part, while closed, only his first line today (and his cautions, which always show).
    public func linesShown(inRest: Bool, isOpen: Bool) -> ScoutingRowLines {
        let brief = inRest && !isOpen
        return ScoutingRowLines(today: brief ? Array(todayLines.prefix(1)) : todayLines,
                                later: brief ? [] : laterLines, otherSlots: isOpen ? otherSlots : [])
    }

    /// Whether opening the row shows anything more: his other slots, and, in the rest part, where a closed row shows
    /// only his first line today and his cautions, the lines it leaves out.
    public func opens(inRest: Bool) -> Bool {
        !otherSlots.isEmpty || (inRest && (todayLines.count > 1 || !laterLines.isEmpty))
    }
}

/// One slot a candidate can play that is not his headline: the engine's lines for it, drawn together.
public struct ScoutingOtherSlot: Identifiable, Equatable, Sendable {
    public var id: SlotID { slot }
    public let slot: SlotID
    /// His lines for today there, then one for later when he has a reach; each names the position.
    public let lines: [String]

    public init(slot: SlotID, lines: [String]) {
        self.slot = slot
        self.lines = lines
    }
}

/// The lines a candidate's row shows under his name, by label; an empty list shows no label.
public struct ScoutingRowLines: Equatable, Sendable {
    public let today: [String]
    public let later: [String]
    public let otherSlots: [ScoutingOtherSlot]
}

/// One group of candidates: those answering one need at one slot, or one of the two parts that are a group each.
public struct CandidateGroupRows: Identifiable, Equatable, Sendable {
    public let id: String
    /// The part's name when this group is the first of its part; nil otherwise.
    public let partTitle: String?
    /// "Left back · needs a better player"; nil for a part that is one group.
    public let heading: String?
    /// The last part, "The rest": it starts closed behind a line saying how many are in it, and its rows show only
    /// their first line today and their cautions until opened.
    public let isRest: Bool
    public let rows: [ScoutingCandidateRow]
    /// The line the group is closed behind, "6 more players", for the rest; nil for a group that is never closed.
    public let closedLine: String?

    /// Whether the group's rows show: always, except for the rest part while it is closed.
    public func showsRows(restOpen: Bool) -> Bool { !isRest || restOpen }
}

/// Everything the Candidates tab shows for the held players.
public struct CandidatesSheet: Equatable, Sendable {
    /// "6 players read."
    public let readLine: String
    /// The players left out as already the owner's; nil for none.
    public let leftOutLine: String?
    /// In the engine's order, without empty groups.
    public let groups: [CandidateGroupRows]
    /// How well backed the candidates shown are, once for them all; nil for FM27 evidence or none shown.
    public let evidenceNote: String?

    /// Every candidate's row, so every row can be opened at once.
    public var rowIDs: Set<PlayerID> { Set(groups.flatMap(\.rows).map(\.id)) }
}

/// What the Scouting screen shows, in the engine's words; Core holds only the labels.
public enum ScoutingPresentation {
    public static let pasteButton = "Paste players"
    public static let clearButton = "Clear"
    public static let nothingPasted = "Copy the rows of a search or a shortlist in FMRTE, then paste them here."
    public static let fineHeading = "Fine"
    public static let betterPlayersHeading = AdvisorText.betterPlayersHeading
    public static let moreDepthHeading = AdvisorText.moreDepthHeading
    /// The labels before a candidate's lines.
    public static let todayLabel = AdvisorText.name(CandidateOrder.today)
    public static let laterLabel = AdvisorText.name(CandidateOrder.later)
    public static let otherSlotsLabel = "Other slots"
    public static let cautionsLabel = "Cautions"
    /// Before the Today and Later control, whose words are also the row labels.
    public static let orderLabel = "Order by"
    /// Above the engine's sentences when the needs or the candidates for the tactic shown cannot be worked out.
    public static let failedLead = "Scouting cannot be worked out for this tactic."

    /// The Today and Later control, in the engine's words.
    public static var orderChoices: [(order: CandidateOrder, title: String)] {
        CandidateOrder.allCases.map { ($0, AdvisorText.name($0)) }
    }

    /// "Age 19".
    public static func ageText(_ age: Int) -> String { "Age \(age)" }

    /// "6 more players", "1 more player".
    public static func restLine(_ count: Int) -> String { "\(count) more \(count == 1 ? "player" : "players")" }

    /// What a click on the rest part's line does.
    public static func restHelp(_ isOpen: Bool) -> String { isOpen ? "Hide them" : "Show them" }

    /// What a click on a candidate's name does.
    public static func rowHelp(_ isOpen: Bool) -> String { isOpen ? "Show less" : "Show his other slots" }

    public static func needsSheet(_ needs: ScoutingNeeds, parameters: EngineParameters) -> NeedsSheet {
        NeedsSheet(
            goingLine: AdvisorText.countedAsGoing(needs.going),
            betterPlayers: needs.betterPlayers.map { need in
                NeedRow(slot: need.slot, lines: AdvisorText.betterPlayerLines(need), isEased: need.easedBy != nil)
            },
            moreDepth: needs.moreDepth.map { need in
                NeedRow(slot: need.depth.slot, lines: AdvisorText.depthNeedLines(need, parameters: parameters),
                        isEased: false)
            },
            fine: needs.fine,
            evidenceNote: AdvisorText.note(for: needs.basis))
    }

    /// The held players' sheet: `pasted` is how many players the paste held, and `money` how it wrote money.
    public static func candidatesSheet(_ report: CandidatesReport, order: CandidateOrder, pasted: Int,
                                       money: MoneyStyle) -> CandidatesSheet {
        var partsSeen: Set<CandidatePart> = []
        let groups = report.groups(orderedBy: order).map { group -> CandidateGroupRows in
            let isFirstOfPart = partsSeen.insert(group.part).inserted
            let heading = group.slot.flatMap { slot in
                group.answer.map { AdvisorText.groupHeading(slot: slot, answer: $0) }
            }
            let id = [group.part.rawValue, group.slot?.rawValue, group.answer?.rawValue].compactMap { $0 }
                .joined(separator: "-")
            let isRest: Bool
            switch group.part {
            case .answersToday, .answersLater, .wouldStartElsewhere, .couldPassElsewhere: isRest = false
            case .rest: isRest = true
            }
            return CandidateGroupRows(id: id, partTitle: isFirstOfPart ? AdvisorText.name(group.part) : nil,
                                      heading: heading, isRest: isRest, rows: group.candidates.map { row($0, money: money) },
                                      closedLine: isRest ? restLine(group.candidates.count) : nil)
        }
        return CandidatesSheet(readLine: AdvisorText.playersRead(pasted),
                               leftOutLine: AdvisorText.leftOutAlreadyYours(report.leftOut), groups: groups,
                               evidenceNote: report.basis.flatMap(AdvisorText.note(for:)))
    }

    static func row(_ candidate: LineupEngine.Candidate, money: MoneyStyle) -> ScoutingCandidateRow {
        let player = candidate.player
        let headline = candidate.headline.flatMap { slot in candidate.slots.first { $0.slot == slot } }
        return ScoutingCandidateRow(
            id: candidate.id, name: player.name, age: player.age, positions: player.positionsText,
            club: AdvisorText.club(of: player), onLoan: player.loanedTo.map(AdvisorText.onLoan(at:)),
            askingPrice: player.askingPrice.map { AdvisorText.askingPrice($0, money) },
            wage: Display.wage(perWeek: player.wagePerWeek, money), isInjured: player.isInjured,
            todayLines: headline.map(AdvisorText.todayLines) ?? [AdvisorText.playsNoSlot],
            laterLines: AdvisorText.laterLines(candidate),
            cautions: candidate.cautions.map(AdvisorText.caution),
            otherSlots: candidate.slots.filter { $0.slot != headline?.slot }.map {
                ScoutingOtherSlot(slot: $0.slot, lines: AdvisorText.otherSlotLines($0))
            })
    }
}
