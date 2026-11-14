import Testing
@testable import LineupEngine

@Suite struct ImportanceSuggestionTests {
    let parameters = EngineParameters.fm27
    let today = Day(iso: "2026-11-20")!
    let tactic: Tactic = try! PlannerFixture.tactic()

    func fixture(_ id: String = "this", daysFromToday offset: Int = 0, competition: Competition? = .league,
                 opponent: OpponentStrength? = .similar) -> Fixture {
        var f = Fixture(id: FixtureID(id), date: today.adding(days: offset), opponent: "Rovers", importance: .medium, tactic: tactic)
        f.competition = competition
        f.opponentStrength = opponent
        return f
    }

    func confirmed(_ id: String, daysFromToday offset: Int) -> ConfirmedLineup {
        ConfirmedLineup(fixture: FixtureID(id), date: today.adding(days: offset), starters: [:])
    }

    /// Eleven first-eleven players with the given sharpness each (the first `injured` of them injured), and one extra
    /// outside the eleven.
    func squad(sharpness: [Double], injured: Int = 0, outsideSharpness: Double = 1) -> (players: [Player], tiers: SquadTiers) {
        var players: [Player] = []
        var first: [SlotID: PlayerID] = [:]
        for (i, slot) in SlotID.allCases.prefix(11).enumerated() {
            let p = Player.fixture(name: "Starter \(i)", sharpness: i < sharpness.count ? sharpness[i] : 1, isInjured: i < injured)
            players.append(p)
            first[slot] = p.id
        }
        players.append(Player.fixture(name: "Reserve", sharpness: outsideSharpness))
        return (players, SquadTiers(first: first, second: [:], ratings: [:]))
    }

    func suggest(_ f: Fixture, among others: [Fixture] = [], confirmed: [ConfirmedLineup] = [],
                 sharpness: [Double] = [], injured: Int = 0, outside: Double = 1,
                 parameters: EngineParameters? = nil) throws -> ImportanceSuggestion {
        let s = squad(sharpness: sharpness, injured: injured, outsideSharpness: outside)
        return try ImportanceAdvisor.suggest(for: f, among: others, confirmed: confirmed, players: s.players, tiers: s.tiers,
                                             parameters: parameters ?? self.parameters)
    }

    /// The standard parameters with the importance rules changed by `change`.
    func rules(_ change: (inout ImportanceSuggestionRules) -> Void) -> EngineParameters {
        var q = parameters
        var r = q.importanceRules.value
        change(&r)
        q.importanceRules = Parameter(r, .carriedOverFM26, source: "test")
        return q
    }

    // MARK: Base and opponent

    @Test func aLeagueMatchAgainstASimilarSideIsMedium() throws {
        let s = try suggest(fixture())
        #expect(s.importance == .medium)
        #expect(s.score == 80)
        #expect(s.basis == .carriedOverFM26)
    }

    @Test func againstAStrongerSideItIsHigh() throws {
        let s = try suggest(fixture(opponent: .stronger))
        #expect(s.importance == .high)
        #expect(abs(s.score - 88) < 1e-9)
    }

    @Test func opponentFactorsApply() throws {
        #expect(abs(try suggest(fixture(opponent: .muchStronger)).score - 96) < 1e-9)
        #expect(abs(try suggest(fixture(opponent: .weaker)).score - 64) < 1e-9)
        #expect(abs(try suggest(fixture(opponent: .muchWeaker)).score - 48) < 1e-9)
        #expect(try suggest(fixture(opponent: .muchWeaker)).importance == .low)
    }

    @Test func aMinorCupMatchIsLow() throws {
        let s = try suggest(fixture(competition: .minorCup))
        #expect(s.importance == .low)
        #expect(s.score == 30)
    }

    @Test func aFriendlyIsLow() throws {
        let s = try suggest(fixture(competition: .friendly))
        #expect(s.importance == .low)
        #expect(s.score == 10)
    }

    @Test func aCupMatchIsMedium() throws {
        let s = try suggest(fixture(competition: .cup))
        #expect(s.importance == .medium)
        #expect(s.score == 60)
    }

    @Test func withNothingSetTheSuggestionIsMedium() throws {
        let s = try suggest(fixture(competition: nil, opponent: nil))
        #expect(s.importance == .medium)
        #expect(s.score == 50)
        #expect(s.reasons == ["No competition set: 50", "Score 50: Medium"])
    }

    // MARK: Levels at their lines

    @Test func aScoreOfExactly85IsHigh() throws {
        let at85 = try suggest(fixture(), parameters: rules { $0.leagueBase = 85 })
        #expect(at85.score == 85)
        #expect(at85.importance == .high)
        #expect(at85.reasons.last == "Score 85: High")
        #expect(try suggest(fixture(), parameters: rules { $0.leagueBase = 84.9 }).importance == .medium)
    }

    @Test func aScoreOfExactly50WithUnsharpRegularsIsMedium() throws {
        let s = try suggest(fixture(competition: nil, opponent: nil), sharpness: [0.5, 0.6, 0.65])
        #expect(s.score == 50)
        #expect(s.importance == .medium)
        #expect(!s.reasons.contains { $0.contains("sharpness") })
        // Just under 50 they make it Sharpness.
        let under = try suggest(fixture(competition: nil, opponent: nil), sharpness: [0.5, 0.6, 0.65],
                                parameters: rules { $0.unsetBase = 49.9 })
        #expect(under.importance == .sharpness)
    }

    // MARK: Schedule

    @Test func aBiggerMatchSoonAfterReducesTheScore() throws {
        // The next match is a league match against a stronger side: 88, bigger than this one's 80.
        for (days, expected) in [(2, 48.0), (3, 56), (4, 72), (5, 80)] {
            let s = try suggest(fixture(), among: [fixture("next", daysFromToday: days, opponent: .stronger)])
            #expect(abs(s.score - expected) < 1e-9, "\(days) days")
        }
        #expect(try suggest(fixture(), among: [fixture("next", daysFromToday: 2, opponent: .stronger)]).importance == .low)
    }

    @Test func theNextMatchMustBeBiggerThanThisOne() throws {
        // 96 then 80 three days later: the next match reaches the line but is smaller.
        let big = try suggest(fixture(opponent: .muchStronger), among: [fixture("next", daysFromToday: 3)])
        #expect(abs(big.score - 96) < 1e-9)
        #expect(big.importance == .high)
        #expect(!big.reasons.contains { $0.hasPrefix("A bigger match follows") })
        // 80 then 80 two days later: the same size is not bigger.
        let same = try suggest(fixture(), among: [fixture("next", daysFromToday: 2)])
        #expect(same.score == 80)
        #expect(!same.reasons.contains { $0.hasPrefix("A bigger match follows") })
        // 80 then 88 two days later.
        let bigger = try suggest(fixture(), among: [fixture("next", daysFromToday: 2, opponent: .stronger)])
        #expect(abs(bigger.score - 48) < 1e-9)
        #expect(bigger.reasons.contains("A bigger match follows in 2 days (×0.6)"))
    }

    @Test func aNextMatchOfExactly80ReachesTheLine() throws {
        // This one is 64 (league, weaker); the next is exactly 80 and bigger, two days later.
        let s = try suggest(fixture(opponent: .weaker), among: [fixture("next", daysFromToday: 2)])
        #expect(abs(s.score - 64 * 0.6) < 1e-9)
        #expect(s.reasons.contains("A bigger match follows in 2 days (×0.6)"))
        // With the line just above 80, it does not.
        let above = try suggest(fixture(opponent: .weaker), among: [fixture("next", daysFromToday: 2)],
                                parameters: rules { $0.biggerMatchFrom = 80.1 })
        #expect(abs(above.score - 64) < 1e-9)
    }

    @Test func aLesserMatchFollowingDoesNotReduceTheScore() throws {
        let next = fixture("next", daysFromToday: 2, competition: .cup)
        #expect(try suggest(fixture(), among: [next]).score == 80)
        let weakLeague = fixture("next", daysFromToday: 2, opponent: .weaker)
        #expect(try suggest(fixture(), among: [weakLeague]).score == 80)
    }

    @Test func theNextFixtureIsTheEarliestAfterThisOneAndThisOneIsIgnored() throws {
        let early = fixture("a", daysFromToday: 3, opponent: .stronger)
        let late = fixture("b", daysFromToday: 2, competition: .friendly)
        // The earlier of the two (2 days) is a friendly, so nothing applies, although the other would.
        #expect(try suggest(fixture(), among: [early, late]).score == 80)
        #expect(abs(try suggest(fixture(), among: [fixture(), early]).score - 56) < 1e-9)
    }

    @Test func aThirdMatchInSevenDaysReducesTheScore() throws {
        // Six and three days before: with the match day, three matches in seven days.
        let s = try suggest(fixture(), among: [fixture("p1", daysFromToday: -3)], confirmed: [confirmed("p2", daysFromToday: -6)])
        #expect(abs(s.score - 64) < 1e-9)
        #expect(s.reasons.contains("Third match in 7 days (×0.8)"))
    }

    @Test func aMatchSevenDaysBeforeIsOutsideTheWindow() throws {
        // Seven days before is the eighth day counting the match day.
        let s = try suggest(fixture(), among: [fixture("p1", daysFromToday: -3)], confirmed: [confirmed("p2", daysFromToday: -7)])
        #expect(s.score == 80)
        #expect(!s.reasons.contains { $0.contains("in 7 days") })
        let planned = try suggest(fixture(), among: [fixture("p1", daysFromToday: -3), fixture("p2", daysFromToday: -7)])
        #expect(planned.score == 80)
    }

    @Test func twoMatchesInSevenDaysAreNeeded() throws {
        #expect(try suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -3)]).score == 80)
        // A match 8 days back is outside the window.
        #expect(try suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -3), confirmed("p2", daysFromToday: -8)]).score == 80)
    }

    @Test func aFixtureAndALineupWithTheSameIdCountOnce() throws {
        let s = try suggest(fixture(), among: [fixture("p1", daysFromToday: -3)], confirmed: [confirmed("p1", daysFromToday: -3)])
        #expect(s.score == 80)
    }

    @Test func aWeekSinceTheLastMatchRaisesTheScore() throws {
        let s = try suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -8)])
        #expect(s.importance == .high)
        #expect(abs(s.score - 88) < 1e-9)
        #expect(abs(try suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -7)]).score - 88) < 1e-9)
        #expect(try suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -6)]).score == 80)
    }

    @Test func theRestedReasonNamesTheDaysItNeeds() throws {
        let week = try suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -8)])
        #expect(week.reasons.contains("A week or more since the last match (×1.1)"))
        let nine = rules { $0.restedAfterDays = 9 }
        let s = try suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -9)], parameters: nine)
        #expect(s.reasons.contains("9 days or more since the last match (×1.1)"))
        #expect(abs(s.score - 88) < 1e-9)
        #expect(try suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -8)], parameters: nine).score == 80)
        let one = try suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -1)], parameters: rules { $0.restedAfterDays = 1 })
        #expect(one.reasons.contains("1 day or more since the last match (×1.1)"))
    }

    @Test func noRiseWhenAReductionApplies() throws {
        let s = try suggest(fixture(), among: [fixture("next", daysFromToday: 3, opponent: .stronger)],
                            confirmed: [confirmed("p1", daysFromToday: -9)])
        #expect(abs(s.score - 56) < 1e-9)
        #expect(!s.reasons.contains { $0.contains("A week or more") })
    }

    // MARK: Sharpness

    @Test func aLowScoreWithUnsharpRegularsAndTimeToRecoverSuggestsSharpness() throws {
        let f = fixture(competition: .friendly)
        let s = try suggest(f, among: [fixture("next", daysFromToday: 5)], sharpness: [0.5, 0.6, 0.69])
        #expect(s.importance == .sharpness)
        #expect(s.score == 10)
        #expect(s.reasons.last == "3 of the first eleven are under 70% sharpness, and the next match is 5 days later")
        #expect(s.reasons.dropLast().last == "Score 10: Low")
        let none = try suggest(f, sharpness: [0.5, 0.6, 0.69])
        #expect(none.importance == .sharpness)
        #expect(none.reasons.last == "3 of the first eleven are under 70% sharpness, and no match follows")
    }

    @Test func twoUnsharpRegularsStayLow() throws {
        #expect(try suggest(fixture(competition: .friendly), sharpness: [0.5, 0.6]).importance == .low)
    }

    @Test func injuredRegularsDoNotCountAsUnsharp() throws {
        // Three first-eleven players under the line, all injured: not Sharpness.
        let injured = try suggest(fixture(competition: .friendly), sharpness: [0.5, 0.6, 0.65], injured: 3)
        #expect(injured.importance == .low)
        // With one of them fit, two count: still low. With all three fit, Sharpness.
        #expect(try suggest(fixture(competition: .friendly), sharpness: [0.5, 0.6, 0.65], injured: 1).importance == .low)
        #expect(try suggest(fixture(competition: .friendly), sharpness: [0.5, 0.6, 0.65]).importance == .sharpness)
        // An injured player above the line does not stop three unsharp fit ones counting.
        #expect(try suggest(fixture(competition: .friendly), sharpness: [1, 0.5, 0.6, 0.65], injured: 1).importance == .sharpness)
    }

    @Test func aMatchInThreeDaysStaysLow() throws {
        let s = try suggest(fixture(competition: .friendly), among: [fixture("next", daysFromToday: 3, competition: .friendly)],
                            sharpness: [0.5, 0.6, 0.65])
        #expect(s.importance == .low)
    }

    @Test func sharpnessLevelExactlyAtTheLineIsNotUnsharp() throws {
        #expect(try suggest(fixture(competition: .friendly), sharpness: [0.7, 0.7, 0.7]).importance == .low)
    }

    @Test func unsharpPlayersOutsideTheFirstElevenDoNotCount() throws {
        let s = try suggest(fixture(competition: .friendly), sharpness: [0.5, 0.6], outside: 0.1)
        #expect(s.importance == .low)
    }

    @Test func aHighScoreIsNeverSharpness() throws {
        #expect(try suggest(fixture(), sharpness: Array(repeating: 0.1, count: 11)).importance == .medium)
    }

    // MARK: Reasons and order

    @Test func reasonsReadAsWritten() throws {
        let s = try suggest(fixture(opponent: .stronger), among: [fixture("next", daysFromToday: 2, opponent: .muchStronger)],
                            confirmed: [confirmed("p1", daysFromToday: -2), confirmed("p2", daysFromToday: -5)])
        #expect(s.reasons == ["League match: 80", "Stronger opponent (×1.1)", "A bigger match follows in 2 days (×0.6)",
                              "Third match in 7 days (×0.8)", "Score 42: Low"])
        let rested = try suggest(fixture(opponent: .stronger), confirmed: [confirmed("p1", daysFromToday: -8)])
        #expect(rested.reasons == ["League match: 80", "Stronger opponent (×1.1)", "A week or more since the last match (×1.1)",
                                   "Score 97: High"])
        let one = try suggest(fixture(competition: .cup, opponent: .weaker), among: [fixture("next", daysFromToday: 1, competition: .cup)])
        #expect(one.reasons == ["Cup match: 60", "Weaker opponent (×0.8)", "Score 48: Low"])
        let bigger = try suggest(fixture(competition: .friendly, opponent: .muchWeaker), among: [fixture("next", daysFromToday: 1)])
        #expect(bigger.reasons == ["Friendly: 10", "Much weaker opponent (×0.6)", "A bigger match follows in 1 day (×0.6)", "Score 4: Low"])
    }

    @Test func matchCountsReadByHowManyCameBefore() throws {
        func reason(_ before: Int) throws -> String {
            let lineups = (0..<before).map { confirmed("p\($0)", daysFromToday: -($0 + 1)) }
            return try suggest(fixture(), confirmed: lineups).reasons[1]
        }
        #expect(try reason(2) == "Third match in 7 days (×0.8)")
        #expect(try reason(3) == "Fourth match in 7 days (×0.8)")
        #expect(try reason(4) == "Fifth match in 7 days (×0.8)")
        #expect(try reason(5) == "Match 6 in 7 days (×0.8)")
        #expect(try reason(6) == "Match 7 in 7 days (×0.8)")
    }

    @Test func inputOrderDoesNotMatter() throws {
        let others = [fixture("n1", daysFromToday: 3), fixture("n2", daysFromToday: 5), fixture("p1", daysFromToday: -2)]
        let lineups = [confirmed("p2", daysFromToday: -4), confirmed("p3", daysFromToday: -6)]
        let a = try suggest(fixture(), among: others, confirmed: lineups)
        let b = try suggest(fixture(), among: others.reversed(), confirmed: lineups.reversed())
        #expect(a == b)
    }

    @Test func theSuggestionNeverChangesTheFixture() throws {
        let f = fixture()
        _ = try suggest(f)
        #expect(f.importance == .medium)
    }

    // MARK: Bad parameters

    @Test func badParametersAreAnError() throws {
        let zeroWindow = rules { $0.crowdedWindowDays = 0 }
        #expect(throws: PlanError.badParameters(["importanceRules crowdedWindowDays is 0, not 1 or more"])) {
            try suggest(fixture(), parameters: zeroWindow)
        }
        let zeroFactor = rules { $0.strongerFactor = 0 }
        #expect(throws: PlanError.badParameters(["importanceRules strongerFactor is 0.0, not a finite number above 0"])) {
            try suggest(fixture(), parameters: zeroFactor)
        }
    }

    @Test func aScoreTooLargeToCountIsAnErrorNotACrash() throws {
        // Every base and factor is finite, but the base is beyond what a whole number can hold.
        let huge = rules { $0.leagueBase = 1e300 }
        #expect(FitnessModel.problems(in: huge).isEmpty)
        #expect(throws: PlanError.self) { try suggest(fixture(), parameters: huge) }
        // Finite factors whose product overflows.
        let overflow = rules { $0.strongerFactor = 1e308 }
        #expect(FitnessModel.problems(in: overflow).isEmpty)
        #expect(throws: PlanError.self) { try suggest(fixture(opponent: .stronger), parameters: overflow) }
        // Not a number never reaches the count: the parameter check stops it.
        #expect(throws: PlanError.self) { try suggest(fixture(), parameters: rules { $0.leagueBase = .nan }) }
    }
}
