import LineupEngine

/// A slot in one phase of a tactic: what the Tactics editor has selected.
public struct TacticSlot: Hashable, Sendable {
    public let phase: Phase
    public let slot: SlotID

    public init(_ slot: SlotID, in phase: Phase) {
        self.phase = phase
        self.slot = slot
    }
}

/// The edits a tactic allows, kept out of the views so they can be tested. A draft may break the engine's rules
/// (ten slots, a slot turning into nothing); `AppModel.problems(of:)` says how.
public struct TacticDraft: Equatable, Sendable {
    /// The slots each side of a tactic must fill. The engine's rule; it has no constant of its own, so this one
    /// is tested against the problems it reports.
    public static let slotsPerSide = 11

    public var tactic: Tactic

    public init(_ tactic: Tactic) {
        self.tactic = tactic
    }

    /// The role at `slot` in `phase`, or nil when the slot is empty.
    public func role(at slot: SlotID, in phase: Phase) -> String? {
        roles(in: phase)[slot]
    }

    /// How many slots are filled in `phase`.
    public func filled(in phase: Phase) -> Int {
        roles(in: phase).count
    }

    /// Adds or removes a slot in a phase. A new slot takes the first role the catalogue lists for it; a slot the
    /// catalogue has no role for is not added.
    /// In possession, a new slot maps to the same slot out of possession when that slot is active.
    /// Removing an in-possession slot removes its mapping; removing an out-of-possession slot removes every
    /// mapping to it.
    public mutating func toggle(_ slot: SlotID, in phase: Phase, catalog: RoleCatalog) {
        if roles(in: phase)[slot] != nil {
            setRoles(in: phase) { $0[slot] = nil }
            switch phase {
            case .inPossession:
                tactic.mapping[slot] = nil
            case .outOfPossession:
                for (from, target) in tactic.mapping where target == slot {
                    tactic.mapping[from] = nil
                }
            }
            return
        }
        guard let first = catalog.roles(phase: phase, at: slot.position).first else { return }
        setRoles(in: phase) { $0[slot] = first.name }
        if phase == .inPossession {
            tactic.mapping[slot] = tactic.outOfPossession[slot] != nil ? slot : nil
        }
    }

    /// Changes the role of a filled slot; an empty slot stays empty.
    public mutating func setRole(_ name: String, at slot: SlotID, in phase: Phase) {
        guard roles(in: phase)[slot] != nil else { return }
        setRoles(in: phase) { $0[slot] = name }
    }

    /// Makes the in-possession `slot` turn into `target` out of possession.
    public mutating func map(_ slot: SlotID, to target: SlotID) {
        tactic.mapping[slot] = target
    }

    /// The out-of-possession slots no in-possession slot maps to, in `SlotID` order.
    public var unmappedTargets: [SlotID] {
        let targets = Set(tactic.mapping.filter { tactic.inPossession[$0.key] != nil }.values)
        return SlotID.allCases.filter { tactic.outOfPossession[$0] != nil && !targets.contains($0) }
    }

    /// The slots on the other side linked to `place`: for a filled in-possession slot, the slot it turns into;
    /// for an out-of-possession slot, every filled in-possession slot that turns into it, in `SlotID` order.
    public func linked(to place: TacticSlot) -> [TacticSlot] {
        switch place.phase {
        case .inPossession:
            guard tactic.inPossession[place.slot] != nil, let target = tactic.mapping[place.slot] else { return [] }
            return [TacticSlot(target, in: .outOfPossession)]
        case .outOfPossession:
            return SlotID.allCases
                .filter { tactic.inPossession[$0] != nil && tactic.mapping[$0] == place.slot }
                .map { TacticSlot($0, in: .inPossession) }
        }
    }

    /// What the in-possession `slot` may turn into: every filled out-of-possession slot, with its current target
    /// added if that is empty, in `SlotID` order.
    public func targetChoices(for slot: SlotID) -> [SlotID] {
        let current = tactic.mapping[slot]
        return SlotID.allCases.filter { tactic.outOfPossession[$0] != nil || $0 == current }
    }

    // MARK: The editor's words

    /// "11 of 11 slots filled".
    public func filledText(in phase: Phase) -> String {
        "\(filled(in: phase)) of \(Self.slotsPerSide) slots filled"
    }

    /// The selected slot above the role menu: "AM L, in possession".
    public static func inspectorTitle(_ place: TacticSlot) -> String {
        "\(place.slot.displayName), \(place.phase.inSentence)"
    }

    /// What the editor says while no slot is selected.
    public static let inspectorHint = "Click a place on either pitch to add a slot there, or a filled slot to change its role."

    /// The menu entry while an in-possession slot turns into nothing.
    public static let noTargetYet = "Nothing yet"

    /// An out-of-possession slot in the "becomes" menu: its code, marked "(empty)" when it has no role and "(nothing
    /// turns into it yet)" when no in-possession slot maps to it.
    public func targetName(_ target: SlotID) -> String {
        let label = target.displayName
        if role(at: target, in: .outOfPossession) == nil { return "\(label) (empty)" }
        return unmappedTargets.contains(target) ? "\(label) (nothing turns into it yet)" : label
    }

    /// The roles the role menu offers at a filled slot: those the catalogue allows there, with the current role first
    /// when the catalogue does not list it, so the menu can show it. Empty for an empty slot.
    public func roleChoices(at place: TacticSlot, catalog: RoleCatalog) -> [String] {
        guard let current = role(at: place.slot, in: place.phase) else { return [] }
        let allowed = catalog.roles(phase: place.phase, at: place.slot.position).map(\.name)
        return allowed.contains(current) ? allowed : [current] + allowed
    }

    /// A slot's help on the pitch: "AM L: Winger", or "Add a slot at AM L" when it is empty.
    public static func slotHelp(_ slot: SlotID, role: String?) -> String {
        role.map { "\(slot.displayName): \($0)" } ?? "Add a slot at \(slot.displayName)"
    }

    private func roles(in phase: Phase) -> [SlotID: String] {
        switch phase {
        case .inPossession: tactic.inPossession
        case .outOfPossession: tactic.outOfPossession
        }
    }

    private mutating func setRoles(in phase: Phase, _ change: (inout [SlotID: String]) -> Void) {
        switch phase {
        case .inPossession: change(&tactic.inPossession)
        case .outOfPossession: change(&tactic.outOfPossession)
        }
    }
}

extension Phase {
    /// The heading over a phase's pitch: "In possession".
    public var title: String {
        switch self {
        case .inPossession: "In possession"
        case .outOfPossession: "Out of possession"
        }
    }

    /// The phase in the middle of a sentence: "in possession".
    public var inSentence: String {
        switch self {
        case .inPossession: "in possession"
        case .outOfPossession: "out of possession"
        }
    }
}
