import Foundation

/// One player in an eleven: where he plays, how well he rates there, and whether he is injured.
public struct ElevenPlace: Equatable, Sendable {
    public let slot: SlotID
    public let player: PlayerID
    public let name: String
    public let rating: SlotRating
    public let isInjured: Bool
}

/// The squad's first and second elevens as the advisors see them: injured players keep their places
/// (and are marked), players out on loan are left out.
public struct ElevensReport: Equatable, Sendable {
    /// In slot order.
    public let first: [ElevenPlace]
    public let second: [ElevenPlace]
    /// Mean of the places' rating values; nil when the eleven has no places.
    public let firstAverage: Double?
    public let secondAverage: Double?
    public let unfilledFirst: [SlotID]
    public let unfilledSecond: [SlotID]
    /// The tiers computed with injured players kept in.
    public let tiers: SquadTiers
}

public enum Elevens {
    /// Throws what `SquadTiers.compute` throws, and `RatingError` for a player with missing data.
    public static func report(tactic: Tactic, players: [Player], ownClub: String?, catalog: RoleCatalog,
                              profile: RatingProfile, parameters: EngineParameters) throws -> ElevensReport {
        let tiers = try SquadTiers.compute(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                           profile: profile, parameters: parameters, ignoringInjuries: true)
        let assignments = try tactic.assignments(catalog: catalog)
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        let byID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })

        func places(_ chosen: [SlotID: PlayerID]) throws -> (places: [ElevenPlace], unfilled: [SlotID]) {
            var places: [ElevenPlace] = []
            var unfilled: [SlotID] = []
            for assignment in assignments {
                guard let id = chosen[assignment.slot], let player = byID[id] else {
                    unfilled.append(assignment.slot)
                    continue
                }
                places.append(ElevenPlace(slot: assignment.slot, player: id, name: player.name,
                                          rating: try engine.rating(for: player, in: assignment),
                                          isInjured: player.isInjured))
            }
            return (places, unfilled)
        }

        func average(_ places: [ElevenPlace]) -> Double? {
            places.isEmpty ? nil : places.map(\.rating.value).reduce(0, +) / Double(places.count)
        }

        let first = try places(tiers.first)
        let second = try places(tiers.second)
        return ElevensReport(first: first.places, second: second.places,
                             firstAverage: average(first.places), secondAverage: average(second.places),
                             unfilledFirst: first.unfilled, unfilledSecond: second.unfilled, tiers: tiers)
    }
}
