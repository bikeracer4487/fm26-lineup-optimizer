/// A way of playing: a role for each slot in each phase, and which out-of-possession slot
/// each in-possession slot turns into when the ball is lost.
public struct Tactic: Equatable, Codable, Sendable {
    public var name: String
    /// Slot to role name.
    public var inPossession: [SlotID: String]
    public var outOfPossession: [SlotID: String]
    /// In-possession slot to out-of-possession slot. Entries for inactive in-possession slots are ignored.
    public var mapping: [SlotID: SlotID]

    public init(name: String, inPossession: [SlotID: String], outOfPossession: [SlotID: String],
                mapping: [SlotID: SlotID]) {
        self.name = name
        self.inPossession = inPossession
        self.outOfPossession = outOfPossession
        self.mapping = mapping
    }

    /// Every problem that stops this tactic being used: slot counts, then goalkeepers, then
    /// per-slot problems in `SlotID` order.
    public func problems(catalog: RoleCatalog) -> [TacticProblem] {
        var found: [TacticProblem] = []
        let phases: [(Phase, [SlotID: String])] = [(.inPossession, inPossession), (.outOfPossession, outOfPossession)]
        for (phase, roles) in phases where roles.count != 11 {
            found.append(.wrongSlotCount(phase, roles.count))
        }
        for (phase, roles) in phases where roles[.GK] == nil {
            found.append(.missingGoalkeeper(phase))
        }
        var claimed = Set<SlotID>()
        var reportedDuplicates = Set<SlotID>()
        for slot in SlotID.allCases {
            for (phase, roles) in phases {
                if let role = roles[slot], (try? catalog.role(named: role, phase: phase, at: slot.position)) == nil {
                    found.append(.unknownRole(phase, slot, role))
                }
            }
            guard inPossession[slot] != nil else { continue }
            guard let target = mapping[slot] else {
                found.append(.unmapped(slot))
                continue
            }
            if outOfPossession[target] == nil {
                found.append(.mappingTargetInactive(from: slot, to: target))
            } else if !claimed.insert(target).inserted, reportedDuplicates.insert(target).inserted {
                found.append(.duplicateMappingTarget(target))
            }
        }
        return found
    }

    /// One assignment per in-possession slot, in `SlotID` order.
    public func assignments(catalog: RoleCatalog) throws -> [SlotAssignment] {
        let found = problems(catalog: catalog)
        guard found.isEmpty else { throw TacticError(problems: found) }
        return try SlotID.allCases.compactMap { slot in
            guard let ipName = inPossession[slot], let oopSlot = mapping[slot], let oopName = outOfPossession[oopSlot] else {
                return nil
            }
            return SlotAssignment(
                slot: slot,
                ipPosition: slot.position,
                ipRole: try catalog.role(named: ipName, phase: .inPossession, at: slot.position),
                oopSlot: oopSlot,
                oopPosition: oopSlot.position,
                oopRole: try catalog.role(named: oopName, phase: .outOfPossession, at: oopSlot.position))
        }
    }
}

public enum TacticProblem: Equatable, Sendable {
    case wrongSlotCount(Phase, Int)
    case missingGoalkeeper(Phase)
    case unmapped(SlotID)
    case mappingTargetInactive(from: SlotID, to: SlotID)
    case duplicateMappingTarget(SlotID)
    case unknownRole(Phase, SlotID, String)
}

public struct TacticError: Error, Equatable {
    public let problems: [TacticProblem]

    public init(problems: [TacticProblem]) { self.problems = problems }
}

public struct SlotAssignment: Equatable, Sendable {
    /// The in-possession slot; identifies the pick.
    public let slot: SlotID
    public let ipPosition: Position
    public let ipRole: Role
    public let oopSlot: SlotID
    public let oopPosition: Position
    public let oopRole: Role

    public init(slot: SlotID, ipPosition: Position, ipRole: Role, oopSlot: SlotID, oopPosition: Position, oopRole: Role) {
        self.slot = slot
        self.ipPosition = ipPosition
        self.ipRole = ipRole
        self.oopSlot = oopSlot
        self.oopPosition = oopPosition
        self.oopRole = oopRole
    }
}
