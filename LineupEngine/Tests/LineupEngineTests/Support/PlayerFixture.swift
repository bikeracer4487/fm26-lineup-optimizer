@testable import LineupEngine

extension Player {
    /// A player with every attribute at `all` unless `attributes` overrides it, every
    /// unspecified position familiarity at 1, and club "Oxford City".
    static func fixture(
        name: String = "Test Player",
        squad: Squad = .firstTeam,
        age: Int = 25,
        all: Int = 10,
        attributes: [Attribute: Int] = [:],
        familiarity: [Position: Int] = [:],
        currentAbility: Int = 100,
        potentialAbility: Int = 120,
        condition: Double = 1,
        sharpness: Double = 1,
        jadedness: Int = -500,
        isInjured: Bool = false,
        isBanned: Bool = false,
        club: String? = "Oxford City",
        loanedTo: String? = nil
    ) -> Player {
        Player(
            id: PlayerID(key: PlayerID.normalise(name)), name: name, squad: squad, age: age,
            positionsText: "",
            currentAbility: currentAbility, potentialAbility: potentialAbility,
            attributes: Dictionary(uniqueKeysWithValues: Attribute.allCases.map { ($0, all) })
                .merging(attributes) { _, override in override },
            familiarity: Dictionary(uniqueKeysWithValues: Position.allCases.map { ($0, 1) })
                .merging(familiarity) { _, override in override },
            condition: condition, sharpness: sharpness, jadedness: jadedness,
            isInjured: isInjured, isBanned: isBanned, club: club, loanedTo: loanedTo,
            contractType: .fullTime, monthsLeft: 12, wagePerWeek: 500, askingPrice: nil,
            nationalities: [], extras: [:]
        )
    }
}
