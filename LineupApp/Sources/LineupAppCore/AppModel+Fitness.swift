import LineupEngine

extension AppModel {
    /// The rates for the saved state, as of the plan's starting day: the readings kept, the confirmed lineups as they
    /// now stand, each held player's squad and the measure-from day. `.none` before a squad is imported, and while the
    /// engine's parameters have problems, which the plan and the advice then report themselves. Worked out each time it
    /// is read; nothing of it is saved.
    var fitnessTrends: FitnessTrends {
        guard let asOf = planStartDay else { return .none }
        let parameters = planParameters
        guard FitnessModel.problems(in: parameters).isEmpty else { return .none }
        let squads = Dictionary(squad.book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })
        return FitnessTrend.rates(readings: fitness.readings, confirmed: history.map(\.lineup), squads: squads,
                                  asOf: asOf, measureFrom: fitness.measureFrom, parameters: parameters)
    }

    /// Takes a reading of every player of the squad as the book now holds him, on `day`, including the fixtures of the
    /// confirmed lineups still awaiting this squad's import, and saves the file. Called by an import after the book is
    /// saved and before the import clears those marks. Does not plan: the import plans after.
    func recordFitness(after squad: Squad, on day: Day) {
        let fixtures = history.filter { $0.awaitingImport.contains(squad) }.map(\.lineup.fixture)
        record(squad, on: day, including: fixtures)
    }

    /// For a state saved before readings were kept: a reading of each held squad on the day it was last imported, with
    /// the fixtures of the confirmed lineups dated that day that no longer await it, as its import had included them.
    /// The squads are read in day order, so the readings dropped as too old never depend on the order they are held in.
    func recordFirstFitness() {
        let order = { (squad: Squad) in Squad.allCases.firstIndex(of: squad) ?? 0 }
        let imports = squad.importedOn.sorted { ($0.value, order($0.key)) < ($1.value, order($1.key)) }
        for (squad, day) in imports {
            let fixtures = history.filter { $0.lineup.date == day && !$0.awaitingImport.contains(squad) }
                .map(\.lineup.fixture)
            record(squad, on: day, including: fixtures)
        }
    }

    /// Sets the measure-from day to today in the game, saves the file and plans again, which leaves the advice to be
    /// worked out again. Every reading stays in the file: it is only left out of the rates.
    public func measureTrendAgain() {
        fitness.measureFrom = settings.currentDate
        save(.fitness)
        replan()
    }

    private func record(_ squad: Squad, on day: Day, including fixtures: [FixtureID]) {
        let players = self.squad.book.current[squad] ?? []
        fitness.record(players, on: day, including: fixtures,
                       keptDays: planParameters.jadednessTrendRules.value.keptDays)
        save(.fitness)
    }
}
