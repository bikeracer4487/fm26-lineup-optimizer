import Testing
@testable import LineupEngine

@Suite struct DevelopmentTests {
    let parameters = EngineParameters.fm27
    let assignments: [SlotAssignment]
    let day = Day(year: 2026, month: 11, day: 14)!

    init() throws {
        assignments = try PlannerFixture.tactic().assignments(catalog: RoleCatalog.fm27())
    }

    func assignment(_ slot: SlotID) -> SlotAssignment { assignments.first { $0.slot == slot }! }

    /// A player with familiarity `familiarity` in both phases at each of `slots`, Professionalism 20 and Ambition and
    /// Determination 10: his growth is the table's in full, so his reach is his potential whenever it is within it.
    func player(_ name: String, age: Int = 20, current: Int = 100, potential: Int = 100, slots: [SlotID] = [],
                familiarity: Int = 15, squad: Squad = .firstTeam, club: String? = "Oxford City",
                loanedTo: String? = nil, professionalism: Int = 20) -> Player {
        var positions: [Position: Int] = [:]
        for slot in slots {
            positions[assignment(slot).ipPosition] = familiarity
            positions[assignment(slot).oopPosition] = familiarity
        }
        return Player.fixture(name: name, squad: squad, age: age, attributes: [.professionalism: professionalism],
                              familiarity: positions, currentAbility: current, potentialAbility: potential,
                              club: club, loanedTo: loanedTo)
    }

    /// A player of 28 who no longer grows: he is compared at his rating today.
    func veteran(_ name: String) -> Player { player(name, age: 28, current: 120, potential: 120) }

    func tiers(first: [SlotID: Player] = [:], second: [SlotID: Player] = [:],
               ratings: [(Player, SlotID, Double)] = []) -> SquadTiers {
        var table: [PlayerID: [SlotID: Double]] = [:]
        for (player, slot, value) in ratings { table[player.id, default: [:]][slot] = value }
        return SquadTiers(first: first.mapValues(\.id), second: second.mapValues(\.id), ratings: table)
    }

    func outlooks(_ players: [Player], _ tiers: SquadTiers, retraining: [Retraining] = [],
                  parameters: EngineParameters? = nil) throws -> [PlayerID: Outlook] {
        try Development.outlooks(players: players, ownClub: "Oxford City", assignments: assignments, tiers: tiers,
                                 retraining: retraining, parameters: parameters ?? self.parameters)
    }

    func slot(_ outlook: Outlook?, _ slot: SlotID) -> SlotOutlook? { outlook?.slots.first { $0.slot == slot } }

    // MARK: The slots he can play

    @Test func aSlotCountsWhenHeIsAnOptionInBothPhasesOrIsRetrainingThere() throws {
        let am = assignment(.AM_L)
        #expect(am.ipPosition != am.oopPosition)
        let option = player("Option", slots: [.AM_L], familiarity: 10)
        var short = player("Short", slots: [.AM_L], familiarity: 10)
        short.familiarity[am.oopPosition] = 9
        let retrainee = player("Retrainee", slots: [.AM_L], familiarity: 9)
        let oopRetrainee = player("Oop Retrainee", slots: [.AM_L], familiarity: 9)
        let unentered = player("Unentered", slots: [.AM_L], familiarity: 9)
        let everyone = [option, short, retrainee, oopRetrainee, unentered]
        let t = tiers(ratings: everyone.map { ($0, .AM_L, 50) })
        let found = try outlooks(everyone, t, retraining: [
            Retraining(player: retrainee.id, position: am.ipPosition, acceptedOn: day),
            Retraining(player: oopRetrainee.id, position: am.oopPosition, acceptedOn: day),
            Retraining(player: unentered.id, position: assignment(.D_L).ipPosition, acceptedOn: day)])
        #expect(found[option.id]?.slots.map(\.slot) == [.AM_L])
        #expect(found[short.id]?.slots.map(\.slot) == [])
        #expect(found[retrainee.id]?.slots.map(\.slot) == [.AM_L])
        #expect(found[oopRetrainee.id]?.slots.map(\.slot) == [.AM_L])
        #expect(found[unentered.id]?.slots.map(\.slot) == [])
    }

    // MARK: Levels

    @Test func eachLevelAtAndBesideItsBoundary() throws {
        let first = veteran("First Choice"), second = veteran("Second Choice")
        // Rated 50 at an ability of 100, so his reach rating is half his potential.
        let cases: [(potential: Int, level: ReachLevel)] = [
            (140, .couldPassFirst), (139, .couldMakeSecond), (120, .couldMakeSecond), (119, .couldBeCover),
            (112, .couldBeCover), (111, .markedlyLower)]
        let young = cases.map { player("Young \($0.potential)", potential: $0.potential, slots: [.D_L]) }
        let t = tiers(first: [.D_L: first], second: [.D_L: second],
                      ratings: [(first, .D_L, 70), (second, .D_L, 60)] + young.map { ($0, .D_L, 50) })
        let found = try outlooks([first, second] + young, t)
        for (player, expected) in zip(young, cases) {
            let outlook = found[player.id]
            #expect(slot(outlook, .D_L)?.level == expected.level, "\(player.name)")
            #expect(outlook?.level == expected.level, "\(player.name)")
            #expect(outlook?.isMarkedlyLower == (expected.level == .markedlyLower), "\(player.name)")
            #expect(slot(outlook, .D_L)?.reachRating == Double(expected.potential) / 2, "\(player.name)")
        }
        let row = try #require(slot(found[young[0].id], .D_L))
        #expect(row.rating == 50 && !row.isFirstChoice)
        #expect(row.firstChoice == Rival(player: first.id, name: "First Choice", age: 28, rating: 70, compared: 70))
        #expect(row.secondChoice == Rival(player: second.id, name: "Second Choice", age: 28, rating: 60, compared: 60))
        #expect(found[young[0].id]?.best == row)
        #expect(found[young[0].id]?.average == nil)
    }

    @Test func thePlayerOfSixteenHasTheLowerBarAndThePlayerOfSeventeenDoesNot() throws {
        let first = veteran("First Choice"), second = veteran("Second Choice")
        // Rated 40 at 100 with a reach of 125: 50, under the bar of 56 (80% of 70) and over the youngest's 49 (70%).
        let sixteen = player("Sixteen", age: 16, potential: 125, slots: [.D_L])
        let seventeen = player("Seventeen", age: 17, potential: 125, slots: [.D_L])
        let t = tiers(first: [.D_L: first], second: [.D_L: second],
                      ratings: [(first, .D_L, 70), (second, .D_L, 60), (sixteen, .D_L, 40), (seventeen, .D_L, 40)])
        let found = try outlooks([first, second, sixteen, seventeen], t)
        #expect(slot(found[sixteen.id], .D_L)?.reachRating == 50)
        #expect(found[sixteen.id]?.level == .couldBeCover)
        #expect(found[seventeen.id]?.level == .markedlyLower)
    }

    @Test func aMissingSecondChoiceCountsAsReached() throws {
        let first = veteran("First Choice"), second = veteran("Second Choice")
        // A reach rating of 56: over the bar, under the second choice's 60.
        let young = player("Young", potential: 112, slots: [.D_L])
        let ratings: [(Player, SlotID, Double)] = [(first, .D_L, 70), (second, .D_L, 60), (young, .D_L, 50)]
        let none = try outlooks([first, second, young], tiers(first: [.D_L: first], ratings: ratings))
        #expect(slot(none[young.id], .D_L)?.secondChoice == nil)
        #expect(none[young.id]?.level == .couldMakeSecond)
        // He is the second choice himself.
        let himself = try outlooks([first, second, young], tiers(first: [.D_L: first], second: [.D_L: young], ratings: ratings))
        #expect(slot(himself[young.id], .D_L)?.secondChoice == nil)
        #expect(himself[young.id]?.level == .couldMakeSecond)
        // A second choice he does not reach.
        let behind = try outlooks([first, second, young], tiers(first: [.D_L: first], second: [.D_L: second], ratings: ratings))
        #expect(behind[young.id]?.level == .couldBeCover)
    }

    @Test func aSlotWithNoFirstChoiceHasNoBandAndNoLevel() throws {
        let second = veteran("Second Choice")
        let young = player("Young", potential: 140, slots: [.D_L])
        let found = try outlooks([second, young], tiers(second: [.D_L: second], ratings: [(second, .D_L, 60), (young, .D_L, 50)]))
        let row = try #require(slot(found[young.id], .D_L))
        #expect(row.firstChoice == nil && !row.isFirstChoice)
        #expect(row.band == nil && row.level == nil && row.pointsNeeded == nil)
        #expect(row.secondChoice?.player == second.id)
        #expect(found[young.id]?.best == nil)
    }

    @Test func heIsNotComparedWithHimself() throws {
        let other = veteran("Other"), cover = veteran("Cover")
        let young = player("Young", potential: 140, slots: [.D_L, .D_R])
        let t = tiers(first: [.D_L: young, .D_R: other], second: [.D_L: cover],
                      ratings: [(young, .D_L, 80), (young, .D_R, 50), (other, .D_R, 60), (cover, .D_L, 70)])
        let found = try outlooks([other, cover, young], t)
        let own = try #require(slot(found[young.id], .D_L))
        #expect(own.isFirstChoice && own.firstChoice == nil)
        #expect(own.band == nil && own.level == nil && own.pointsNeeded == nil)
        #expect(own.secondChoice?.player == cover.id)
        #expect(found[young.id]?.best?.slot == .D_R)
        #expect(found[young.id]?.level == .couldPassFirst)

        // First choice at his only slot: nothing to compare.
        let only = player("Only", potential: 140, slots: [.D_L])
        let alone = try outlooks([cover, only], tiers(first: [.D_L: only], second: [.D_L: cover],
                                                      ratings: [(only, .D_L, 80), (cover, .D_L, 70)]))
        #expect(slot(alone[only.id], .D_L)?.isFirstChoice == true)
        #expect(alone[only.id]?.best == nil)
        #expect(alone[only.id]?.level == nil)
        #expect(alone[only.id]?.average == nil)
    }

    @Test func aYoungFirstChoiceIsComparedAtHisOwnReach() throws {
        // Rated 50 at 100 with a reach of 140: a reach rating of 70.
        let young = player("Young", age: 18, potential: 140, slots: [.D_L])
        let old = player("Old", age: 28, current: 100, potential: 100)
        let behindOld = try outlooks([old, young], tiers(first: [.D_L: old], ratings: [(old, .D_L, 60), (young, .D_L, 50)]))
        #expect(slot(behindOld[young.id], .D_L)?.firstChoice?.compared == 60)
        #expect(behindOld[young.id]?.level == .couldPassFirst)

        // Of equal rating, growing as fast: his own reach rating is 60 × 140 ÷ 100.
        let rising = player("Rising", age: 20, current: 100, potential: 140)
        let behindRising = try outlooks([rising, young], tiers(first: [.D_L: rising], ratings: [(rising, .D_L, 60), (young, .D_L, 50)]))
        let row = try #require(slot(behindRising[young.id], .D_L))
        #expect(row.firstChoice?.rating == 60)
        #expect(abs((row.firstChoice?.compared ?? 0) - 84) < 1e-9)
        #expect(row.level != .couldPassFirst)
    }

    // MARK: Bands

    @Test func eachBand() throws {
        func band(_ young: Player, rating: Double, firstChoiceRating: Double) throws -> ReachBand? {
            let first = veteran("First Choice")
            let found = try outlooks([first, young], tiers(first: [.D_L: first],
                                                           ratings: [(first, .D_L, firstChoiceRating), (young, .D_L, rating)]))
            return slot(found[young.id], .D_L)?.band
        }
        // Aged 20 at 100, potential 200: 100, 114, 126, 138, 150 over the coming seasons; rated 50: 50, 57, 63, 69, 75.
        let rising = player("Rising", age: 20, current: 100, potential: 200, slots: [.D_L])
        #expect(try band(rising, rating: 50, firstChoiceRating: 50) == .close)
        #expect(try band(rising, rating: 50, firstChoiceRating: 56) == .close)
        #expect(try band(rising, rating: 50, firstChoiceRating: 57.5) == .onCourse)
        // Ahead at 23 (three seasons on) is on course; at 24 it is only possible.
        #expect(try band(rising, rating: 50, firstChoiceRating: 69) == .onCourse)
        #expect(try band(rising, rating: 50, firstChoiceRating: 70) == .possible)
        // His reach falls short, but his potential does not.
        let slow = player("Slow", age: 20, current: 100, potential: 200, slots: [.D_L], professionalism: 1)
        #expect(try band(slow, rating: 50, firstChoiceRating: 70) == .possible)
        // His potential as a rating, 65, is below the first choice's 70.
        let capped = player("Capped", age: 20, current: 100, potential: 130, slots: [.D_L])
        #expect(try band(capped, rating: 50, firstChoiceRating: 70) == .notExpected)
        #expect(try band(capped, rating: 50, firstChoiceRating: 65) == .onCourse)
    }

    @Test func theBandWalksAYoungFirstChoiceForwardToo() throws {
        // Aged 18 at 100, potential 200, rated 70: 70, 82.6, 92.4, 102.2, 110.6, 119 over the coming seasons.
        let young = player("Young", age: 18, current: 100, potential: 200, slots: [.D_L])
        func band(_ first: Player, rating: Double) throws -> ReachBand? {
            let found = try outlooks([first, young], tiers(first: [.D_L: first], ratings: [(first, .D_L, rating), (young, .D_L, 70)]))
            return slot(found[young.id], .D_L)?.band
        }
        // Today's 79 is passed in one season, but walked forward he is 88.5, 98.0, 107.4, 116.9: passed at 23.
        #expect(try band(player("Old", age: 28, current: 100, potential: 100), rating: 79) == .close)
        #expect(try band(player("Rising", age: 22, current: 100, potential: 148), rating: 79) == .onCourse)
        // Walked forward from 73 he is 81.8 a season on, and passed then; his reach rating, 108, only at 22.
        #expect(try band(player("Rising", age: 22, current: 100, potential: 148), rating: 73) == .close)
        // His seasons run out four on, at 26: his last value, 116.9, is held, and passed five seasons on, at 23.
        #expect(try band(player("Older", age: 23, current: 100, potential: 148), rating: 79) == .onCourse)
    }

    // MARK: His best slot

    @Test func hisBestSlotHasTheBestLevelThenTheGreatestShare() throws {
        let left = veteran("Left"), right = veteran("Right"), rightCover = veteran("Right Cover")
        let young = player("Young", slots: [.D_L, .D_R])
        func best(leftRating: Double, rightRating: Double, rightSecond: Bool = false) throws -> Outlook? {
            let t = tiers(first: [.D_L: left, .D_R: right], second: rightSecond ? [.D_R: rightCover] : [:],
                          ratings: [(left, .D_L, leftRating), (right, .D_R, rightRating), (rightCover, .D_R, 55),
                                    (young, .D_L, 50), (young, .D_R, 50)])
            return try outlooks([left, right, rightCover, young], t)[young.id]
        }
        // The same level at both: the greater share of the first choice's rating.
        #expect(try best(leftRating: 70, rightRating: 60)?.best?.slot == .D_R)
        // A tie: the earlier slot.
        #expect(try best(leftRating: 60, rightRating: 60)?.best?.slot == .D_L)
        // The greater share is at a slot where a strong second choice leaves him cover only.
        let outlook = try best(leftRating: 70, rightRating: 60, rightSecond: true)
        #expect(slot(outlook, .D_R)?.level == .couldBeCover)
        #expect(outlook?.best?.slot == .D_L)
        #expect(outlook?.level == .couldMakeSecond)
    }

    // MARK: With no slot

    @Test func withNoSlotHeIsComparedWithTheAverage() throws {
        let senior = player("Senior", age: 28, current: 120, potential: 120)
        let loanee = player("Loanee", age: 28, current: 200, potential: 200, club: "Elsewhere FC")
        let away = player("Away", age: 28, current: 10, potential: 10, loanedTo: "Elsewhere FC")
        let reserve = player("Reserve", age: 28, current: 50, potential: 50, squad: .u21)
        let others = [senior, loanee, away, reserve]
        #expect(Development.averageAbility(of: others, ownClub: "Oxford City") == 120)
        #expect(Development.averageAbility(of: [loanee, away, reserve], ownClub: "Oxford City") == nil)

        let cases: [(potential: Int, level: ReachLevel)] = [
            (120, .couldMakeSecond), (119, .couldBeCover), (102, .couldBeCover), (101, .markedlyLower)]
        for (potential, level) in cases {
            let young = player("Young", potential: potential, squad: .u21)
            let outlook = try outlooks(others + [young], tiers())[young.id]
            #expect(outlook?.slots == [], "\(potential)")
            #expect(outlook?.best == nil, "\(potential)")
            #expect(outlook?.level == level, "\(potential)")
            #expect(outlook?.average == 120, "\(potential)")
        }
        let young = player("Young", potential: 101, squad: .u21)
        let unknown = try outlooks([loanee, away, reserve, young], tiers())[young.id]
        #expect(unknown?.level == .couldBeCover)
        #expect(unknown?.average == nil)
    }

    // MARK: Who gets one

    @Test func whoGetsAnOutlook() throws {
        let own = player("Own", age: 23)
        let reserve = player("Reserve", age: 17, squad: .u18)
        let loanee = player("Loanee", club: "Elsewhere FC")
        let away = player("Away", loanedTo: "Elsewhere FC")
        let older = player("Older", age: 24)
        let unrated = player("Unrated", current: 0)
        let found = try outlooks([own, reserve, loanee, away, older, unrated], tiers())
        #expect(Set(found.keys) == [own.id, reserve.id])
        #expect(found[own.id]?.estimate == (try Reach.estimate(for: own, parameters: parameters)))
    }

    // MARK: Points needed

    @Test func pointsNeededIsRoundedUpAndNeverNegative() throws {
        let first = veteran("First Choice")
        func points(rating: Double, firstChoiceRating: Double) throws -> Int? {
            let young = player("Young", slots: [.D_L])
            let found = try outlooks([first, young], tiers(first: [.D_L: first],
                                                           ratings: [(first, .D_L, firstChoiceRating), (young, .D_L, rating)]))
            return slot(found[young.id], .D_L)?.pointsNeeded
        }
        #expect(try points(rating: 50, firstChoiceRating: 70.2) == 41)
        // 100 × (1.1 − 1) is 10.000000000000009 in binary floating point: still 10.
        #expect(try points(rating: 100, firstChoiceRating: 110) == 10)
        #expect(try points(rating: 50, firstChoiceRating: 70) == 40)
        #expect(try points(rating: 70, firstChoiceRating: 70) == 0)
        #expect(try points(rating: 80, firstChoiceRating: 70) == 0)
        #expect(try points(rating: 0, firstChoiceRating: 70) == nil)
    }

    // MARK: Matches here

    /// `count` lineups on consecutive days ending the day before `day`, `player` starting `starts` of them (the first ones).
    func history(starts: Int, of count: Int, player: Player) -> StartHistory {
        let other = PlayerID(key: "other")
        return StartHistory((0..<count).map { n in
            ConfirmedLineup(fixture: FixtureID("m\(n)"), date: day.adding(days: -1 - n),
                            starters: [.D_L: n < starts ? player.id : other])
        })
    }

    func matchesHere(_ player: Player, _ tiers: SquadTiers, _ history: StartHistory) -> MatchesHere {
        Development.matchesHere(for: player.id, tiers: tiers, history: history, asOf: day, parameters: parameters)
    }

    @Test func aFirstChoiceHasEnoughWhateverHeStarted() {
        let p = player("First", slots: [.D_L])
        let t = tiers(first: [.D_L: p], ratings: [(p, .D_L, 50)])
        let result = matchesHere(p, t, history(starts: 0, of: 8, player: p))
        #expect(result == MatchesHere(starts: 0, matches: 8, isCounted: true, isEnough: true))
        // Even with nothing confirmed.
        #expect(matchesHere(p, t, StartHistory([])).isEnough)
    }

    @Test func aThirdOfSixIsEnoughAndOneOfSixIsNot() {
        let p = player("Backup", slots: [.D_L])
        let t = tiers(ratings: [(p, .D_L, 50)])
        #expect(matchesHere(p, t, history(starts: 2, of: 6, player: p))
            == MatchesHere(starts: 2, matches: 6, isCounted: true, isEnough: true))
        #expect(matchesHere(p, t, history(starts: 1, of: 6, player: p))
            == MatchesHere(starts: 1, matches: 6, isCounted: true, isEnough: false))
        // A second choice who started too little has not enough either, once the matches are counted.
        let s = player("Second", slots: [.D_L])
        let t2 = tiers(second: [.D_L: s], ratings: [(s, .D_L, 50)])
        #expect(!matchesHere(s, t2, history(starts: 1, of: 6, player: s)).isEnough)
        #expect(matchesHere(s, t2, history(starts: 2, of: 6, player: s)).isEnough)
    }

    @Test func matchesOutsideTheWindowAreNotCounted() {
        let p = player("Backup", slots: [.D_L])
        let t = tiers(ratings: [(p, .D_L, 50)])
        let old = (0..<6).map { n in
            ConfirmedLineup(fixture: FixtureID("old\(n)"), date: day.adding(days: -61 - n), starters: [.D_L: p.id])
        }
        let result = matchesHere(p, t, StartHistory(old))
        #expect(result == MatchesHere(starts: 0, matches: 0, isCounted: false, isEnough: false))
    }

    @Test func withFewerThanSixConfirmedHisPlaceDecides() {
        let second = player("Second", slots: [.D_L]), backup = player("Backup", slots: [.D_L])
        let t = tiers(second: [.D_L: second], ratings: [(second, .D_L, 50), (backup, .D_L, 40)])
        let none = StartHistory([])
        #expect(matchesHere(second, t, none) == MatchesHere(starts: 0, matches: 0, isCounted: false, isEnough: true))
        #expect(matchesHere(backup, t, none) == MatchesHere(starts: 0, matches: 0, isCounted: false, isEnough: false))
        // Five confirmed and he started all five, but is a backup: not counted, not enough.
        let five = matchesHere(backup, t, history(starts: 5, of: 5, player: backup))
        #expect(five == MatchesHere(starts: 5, matches: 5, isCounted: false, isEnough: false))
        // Six confirmed counts them: all six started is enough for the backup.
        #expect(matchesHere(backup, t, history(starts: 6, of: 6, player: backup)).isCounted)
        // A player the tiers did not rate has no place to decide it.
        let unrated = player("Unrated", slots: [.D_L])
        #expect(!matchesHere(unrated, t, none).isEnough)
    }

    @Test func theMinimumAndShareComeFromTheParameters() {
        let p = player("Backup", slots: [.D_L])
        let t = tiers(ratings: [(p, .D_L, 50)])
        var q = parameters
        q.matchesHereMinimumConfirmed = Parameter(3, .derived, source: "test")
        q.matchesHereShare = Parameter(0.5, .derived, source: "test")
        let h = history(starts: 1, of: 4, player: p)
        #expect(!Development.matchesHere(for: p.id, tiers: t, history: h, asOf: day, parameters: q).isEnough)
        #expect(Development.matchesHere(for: p.id, tiers: t, history: history(starts: 2, of: 4, player: p), asOf: day,
                                        parameters: q).isEnough)
        q.matchesHereWindowDays = Parameter(3, .derived, source: "test")
        #expect(Development.matchesHere(for: p.id, tiers: t, history: h, asOf: day, parameters: q).matches == 2)
    }
}
