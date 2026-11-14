import Foundation
import Testing
@testable import LineupEngine

@Suite struct TrainingTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()
    let sample = "Sample 4-2-3-1"

    func report(_ players: [Player], tactics: [Tactic]? = nil, ownClub: String? = "Oxford City",
                accepted: [Retraining] = [], rejected: Set<RetrainingChoice> = [], leaving: Set<PlayerID> = [],
                parameters: EngineParameters = .fm27) throws -> TrainingReport {
        try Training.report(tactics: tactics ?? [tactic], players: players, ownClub: ownClub, accepted: accepted,
                            rejected: rejected, leaving: leaving, catalog: catalog, profile: profile, parameters: parameters)
    }

    func named(_ slot: SlotID, _ tier: String) -> String { PlannerFixture.name(slot, tier) }

    /// The planner's squad made slow to retrain (age 30, Versatility and Professionalism 5, no room to grow),
    /// so that only the players a test adds are candidates.
    func squad(without removed: Set<String> = []) throws -> [Player] {
        try PlannerFixture.squad().filter { !removed.contains($0.name) }.map { p in
            var p = p
            p.age = 30
            p.attributes[.versatility] = 5
            p.attributes[.professionalism] = 5
            p.potentialAbility = p.currentAbility
            return p
        }
    }

    /// The squad without its second-choice left back, so cover at left back is thin, plus `extra`.
    func thinAtLeftBack(_ extra: [Player]) throws -> [Player] { try squad(without: [named(.D_L, "second")]) + extra }

    /// A natural right back with familiarity `leftBack` at D (L), quick to retrain by default.
    func rightBack(_ name: String = "Right Back", age: Int = 20, all: Int = 13, versatility: Int = 14,
                   professionalism: Int = 12, leftBack: Int = 8, familiarity: [Position: Int] = [:],
                   currentAbility: Int = 100, potentialAbility: Int = 120, club: String? = "Oxford City",
                   isInjured: Bool = false) -> Player {
        Player.fixture(name: name, age: age, all: all,
                       attributes: [.versatility: versatility, .professionalism: professionalism],
                       familiarity: [.defenderRight: 20, .defenderLeft: leftBack].merging(familiarity) { _, new in new },
                       currentAbility: currentAbility, potentialAbility: potentialAbility, isInjured: isInjured, club: club)
    }

    func id(_ name: String) -> PlayerID { PlayerID(key: PlayerID.normalise(name)) }

    func choices(_ r: TrainingReport) -> [RetrainingChoice] { r.recommendations.map(\.choice) }

    func assignment(_ slot: SlotID) throws -> SlotAssignment {
        try #require(try tactic.assignments(catalog: catalog).first { $0.slot == slot })
    }

    /// His rating in `slot` at familiarity 20 in both of its positions, over the slot's first choice's rating there.
    func share(of player: Player, at slot: SlotID, firstChoice: Player) throws -> (rating: Double, share: Double) {
        let engine = RatingEngine(profile: profile, parameters: .fm27, configuration: .fm27)
        let a = try assignment(slot)
        var learnt = player
        learnt.familiarity[a.ipPosition] = 20
        learnt.familiarity[a.oopPosition] = 20
        let rating = try engine.rating(for: learnt, in: a).value
        return (rating, rating / (try engine.rating(for: firstChoice, in: a).value))
    }

    func firstChoice(_ slot: SlotID, in players: [Player]) throws -> Player {
        try #require(players.first { $0.name == named(slot, "first") })
    }

    // MARK: Needs and the basic recommendation

    @Test func noThinSlotsGivesNoRecommendations() throws {
        let r = try report(try squad() + [rightBack()])
        #expect(r.recommendations.isEmpty)
        #expect(r.needsWithoutCandidates.isEmpty)
    }

    @Test func aRightBackIsRecommendedForThinCoverAtLeftBack() throws {
        let players = try thinAtLeftBack([rightBack()])
        let depth = try Depth.report(tactic: tactic, players: players, ownClub: "Oxford City", catalog: catalog,
                                     profile: profile, parameters: .fm27)
        try #require(depth.thin == [.D_L])
        let r = try report(players)
        #expect(r.recommendations.count == 1)
        let rec = try #require(r.recommendations.first)
        #expect(rec.choice == RetrainingChoice(player: id("Right Back"), position: .defenderLeft))
        #expect(rec.name == "Right Back" && rec.age == 20 && rec.currentFamiliarity == 8)
        #expect(rec.needs == [RetrainingNeed(tactic: sample, slot: .D_L)])
        #expect(rec.from == .defenderRight)
        // D (R) to D (L) is not in the table; both are in the defensive group, so the default is structural.
        #expect(rec.difficulty == .structural)
        // The middle of 12 to 20 weeks, ×1.0 at age 20, ×1.0 at Versatility 14, no head start at familiarity 8.
        #expect(rec.weeks == 16)
        let expected = try share(of: rightBack(), at: .D_L, firstChoice: firstChoice(.D_L, in: players))
        #expect(abs(rec.ratingIfLearnt - expected.rating) < 1e-9)
        #expect(abs(rec.shareOfFirstChoice - expected.share) < 1e-9)
        // 0.45 × 14/20 + 0.25 × 1.0 + 0.20 × 12/20 + 0.10 × 20/30
        #expect(abs(rec.learnability - (0.45 * 0.7 + 0.25 * 1.0 + 0.20 * 0.6 + 0.10 * 20.0 / 30.0)) < 1e-9)
        #expect(r.needsWithoutCandidates.isEmpty)
    }

    // MARK: Filters

    @Test func aPlayerAlreadySolidInTheSlotIsNotACandidate() throws {
        // Injured, so he is not cover and the slot stays thin, but he already knows the position.
        let solid = try report(thinAtLeftBack([rightBack(leftBack: 15, isInjured: true)]))
        #expect(solid.recommendations.isEmpty)
        #expect(solid.needsWithoutCandidates == [RetrainingNeed(tactic: sample, slot: .D_L)])
        let short = try report(thinAtLeftBack([rightBack(leftBack: 14, isInjured: true)]))
        #expect(choices(short) == [RetrainingChoice(player: id("Right Back"), position: .defenderLeft)])
    }

    @Test func aFirstChoiceInAnotherThinSlotIsNotACandidate() throws {
        // Without either natural right back he is first choice at D_R, which is then thin too.
        let players = try squad(without: [named(.D_L, "second"), named(.D_R, "first"), named(.D_R, "second")]) + [rightBack()]
        let r = try report(players)
        #expect(r.recommendations.isEmpty)
        #expect(r.needsWithoutCandidates.map(\.slot).sorted { $0.rawValue < $1.rawValue } == [.D_L, .D_R])
    }

    @Test func aFirstChoiceElsewhereIsNeverACandidate() throws {
        // With the second-choice right back kept, D_R is not thin, but he is still its first choice: retrained, he
        // would not count as cover at left back, so he is not offered it.
        let firstAtRight = try squad(without: [named(.D_L, "second"), named(.D_R, "first")]) + [rightBack()]
        let elevens = try Elevens.report(tactic: tactic, players: firstAtRight, ownClub: "Oxford City", catalog: catalog,
                                         profile: profile, parameters: .fm27)
        try #require(elevens.first.first { $0.slot == .D_R }?.player == id("Right Back"))
        let depth = try Depth.report(tactic: tactic, players: firstAtRight, ownClub: "Oxford City", catalog: catalog,
                                     profile: profile, parameters: .fm27)
        try #require(depth.thin == [.D_L])
        let r = try report(firstAtRight)
        #expect(r.recommendations.isEmpty)
        #expect(r.needsWithoutCandidates == [RetrainingNeed(tactic: sample, slot: .D_L)])
        // Behind the first-choice right back he is second choice there, and free to learn left back.
        let second = try thinAtLeftBack([rightBack()])
        let secondElevens = try Elevens.report(tactic: tactic, players: second, ownClub: "Oxford City", catalog: catalog,
                                               profile: profile, parameters: .fm27)
        try #require(!secondElevens.first.contains { $0.player == id("Right Back") })
        #expect(choices(try report(second)) == [RetrainingChoice(player: id("Right Back"), position: .defenderLeft)])
    }

    @Test func aPlayerShortInBothPhasesIsNotACandidate() throws {
        // AM_L plays AM (L) with the ball and M (L) without it. Without a second choice there, cover is thin.
        func winger(attackingMid: Int, midfield: Int) -> Player {
            Player.fixture(name: "Winger", age: 20, all: 13, attributes: [.versatility: 14, .professionalism: 12],
                           familiarity: [.attackingMidLeft: attackingMid, .midfielderLeft: midfield])
        }
        let need = RetrainingNeed(tactic: sample, slot: .AM_L)
        // Short at both: learning one would still leave him short at the other.
        let both = try report(try squad(without: [named(.AM_L, "second")]) + [winger(attackingMid: 14, midfield: 9)])
        #expect(both.recommendations.isEmpty)
        #expect(both.needsWithoutCandidates == [need])
        // His neighbour, solid with the ball, is offered the position he is short in.
        let neighbour = try report(try squad(without: [named(.AM_L, "second")]) + [winger(attackingMid: 15, midfield: 9)])
        #expect(choices(neighbour) == [RetrainingChoice(player: id("Winger"), position: .midfielderLeft)])
        // And the other way round.
        let other = try report(try squad(without: [named(.AM_L, "second")]) + [winger(attackingMid: 9, midfield: 15)])
        #expect(choices(other) == [RetrainingChoice(player: id("Winger"), position: .attackingMidLeft)])
    }

    @Test func theFirstChoiceOfTheThinSlotCanLearnThePositionHeIsShortIn() throws {
        // The first-choice AM_L is short at M (L), so he is not solid cover and the slot, without a second choice, is
        // thin. He is quick to learn; learning M (L) makes him count.
        let first = named(.AM_L, "first")
        let players = try squad(without: [named(.AM_L, "second")]).map { p -> Player in
            guard p.name == first else { return p }
            var p = p
            p.age = 20
            p.attributes[.versatility] = 14
            p.attributes[.professionalism] = 12
            p.potentialAbility = p.currentAbility + 20
            p.familiarity[.midfielderLeft] = 12
            return p
        }
        let elevens = try Elevens.report(tactic: tactic, players: players, ownClub: "Oxford City", catalog: catalog,
                                         profile: profile, parameters: .fm27)
        try #require(elevens.first.first { $0.slot == .AM_L }?.player == id(first))
        let r = try report(players)
        let rec = try #require(r.recommendations.first)
        #expect(choices(r) == [RetrainingChoice(player: id(first), position: .midfielderLeft)])
        #expect(rec.needs == [RetrainingNeed(tactic: sample, slot: .AM_L)])
        #expect(rec.currentFamiliarity == 12)
        // Short at both of the slot's positions, he is not offered either.
        let both = players.map { p -> Player in
            guard p.name == first else { return p }
            var p = p
            p.familiarity[.attackingMidLeft] = 14
            return p
        }
        #expect(try report(both).recommendations.isEmpty)
    }

    @Test func aPlayerBelowTheMinimumShareOfTheFirstChoiceIsNotACandidate() throws {
        let weak = rightBack(all: 9), able = rightBack(all: 13)
        let first = try firstChoice(.D_L, in: try squad())
        try #require(try share(of: weak, at: .D_L, firstChoice: first).share < 0.8)
        try #require(try share(of: able, at: .D_L, firstChoice: first).share >= 0.8)
        #expect(try report(thinAtLeftBack([weak])).recommendations.isEmpty)
        #expect(choices(try report(thinAtLeftBack([able]))) == [RetrainingChoice(player: id("Right Back"), position: .defenderLeft)])
        // The line is the parameter, either side of his own share.
        let s = try share(of: able, at: .D_L, firstChoice: first).share
        var above = EngineParameters.fm27
        above.retrainingMinimumShare = Parameter(s + 0.001, .derived, source: "test")
        #expect(try report(thinAtLeftBack([able]), parameters: above).recommendations.isEmpty)
        var below = EngineParameters.fm27
        below.retrainingMinimumShare = Parameter(s - 0.001, .derived, source: "test")
        #expect(try report(thinAtLeftBack([able]), parameters: below).recommendations.count == 1)
    }

    @Test func learnabilityBelowTheMinimumRulesHimOut() throws {
        // Age 30 (0.05), Versatility 15, no room to grow: Professionalism 4 gives 0.39 and 6 gives 0.41.
        func player(_ professionalism: Int) -> Player {
            rightBack(age: 30, versatility: 15, professionalism: professionalism, currentAbility: 110, potentialAbility: 110)
        }
        #expect(abs(try Training.learnability(of: player(4), parameters: .fm27) - 0.39) < 1e-9)
        #expect(abs(try Training.learnability(of: player(6), parameters: .fm27) - 0.41) < 1e-9)
        #expect(try report(thinAtLeftBack([player(4)])).recommendations.isEmpty)
        let r = try report(thinAtLeftBack([player(6)]))
        #expect(choices(r) == [RetrainingChoice(player: id("Right Back"), position: .defenderLeft)])
        #expect(abs(try #require(r.recommendations.first).learnability - 0.41) < 1e-9)
    }

    @Test func aLoanedInPlayerIsNotACandidate() throws {
        #expect(try report(thinAtLeftBack([rightBack(club: "Elsewhere FC")])).recommendations.isEmpty)
        #expect(try report(thinAtLeftBack([rightBack(club: "Oxford City")])).recommendations.count == 1)
    }

    @Test func aGoalkeeperIsNotACandidateForAnOutfieldSlot() throws {
        #expect(try report(thinAtLeftBack([rightBack(familiarity: [.goalkeeper: 15])])).recommendations.isEmpty)
        #expect(try report(thinAtLeftBack([rightBack(familiarity: [.goalkeeper: 14])])).recommendations.count == 1)
    }

    @Test func anOutfieldPlayerIsNotACandidateForTheGoalkeepersSlot() throws {
        // Without a second goalkeeper, cover in goal is thin.
        let players = try squad(without: [named(.GK, "second")])
        let goal = RetrainingNeed(tactic: sample, slot: .GK)
        let assignment = try assignment(.GK)
        try #require(assignment.ipPosition == .goalkeeper && assignment.oopPosition == .goalkeeper)
        // GK 14 is below solid, so he is an outfield player: not offered the goalkeeper's slot, though he is quick to learn
        // and offered left back when that is thin.
        let outfield = rightBack(familiarity: [.goalkeeper: 14])
        let r = try report(players + [outfield])
        #expect(r.recommendations.isEmpty)
        #expect(r.needsWithoutCandidates == [goal])
        let left = try report(try squad(without: [named(.GK, "second"), named(.D_L, "second")]) + [outfield])
        #expect(choices(left) == [RetrainingChoice(player: id("Right Back"), position: .defenderLeft)])
        // At GK 15 he is a goalkeeper, but then he is already solid in both of the slot's phases, so still not a
        // candidate (injured, so the slot stays thin): the goalkeeper's slot always goes to recruitment.
        let keeper = rightBack(familiarity: [.goalkeeper: 15], isInjured: true)
        let k = try report(players + [keeper])
        #expect(k.recommendations.isEmpty && k.needsWithoutCandidates == [goal])
    }

    @Test func anInversionRulesHimOut() throws {
        // A natural striker and nothing else: ST (C) to D (L) is an inversion.
        let striker = Player.fixture(name: "Striker", age: 20, all: 13,
                                     attributes: [.versatility: 14, .professionalism: 12],
                                     familiarity: [.striker: 20])
        #expect(try report(thinAtLeftBack([striker])).recommendations.isEmpty)
        // The same striker who is also natural at WB (L) retrains from there instead: a fluid change.
        var wide = striker
        wide.familiarity[.wingBackLeft] = 18
        let r = try report(thinAtLeftBack([wide]))
        let rec = try #require(r.recommendations.first)
        #expect(rec.choice == RetrainingChoice(player: id("Striker"), position: .defenderLeft))
        #expect(rec.from == .wingBackLeft && rec.difficulty == .fluid)
    }

    // MARK: Learnability, the position to learn and the weeks

    @Test func learnabilityFollowsTheWeights() throws {
        // 0.45 × 14/20 + 0.25 × 1.0 (age 20) + 0.20 × 12/20 + 0.10 × 20/30
        let young = rightBack(age: 20, versatility: 14, professionalism: 12, currentAbility: 100, potentialAbility: 120)
        #expect(abs(try Training.learnability(of: young, parameters: .fm27) - 0.7516666666666667) < 1e-9)
        // Versatility 9 counts 9/20 × 0.3; age 26 is 0.40; potential below current leaves no room to grow.
        // 0.45 × 0.135 + 0.25 × 0.40 + 0.20 × 10/20 + 0.10 × 0
        let older = rightBack(age: 26, versatility: 9, professionalism: 10, currentAbility: 120, potentialAbility: 100)
        #expect(abs(try Training.learnability(of: older, parameters: .fm27) - 0.26075) < 1e-9)
        // Room to grow is kept at 1 however large the gap.
        let gap = rightBack(age: 20, versatility: 20, professionalism: 20, currentAbility: 60, potentialAbility: 200)
        #expect(abs(try Training.learnability(of: gap, parameters: .fm27) - 1.0) < 1e-9)
        // Each age band.
        for (age, factor) in [(20, 1.0), (21, 0.95), (23, 0.95), (24, 0.70), (25, 0.70), (26, 0.40), (27, 0.40),
                              (28, 0.15), (29, 0.15), (30, 0.05), (35, 0.05)] {
            let p = rightBack(age: age, versatility: 10, professionalism: 10, currentAbility: 100, potentialAbility: 100)
            #expect(abs(try Training.learnability(of: p, parameters: .fm27) - (0.45 * 0.5 + 0.25 * factor + 0.20 * 0.5)) < 1e-9,
                    "age \(age)")
        }
    }

    @Test func thePositionToLearnIsTheOutOfPossessionOneWhenOnlyThatIsShort() throws {
        // AM_L plays AM (L) with the ball and M (L) without it.
        let winger = Player.fixture(name: "Winger", age: 20, all: 13, attributes: [.versatility: 14, .professionalism: 12],
                                    familiarity: [.attackingMidLeft: 15, .midfielderLeft: 9])
        let r = try report(try squad(without: [named(.AM_L, "second")]) + [winger])
        let rec = try #require(r.recommendations.first)
        #expect(rec.choice == RetrainingChoice(player: id("Winger"), position: .midfielderLeft))
        #expect(rec.currentFamiliarity == 9)
        #expect(rec.needs == [RetrainingNeed(tactic: sample, slot: .AM_L)])
        // Nothing at 18, so he retrains from his best position.
        #expect(rec.from == .attackingMidLeft && rec.difficulty == .fluid)
        #expect(rec.cautions.contains("Needed out of possession only: reports say out-of-possession familiarity was hard to train in FM26"))
        // Short in possession and solid out of it: he learns AM (L) and there is no such caution.
        var inPossession = winger
        inPossession.familiarity[.attackingMidLeft] = 12
        inPossession.familiarity[.midfielderLeft] = 15
        let r2 = try report(try squad(without: [named(.AM_L, "second")]) + [inPossession])
        let rec2 = try #require(r2.recommendations.first)
        #expect(rec2.choice.position == .attackingMidLeft)
        #expect(!rec2.cautions.contains { $0.hasPrefix("Needed out of possession only") })
    }

    @Test func weeksFollowAgeVersatilityAndHeadStart() throws {
        // Natural at WB (L) learning D (L): a fluid change, 4 to 8 weeks, middle 6.
        func weeks(age: Int = 20, versatility: Int = 12, leftBack: Int = 5) throws -> Int {
            let p = Player.fixture(name: "Wing Back", age: age, all: 13,
                                   attributes: [.versatility: versatility, .professionalism: 12],
                                   familiarity: [.wingBackLeft: 20, .defenderLeft: leftBack])
            let rec = try #require(try report(thinAtLeftBack([p])).recommendations.first)
            #expect(rec.difficulty == .fluid && rec.from == .wingBackLeft)
            return rec.weeks
        }
        #expect(try weeks() == 6)
        #expect(try weeks(age: 28) == 10)          // 6 × 1.6 = 9.6, rounded up
        #expect(try weeks(age: 22) == 8)           // 6 × 1.3 = 7.8
        #expect(try weeks(versatility: 16) == 4)   // 6 × 0.6 = 3.6, rounded up and at least 4
        #expect(try weeks(versatility: 9) == 9)    // 6 × 1.5
        #expect(try weeks(leftBack: 13) == 4)      // 6 × 0.5 = 3, at least 4
        #expect(try weeks(age: 28, leftBack: 10) == 7) // 6 × 1.6 × 0.7 = 6.72
    }

    @Test func theTransitionTableIsTheBranchs() {
        let transitions = EngineParameters.fm27.retrainingTransitions.value
        #expect(transitions.pairs.count == 35)
        #expect(transitions.difficulty(from: .defenderLeft, to: .wingBackLeft) == .fluid)
        #expect(transitions.difficulty(from: .defensiveMidfielder, to: .defenderCentral) == .structural)
        #expect(transitions.difficulty(from: .striker, to: .attackingMidRight) == .spatial)
        #expect(transitions.difficulty(from: .striker, to: .defenderRight) == .inversion)
        #expect(transitions.difficulty(from: .midfielderCentral, to: .goalkeeper) == .inversion)
        // Defaults: both in the defensive group, or both in the attacking group, is structural; otherwise spatial.
        #expect(transitions.difficulty(from: .defenderRight, to: .defenderLeft) == .structural)
        #expect(transitions.difficulty(from: .attackingMidLeft, to: .striker) == .structural)
        #expect(transitions.difficulty(from: .midfielderCentral, to: .defenderCentral) == .spatial)
        #expect(transitions.difficulty(from: .attackingMidLeft, to: .defensiveMidfielder) == .spatial)
        // Each class's count in the branch's table.
        let counts = Dictionary(grouping: transitions.pairs.values, by: { $0 }).mapValues(\.count)
        #expect(counts == [.fluid: 14, .structural: 10, .spatial: 6, .inversion: 5])
    }

    // MARK: Choosing

    /// Thin at left back and at both centre-back slots, so a right back can be offered D (L) or D (C).
    func thinAtTheBack(_ extra: [Player]) throws -> [Player] {
        try squad(without: [named(.D_L, "second"), named(.D_CL, "second"), named(.D_CR, "second")]) + extra
    }

    @Test func onePlayerGetsOneRecommendation() throws {
        let r = try report(thinAtTheBack([rightBack()]))
        #expect(r.recommendations.count == 1)
        let rec = try #require(r.recommendations.first)
        #expect([Position.defenderLeft, .defenderCentral].contains(rec.choice.position))
        // The needs he does not take are left for recruitment.
        let covered = Set(rec.needs.map(\.slot))
        #expect(Set(r.needsWithoutCandidates.map(\.slot)) == Set([SlotID.D_L, .D_CL, .D_CR]).subtracting(covered))
    }

    @Test func aRejectedPairIsSkippedAndAnotherPositionForHimIsStillOffered() throws {
        let players = try thinAtTheBack([rightBack()])
        let first = try #require(try report(players).recommendations.first).choice
        let r = try report(players, rejected: [first])
        let next = try #require(r.recommendations.first)
        #expect(next.choice.player == first.player)
        #expect(next.choice.position != first.position)
        #expect([Position.defenderLeft, .defenderCentral].contains(next.choice.position))
        // Rejecting both leaves nothing.
        #expect(try report(players, rejected: [first, next.choice]).recommendations.isEmpty)
    }

    @Test func anAcceptedPairIsSkipped() throws {
        let players = try thinAtLeftBack([rightBack()])
        let accepted = Retraining(player: id("Right Back"), position: .defenderLeft, acceptedOn: Day(iso: "2026-11-01")!)
        #expect(try report(players, accepted: [accepted]).recommendations.isEmpty)
        // Accepting another position for him does not hide this one.
        let elsewhere = Retraining(player: id("Right Back"), position: .defenderCentral, acceptedOn: Day(iso: "2026-11-01")!)
        #expect(choices(try report(players, accepted: [elsewhere])) == [RetrainingChoice(player: id("Right Back"), position: .defenderLeft)])
    }

    // MARK: Needs already being retrained

    let acceptedOn = Day(iso: "2026-11-01")!
    var leftBackNeed: RetrainingNeed { RetrainingNeed(tactic: sample, slot: .D_L) }

    @Test func aNeedAnAcceptedRetrainingCoversIsNotForRecruitment() throws {
        let players = try thinAtLeftBack([rightBack()])
        let accepted = Retraining(player: id("Right Back"), position: .defenderLeft, acceptedOn: acceptedOn)
        let r = try report(players, accepted: [accepted])
        #expect(r.recommendations.isEmpty)
        #expect(r.needsBeingRetrained == [leftBackNeed])
        #expect(r.needsWithoutCandidates.isEmpty)
        // With nothing accepted he is recommended, and the need is in neither list.
        let open = try report(players)
        #expect(choices(open) == [RetrainingChoice(player: id("Right Back"), position: .defenderLeft)])
        #expect(open.needsBeingRetrained.isEmpty && open.needsWithoutCandidates.isEmpty)
    }

    @Test func aRetrainingThatDoesNotFitTheNeedDoesNotCount() throws {
        let players = try thinAtLeftBack([rightBack()])
        let rejectLeft: Set<RetrainingChoice> = [RetrainingChoice(player: id("Right Back"), position: .defenderLeft)]
        // Accepted at another position.
        let centre = Retraining(player: id("Right Back"), position: .defenderCentral, acceptedOn: acceptedOn)
        let other = try report(players, accepted: [centre], rejected: rejectLeft)
        #expect(other.needsBeingRetrained.isEmpty && other.needsWithoutCandidates == [leftBackNeed])
        // Accepted for a player already solid there (injured, so the slot is still thin).
        let solid = try report(thinAtLeftBack([rightBack(leftBack: 15, isInjured: true)]),
                               accepted: [Retraining(player: id("Right Back"), position: .defenderLeft, acceptedOn: acceptedOn)])
        #expect(solid.needsBeingRetrained.isEmpty && solid.needsWithoutCandidates == [leftBackNeed])
        // Accepted for a player out on loan.
        var away = rightBack()
        away.loanedTo = "Elsewhere FC"
        let loaned = try report(thinAtLeftBack([away]),
                                accepted: [Retraining(player: id("Right Back"), position: .defenderLeft, acceptedOn: acceptedOn)])
        #expect(loaned.needsBeingRetrained.isEmpty && loaned.needsWithoutCandidates == [leftBackNeed])
        // Accepted for a player who is not in the squad.
        let gone = try report(try thinAtLeftBack([]),
                              accepted: [Retraining(player: id("Right Back"), position: .defenderLeft, acceptedOn: acceptedOn)])
        #expect(gone.needsBeingRetrained.isEmpty && gone.needsWithoutCandidates == [leftBackNeed])
    }

    @Test func anOutOfPossessionRetrainingCountsWhereHeIsShortOutOfPossession() throws {
        // AM_L plays AM (L) with the ball and M (L) without; he is solid at AM (L) and short at M (L).
        let winger = Player.fixture(name: "Winger", age: 20, all: 13, attributes: [.versatility: 14, .professionalism: 12],
                                    familiarity: [.attackingMidLeft: 15, .midfielderLeft: 9])
        let players = try squad(without: [named(.AM_L, "second")]) + [winger]
        let need = RetrainingNeed(tactic: sample, slot: .AM_L)
        let short = try report(players, accepted: [Retraining(player: id("Winger"), position: .midfielderLeft, acceptedOn: acceptedOn)])
        #expect(short.needsBeingRetrained == [need])
        // Accepting the position he already knows does not cover the need; he is still offered M (L).
        let known = try report(players, accepted: [Retraining(player: id("Winger"), position: .attackingMidLeft, acceptedOn: acceptedOn)])
        #expect(known.needsBeingRetrained.isEmpty)
        #expect(choices(known) == [RetrainingChoice(player: id("Winger"), position: .midfielderLeft)])
    }

    @Test func needsBeingRetrainedComeInTacticOrderThenNeed() throws {
        // Left back and both centre-back slots are thin; one back is being retrained at each position.
        var other = tactic
        other.name = "Second Sample"
        let players = try thinAtTheBack([rightBack("Back A"), rightBack("Back B")])
        let accepted = [Retraining(player: id("Back B"), position: .defenderCentral, acceptedOn: acceptedOn),
                        Retraining(player: id("Back A"), position: .defenderLeft, acceptedOn: acceptedOn)]
        let depth = try Depth.report(tactic: tactic, players: players, ownClub: "Oxford City", catalog: catalog,
                                     profile: profile, parameters: .fm27)
        let thin = depth.thin.filter { [.D_L, .D_CL, .D_CR].contains($0) }
        try #require(thin.count == 3)
        let r = try report(players, tactics: [other, tactic], accepted: accepted,
                           rejected: [RetrainingChoice(player: id("Back A"), position: .defenderCentral),
                                      RetrainingChoice(player: id("Back B"), position: .defenderLeft)])
        #expect(r.recommendations.isEmpty)
        #expect(r.needsBeingRetrained == thin.map { RetrainingNeed(tactic: "Second Sample", slot: $0) }
                + thin.map { RetrainingNeed(tactic: sample, slot: $0) })
        #expect(r.needsWithoutCandidates.isEmpty)
    }

    @Test func aNeedBeingRetrainedCanStillGetAnotherRecommendation() throws {
        let players = try thinAtLeftBack([rightBack("Back A", versatility: 14), rightBack("Back B", versatility: 13)])
        let r = try report(players, accepted: [Retraining(player: id("Back A"), position: .defenderLeft, acceptedOn: acceptedOn)])
        #expect(choices(r) == [RetrainingChoice(player: id("Back B"), position: .defenderLeft)])
        #expect(r.needsBeingRetrained.isEmpty && r.needsWithoutCandidates.isEmpty)
    }

    @Test func aPlayerWhoseBestPositionIsFullIsOfferedHisNextBest() throws {
        // The centre-backs' first choices are stronger, so for every back D (L) has the larger share.
        let players = try thinAtTheBack([rightBack("Back A", versatility: 14), rightBack("Back B", versatility: 13),
                                         rightBack("Back C", versatility: 12)]).map { p -> Player in
            guard p.name == named(.D_CL, "first") || p.name == named(.D_CR, "first") else { return p }
            var strong = p
            for attribute in Attribute.allCases where attribute != .versatility && attribute != .professionalism {
                strong.attributes[attribute] = 16
            }
            return strong
        }
        let back = rightBack("Back C", versatility: 12)
        let atLeft = try share(of: back, at: .D_L, firstChoice: firstChoice(.D_L, in: players)).share
        let atCentre = try share(of: back, at: .D_CL, firstChoice: firstChoice(.D_CL, in: players)).share
        try #require(atLeft > atCentre && atCentre >= 0.8)
        let r = try report(players)
        #expect(Set(choices(r)) == [RetrainingChoice(player: id("Back A"), position: .defenderLeft),
                                    RetrainingChoice(player: id("Back B"), position: .defenderLeft),
                                    RetrainingChoice(player: id("Back C"), position: .defenderCentral)])
        #expect(r.needsWithoutCandidates.isEmpty)
    }

    @Test func aPositionGetsAtMostTwo() throws {
        // Equal ratings; Versatility orders their learnability.
        let backs = [rightBack("Back A", versatility: 14), rightBack("Back B", versatility: 13), rightBack("Back C", versatility: 12)]
        let r = try report(thinAtLeftBack(backs))
        #expect(choices(r) == [RetrainingChoice(player: id("Back A"), position: .defenderLeft),
                               RetrainingChoice(player: id("Back B"), position: .defenderLeft)])
        var three = EngineParameters.fm27
        three.retrainingPerPosition = Parameter(3, .derived, source: "test")
        #expect(try report(thinAtLeftBack(backs), parameters: three).recommendations.count == 3)
    }

    @Test func aPlayerAdvisedToLeaveIsNeverACandidate() throws {
        // Back A is recommended until he is among the players leaving; then the place goes to Back C.
        let backs = [rightBack("Back A", versatility: 14), rightBack("Back B", versatility: 13), rightBack("Back C", versatility: 12)]
        let leaving = try report(thinAtLeftBack(backs), leaving: [id("Back A")])
        #expect(choices(leaving) == [RetrainingChoice(player: id("Back B"), position: .defenderLeft),
                                     RetrainingChoice(player: id("Back C"), position: .defenderLeft)])
        // The only candidate leaving: the need is left for recruitment.
        let players = try thinAtLeftBack([rightBack()])
        #expect(try report(players).recommendations.map(\.choice.player) == [id("Right Back")])
        let alone = try report(players, leaving: [id("Right Back")])
        #expect(alone.recommendations.isEmpty)
        #expect(alone.needsWithoutCandidates == [RetrainingNeed(tactic: sample, slot: .D_L)])
        // Someone leaving who is no candidate changes nothing.
        #expect(try report(players, leaving: [PlannerFixture.id(.GK, "first")]) == report(players))
    }

    @Test func aPairCoveringTwoNeedsListsBoth() throws {
        var other = tactic
        other.name = "Second Sample"
        let r = try report(thinAtLeftBack([rightBack()]), tactics: [tactic, other])
        #expect(r.recommendations.count == 1)
        let rec = try #require(r.recommendations.first)
        #expect(rec.needs == [RetrainingNeed(tactic: sample, slot: .D_L), RetrainingNeed(tactic: "Second Sample", slot: .D_L)])
        #expect(rec.reasons.prefix(2) == ["Cover at D (L) is thin in Sample 4-2-3-1 (1 solid player available)",
                                          "Cover at D (L) is thin in Second Sample (1 solid player available)"])
        #expect(r.needsWithoutCandidates.isEmpty)
    }

    @Test func recommendationsComeInTheOrderOfTheNeedsTheyCover() throws {
        // ST_C has no solid player (cover 0) and comes before D_L (cover 1) in the depth report's order.
        // The forward, slower to learn, has the smaller product, so only the need order puts him first.
        let forward = Player.fixture(name: "Forward", age: 27, all: 13, attributes: [.versatility: 12, .professionalism: 12],
                                     familiarity: [.attackingMidCentral: 20, .striker: 12],
                                     currentAbility: 100, potentialAbility: 100)
        let players = try squad(without: [named(.D_L, "second"), named(.ST_C, "first"), named(.ST_C, "second")])
            + [rightBack(), forward]
        let depth = try Depth.report(tactic: tactic, players: players, ownClub: "Oxford City", catalog: catalog,
                                     profile: profile, parameters: .fm27)
        let st = try #require(depth.thin.firstIndex(of: .ST_C)), dl = try #require(depth.thin.firstIndex(of: .D_L))
        try #require(st < dl)
        // Each is kept to one position, so the order of the needs is what is tested.
        let pinned: Set<RetrainingChoice> = [RetrainingChoice(player: id("Forward"), position: .defenderLeft),
                                             RetrainingChoice(player: id("Right Back"), position: .striker)]
        let r = try report(players, rejected: pinned)
        #expect(r.recommendations.map(\.choice) == [RetrainingChoice(player: id("Forward"), position: .striker),
                                                    RetrainingChoice(player: id("Right Back"), position: .defenderLeft)])
        let products = r.recommendations.map { $0.shareOfFirstChoice * $0.learnability }
        #expect(products[0] < products[1])
    }

    @Test func aNeedNobodySuitsIsReportedForRecruitment() throws {
        // Nobody can play up front and nobody in this squad is quick enough to learn it.
        let r = try report(try squad(without: [named(.ST_C, "first"), named(.ST_C, "second")]))
        #expect(r.recommendations.isEmpty)
        #expect(r.needsWithoutCandidates.contains(RetrainingNeed(tactic: sample, slot: .ST_C)))
        // A squad of one: every slot is thin; nobody suits any of them, and nothing crashes.
        let keeper = try #require(try squad().first { $0.name == named(.GK, "first") })
        let small = try report([keeper])
        #expect(small.recommendations.isEmpty)
        #expect(Set(small.needsWithoutCandidates.map(\.slot)) == Set(try tactic.assignments(catalog: catalog).map(\.slot)))
        // No players at all.
        let none = try report([])
        #expect(none.recommendations.isEmpty && none.needsWithoutCandidates.count == 11)
    }

    // MARK: Words, basis, errors and order

    @Test func reasonsAndCautionsReadAsWritten() throws {
        // Natural at WB (L), familiarity 5 at D (L), age 20, Versatility 9: fluid, 6 × 1.5 = 9 weeks.
        let p = Player.fixture(name: "Wing Back", age: 20, all: 13, attributes: [.versatility: 9, .professionalism: 20],
                               familiarity: [.wingBackLeft: 20, .defenderLeft: 5], currentAbility: 100, potentialAbility: 140)
        let players = try thinAtLeftBack([p])
        let rec = try #require(try report(players).recommendations.first)
        // The figures typed out below match an independent rating of him with familiarity 20 at D (L).
        let expected = try share(of: p, at: .D_L, firstChoice: firstChoice(.D_L, in: players))
        #expect(abs(expected.rating - 144.2) < 0.05)
        #expect(expected.share >= 0.94 && expected.share < 0.95)
        #expect(rec.reasons == [
            "Cover at D (L) is thin in Sample 4-2-3-1 (1 solid player available)",
            "He would rate 144.2 there once learnt, 94% of the first choice",
            "From WB (L): a fluid change, about 9 weeks at his age and Versatility",
        ])
        #expect(rec.cautions == [
            "Timings are estimates from earlier versions of the game; none is published for FM27",
            "His familiarity at WB (L) may fall while he learns a new position",
            "He may never become natural there",
            "Low Versatility: this may take 18 months or more",
        ])
        // At familiarity 10 and Versatility 10 the conditional cautions go.
        var steadier = p
        steadier.familiarity[.defenderLeft] = 10
        steadier.attributes[.versatility] = 10
        let rec2 = try #require(try report(thinAtLeftBack([steadier])).recommendations.first)
        #expect(rec2.cautions == [
            "Timings are estimates from earlier versions of the game; none is published for FM27",
            "His familiarity at WB (L) may fall while he learns a new position",
        ])
    }

    @Test func theCoverBracketCountsSolidPlayers() throws {
        // ST_C with nobody: no solid player.
        let striker = Player.fixture(name: "Forward", age: 20, all: 13, attributes: [.versatility: 14, .professionalism: 12],
                                     familiarity: [.attackingMidCentral: 20, .striker: 12])
        let r = try report(try squad(without: [named(.ST_C, "first"), named(.ST_C, "second")]) + [striker])
        let rec = try #require(r.recommendations.first { $0.choice.player == id("Forward") })
        #expect(rec.reasons.first == "Cover at ST (C) is thin in Sample 4-2-3-1 (no solid player available)")
        // A slot is thin below three when the line is raised, so two solid players can be named.
        var three = EngineParameters.fm27
        three.depthThinBelow = Parameter(3, .derived, source: "test")
        let r3 = try report(try squad() + [rightBack()], parameters: three)
        let any = try #require(r3.recommendations.first)
        let reason = try #require(any.reasons.first)
        #expect(reason.hasPrefix("Cover at ") && reason.hasSuffix(" is thin in Sample 4-2-3-1 (2 solid players available)"))
    }

    @Test func theBasisIsTheWeakestEvidenceBehindTheAdvice() throws {
        let players = try thinAtLeftBack([rightBack()])
        #expect(try #require(try report(players).recommendations.first).basis == .derived)
        var q = EngineParameters.fm27
        func measured<V>(_ p: Parameter<V>) -> Parameter<V> { Parameter(p.value, .fm27Measured, source: "test") }
        q.depthCoverFamiliarity = measured(q.depthCoverFamiliarity)
        q.depthSolidFamiliarity = measured(q.depthSolidFamiliarity)
        q.depthThinBelow = measured(q.depthThinBelow)
        q.learnabilityRules = measured(q.learnabilityRules)
        q.retrainingMinimumLearnability = measured(q.retrainingMinimumLearnability)
        q.retrainingMinimumShare = measured(q.retrainingMinimumShare)
        q.retrainingPerPosition = measured(q.retrainingPerPosition)
        q.retrainingTransitions = measured(q.retrainingTransitions)
        q.retrainingWeeks = measured(q.retrainingWeeks)
        q.retrainingPace = Parameter(q.retrainingPace.value, .carriedOverFM26, source: "test")
        #expect(try #require(try report(players, parameters: q).recommendations.first).basis == .carriedOverFM26)
        q.retrainingPace = measured(q.retrainingPace)
        q.retrainingTransitions = Parameter(q.retrainingTransitions.value, .fm27Official, source: "test")
        #expect(try #require(try report(players, parameters: q).recommendations.first).basis == .fm27Official)
        q.retrainingTransitions = measured(q.retrainingTransitions)
        #expect(try #require(try report(players, parameters: q).recommendations.first).basis == .fm27Measured)
        // A parameter the advice does not use leaves the basis alone.
        q.retrainingStalledAfterWeeks = Parameter(6, .derived, source: "test")
        #expect(try #require(try report(players, parameters: q).recommendations.first).basis == .fm27Measured)
    }

    @Test func aMissingVersatilityIsAnErrorThatNamesThePlayer() throws {
        var p = rightBack()
        p.attributes[.versatility] = nil
        #expect(throws: RatingError.missingAttribute(player: "Right Back", attribute: .versatility)) {
            try report(thinAtLeftBack([p]))
        }
        // With no thin slot he is never weighed up.
        #expect(try report(try squad() + [p]).recommendations.isEmpty)
    }

    @Test func badParametersAreAnError() throws {
        var q = EngineParameters.fm27
        var weeks = q.retrainingWeeks.value
        weeks.fluid = WeekRange(fewest: 8, most: 4)
        q.retrainingWeeks = Parameter(weeks, .derived, source: "test")
        #expect(throws: PlanError.self) { try report(thinAtLeftBack([rightBack()]), parameters: q) }
    }

    @Test func inputOrderDoesNotMatter() throws {
        let backs = [rightBack("Back A", versatility: 14), rightBack("Back B", versatility: 13), rightBack("Back C", versatility: 12)]
        let players = try thinAtTheBack(backs)
        let forward = try report(players)
        #expect(!forward.recommendations.isEmpty)
        #expect(try report(players.reversed()) == forward)
        var shuffled = players
        var generator = SeededGenerator(seed: 11)
        shuffled.shuffle(using: &generator)
        #expect(try report(shuffled) == forward)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
