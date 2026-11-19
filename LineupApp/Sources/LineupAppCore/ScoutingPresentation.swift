import Foundation
import LineupEngine

/// One need at one slot, as the Needs tab lists it: the slot's token and the engine's lines for the need.
public struct NeedRow: Identifiable, Equatable, Sendable {
    public var id: SlotID { slot }
    public let slot: SlotID
    /// The slot's token text: "D L".
    public var slotText: String { slot.displayName }
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
    /// The headline slot's token text; nil when he plays no slot.
    public let slotText: String?
    /// How he would stand at his headline slot today; the engine's sentence that he can play no slot when he has none.
    public let todayLines: [String]
    public let laterLines: [String]
    /// "Injury Proneness 16".
    public let cautions: [String]
    /// A line for each other slot he can play, in the tactic's order.
    public let otherSlots: [String]
}

/// One group of candidates: those answering one need at one slot, or one of the two parts that are a group each.
public struct CandidateGroupRows: Identifiable, Equatable, Sendable {
    public let id: String
    /// The part's name when this group is the first of its part; nil otherwise.
    public let partTitle: String?
    /// "Left back · needs a better player"; nil for a part that is one group.
    public let heading: String?
    public let rows: [ScoutingCandidateRow]
}

/// Everything the Candidates tab shows for the held players.
public struct CandidatesSheet: Equatable, Sendable {
    /// "6 players read."
    public let readLine: String
    /// The players left out as already the owner's; nil for none.
    public let leftOutLine: String?
    /// In the engine's order, without empty groups.
    public let groups: [CandidateGroupRows]
}

/// What the Scouting screen shows, in the engine's words; Core holds only the labels.
public enum ScoutingPresentation {
    public static let pasteButton = "Paste players"
    public static let clearButton = "Clear"
    public static let nothingPasted = "Copy the rows of a search or a shortlist in FMRTE, then paste them here."
    public static let fineHeading = "Fine"

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
            return CandidateGroupRows(id: id, partTitle: isFirstOfPart ? AdvisorText.name(group.part) : nil,
                                      heading: heading, rows: group.candidates.map { row($0, money: money) })
        }
        return CandidatesSheet(readLine: AdvisorText.playersRead(pasted),
                               leftOutLine: AdvisorText.leftOutAlreadyYours(report.leftOut), groups: groups)
    }

    static func row(_ candidate: LineupEngine.Candidate, money: MoneyStyle) -> ScoutingCandidateRow {
        let player = candidate.player
        let headline = candidate.headline.flatMap { slot in candidate.slots.first { $0.slot == slot } }
        return ScoutingCandidateRow(
            id: candidate.id, name: player.name, age: player.age, positions: player.positionsText,
            club: AdvisorText.club(of: player), onLoan: player.loanedTo.map(AdvisorText.onLoan(at:)),
            askingPrice: player.askingPrice.map { AdvisorText.askingPrice($0, money) },
            wage: Display.wage(perWeek: player.wagePerWeek, money), isInjured: player.isInjured,
            slotText: headline?.slot.displayName,
            todayLines: headline.map(AdvisorText.todayLines) ?? [AdvisorText.playsNoSlot],
            laterLines: AdvisorText.laterLines(candidate),
            cautions: candidate.cautions.map(AdvisorText.caution),
            otherSlots: candidate.slots.filter { $0.slot != headline?.slot }.map(AdvisorText.otherSlotLine))
    }
}
