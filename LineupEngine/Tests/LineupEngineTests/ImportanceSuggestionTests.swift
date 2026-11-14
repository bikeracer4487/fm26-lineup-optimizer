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

    /// Eleven first-eleven players with the given sharpness each, and one extra outside the eleven.
    func squad(sharpness: [Double], outsideSharpness: Double = 1) -> (players: [Player], tiers: SquadTiers) {
        var players: [Player] = []
        var first: [SlotID: PlayerID] = [:]
        for (i, slot) in SlotID.allCases.prefix(11).enumerated() {
            let p = Player.fixture(name: "Starter \(i)", sharpness: i < sharpness.count ? sharpness[i] : 1)
            players.append(p)
            first[slot] = p.id
        }
        players.append(Player.fixture(name: "Reserve", sharpness: outsideSharpness))
        return (players, SquadTiers(first: first, second: [:], ratings: [:]))
    }

    func suggest(_ f: Fixture, among others: [Fixture] = [], confirmed: [ConfirmedLineup] = [],
                 sharpness: [Double] = [], outside: Double = 1, parameters: EngineParameters? = nil) -> ImportanceSuggestion {
        let s = squad(sharpness: sharpness, outsideSharpness: outside)
        return ImportanceAdvisor.suggest(for: f, among: others, confirmed: confirmed, players: s.players, tiers: s.tiers,
                                         parameters: parameters ?? self.parameters)
    }

    // MARK: Base and opponent

    @Test func aLeagueMatchAgainstASimilarSideIsMedium() {
        let s = suggest(fixture())
        #expect(s.importance == .medium)
        #expect(s.score == 80)
        #expect(s.basis == .carriedOverFM26)
    }

    @Test func againstAStrongerSideItIsHigh() {
        let s = suggest(fixture(opponent: .stronger))
        #expect(s.importance == .high)
        #expect(abs(s.score - 88) < 1e-9)
    }

    @Test func opponentFactorsApply() {
        #expect(abs(suggest(fixture(opponent: .muchStronger)).score - 96) < 1e-9)
        #expect(abs(suggest(fixture(opponent: .weaker)).score - 64) < 1e-9)
        #expect(abs(suggest(fixture(opponent: .muchWeaker)).score - 48) < 1e-9)
        #expect(suggest(fixture(opponent: .muchWeaker)).importance == .low)
    }

    @Test func aMinorCupMatchIsLow() {
        let s = suggest(fixture(competition: .minorCup))
        #expect(s.importance == .low)
        #expect(s.score == 30)
    }

    @Test func aFriendlyIsLow() {
        let s = suggest(fixture(competition: .friendly))
        #expect(s.importance == .low)
        #expect(s.score == 10)
    }

    @Test func aCupMatchIsMedium() {
        let s = suggest(fixture(competition: .cup))
        #expect(s.importance == .medium)
        #expect(s.score == 60)
    }

    @Test func withNothingSetTheSuggestionIsMedium() {
        let s = suggest(fixture(competition: nil, opponent: nil))
        #expect(s.importance == .medium)
        #expect(s.score == 50)
        #expect(s.reasons == ["No competition set: 50", "Score 50: medium"])
    }

    // MARK: Schedule

    @Test func aBiggerMatchSoonAfterReducesTheScore() {
        // The next match is a league match against a stronger side: 88, bigger than this one's 80.
        for (days, expected) in [(2, 48.0), (3, 56), (4, 72), (5, 80)] {
            let s = suggest(fixture(), among: [fixture("next", daysFromToday: days, opponent: .stronger)])
            #expect(abs(s.score - expected) < 1e-9, "\(days) days")
        }
        #expect(suggest(fixture(), among: [fixture("next", daysFromToday: 2, opponent: .stronger)]).importance == .low)
    }

    @Test func theNextMatchMustBeBiggerThanThisOne() {
        // 96 then 80 three days later: the next match reaches the line but is smaller.
        let big = suggest(fixture(opponent: .muchStronger), among: [fixture("next", daysFromToday: 3)])
        #expect(abs(big.score - 96) < 1e-9)
        #expect(big.importance == .high)
        #expect(!big.reasons.contains { $0.hasPrefix("A bigger match follows") })
        // 80 then 80 two days later: the same size is not bigger.
        let same = suggest(fixture(), among: [fixture("next", daysFromToday: 2)])
        #expect(same.score == 80)
        #expect(!same.reasons.contains { $0.hasPrefix("A bigger match follows") })
        // 80 then 88 two days later.
        let bigger = suggest(fixture(), among: [fixture("next", daysFromToday: 2, opponent: .stronger)])
        #expect(abs(bigger.score - 48) < 1e-9)
        #expect(bigger.reasons.contains("A bigger match follows in 2 days (×0.6)"))
    }

    @Test func aLesserMatchFollowingDoesNotReduceTheScore() {
        let next = fixture("next", daysFromToday: 2, competition: .cup)
        #expect(suggest(fixture(), among: [next]).score == 80)
        let weakLeague = fixture("next", daysFromToday: 2, opponent: .weaker)
        #expect(suggest(fixture(), among: [weakLeague]).score == 80)
    }

    @Test func theNextFixtureIsTheEarliestAfterThisOneAndThisOneIsIgnored() {
        let early = fixture("a", daysFromToday: 3, opponent: .stronger)
        let late = fixture("b", daysFromToday: 2, competition: .friendly)
        // The earlier of the two (2 days) is a friendly, so nothing applies, although the other would.
        #expect(suggest(fixture(), among: [early, late]).score == 80)
        #expect(abs(suggest(fixture(), among: [fixture(), early]).score - 56) < 1e-9)
    }

    @Test func aThirdMatchInSevenDaysReducesTheScore() {
        // Six and three days before: with the match day, three matches in seven days.
        let s = suggest(fixture(), among: [fixture("p1", daysFromToday: -3)], confirmed: [confirmed("p2", daysFromToday: -6)])
        #expect(abs(s.score - 64) < 1e-9)
        #expect(s.reasons.contains("Third match in 7 days (×0.8)"))
    }

    @Test func aMatchSevenDaysBeforeIsOutsideTheWindow() {
        // Seven days before is the eighth day counting the match day.
        let s = suggest(fixture(), among: [fixture("p1", daysFromToday: -3)], confirmed: [confirmed("p2", daysFromToday: -7)])
        #expect(s.score == 80)
        #expect(!s.reasons.contains { $0.contains("in 7 days") })
        let planned = suggest(fixture(), among: [fixture("p1", daysFromToday: -3), fixture("p2", daysFromToday: -7)])
        #expect(planned.score == 80)
    }

    @Test func twoMatchesInSevenDaysAreNeeded() {
        #expect(suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -3)]).score == 80)
        // A match 8 days back is outside the window.
        #expect(suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -3), confirmed("p2", daysFromToday: -8)]).score == 80)
    }

    @Test func aFixtureAndALineupWithTheSameIdCountOnce() {
        let s = suggest(fixture(), among: [fixture("p1", daysFromToday: -3)], confirmed: [confirmed("p1", daysFromToday: -3)])
        #expect(s.score == 80)
    }

    @Test func aWeekSinceTheLastMatchRaisesTheScore() {
        let s = suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -8)])
        #expect(s.importance == .high)
        #expect(abs(s.score - 88) < 1e-9)
        #expect(abs(suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -7)]).score - 88) < 1e-9)
        #expect(suggest(fixture(), confirmed: [confirmed("p1", daysFromToday: -6)]).score == 80)
    }

    @Test func noRiseWhenAReductionApplies() {
        let s = suggest(fixture(), among: [fixture("next", daysFromToday: 3, opponent: .stronger)],
                        confirmed: [confirmed("p1", daysFromToday: -9)])
        #expect(abs(s.score - 56) < 1e-9)
        #expect(!s.reasons.contains { $0.contains("A week or more") })
    }

    // MARK: Sharpness

    @Test func aLowScoreWithUnsharpRegularsAndTimeToRecoverSuggestsSharpness() {
        let f = fixture(competition: .friendly)
        let s = suggest(f, among: [fixture("next", daysFromToday: 5)], sharpness: [0.5, 0.6, 0.69])
        #expect(s.importance == .sharpness)
        #expect(s.score == 10)
        #expect(s.reasons.last == "3 of the first eleven are under 70% sharpness, and the next match is 5 days later")
        #expect(s.reasons.dropLast().last == "Score 10: low")
        let none = suggest(f, sharpness: [0.5, 0.6, 0.69])
        #expect(none.importance == .sharpness)
        #expect(none.reasons.last == "3 of the first eleven are under 70% sharpness, and no match follows")
    }

    @Test func twoUnsharpRegularsStayLow() {
        #expect(suggest(fixture(competition: .friendly), sharpness: [0.5, 0.6]).importance == .low)
    }

    @Test func aMatchInThreeDaysStaysLow() {
        let s = suggest(fixture(competition: .friendly), among: [fixture("next", daysFromToday: 3, competition: .friendly)],
                        sharpness: [0.5, 0.6, 0.65])
        #expect(s.importance == .low)
    }

    @Test func sharpnessLevelExactlyAtTheLineIsNotUnsharp() {
        #expect(suggest(fixture(competition: .friendly), sharpness: [0.7, 0.7, 0.7]).importance == .low)
    }

    @Test func unsharpPlayersOutsideTheFirstElevenDoNotCount() {
        let s = suggest(fixture(competition: .friendly), sharpness: [0.5, 0.6], outside: 0.1)
        #expect(s.importance == .low)
    }

    @Test func aHighScoreIsNeverSharpness() {
        #expect(suggest(fixture(), sharpness: Array(repeating: 0.1, count: 11)).importance == .medium)
    }

    // MARK: Reasons and order

    @Test func reasonsReadAsWritten() {
        let s = suggest(fixture(opponent: .stronger), among: [fixture("next", daysFromToday: 2, opponent: .muchStronger)],
                        confirmed: [confirmed("p1", daysFromToday: -2), confirmed("p2", daysFromToday: -5)])
        #expect(s.reasons == ["League match: 80", "Stronger opponent (×1.1)", "A bigger match follows in 2 days (×0.6)",
                              "Third match in 7 days (×0.8)", "Score 42: low"])
        let rested = suggest(fixture(opponent: .stronger), confirmed: [confirmed("p1", daysFromToday: -8)])
        #expect(rested.reasons == ["League match: 80", "Stronger opponent (×1.1)", "A week or more since the last match (×1.1)",
                                   "Score 97: high"])
        let one = suggest(fixture(competition: .cup, opponent: .weaker), among: [fixture("next", daysFromToday: 1, competition: .cup)])
        #expect(one.reasons == ["Cup match: 60", "Weaker opponent (×0.8)", "Score 48: low"])
        let bigger = suggest(fixture(competition: .friendly, opponent: .muchWeaker), among: [fixture("next", daysFromToday: 1)])
        #expect(bigger.reasons == ["Friendly: 10", "Much weaker opponent (×0.6)", "A bigger match follows in 1 day (×0.6)", "Score 4: low"])
    }

    @Test func matchCountsReadByHowManyCameBefore() {
        func reason(_ before: Int) -> String {
            let lineups = (0..<before).map { confirmed("p\($0)", daysFromToday: -($0 + 1)) }
            return suggest(fixture(), confirmed: lineups).reasons[1]
        }
        #expect(reason(2) == "Third match in 7 days (×0.8)")
        #expect(reason(3) == "Fourth match in 7 days (×0.8)")
        #expect(reason(4) == "Fifth match in 7 days (×0.8)")
        #expect(reason(5) == "Match 6 in 7 days (×0.8)")
        #expect(reason(6) == "Match 7 in 7 days (×0.8)")
    }

    @Test func inputOrderDoesNotMatter() {
        let others = [fixture("n1", daysFromToday: 3), fixture("n2", daysFromToday: 5), fixture("p1", daysFromToday: -2)]
        let lineups = [confirmed("p2", daysFromToday: -4), confirmed("p3", daysFromToday: -6)]
        let a = suggest(fixture(), among: others, confirmed: lineups)
        let b = suggest(fixture(), among: others.reversed(), confirmed: lineups.reversed())
        #expect(a == b)
    }

    @Test func theSuggestionNeverChangesTheFixture() {
        let f = fixture()
        _ = suggest(f)
        #expect(f.importance == .medium)
    }
}
