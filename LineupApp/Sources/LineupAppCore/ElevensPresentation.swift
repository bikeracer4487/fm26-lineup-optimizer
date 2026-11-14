import Foundation
import LineupEngine

/// One of the two elevens the Elevens screen shows.
public enum Eleven: Hashable, Sendable {
    case first, second
}

extension ElevensView {
    /// The eleven this view shows; nil for Depth.
    public var eleven: Eleven? {
        switch self {
        case .first: .first
        case .second: .second
        case .depth: nil
        }
    }
}

/// One slot of an eleven in the list beside the pitch: who plays there and how well he fits, or "Nobody".
public struct ElevenRow: Identifiable, Equatable, Sendable {
    public var id: SlotID { slot }
    public let slot: SlotID
    /// The slot in words: "left back".
    public let slotText: String
    /// The line the slot is in, which colours its magnet.
    public var line: PitchLine { PitchLine(slot) }
    /// Nil for a slot nobody could fill.
    public let player: PlayerID?
    /// His name, or "Nobody".
    public let name: String
    public let squadText: String?
    public let ratingText: String?
    /// His familiarity in possession, then out of possession: "20 / 14".
    public let familiarityText: String?
    /// Injured, then out of position.
    public let stamps: [StatusStamp]
    public var isFilled: Bool { player != nil }

    /// The slot in words and his squad, under his name: "Left back, First team"; the slot alone when unfilled.
    public var placeLine: String {
        ([ElevensPresentation.sentenceCase(slotText)] + [squadText].compactMap { $0 }).joined(separator: ", ")
    }

    /// The row as said to assistive technology: "left back, Evan Humphries, 124.4".
    public var spokenText: String {
        ([slotText, name, ratingText].compactMap { $0 } + stamps.map(\.text)).joined(separator: ", ")
    }
}

/// An eleven as the screen shows it: its magnets, its unfilled slots, its list and its average.
public struct ElevenSheet: Equatable, Sendable {
    /// In slot order.
    public let tokens: [TokenContent]
    public let unfilled: [SlotID]
    /// Every slot of the tactic, in its order.
    public let rows: [ElevenRow]
    public let averageText: String
}

/// A slot's magnet in Depth: its cover count, and whether the cover is thin.
public struct DepthToken: Identifiable, Equatable, Sendable {
    public var id: SlotID { slot }
    public let slot: SlotID
    /// The slot's short name under the magnet: "D L".
    public var slotText: String { slot.displayName }
    public var line: PitchLine { PitchLine(slot) }
    public let coverText: String
    public let isThin: Bool
    /// "left back: 1 solid player; 2 needed".
    public let spokenText: String
}

/// One player who could cover a slot, as the list in Depth shows him.
public struct DepthOptionRow: Identifiable, Equatable, Sendable {
    public var id: PlayerID { player }
    public let player: PlayerID
    public let name: String
    public let squadText: String
    public let ratingText: String
    /// "20 / 14": in possession, then out of possession.
    public let familiarityText: String
    public let countsAsCover: Bool
    /// Why he cannot play today, in the engine's words; nil when he can.
    public let unavailable: String?
    /// "Also needed at left back"; nil when he is not first or second choice elsewhere.
    public let alsoNeeded: String?

    /// The row as said to assistive technology.
    public var spokenText: String {
        ([name, squadText, ratingText, "familiarity \(familiarityText)", countsAsCover ? "counts as cover" : nil,
          unavailable, alsoNeeded].compactMap { $0 }).joined(separator: ", ")
    }
}

/// Everything Depth shows beside the pitch for the chosen slot.
public struct DepthDetail: Equatable, Sendable {
    public let slot: SlotID
    /// The slot in words, as a heading: "Left back".
    public let title: String
    /// The engine's words for its cover: "1 solid player; 2 needed".
    public let cover: String
    /// The engine's words for who would step in.
    public let nextBest: String
    /// Best first.
    public let options: [DepthOptionRow]
    public let onLoan: [DepthOptionRow]
    /// "Nobody can play here" when the slot has no options; nil otherwise.
    public let emptyText: String?
}

public enum ElevensPresentation {
    public static let averageLabel = "Average rating"
    public static let nobody = "Nobody"
    public static let nobodyCanPlay = "Nobody can play here"
    public static let onLoanHeading = "Out on loan"
    public static let failedLead = "This tactic cannot be used, so there are no elevens for it."
    public static let tacticMenuLabel = "Tactic"
    public static let chooseSlotHint = "Click a slot on the pitch to see who could play there."

    public static let injuredStamp = StatusStamp(text: "Injured", isOut: true)
    public static let outOfPositionStamp = StatusStamp(text: "Out of position", isOut: false)
    public static let thinStamp = StatusStamp(text: "Thin", isOut: true)

    /// The headings over the list of an eleven and over a slot's options.
    public static let elevenColumns = ["Player", "Rating", "Familiarity in / out of possession"]
    public static let optionColumns = ["Player", "Rating", "Familiarity in / out of possession", "Cover"]

    /// What each mark on an eleven's magnets means, in the order a token shows them.
    public static let markKey: [TokenMark.KeyEntry] = [
        TokenMark.KeyEntry(mark: .injured, text: "Injured"),
        TokenMark.KeyEntry(mark: .caution, text: "Out of position"),
        TokenMark.KeyEntry(mark: .youth(.u21), text: "From the U21s or U18s"),
    ]

    /// "20 / 14".
    public static func familiarityText(ip: Int, oop: Int) -> String { "\(ip) / \(oop)" }

    /// The average to one decimal place, or a dash for an eleven with nobody in it.
    public static func averageText(_ average: Double?) -> String {
        average.map(MatchText.oneDecimal) ?? MatchText.noFigure
    }

    /// One of the elevens: a magnet for each place, a row for every slot of the tactic in `depth`'s order (the
    /// tactic's), "Nobody" in each unfilled one.
    public static func sheet(_ eleven: Eleven, report: ElevensReport, depth: DepthReport,
                             squads: [PlayerID: Squad]) -> ElevenSheet {
        let places: [ElevenPlace], unfilled: [SlotID], average: Double?
        switch eleven {
        case .first: (places, unfilled, average) = (report.first, report.unfilledFirst, report.firstAverage)
        case .second: (places, unfilled, average) = (report.second, report.unfilledSecond, report.secondAverage)
        }
        let tokens = places.map { place in
            TokenContent(slot: place.slot, player: place.player, name: place.name, surname: MatchText.surname(place.name),
                         initials: BoardText.initials(place.name), value: MatchText.oneDecimal(place.rating.value),
                         marks: TokenMark.marks(isInjured: place.isInjured, isOutOfPosition: place.isOutOfPosition,
                                                squad: squads[place.player]))
        }
        let bySlot = Dictionary(places.map { ($0.slot, $0) }, uniquingKeysWith: { first, _ in first })
        let rows = depth.slots.map(\.slot).map { slot -> ElevenRow in
            guard let place = bySlot[slot] else {
                return ElevenRow(slot: slot, slotText: slot.longName, player: nil, name: nobody, squadText: nil,
                                 ratingText: nil, familiarityText: nil, stamps: [])
            }
            var stamps: [StatusStamp] = []
            if place.isInjured { stamps.append(injuredStamp) }
            if place.isOutOfPosition { stamps.append(outOfPositionStamp) }
            return ElevenRow(slot: slot, slotText: slot.longName, player: place.player, name: place.name,
                             squadText: squads[place.player]?.displayName, ratingText: MatchText.oneDecimal(place.rating.value),
                             familiarityText: familiarityText(ip: place.ipFamiliarity, oop: place.oopFamiliarity),
                             stamps: stamps)
        }
        return ElevenSheet(tokens: tokens, unfilled: unfilled, rows: rows, averageText: averageText(average))
    }

    // MARK: Depth

    /// A magnet for each slot, in the tactic's order.
    public static func depthTokens(_ depth: DepthReport, parameters: EngineParameters) -> [DepthToken] {
        depth.slots.map { slot in
            DepthToken(slot: slot.slot, coverText: String(slot.cover), isThin: slot.isThin,
                       spokenText: "\(slot.slot.longName): \(AdvisorText.cover(slot, parameters: parameters))")
        }
    }

    /// The slot Depth shows: the owner's choice while the tactic has it, else the thinnest, else the first.
    public static func selectedSlot(_ chosen: SlotID?, slots: [SlotID], thin: [SlotID]) -> SlotID? {
        if let chosen, slots.contains(chosen) { return chosen }
        return thin.first ?? slots.first
    }

    /// The slot Depth shows for the owner's choice in `depth`.
    public static func selectedSlot(_ chosen: SlotID?, in depth: DepthReport) -> SlotID? {
        selectedSlot(chosen, slots: depth.slots.map(\.slot), thin: depth.thin)
    }

    /// The engine's sticky note naming the slots to recruit for; nil when no slot is thin.
    public static func recruitNote(_ depth: DepthReport) -> String? {
        AdvisorText.recruitFirst(depth)
    }

    /// What cover counts, in the engine's sentence, with the evidence note after it in brackets when it has one.
    public static func coverLine(_ parameters: EngineParameters, basis: Evidence) -> String {
        let line = AdvisorText.whatCoverCounts(parameters)
        return AdvisorText.note(for: basis).map { "\(line) (\($0))" } ?? line
    }

    /// "Also needed at left back"; nil for none.
    public static func alsoNeeded(_ slots: [SlotID]) -> String? {
        guard !slots.isEmpty else { return nil }
        let names = slots.map(\.longName)
        let list = names.count == 1 ? names[0] : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        return "Also needed at \(list)"
    }

    /// The detail for `slot`; nil when the tactic has no such slot.
    public static func detail(for slot: SlotID, in depth: DepthReport, parameters: EngineParameters) -> DepthDetail? {
        guard let shown = depth.slots.first(where: { $0.slot == slot }) else { return nil }
        func rows(_ options: [DepthOption]) -> [DepthOptionRow] {
            options.map { option in
                DepthOptionRow(player: option.player, name: option.name, squadText: option.squad.displayName,
                               ratingText: MatchText.oneDecimal(option.rating),
                               familiarityText: familiarityText(ip: option.ipFamiliarity, oop: option.oopFamiliarity),
                               countsAsCover: option.countsAsCover,
                               unavailable: option.unavailable.map { sentenceCase(ErrorDescriptions.describe($0, parameters: parameters)) },
                               alsoNeeded: alsoNeeded(option.alsoNeededAt))
            }
        }
        let nextName = shown.nextBest.flatMap { id in shown.options.first { $0.player == id }?.name }
        return DepthDetail(slot: slot, title: sentenceCase(slot.longName),
                           cover: AdvisorText.cover(shown, parameters: parameters),
                           nextBest: AdvisorText.nextBest(shown, name: nextName),
                           options: rows(shown.options), onLoan: rows(shown.onLoan),
                           emptyText: shown.options.isEmpty ? nobodyCanPlay : nil)
    }

    /// The first letter made a capital.
    static func sentenceCase(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}

extension AppModel {
    /// One of the elevens of `report`, with each player's squad as imported.
    public func elevenSheet(_ eleven: Eleven, report: ElevensReport, depth: DepthReport) -> ElevenSheet {
        ElevensPresentation.sheet(eleven, report: report, depth: depth, squads: elevensSquads)
    }

    /// The detail Depth shows for `slot`, with the plan's parameters; nil when the tactic has no such slot.
    public func depthDetail(for slot: SlotID, in depth: DepthReport) -> DepthDetail? {
        ElevensPresentation.detail(for: slot, in: depth, parameters: planParameters)
    }

    /// The magnets Depth shows, with the plan's parameters.
    public func depthTokens(_ depth: DepthReport) -> [DepthToken] {
        ElevensPresentation.depthTokens(depth, parameters: planParameters)
    }

    /// What cover counts, with the evidence note for `depth`.
    public func coverLine(_ depth: DepthReport) -> String {
        ElevensPresentation.coverLine(planParameters, basis: depth.basis)
    }

    /// The tactic menu's choices: every saved tactic as the Tactics screen's menu names it.
    public var elevensTacticChoices: [(id: UUID, title: String)] {
        tactics.map { ($0.id, menuTitle(of: $0.id)) }
    }

    /// The tactic the menu shows for the owner's choice: that tactic while it is saved, else the primary.
    public func elevensTacticShown(_ chosen: UUID?) -> UUID? {
        if let chosen, tactics.contains(where: { $0.id == chosen }) { return chosen }
        return settings.primaryTacticID
    }

    /// What choosing `picked` in the menu keeps as the owner's choice: nil for the primary, so the screen follows the
    /// primary when it changes.
    public func elevensTacticChoice(_ picked: UUID) -> UUID? {
        picked == settings.primaryTacticID ? nil : picked
    }

    private var elevensSquads: [PlayerID: Squad] {
        Dictionary(squad.book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })
    }
}
