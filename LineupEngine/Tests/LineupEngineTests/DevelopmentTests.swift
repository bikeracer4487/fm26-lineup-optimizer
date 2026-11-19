import Testing
@testable import LineupEngine

@Suite struct DevelopmentTests {
    /// The standard parameters with the rating offset the numbers below are worked out for: a rating scales by
    /// (70 + ability), so at a current ability of 30 a reach rating is his rating × (70 + reach) ÷ 100.
    let parameters: EngineParameters = {
        var q = EngineParameters.fm27
        q.ratingAbilityOffset = Parameter(70, .derived, source: "test")
        return q
    }()
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
        // Rated 50 at an ability of 30, so his reach rating is (70 + his potential) ÷ 2: the first choice's 100 at 130,
        // the second's 90 at 110, the bar of 80 at 90.
        let cases: [(potential: Int, level: ReachLevel)] = [
            (130, .couldPassFirst), (129, .couldMakeSecond), (110, .couldMakeSecond), (109, .couldBeCover),
            (90, .couldBeCover), (89, .markedlyLower)]
        let young = cases.map { player("Young \($0.potential)", age: 18, current: 30, potential: $0.potential, slots: [.D_L]) }
        let t = tiers(first: [.D_L: first], second: [.D_L: second],
                      ratings: [(first, .D_L, 100), (second, .D_L, 90)] + young.map { ($0, .D_L, 50) })
        let found = try outlooks([first, second] + young, t)
        for (player, expected) in zip(young, cases) {
            let outlook = found[player.id]
            #expect(slot(outlook, .D_L)?.level == expected.level, "\(player.name)")
            #expect(outlook?.level == expected.level, "\(player.name)")
            #expect(outlook?.isMarkedlyLower == (expected.level == .markedlyLower), "\(player.name)")
            #expect(slot(outlook, .D_L)?.reachRating == Double(70 + expected.potential) / 2, "\(player.name)")
        }
        let row = try #require(slot(found[young[0].id], .D_L))
        #expect(row.rating == 50 && !row.isFirstChoice)
        #expect(row.firstChoice == Rival(player: first.id, name: "First Choice", age: 28, rating: 100, compared: 100,
                                         isAgeNamed: false))
        #expect(row.secondChoice == Rival(player: second.id, name: "Second Choice", age: 28, rating: 90, compared: 90,
                                          isAgeNamed: false))
        #expect(found[young[0].id]?.best == row)
        #expect(found[young[0].id]?.average == nil)
    }

    @Test func thePlayerOfSixteenHasTheLowerBarAndThePlayerOfSeventeenDoesNot() throws {
        let first = veteran("First Choice"), second = veteran("Second Choice")
        // Rated 50 at 30 with a reach of 80: 75, under the bar of 80 (80% of 100) and over the youngest's 70 (70%).
        let sixteen = player("Sixteen", age: 16, current: 30, potential: 80, slots: [.D_L])
        let seventeen = player("Seventeen", age: 17, current: 30, potential: 80, slots: [.D_L])
        let t = tiers(first: [.D_L: first], second: [.D_L: second],
                      ratings: [(first, .D_L, 100), (second, .D_L, 90), (sixteen, .D_L, 50), (seventeen, .D_L, 50)])
        let found = try outlooks([first, second, sixteen, seventeen], t)
        #expect(slot(found[sixteen.id], .D_L)?.reachRating == 75)
        #expect(found[sixteen.id]?.level == .couldBeCover)
        #expect(found[seventeen.id]?.level == .markedlyLower)
    }

    /// The levels of two players of `age` rated 50 at an ability of 30 at left back, with potentials `below` and `at`,
    /// behind a first choice rated 100 and, when `secondRating` is given, a second choice rated that.
    func levels(age: Int, below: Int, at: Int, secondRating: Double?) throws -> (below: SlotOutlook?, at: SlotOutlook?) {
        let first = veteran("First Choice"), second = veteran("Second Choice")
        let low = player("Below", age: age, current: 30, potential: below, slots: [.D_L])
        let level = player("At", age: age, current: 30, potential: at, slots: [.D_L])
        var ratings: [(Player, SlotID, Double)] = [(first, .D_L, 100), (low, .D_L, 50), (level, .D_L, 50)]
        if let secondRating { ratings.append((second, .D_L, secondRating)) }
        let t = tiers(first: [.D_L: first], second: secondRating == nil ? [:] : [.D_L: second], ratings: ratings)
        let found = try outlooks([first, second, low, level], t)
        return (slot(found[low.id], .D_L), slot(found[level.id], .D_L))
    }

    @Test func aReachBelowTheBarIsMarkedlyLowerEvenAboveAWeakSecondChoice() throws {
        // Reach ratings of (70 + potential) ÷ 2: 79 and 80, against a bar of 80 (80% of 100), both above the second
        // choice's 60.
        let (below, at) = try levels(age: 18, below: 88, at: 90, secondRating: 60)
        #expect(below?.reachRating == 79 && at?.reachRating == 80)
        #expect(below?.secondChoice?.rating == 60)
        #expect(below?.level == .markedlyLower)
        #expect(at?.level == .couldMakeSecond)
    }

    @Test func aReachBelowTheBarIsMarkedlyLowerEvenAboveAWeakSecondChoiceAndWithNoSecondChoice() throws {
        let (below, at) = try levels(age: 18, below: 88, at: 90, secondRating: nil)
        #expect(below?.secondChoice == nil && at?.secondChoice == nil)
        #expect(below?.level == .markedlyLower)
        #expect(at?.level == .couldMakeSecond)
    }

    @Test func aReachAboveTheBarAndBelowTheSecondChoiceIsCover() throws {
        // 80 and 89, at and above the bar of 80, below the second choice's 90.
        let (low, high) = try levels(age: 18, below: 90, at: 108, secondRating: 90)
        #expect(low?.reachRating == 80 && high?.reachRating == 89)
        #expect(low?.level == .couldBeCover)
        #expect(high?.level == .couldBeCover)
    }

    @Test func aReachExactlyAtTheSecondChoicesAboveTheBarCouldMakeTheSecondEleven() throws {
        // 84 and 85 against a second choice's 85, both above the bar of 80.
        let (below, at) = try levels(age: 18, below: 98, at: 100, secondRating: 85)
        #expect(below?.reachRating == 84 && at?.reachRating == 85)
        #expect(below?.level == .couldBeCover)
        #expect(at?.level == .couldMakeSecond)
    }

    @Test func theYoungestsBarIsSeventyPercentWhateverTheSecondChoice() throws {
        // 69 and 70 against the youngest's bar of 70 (70% of 100), above a second choice's 60 or with none.
        for second in [60.0, nil] {
            let (below, at) = try levels(age: 16, below: 68, at: 70, secondRating: second)
            #expect(below?.reachRating == 69 && at?.reachRating == 70)
            #expect(below?.level == .markedlyLower, "\(String(describing: second))")
            #expect(at?.level == .couldMakeSecond, "\(String(describing: second))")
        }
        // At 17 the bar is 80: 70 is below it.
        #expect(try levels(age: 17, below: 68, at: 70, secondRating: 60).at?.level == .markedlyLower)
    }

    @Test func aMissingSecondChoiceCountsAsReached() throws {
        let first = veteran("First Choice"), second = veteran("Second Choice")
        // Rated 50 at 30 with a reach of 42: a reach rating of 56, over the bar, under the second choice's 60.
        let young = player("Young", current: 30, potential: 42, slots: [.D_L])
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
        // Rated 70 at 100 with a reach of 140: a reach rating of 70 × 210 ÷ 170, about 86.5.
        let young = player("Young", age: 18, potential: 140, slots: [.D_L])
        let old = player("Old", age: 28, current: 100, potential: 100)
        let behindOld = try outlooks([old, young], tiers(first: [.D_L: old], ratings: [(old, .D_L, 85), (young, .D_L, 70)]))
        #expect(slot(behindOld[young.id], .D_L)?.firstChoice?.compared == 85)
        #expect(behindOld[young.id]?.level == .couldPassFirst)

        // Of equal rating, growing as fast: his own reach rating is 85 × 210 ÷ 170, 105.
        let rising = player("Rising", age: 20, current: 100, potential: 140)
        let behindRising = try outlooks([rising, young], tiers(first: [.D_L: rising], ratings: [(rising, .D_L, 85), (young, .D_L, 70)]))
        let row = try #require(slot(behindRising[young.id], .D_L))
        #expect(row.firstChoice?.rating == 85)
        #expect(abs((row.firstChoice?.compared ?? 0) - 105) < 1e-9)
        #expect(row.level != .couldPassFirst)
    }

    // MARK: The rivals at a slot

    /// The first and second choice as a young player's outlook names them, and the first choice's estimate only when he
    /// is developing.
    @Test func rivalsAreTheOnesTheOutlookNames() throws {
        let rising = player("Rising", age: 20, current: 100, potential: 140)
        let old = player("Old", age: 28, current: 100, potential: 100)
        let young = player("Young", age: 18, potential: 140, slots: [.D_L])
        let t = tiers(first: [.D_L: rising], second: [.D_L: old],
                      ratings: [(rising, .D_L, 85), (old, .D_L, 70), (young, .D_L, 60)])
        let row = try #require(slot(try outlooks([rising, old, young], t)[young.id], .D_L))
        let found = try Development.rivals(at: .D_L, tiers: t, squad: [rising, old, young], ownClub: "Oxford City",
                                           parameters: parameters)
        #expect(found.first == row.firstChoice && found.second == row.secondChoice)
        #expect(found.first != nil && found.second != nil)
        #expect(found.firstEstimate?.reach == 140)

        let steady = try Development.rivals(at: .D_L, tiers: tiers(first: [.D_L: old], ratings: [(old, .D_L, 70)]),
                                            squad: [old], ownClub: "Oxford City", parameters: parameters)
        #expect(steady.first?.compared == 70 && steady.second == nil && steady.firstEstimate == nil)
        let none = try Development.rivals(at: .D_L, tiers: tiers(), squad: [old], ownClub: "Oxford City", parameters: parameters)
        #expect(none.first == nil && none.second == nil && none.firstEstimate == nil)
    }

    // MARK: Bands

    @Test func eachBand() throws {
        func band(_ young: Player, rating: Double, firstChoiceRating: Double) throws -> ReachBand? {
            let first = veteran("First Choice")
            let found = try outlooks([first, young], tiers(first: [.D_L: first],
                                                           ratings: [(first, .D_L, firstChoiceRating), (young, .D_L, rating)]))
            return slot(found[young.id], .D_L)?.band
        }
        // Aged 20 at 100, potential 200: 100, 114, 126, 138, 150 over the coming seasons; rated 85, so (70 + ability) ÷ 2:
        // 85, 92, 98, 104, 110.
        let rising = player("Rising", age: 20, current: 100, potential: 200, slots: [.D_L])
        #expect(try band(rising, rating: 85, firstChoiceRating: 85) == .close)
        #expect(try band(rising, rating: 85, firstChoiceRating: 92) == .close)
        #expect(try band(rising, rating: 85, firstChoiceRating: 92.5) == .onCourse)
        // Ahead at 23 (three seasons on) is on course; at 24 it is only possible.
        #expect(try band(rising, rating: 85, firstChoiceRating: 104) == .onCourse)
        #expect(try band(rising, rating: 85, firstChoiceRating: 105) == .possible)
        // His reach falls short, but his potential does not.
        let slow = player("Slow", age: 20, current: 100, potential: 200, slots: [.D_L], professionalism: 1)
        #expect(try band(slow, rating: 85, firstChoiceRating: 105) == .possible)
        // His potential as a rating, 100, is below the first choice's 105.
        let capped = player("Capped", age: 20, current: 100, potential: 130, slots: [.D_L])
        #expect(try band(capped, rating: 85, firstChoiceRating: 105) == .notExpected)
        #expect(try band(capped, rating: 85, firstChoiceRating: 100) == .onCourse)
    }

    @Test func theBandWalksAYoungFirstChoiceForwardToo() throws {
        // Aged 18 at 100, potential 200 (100, 118, 132, 146, 158, 170), rated 85: 85, 94, 101, 108, 114, 120.
        let young = player("Young", age: 18, current: 100, potential: 200, slots: [.D_L])
        func band(_ first: Player, rating: Double) throws -> ReachBand? {
            let found = try outlooks([first, young], tiers(first: [.D_L: first], ratings: [(first, .D_L, rating), (young, .D_L, 85)]))
            return slot(found[young.id], .D_L)?.band
        }
        // Today's 92 is passed in one season, but walked forward (100, 112, 124, 136, 148) he is 98.5, 105.0, 111.5,
        // 118.0: passed five seasons on, at 23.
        #expect(try band(player("Old", age: 28, current: 100, potential: 100), rating: 92) == .close)
        #expect(try band(player("Rising", age: 22, current: 100, potential: 148), rating: 92) == .onCourse)
        // Walked forward from 87 he is 93.1 a season on, and passed then; his reach rating, 111.6, only at 22.
        #expect(try band(player("Rising", age: 22, current: 100, potential: 148), rating: 87) == .close)
        // His seasons run out four on, at 26: his last value, 118.0, is held, and passed five seasons on, at 23.
        #expect(try band(player("Older", age: 23, current: 100, potential: 148), rating: 92) == .onCourse)
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
        // The same level at both (over the bar, with no second choice): the greater share of the first choice's rating.
        let same = try best(leftRating: 62, rightRating: 58)
        #expect(slot(same, .D_L)?.level == .couldMakeSecond && slot(same, .D_R)?.level == .couldMakeSecond)
        #expect(same?.best?.slot == .D_R)
        // A tie: the earlier slot.
        #expect(try best(leftRating: 60, rightRating: 60)?.best?.slot == .D_L)
        // The greater share is at a slot where a strong second choice leaves him cover only.
        let outlook = try best(leftRating: 62, rightRating: 58, rightSecond: true)
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
        // At an ability of 30, (70 + 30) × (his rating ÷ the first choice's − 1).
        func points(rating: Double, firstChoiceRating: Double) throws -> Int? {
            let young = player("Young", current: 30, potential: 30, slots: [.D_L])
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

    // MARK: Scaling from the offset

    @Test func ratingsScaleFromTheOffsetNotInProportion() throws {
        // Two centre-backs equally suited to the slot: a rating is 0.5 × (offset + ability).
        let offset = parameters.ratingAbilityOffset.value
        let first = player("First Choice", age: 28, current: 66, potential: 66)
        func outlook(potential: Int) throws -> SlotOutlook? {
            let young = player("Young", age: 19, current: 25, potential: potential, slots: [.D_CL])
            let found = try outlooks([first, young], tiers(first: [.D_CL: first],
                                                           ratings: [(first, .D_CL, 0.5 * (offset + 66)),
                                                                     (young, .D_CL, 0.5 * (offset + 25))]))
            return slot(found[young.id], .D_CL)
        }
        // A potential of 41, below the first choice's ability: in proportion, 47.5 × 41 ÷ 25 would be 77.9, past his 68.
        let low = try #require(try outlook(potential: 41))
        #expect(abs(low.reachRating - 0.5 * (offset + 41)) < 1e-9)
        #expect(low.level != .couldPassFirst)
        #expect(low.band == .notExpected)
        // A potential of 70, above it.
        let high = try #require(try outlook(potential: 70))
        #expect(high.level == .couldPassFirst)
        #expect(high.band != .notExpected)
    }

    @Test func anOffsetOfZeroScalesInProportion() throws {
        var q = parameters
        q.ratingAbilityOffset = Parameter(0, .derived, source: "test")
        // His reach rating 50 × 140 ÷ 100, a developing first choice's 60 × 120 ÷ 100, and the points 100 × (60 ÷ 50 − 1).
        let young = player("Young", age: 20, current: 100, potential: 140, slots: [.D_L])
        let rising = player("Rising", age: 20, current: 100, potential: 120)
        let row = try #require(slot(try outlooks([rising, young], tiers(first: [.D_L: rising],
                                                                         ratings: [(rising, .D_L, 60), (young, .D_L, 50)]),
                                                 parameters: q)[young.id], .D_L))
        #expect(abs(row.reachRating - 70) < 1e-9)
        #expect(abs((row.firstChoice?.compared ?? 0) - 72) < 1e-9)
        #expect(row.pointsNeeded == 20)
        // The walk: rated 50 at 100 with potential 200 he is 50, 57, 63, 69, so passes 69 at 23. With the offset he
        // would be 50, 54.1, 57.6, 61.2, then 64.7 at 24, and not pass it in time.
        let first = veteran("First Choice")
        func band(_ young: Player, firstChoiceRating: Double, _ parameters: EngineParameters) throws -> ReachBand? {
            let found = try outlooks([first, young], tiers(first: [.D_L: first],
                                                           ratings: [(first, .D_L, firstChoiceRating), (young, .D_L, 50)]),
                                     parameters: parameters)
            return slot(found[young.id], .D_L)?.band
        }
        let rising200 = player("Rising 200", age: 20, current: 100, potential: 200, slots: [.D_L])
        #expect(try band(rising200, firstChoiceRating: 69, q) == .onCourse)
        #expect(try band(rising200, firstChoiceRating: 69, parameters) == .possible)
        // His potential as a rating: 50 × 130 ÷ 100 = 65 reaches 64; 50 × 200 ÷ 170, about 58.8, does not.
        let slow = player("Slow", age: 20, current: 100, potential: 130, slots: [.D_L], professionalism: 1)
        #expect(try band(slow, firstChoiceRating: 64, q) == .possible)
        #expect(try band(slow, firstChoiceRating: 64, parameters) == .notExpected)
    }

    @Test func pointsNeededUsesTheOffset() throws {
        let first = veteran("First Choice")
        let young = player("Young", slots: [.D_L])
        func points(_ parameters: EngineParameters) throws -> Int? {
            let found = try outlooks([first, young], tiers(first: [.D_L: first], ratings: [(first, .D_L, 90), (young, .D_L, 80)]),
                                     parameters: parameters)
            return slot(found[young.id], .D_L)?.pointsNeeded
        }
        // (70 + 100) × (90 ÷ 80 − 1) = 21.25, rounded up; in proportion it would be 12.5, so 13.
        #expect(try points(parameters) == 22)
        var q = parameters
        q.ratingAbilityOffset = Parameter(0, .derived, source: "test")
        #expect(try points(q) == 13)
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

    func matchesHere(_ player: Player, _ tiers: SquadTiers, _ history: StartHistory,
                     parameters: EngineParameters? = nil) throws -> MatchesHere {
        try Development.matchesHere(for: player, assignments: assignments, tiers: tiers, history: history, asOf: day,
                                    parameters: parameters ?? self.parameters)
    }

    @Test func aFirstChoiceHasEnoughWhateverHeStarted() throws {
        let p = player("First", slots: [.D_L])
        let t = tiers(first: [.D_L: p], ratings: [(p, .D_L, 50)])
        let result = try matchesHere(p, t, history(starts: 0, of: 8, player: p))
        #expect(result == MatchesHere(starts: 0, matches: 8, basis: .firstChoice))
        #expect(result.isCounted && result.isEnough)
        // Even with nothing confirmed.
        #expect(try matchesHere(p, t, StartHistory([])) == MatchesHere(starts: 0, matches: 0, basis: .firstChoice))
    }

    @Test func aThirdOfSixIsEnoughAndOneOfSixIsNot() throws {
        let p = player("Backup", slots: [.D_L])
        let t = tiers(ratings: [(p, .D_L, 50)])
        let two = try matchesHere(p, t, history(starts: 2, of: 6, player: p))
        #expect(two == MatchesHere(starts: 2, matches: 6, basis: .startedEnough))
        #expect(two.isCounted && two.isEnough)
        let one = try matchesHere(p, t, history(starts: 1, of: 6, player: p))
        #expect(one == MatchesHere(starts: 1, matches: 6, basis: .startedTooFew))
        #expect(one.isCounted && !one.isEnough)
        // A second choice who started too little has not enough either, once the matches are counted.
        let s = player("Second", slots: [.D_L])
        let t2 = tiers(second: [.D_L: s], ratings: [(s, .D_L, 50)])
        #expect(try !matchesHere(s, t2, history(starts: 1, of: 6, player: s)).isEnough)
        #expect(try matchesHere(s, t2, history(starts: 2, of: 6, player: s)).isEnough)
    }

    @Test func matchesOutsideTheWindowAreNotCounted() throws {
        let p = player("Backup", slots: [.D_L])
        let t = tiers(ratings: [(p, .D_L, 50)])
        let old = (0..<6).map { n in
            ConfirmedLineup(fixture: FixtureID("old\(n)"), date: day.adding(days: -61 - n), starters: [.D_L: p.id])
        }
        let result = try matchesHere(p, t, StartHistory(old))
        #expect(result == MatchesHere(starts: 0, matches: 0, basis: .tooFewConfirmed))
        #expect(!result.isCounted && !result.isEnough)
    }

    @Test func withFewerThanSixConfirmedHisPlaceDecides() throws {
        let second = player("Second", slots: [.D_L]), backup = player("Backup", slots: [.D_L])
        let t = tiers(second: [.D_L: second], ratings: [(second, .D_L, 50), (backup, .D_L, 40)])
        let none = StartHistory([])
        let solid = try matchesHere(second, t, none)
        #expect(solid == MatchesHere(starts: 0, matches: 0, basis: .solidSecondChoice))
        #expect(!solid.isCounted && solid.isEnough)
        #expect(try matchesHere(backup, t, none) == MatchesHere(starts: 0, matches: 0, basis: .tooFewConfirmed))
        // Five confirmed and he started all five, but is a backup: not counted, not enough.
        let five = try matchesHere(backup, t, history(starts: 5, of: 5, player: backup))
        #expect(five == MatchesHere(starts: 5, matches: 5, basis: .tooFewConfirmed))
        // Six confirmed counts them: all six started is enough for the backup.
        #expect(try matchesHere(backup, t, history(starts: 6, of: 6, player: backup)).isCounted)
        // A player the tiers did not rate has no place to decide it.
        let unrated = player("Unrated", slots: [.D_L])
        #expect(try !matchesHere(unrated, t, none).isEnough)
    }

    @Test func aSecondChoiceHasEnoughOnlyAtASlotHeIsSolidAt() throws {
        let none = StartHistory([])
        // Solid (familiarity 15 in both phases): enough while too few matches are confirmed.
        let solid = player("Solid", slots: [.D_L], familiarity: 15)
        #expect(try matchesHere(solid, tiers(second: [.D_L: solid], ratings: [(solid, .D_L, 50)]), none).basis
                == .solidSecondChoice)
        // An option there but not solid (14): a stand-in, not enough.
        let standIn = player("Stand-in", slots: [.D_L], familiarity: 14)
        let found = try matchesHere(standIn, tiers(second: [.D_L: standIn], ratings: [(standIn, .D_L, 50)]), none)
        #expect(found == MatchesHere(starts: 0, matches: 0, basis: .tooFewConfirmed))
        #expect(!found.isEnough)
        // An outfield player who is the second eleven's goalkeeper.
        var keeper = player("Outfield keeper", slots: [.D_L], familiarity: 15)
        keeper.familiarity[.goalkeeper] = 1
        #expect(try !matchesHere(keeper, tiers(second: [.GK: keeper], ratings: [(keeper, .GK, 30)]), none).isEnough)
        // Solid is Depth's line, from its parameter.
        var q = parameters
        q.depthSolidFamiliarity = Parameter(14, .derived, source: "test")
        #expect(try matchesHere(standIn, tiers(second: [.D_L: standIn], ratings: [(standIn, .D_L, 50)]), none,
                                parameters: q).isEnough)
        // Once enough matches are confirmed, his starts decide, solid or not.
        #expect(try matchesHere(standIn, tiers(second: [.D_L: standIn], ratings: [(standIn, .D_L, 50)]),
                                history(starts: 2, of: 6, player: standIn)).isEnough)
    }

    @Test func aMissingFamiliarityAtHisSecondChoiceSlotIsAnError() {
        var second = player("Second", slots: [.D_L])
        second.familiarity[assignment(.ST_C).ipPosition] = nil
        #expect(throws: RatingError.missingFamiliarity(player: "Second", position: assignment(.ST_C).ipPosition)) {
            try matchesHere(second, tiers(second: [.ST_C: second], ratings: [(second, .ST_C, 50)]), StartHistory([]))
        }
    }

    @Test func theMinimumAndShareComeFromTheParameters() throws {
        let p = player("Backup", slots: [.D_L])
        let t = tiers(ratings: [(p, .D_L, 50)])
        var q = parameters
        q.matchesHereMinimumConfirmed = Parameter(3, .derived, source: "test")
        q.matchesHereShare = Parameter(0.5, .derived, source: "test")
        let h = history(starts: 1, of: 4, player: p)
        #expect(try !matchesHere(p, t, h, parameters: q).isEnough)
        #expect(try matchesHere(p, t, history(starts: 2, of: 4, player: p), parameters: q).isEnough)
        q.matchesHereWindowDays = Parameter(3, .derived, source: "test")
        #expect(try matchesHere(p, t, h, parameters: q).matches == 2)
    }

    @Test func aFirstChoiceIsNamedWithHisAgeFromTheParameter() throws {
        func standing(firstAge: Int, _ q: EngineParameters? = nil) throws -> (named: Bool?, words: String?) {
            var first = veteran("First Choice")
            first.age = firstAge
            let young = player("Young", slots: [.D_L])
            let found = try outlooks([first, young], tiers(first: [.D_L: first], ratings: [(first, .D_L, 90), (young, .D_L, 80)]),
                                     parameters: q)
            let outlook = try #require(found[young.id])
            return (outlook.best?.firstChoice?.isAgeNamed, AdvisorText.standing(outlook, names: { PositionText.plain($0.position) }))
        }
        let at29 = try standing(firstAge: 29), at30 = try standing(firstAge: 30)
        #expect(at29.named == false && at29.words?.hasSuffix(".") == true && at29.words?.contains("is 29") == false)
        #expect(at30.named == true && at30.words?.hasSuffix(" First Choice is 30.") == true)
        var q = parameters
        q.firstChoiceAgeNamedFrom = Parameter(31, .derived, source: "test")
        #expect(try standing(firstAge: 30, q).named == false)
        #expect(try standing(firstAge: 31, q).words?.hasSuffix(" First Choice is 31.") == true)
    }
}
