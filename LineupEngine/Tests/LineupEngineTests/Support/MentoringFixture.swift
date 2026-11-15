import Foundation
@testable import LineupEngine

/// The arrows the owner read in the game on 14 November 2026, and the first team they were read in.
enum MentoringFixture {
    struct Group {
        let set: String
        let members: [String]
        let arrows: [(from: String, to: String, strength: ArrowStrength)]
    }

    static let readOn = Day(iso: "2026-11-14")!

    private struct ReadingsFile: Decodable {
        struct Arrow: Decodable { let from: String; let to: String; let strength: ArrowStrength }
        struct GroupEntry: Decodable { let set: String; let members: [String]; let arrows: [Arrow] }
        let groups: [GroupEntry]
    }

    private struct SquadFile: Decodable {
        struct Entry: Decodable {
            let name: String
            let age: Int
            let level: Standing
            let socialGroup: SocialGroup?
            let professionalism: Int
            let pressure: Int
            let determination: Int
            let ambition: Int
        }
        let players: [Entry]
    }

    static func groups() throws -> [Group] {
        let file = try JSONDecoder().decode(ReadingsFile.self, from: Fixtures.data("mentoring/arrow-readings-2026-11-14.json"))
        return file.groups.map { entry in
            Group(set: entry.set, members: entry.members, arrows: entry.arrows.map { ($0.from, $0.to, $0.strength) })
        }
    }

    /// Every ordered pair of every group's members with the strength read; a pair read in two groups appears once.
    static func pairs() throws -> [(from: String, to: String, strength: ArrowStrength)] {
        var seen = Set<String>()
        var found: [(from: String, to: String, strength: ArrowStrength)] = []
        for group in try groups() {
            for from in group.members {
                for to in group.members where to != from {
                    guard seen.insert("\(from)\u{1F}\(to)").inserted else { continue }
                    let strength = group.arrows.first { $0.from == from && $0.to == to }?.strength ?? .none
                    found.append((from, to, strength))
                }
            }
        }
        return found
    }

    /// Every reading as the engine takes it: the first team's, read on 14 November 2026, players keyed by name.
    static func readings() throws -> [ArrowReading] {
        try pairs().map {
            ArrowReading(from: PlayerID(key: PlayerID.normalise($0.from)), to: PlayerID(key: PlayerID.normalise($0.to)),
                         squad: .firstTeam, strength: $0.strength, readOn: readOn)
        }
    }

    /// The twenty players with their ages and four counted values, every other attribute 10; and their levels.
    static func squad() throws -> (players: [Player], dynamics: [PlayerID: PlayerDynamics]) {
        let file = try JSONDecoder().decode(SquadFile.self, from: Fixtures.data("mentoring/first-team-2026-11-14.json"))
        var players: [Player] = []
        var dynamics: [PlayerID: PlayerDynamics] = [:]
        for entry in file.players {
            let player = Player.fixture(name: entry.name, age: entry.age, attributes: [
                .professionalism: entry.professionalism, .pressure: entry.pressure,
                .determination: entry.determination, .ambition: entry.ambition])
            players.append(player)
            dynamics[player.id] = PlayerDynamics(standing: entry.level, socialGroup: entry.socialGroup)
        }
        return (players, dynamics)
    }
}
