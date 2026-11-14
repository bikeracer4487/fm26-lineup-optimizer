import Foundation
import LineupEngine

/// What the app keeps for mentoring: the hierarchy the owner entered, the groups he recorded, and a personality
/// reading of every player at each import, so what a group changed can be measured. Nothing is forgotten when a player
/// leaves: the file is the record.
public struct MentoringState: Equatable, Codable, Sendable {
    /// What the owner entered for each player; a player with no entry is `.others` with no social group.
    public var dynamics: [PlayerID: PlayerDynamics]
    /// The day the owner last saved the hierarchy of each squad.
    public var dynamicsUpdatedOn: [Squad: Day]
    /// By start day, then id.
    public var groups: [MentoringGroup]
    /// Each player's readings in day order, one a day.
    public var readings: [PlayerID: [PersonalityReading]]
    /// The name of every player who has been in a group, as he was called when put in it.
    public var names: [PlayerID: String]

    public init() {
        dynamics = [:]; dynamicsUpdatedOn = [:]; groups = []; readings = [:]; names = [:]
    }

    /// By start day, then by id's text, so the order never depends on how groups were added.
    static func order(_ a: MentoringGroup, _ b: MentoringGroup) -> Bool {
        (a.startedOn, a.id.uuidString) < (b.startedOn, b.id.uuidString)
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

/// A group being added or changed.
public struct MentoringGroupDraft: Identifiable, Equatable, Sendable {
    /// A new one for a new group; the group's own when editing.
    public let id: UUID
    public var squad: Squad
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
}
