import Foundation

/// A role with the attributes the game marks as key and preferable for it.
public struct Role: Equatable, Sendable {
    public let name: String
    public let phase: Phase
    public let positions: Set<Position>
    public let key: [Attribute]
    public let preferable: [Attribute]

    public init(name: String, phase: Phase, positions: Set<Position>, key: [Attribute], preferable: [Attribute]) {
        self.name = name
        self.phase = phase
        self.positions = positions
        self.key = key
        self.preferable = preferable
    }
}

public enum CatalogError: Error, Equatable {
    case malformed(reason: String)
    case unknownAttribute(role: String, name: String)
    case unknownRole(name: String, phase: Phase, position: Position)
}

/// The roles a player can be given, looked up by phase, position and name.
public struct RoleCatalog: Sendable {
    /// In file order (FM27) or sorted group order (FM26).
    private let entries: [Role]

    private init(entries: [Role]) { self.entries = entries }

    /// Loads the FM27 role file: `roles[]` entries with `name`, `phase`, `positions`, `key`, `preferable`.
    public init(fm27JSON: Data) throws {
        struct File: Decodable {
            struct Entry: Decodable {
                let name: String
                let phase: String
                let positions: [String]
                let key: [String]
                let preferable: [String]
            }
            let roles: [Entry]
        }
        let file: File
        do { file = try JSONDecoder().decode(File.self, from: fm27JSON) } catch {
            throw CatalogError.malformed(reason: "FM27 role file: \(error)")
        }
        entries = try file.roles.map { entry in
            guard let phase = Phase(rawValue: entry.phase) else {
                throw CatalogError.malformed(reason: "role \(entry.name) has unknown phase \(entry.phase)")
            }
            let positions = try entry.positions.map { code in
                guard let position = Position(rawValue: code) else {
                    throw CatalogError.malformed(reason: "role \(entry.name) has unknown position \(code)")
                }
                return position
            }
            return try Self.makeRole(name: entry.name, phase: phase, positions: Set(positions),
                                     key: entry.key, preferable: entry.preferable)
        }
    }

    /// Loads the FM26 role file: `{ "IP"|"OOP": { group: { role: { "key": [...], "important": [...] } } } }`.
    public init(fm26JSON: Data) throws {
        struct Body: Decodable {
            let key: [String]
            let important: [String]
        }
        let file: [String: [String: [String: Body]]]
        do { file = try JSONDecoder().decode([String: [String: [String: Body]]].self, from: fm26JSON) } catch {
            throw CatalogError.malformed(reason: "FM26 role file: \(error)")
        }
        var built: [Role] = []
        for (phaseName, phase) in [("IP", Phase.inPossession), ("OOP", .outOfPossession)] {
            guard let groups = file[phaseName] else {
                throw CatalogError.malformed(reason: "FM26 role file has no \(phaseName) section")
            }
            for group in groups.keys.sorted() {
                guard let positions = Self.fm26Groups[group] else {
                    throw CatalogError.malformed(reason: "FM26 role file has unknown position group \(group)")
                }
                for (name, body) in groups[group]!.sorted(by: { $0.key < $1.key }) {
                    built.append(try Self.makeRole(name: name, phase: phase, positions: positions,
                                                   key: body.key, preferable: body.important))
                }
            }
        }
        entries = built
    }

    /// The FM27 catalogue bundled with the library.
    public static func fm27() throws -> RoleCatalog {
        guard let url = Bundle.module.url(forResource: "fm27_roles", withExtension: "json") else {
            throw CatalogError.malformed(reason: "fm27_roles.json is missing from the bundle")
        }
        return try RoleCatalog(fm27JSON: Data(contentsOf: url))
    }

    public func role(named name: String, phase: Phase, at position: Position) throws -> Role {
        guard let role = entries.first(where: { $0.name == name && $0.phase == phase && $0.positions.contains(position) }) else {
            throw CatalogError.unknownRole(name: name, phase: phase, position: position)
        }
        return role
    }

    /// The roles available at a position in a phase, sorted by name.
    public func roles(phase: Phase, at position: Position) -> [Role] {
        entries.filter { $0.phase == phase && $0.positions.contains(position) }.sorted { $0.name < $1.name }
    }

    /// One entry per phase and name; where a name appears with different attributes at different
    /// positions (FM26 only), the first entry is kept.
    public var allRoles: [Role] {
        var seen = Set<String>()
        return entries.filter { seen.insert("\($0.phase.rawValue)|\($0.name)").inserted }
    }

    private static let fm26Groups: [String: Set<Position>] = [
        "D(L/R)": [.defenderLeft, .defenderRight],
        "D(C)": [.defenderCentral],
        "WB(L/R)": [.wingBackLeft, .wingBackRight],
        "DM": [.defensiveMidfielder],
        "M (L/R)": [.midfielderLeft, .midfielderRight],
        "M(C)": [.midfielderCentral],
        "AM (L/R)": [.attackingMidLeft, .attackingMidRight],
        "AM (C)": [.attackingMidCentral],
        "ST": [.striker],
        "GK": [.goalkeeper],
    ]

    /// Resolves attribute names, removes duplicates keeping the first, and lets key win over preferable.
    private static func makeRole(name: String, phase: Phase, positions: Set<Position>,
                                 key: [String], preferable: [String]) throws -> Role {
        func resolve(_ names: [String]) throws -> [Attribute] {
            var seen = Set<Attribute>()
            var result: [Attribute] = []
            for attributeName in names {
                guard let attribute = Attribute(catalogName: attributeName) else {
                    throw CatalogError.unknownAttribute(role: name, name: attributeName)
                }
                if seen.insert(attribute).inserted { result.append(attribute) }
            }
            return result
        }
        let keyAttributes = try resolve(key)
        let preferableAttributes = try resolve(preferable).filter { !keyAttributes.contains($0) }
        return Role(name: name, phase: phase, positions: positions, key: keyAttributes, preferable: preferableAttributes)
    }
}
