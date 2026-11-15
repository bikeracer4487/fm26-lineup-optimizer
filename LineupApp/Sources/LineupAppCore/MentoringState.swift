import Foundation
import LineupEngine

/// What the app keeps for mentoring: the hierarchy the owner entered, the groups he recorded, the arrows he read in the
/// game, and a personality reading of every player at each import, so what a group changed can be measured. Nothing is
/// forgotten when a player leaves: the file is the record.
public struct MentoringState: Equatable, Codable, Sendable {
    /// What the owner entered for each player, and the squad he entered it for. An entry is used only while its player
    /// is in that squad (`dynamics(for:)`); a player with no entry in use is `.others` with no social group.
    public var hierarchy: [PlayerID: HierarchyEntry]
    /// The day the owner last saved the hierarchy of each squad.
    public var dynamicsUpdatedOn: [Squad: Day]
    /// By start day, then id.
    public var groups: [MentoringGroup]
    /// Each player's readings in day order, one a day.
    public var readings: [PlayerID: [PersonalityReading]]
    /// The name of every player who has been in a group or had an arrow recorded, as he was called when put in it or
    /// when it was recorded.
    public var names: [PlayerID: String]
    /// The arrows the owner read in the game: one for an ordered pair in a squad, by squad, then from key, then to key
    /// (`setArrow`). A reading stays when its players move squad; the advice uses only the squad's own.
    public var arrows: [ArrowReading]

    public init() {
        hierarchy = [:]; dynamicsUpdatedOn = [:]; groups = []; readings = [:]; names = [:]; arrows = []
    }

    private enum CodingKeys: String, CodingKey { case hierarchy, dynamicsUpdatedOn, groups, readings, names, arrows }

    /// A file written before each entry kept its squad holds its entries under `dynamics`, with no squad. They are not
    /// read, so they are dropped the next time the state is saved. A file written before arrows were kept has no
    /// `arrows`, and reads as having none.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hierarchy = try container.decodeIfPresent([PlayerID: HierarchyEntry].self, forKey: .hierarchy) ?? [:]
        dynamicsUpdatedOn = try container.decode([Squad: Day].self, forKey: .dynamicsUpdatedOn)
        groups = try container.decode([MentoringGroup].self, forKey: .groups)
        readings = try container.decode([PlayerID: [PersonalityReading]].self, forKey: .readings)
        names = try container.decode([PlayerID: String].self, forKey: .names)
        arrows = try container.decodeIfPresent([ArrowReading].self, forKey: .arrows) ?? []
    }

    /// The entries entered for the squad: what its advice, its hierarchy lines and its editor read. One entered for
    /// another squad is left out, so a player who has moved reads as `.others` with no social group until he is
    /// entered in his new squad, and has it back if he returns.
    public func dynamics(for squad: Squad) -> [PlayerID: PlayerDynamics] {
        hierarchy.compactMapValues { $0.squad == squad ? $0.dynamics : nil }
    }

    /// By start day, then by id's text, so the order never depends on how groups were added.
    static func order(_ a: MentoringGroup, _ b: MentoringGroup) -> Bool {
        (a.startedOn, a.id.uuidString) < (b.startedOn, b.id.uuidString)
    }

    /// Sets the pair's reading in the squad, or with nil takes it away. A strength equal to the one kept leaves its day
    /// alone. The readings are then put back in order, so the same readings set in any order are saved the same.
    mutating func setArrow(from: PlayerID, to: PlayerID, in squad: Squad, strength: ArrowStrength?, on day: Day) {
        let index = arrows.firstIndex { $0.squad == squad && $0.from == from && $0.to == to }
        switch (index, strength) {
        case (nil, nil):
            return
        case (let index?, nil):
            arrows.remove(at: index)
        case (let index?, let strength?):
            guard arrows[index].strength != strength else { return }
            arrows[index].strength = strength
            arrows[index].readOn = day
        case (nil, let strength?):
            arrows.append(ArrowReading(from: from, to: to, squad: squad, strength: strength, readOn: day))
        }
        arrows.sort(by: Self.order)
    }

    /// By squad in book order, then by the from key's text, then by the to key's.
    static func order(_ a: ArrowReading, _ b: ArrowReading) -> Bool {
        let rank = { (squad: Squad) in Squad.allCases.firstIndex(of: squad) ?? 0 }
        return (rank(a.squad), a.from.key, a.to.key) < (rank(b.squad), b.from.key, b.to.key)
    }

    /// One reading for each player on the day. A second on the same day replaces the first, readings stay in day
    /// order, and of three in a row with the same values the middle one is dropped, so a quiet squad keeps few.
    mutating func record(_ players: [Player], on day: Day) {
        for player in players {
            var list = readings[player.id, default: []].filter { $0.day != day }
            list.append(PersonalityReading(day: day, player: player))
            list.sort { $0.day < $1.day }
            var index = 1
            while index + 1 < list.count {
                if list[index - 1].values == list[index].values && list[index].values == list[index + 1].values {
                    list.remove(at: index)
                } else {
                    index += 1
                }
            }
            readings[player.id] = list
        }
    }
}

/// What the owner entered for one player, and the squad he entered it for: a level and a social group belong to that
/// squad.
public struct HierarchyEntry: Equatable, Codable, Sendable {
    public var squad: Squad
    public var dynamics: PlayerDynamics

    public init(squad: Squad, dynamics: PlayerDynamics) {
        self.squad = squad
        self.dynamics = dynamics
    }
}

/// A group being added or changed.
public struct MentoringGroupDraft: Identifiable, Equatable, Sendable {
    /// A new one for a new group; the group's own when editing.
    public let id: UUID
    /// Chosen for a new group when it is started; the group's own when editing, and never changed, so a draft is checked
    /// against the squad its group is saved under.
    public let squad: Squad
    public var members: [PlayerID]
    public let isNew: Bool

    /// A new group.
    public init(id: UUID = UUID(), squad: Squad, members: [PlayerID] = []) {
        self.id = id; self.squad = squad; self.members = members; self.isNew = true
    }

    /// A change to the group, starting from the members who have not left.
    public init(editing group: MentoringGroup) {
        id = group.id; squad = group.squad; members = group.current.map(\.player); isNew = false
    }

    /// Takes the player out when he is chosen, and otherwise puts him in last. Whether he may be put in is the choice's
    /// `canToggle`.
    public mutating func toggle(_ player: PlayerID) {
        if let index = members.firstIndex(of: player) {
            members.remove(at: index)
        } else {
            members.append(player)
        }
    }
}

/// The arrows of three players being recorded: the arrows sheet's draft. A change of members goes through
/// `AppModel.arrowsDraft(_:toggling:)`, which fills a new pair from the readings kept.
public struct ArrowsDraft: Identifiable, Equatable, Sendable {
    /// One way between two players.
    public struct Pair: Hashable, Sendable {
        public let from: PlayerID
        public let to: PlayerID

        public init(from: PlayerID, to: PlayerID) {
            self.from = from
            self.to = to
        }
    }

    /// A new one each time the sheet is opened; kept while its members change.
    public let id: UUID
    public let squad: Squad
    public var members: [PlayerID]
    /// A pair it lacks is not read.
    public var strengths: [Pair: ArrowStrength]

    /// Each ordered pair of its members, in member order: the first member to each of the others, then the second, and
    /// so on. Six for three members.
    var pairs: [Pair] {
        members.flatMap { from in members.filter { $0 != from }.map { Pair(from: from, to: $0) } }
    }
}
