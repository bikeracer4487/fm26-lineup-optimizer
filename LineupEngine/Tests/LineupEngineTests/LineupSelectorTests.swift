import Foundation
import Testing
@testable import LineupEngine

@Suite struct LineupSelectorTests {
    let selector = LineupSelector(catalog: try! RoleCatalog.fm27(), tables: try! RatingTables.bundled(), parameters: .fm27)
    let tactic = try! JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))

    /// One natural player per slot of the sample tactic: familiarity 20 at the positions the slot
    /// uses in both phases, every attribute 10.
    static let naturals: [(name: String, positions: [Position])] = [
        ("Goalkeeper", [.goalkeeper]),
        ("Left Back", [.defenderLeft]),
        ("Left Centre Back", [.defenderCentral]),
        ("Right Centre Back", [.defenderCentral]),
        ("Right Back", [.defenderRight]),
        ("Left Holder", [.defensiveMidfielder]),
        ("Right Holder", [.defensiveMidfielder]),
        ("Left Winger", [.attackingMidLeft, .midfielderLeft]),
        ("Playmaker", [.attackingMidCentral]),
        ("Right Winger", [.attackingMidRight, .midfielderRight]),
        ("Striker", [.striker]),
    ]

    func natural(_ name: String, at positions: [Position], all: Int = 10) -> Player {
        Player.fixture(name: name, all: all, familiarity: Dictionary(uniqueKeysWithValues: positions.map { ($0, 20) }))
    }

    /// The eleven naturals followed by `extras`.
    func squad(_ extras: Player...) -> [Player] {
        Self.naturals.map { natural($0.name, at: $0.positions) } + extras
    }

    /// `players` with the one named `name` changed.
    func changing(_ name: String, in players: [Player], _ change: (inout Player) -> Void) -> [Player] {
        players.map { player in
            var player = player
            if player.name == name { change(&player) }
            return player
        }
    }

    func id(_ name: String) -> PlayerID { PlayerID(key: PlayerID.normalise(name)) }

    func request(
        _ players: [Player], importance: Importance = .medium, isNextFixture: Bool = true,
        overrides: [SlotID: PlayerID] = [:], rejected: Set<PlayerID> = [], ownClub: String? = "Oxford City"
    ) -> SelectionRequest {
        SelectionRequest(tactic: tactic, players: players, ownClub: ownClub, importance: importance,
                         isNextFixture: isNextFixture, overrides: overrides, rejected: rejected)
    }

    func pick(_ lineup: Lineup, _ slot: SlotID) -> Pick? { lineup.picks.first { $0.slot == slot } }

    func picked(_ lineup: Lineup, _ name: String) -> Bool { lineup.picks.contains { $0.player == id(name) } }

    func oneDecimal(_ x: Double) -> String { String(format: "%.1f", x) }

    // MARK: - The eleven

    @Test func fieldsElevenDistinctPlayersInSlotOrder() throws {
        let lineup = try selector.select(request(squad()))
        #expect(lineup.picks.count == 11)
        #expect(lineup.picks.map(\.slot) == SlotID.allCases.filter { tactic.inPossession[$0] != nil })
        #expect(Set(lineup.picks.map(\.player)).count == 11)
        #expect(lineup.unfilled.isEmpty)
        #expect(lineup.omissions.isEmpty)
        #expect(lineup.ignoredOverrides.isEmpty)
        #expect(pick(lineup, .ST_C)?.player == id("Striker"))
        #expect(pick(lineup, .AM_L)?.player == id("Left Winger"))
        #expect(lineup.picks.allSatisfy { $0.warnings.isEmpty && !$0.isOverride })
    }

    @Test func theBetterPlayerStartsWhenBothAreFit() throws {
        let stronger = try selector.select(request(squad(natural("Strong Centre Back", at: [.defenderCentral], all: 14))))
        #expect(picked(stronger, "Strong Centre Back"))
        #expect(stronger.picks.filter { [.D_CL, .D_CR].contains($0.slot) }.count == 2)

        let weaker = try selector.select(request(squad(natural("Weak Centre Back", at: [.defenderCentral], all: 7))))
        #expect(!picked(weaker, "Weak Centre Back"))
        #expect(picked(weaker, "Left Centre Back") && picked(weaker, "Right Centre Back"))
        #expect(weaker.omissions.isEmpty)
    }

    @Test func aPickCarriesItsRatingFitnessAndValue() throws {
        let lineup = try selector.select(request(changing("Striker", in: squad()) { $0.sharpness = 0.75 }))
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.name == "Striker")
        #expect(st.fitness == FitnessFactors(condition: 1, sharpness: 0.92, jadedness: 1))
        #expect(st.value == st.rating.value * st.fitness.product)
        #expect(!st.isOverride)
    }

    // MARK: - Fitness

    @Test func lowConditionCostsAStartWhenARivalIsClose() throws {
        // Same attributes at familiarity 17 (factor 0.95 in both phases): a rating exactly 5% lower.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let tired = try selector.select(request(changing("Striker", in: squad(rival)) { $0.condition = 0.86 }))
        #expect(pick(tired, .ST_C)?.player == id("Rival Striker"))
        #expect(tired.omissions.count == 1)
        let omission = try #require(tired.omissions.first)
        #expect(omission.player == id("Striker") && omission.slot == .ST_C && omission.name == "Striker")
        guard case .lowerMatchDayValue(let ideal, let today, let limiting) = omission.cause else {
            Issue.record("expected lowerMatchDayValue, got \(omission.cause)"); return
        }
        #expect(limiting == .condition)
        #expect(abs(today - ideal * 0.892) < 1e-9)
        #expect(omission.reason == "Left out: condition 86% lowers him from \(oneDecimal(ideal)) to \(oneDecimal(today))")

        let fresh = try selector.select(request(squad(rival)))
        #expect(pick(fresh, .ST_C)?.player == id("Striker"))
        #expect(fresh.omissions.isEmpty)
    }

    @Test func aPickBelowFullFitnessExplainsWhy() throws {
        let lineup = try selector.select(request(changing("Striker", in: squad()) { $0.condition = 0.90 }))
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.reasons.contains { $0.hasPrefix("Condition 90%") })
        #expect(st.reasons == [
            "Rating \(oneDecimal(st.rating.value)): ST (C) familiarity 20 in possession, ST (C) familiarity 20 out of possession",
            "Condition 90% (×0.94)",
        ])

        let fit = try #require(pick(lineup, .AM_L))
        #expect(fit.reasons == [
            "Rating \(oneDecimal(fit.rating.value)): AM (L) familiarity 20 in possession, M (L) familiarity 20 out of possession",
        ])
    }

    @Test func everyFactorBelowFullIsExplainedInOrder() throws {
        let lineup = try selector.select(request(changing("Striker", in: squad()) {
            $0.condition = 0.90; $0.sharpness = 0.75; $0.jadedness = 300
        }))
        let st = try #require(pick(lineup, .ST_C))
        #expect(Array(st.reasons.dropFirst()) == ["Condition 90% (×0.94)", "Sharpness 75% (×0.92)", "Jadedness 300 (×0.90)"])
    }

    @Test func aLowFactorOtherThanConditionIsNamedAsTheLimit() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let lineup = try selector.select(request(changing("Striker", in: squad(rival)) { $0.condition = 0.90; $0.sharpness = 0.50 }))
        let omission = try #require(lineup.omissions.first)
        guard case .lowerMatchDayValue(let ideal, let today, let limiting) = omission.cause else {
            Issue.record("expected lowerMatchDayValue, got \(omission.cause)"); return
        }
        #expect(limiting == .sharpness)
        #expect(omission.reason == "Left out: sharpness 50% lowers him from \(oneDecimal(ideal)) to \(oneDecimal(today))")
    }

    // MARK: - Risk rules

    @Test(arguments: Importance.allCases)
    func belowTheFloorDoesNotStartAtAnyImportance(_ importance: Importance) throws {
        // Familiarity 10 (factor 0.80) is below his value at the floor (condition factor 0.88).
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 10])
        let lineup = try selector.select(request(changing("Striker", in: squad(cover)) { $0.condition = 0.84 }, importance: importance))
        #expect(!picked(lineup, "Striker"))
        #expect(pick(lineup, .ST_C)?.player == id("Cover Striker"))
        let omission = try #require(lineup.omissions.first)
        #expect(omission.cause == .excluded(.belowConditionFloor(0.84)))
        #expect(omission.slot == .ST_C)
        #expect(omission.reason == "Left out: below the 85% condition floor at 84%")
    }

    @Test(arguments: Importance.allCases)
    func atTheFloorHeStillStarts(_ importance: Importance) throws {
        // Familiarity 10 (factor 0.80) is below his value at the floor (condition factor 0.88).
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 10])
        let lineup = try selector.select(request(changing("Striker", in: squad(cover)) { $0.condition = 0.85 }, importance: importance))
        #expect(pick(lineup, .ST_C)?.player == id("Striker"))
    }

    @Test func aJadedFirstChoiceStartsOnlyAHighFixture() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 9])
        let players = changing("Striker", in: squad(cover)) { $0.jadedness = 430 }

        let medium = try selector.select(request(players, importance: .medium))
        #expect(!picked(medium, "Striker"))
        let coverPick = try #require(pick(medium, .ST_C))
        #expect(coverPick.player == id("Cover Striker"))
        #expect(coverPick.warnings == [.outOfPosition(.inPossession, familiarity: 9), .outOfPosition(.outOfPossession, familiarity: 9)])
        let omission = try #require(medium.omissions.first)
        #expect(omission.cause == .excluded(.jaded(430)))
        #expect(omission.reason == "Left out: jadedness 430 is above 400")

        let high = try selector.select(request(players, importance: .high))
        let st = try #require(pick(high, .ST_C))
        #expect(st.player == id("Striker"))
        #expect(st.fitness.jadedness == 0.7)
        #expect(high.omissions.isEmpty)
    }

    @Test func atTheJadedThresholdHeStillStarts() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 9])
        let lineup = try selector.select(request(changing("Striker", in: squad(cover)) { $0.jadedness = 400 }, importance: .medium))
        #expect(pick(lineup, .ST_C)?.player == id("Striker"))
    }

    @Test func injuredAndLoanedOutPlayersNeverStart() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let away = Player.fixture(name: "Away Striker", all: 15, familiarity: [.striker: 20], loanedTo: "Wallingford")
        let lineup = try selector.select(request(changing("Striker", in: squad(cover, away)) { $0.isInjured = true }, importance: .high))
        #expect(!picked(lineup, "Striker"))
        #expect(!picked(lineup, "Away Striker"))
        #expect(pick(lineup, .ST_C)?.player == id("Cover Striker"))
        // The ideal eleven leaves out players on loan, so only the injured striker is an omission.
        #expect(lineup.omissions.map(\.player) == [id("Striker")])
        #expect(lineup.omissions.first?.cause == .excluded(.injured))
        #expect(lineup.omissions.first?.reason == "Left out: injured")

        let fit = try selector.select(request(squad(cover, away), importance: .high))
        #expect(pick(fit, .ST_C)?.player == id("Striker"))
    }

    @Test func aBannedPlayerMissesOnlyTheNextFixture() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let players = changing("Striker", in: squad(cover)) { $0.isBanned = true }

        let next = try selector.select(request(players, isNextFixture: true))
        #expect(pick(next, .ST_C)?.player == id("Cover Striker"))
        #expect(next.omissions.first?.cause == .excluded(.banned))
        #expect(next.omissions.first?.reason == "Left out: banned for this fixture")

        let later = try selector.select(request(players, isNextFixture: false))
        #expect(pick(later, .ST_C)?.player == id("Striker"))
        #expect(later.omissions.isEmpty)
    }

    @Test func aRejectedPlayerIsLeftOutAndSaysSo() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let rejected = try selector.select(request(squad(cover), rejected: [id("Striker")]))
        #expect(pick(rejected, .ST_C)?.player == id("Cover Striker"))
        let omission = try #require(rejected.omissions.first)
        #expect(omission.cause == .excluded(.rejected))
        #expect(omission.reason == "Left out: rejected for this fixture")

        let notRejected = try selector.select(request(squad(cover), rejected: [id("Cover Striker")]))
        #expect(pick(notRejected, .ST_C)?.player == id("Striker"))
        #expect(notRejected.omissions.isEmpty)
    }

    @Test func aRuleExclusionTakesPrecedenceOverARejection() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let lineup = try selector.select(request(changing("Striker", in: squad(cover)) { $0.isInjured = true }, rejected: [id("Striker")]))
        #expect(lineup.omissions.first?.cause == .excluded(.injured))
    }

    @Test func aLoanedInPlayerIsAvailable() throws {
        let loanee = Player.fixture(name: "Loan Striker", familiarity: [.striker: 20], club: "Wallingford", loanedTo: "Oxford City")
        let players = squad().filter { $0.name != "Striker" } + [loanee]
        let lineup = try selector.select(request(players, ownClub: "Oxford City"))
        #expect(pick(lineup, .ST_C)?.player == id("Loan Striker"))
        #expect(lineup.unfilled.isEmpty)
    }

    @Test func omissionsFollowTheIdealSlotOrder() throws {
        let coverStriker = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let coverBack = Player.fixture(name: "Cover Back", familiarity: [.defenderLeft: 17])
        var players = changing("Striker", in: squad(coverStriker, coverBack)) { $0.isInjured = true }
        players = changing("Left Back", in: players) { $0.isBanned = true }
        let lineup = try selector.select(request(players))
        #expect(lineup.omissions.map(\.slot) == [.D_L, .ST_C])
        #expect(lineup.omissions.map(\.player) == [id("Left Back"), id("Striker")])
    }

    @Test func aPlayerMovedToAnotherSlotIsNotAnOmission() throws {
        // Ideal: Playmaker at AM_C, Versatile at ST_C. With the Playmaker injured, Versatile moves to
        // AM_C and Backup Striker takes ST_C; only the Playmaker is an omission.
        let versatile = Player.fixture(name: "Versatile", all: 12, familiarity: [.striker: 20, .attackingMidCentral: 20])
        let backup = natural("Backup Striker", at: [.striker], all: 8)
        var players = squad().filter { $0.name != "Striker" && $0.name != "Playmaker" }
        players += [natural("Playmaker", at: [.attackingMidCentral], all: 14), versatile, backup]

        let fit = try selector.select(request(players))
        try #require(pick(fit, .ST_C)?.player == id("Versatile"))

        let lineup = try selector.select(request(changing("Playmaker", in: players) { $0.isInjured = true }))
        try #require(pick(lineup, .AM_C)?.player == id("Versatile"))
        #expect(pick(lineup, .ST_C)?.player == id("Backup Striker"))
        #expect(lineup.omissions.map(\.player) == [id("Playmaker")])
    }

    // MARK: - Overrides

    @Test func anOverrideFixesThePlayerInTheSlot() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let without = try selector.select(request(squad(rival)))
        #expect(pick(without, .ST_C)?.player == id("Striker"))

        let lineup = try selector.select(request(squad(rival), overrides: [.ST_C: id("Rival Striker")]))
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.player == id("Rival Striker"))
        #expect(st.isOverride)
        #expect(st.reasons.contains("Chosen by you"))
        #expect(st.warnings.isEmpty)
        #expect(lineup.ignoredOverrides.isEmpty)
        let omission = try #require(lineup.omissions.first)
        #expect(omission.player == id("Striker"))
        guard case .lowerMatchDayValue(let ideal, let today, let limiting) = omission.cause else {
            Issue.record("expected lowerMatchDayValue, got \(omission.cause)"); return
        }
        #expect(ideal == today && limiting == .condition)
        #expect(omission.reason == "Left out: others are a better fit today")
    }

    @Test func anOverrideBeatsTheConditionFloorAndIsMarked() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let players = changing("Striker", in: squad(cover)) { $0.condition = 0.80 }
        let lineup = try selector.select(request(players, overrides: [.ST_C: id("Striker")]))
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.player == id("Striker"))
        #expect(st.isOverride)
        #expect(st.warnings == [.overridesRule(.belowConditionFloor(0.80))])
        #expect(st.reasons.last == "Chosen by you, overriding: condition 80% is below the 85% floor")
        #expect(lineup.ignoredOverrides.isEmpty)
        #expect(lineup.omissions.isEmpty)
    }

    @Test func anOverrideBeatsARejectionJadednessAndABan() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let rejected = try selector.select(request(squad(cover), overrides: [.ST_C: id("Striker")], rejected: [id("Striker")]))
        #expect(pick(rejected, .ST_C)?.warnings == [.overridesRule(.rejected)])
        #expect(pick(rejected, .ST_C)?.reasons.last == "Chosen by you, overriding: rejected for this fixture")

        let jaded = try selector.select(request(changing("Striker", in: squad(cover)) { $0.jadedness = 430 }, overrides: [.ST_C: id("Striker")]))
        #expect(pick(jaded, .ST_C)?.warnings == [.overridesRule(.jaded(430))])
        #expect(pick(jaded, .ST_C)?.reasons.last == "Chosen by you, overriding: jadedness 430 is above 400")

        let banned = try selector.select(request(changing("Striker", in: squad(cover)) { $0.isBanned = true }, overrides: [.ST_C: id("Striker")]))
        #expect(pick(banned, .ST_C)?.warnings == [.overridesRule(.banned)])
        #expect(pick(banned, .ST_C)?.reasons.last == "Chosen by you, overriding: banned")
    }

    @Test func anOverrideOfAnInjuredPlayerIsIgnoredAndReported() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let lineup = try selector.select(request(changing("Striker", in: squad(cover)) { $0.isInjured = true }, overrides: [.ST_C: id("Striker")]))
        #expect(lineup.ignoredOverrides[.ST_C] == .notAllowed(.injured))
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.player == id("Cover Striker"))
        #expect(!st.isOverride)
    }

    @Test func anOverrideOfAPlayerOutOnLoanIsIgnoredAndReported() throws {
        let away = Player.fixture(name: "Away Striker", familiarity: [.striker: 20], loanedTo: "Wallingford")
        let lineup = try selector.select(request(squad(away), overrides: [.ST_C: id("Away Striker")]))
        #expect(lineup.ignoredOverrides[.ST_C] == .notAllowed(.outOnLoan(to: "Wallingford")))
        #expect(pick(lineup, .ST_C)?.player == id("Striker"))
    }

    @Test func anOverrideForSomeoneNotInTheSquadIsIgnored() throws {
        let lineup = try selector.select(request(squad(), overrides: [.ST_C: id("Nobody")]))
        #expect(lineup.ignoredOverrides == [.ST_C: .notInSquad])
        #expect(pick(lineup, .ST_C)?.player == id("Striker"))
        #expect(lineup.picks.count == 11)
    }

    @Test func onePlayerOverriddenIntoTwoSlotsIsIgnoredInBoth() throws {
        let lineup = try selector.select(request(squad(), overrides: [.ST_C: id("Playmaker"), .GK: id("Playmaker")]))
        #expect(lineup.ignoredOverrides == [.ST_C: .usedTwice, .GK: .usedTwice])
        #expect(lineup == (try selector.select(request(squad()))).withIgnoredOverrides(lineup.ignoredOverrides))
        #expect(lineup.picks.allSatisfy { !$0.isOverride })
    }

    // MARK: - Short squads

    @Test func withBothGoalkeepersInjuredAnOutfielderIsFlaggedInGoal() throws {
        let spareKeeper = natural("Spare Goalkeeper", at: [.goalkeeper])
        let spareDefender = natural("Spare Defender", at: [.defenderCentral])
        var players = changing("Goalkeeper", in: squad(spareKeeper, spareDefender)) { $0.isInjured = true }
        players = changing("Spare Goalkeeper", in: players) { $0.isInjured = true }
        let lineup = try selector.select(request(players))
        #expect(lineup.picks.count == 11)
        #expect(lineup.unfilled.isEmpty)
        let gk = try #require(pick(lineup, .GK))
        #expect(gk.warnings.contains(.outOfPosition(.inPossession, familiarity: 1)))
        #expect(gk.warnings == [.outOfPosition(.inPossession, familiarity: 1), .outOfPosition(.outOfPossession, familiarity: 1)])
        #expect(gk.player != id("Goalkeeper") && gk.player != id("Spare Goalkeeper"))
    }

    @Test func aCoverAtTheCompetentStepIsNotFlagged() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 10])
        let lineup = try selector.select(request(changing("Striker", in: squad(cover)) { $0.isInjured = true }))
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.player == id("Cover Striker"))
        #expect(st.warnings.isEmpty)
    }

    @Test func tenAvailablePlayersLeavesOneSlotUnfilled() throws {
        let lineup = try selector.select(request(squad().filter { $0.name != "Striker" }))
        #expect(lineup.picks.count == 10)
        #expect(lineup.unfilled.count == 1)
        #expect(lineup.unfilled == [.ST_C])
        #expect(lineup.omissions.isEmpty)
    }

    @Test func anEmptySquadReturnsElevenUnfilledSlots() throws {
        let lineup = try selector.select(request([]))
        #expect(lineup.picks.isEmpty)
        #expect(lineup.unfilled == SlotID.allCases.filter { tactic.inPossession[$0] != nil })
        #expect(lineup.omissions.isEmpty)
        #expect(lineup.ignoredOverrides.isEmpty)
    }

    // MARK: - Determinism and input errors

    @Test func resultDoesNotDependOnInputOrder() throws {
        let players = changing("Striker", in: squad(
            natural("Spare Centre Back", at: [.defenderCentral]),
            Player.fixture(name: "Rival Striker", familiarity: [.striker: 17]),
            Player.fixture(name: "Utility", familiarity: [.defensiveMidfielder: 20, .defenderLeft: 20, .defenderRight: 20])
        )) { $0.condition = 0.86 }
        let baseline = try selector.select(request(players))
        #expect(try selector.select(request(players.reversed())) == baseline)
        for shift in [3, 7, 11] {
            let rotated = Array(players[shift...] + players[..<shift])
            #expect(try selector.select(request(rotated)) == baseline)
        }
    }

    @Test func aDuplicatePlayerIDKeepsTheFirst() throws {
        let strong = natural("Striker", at: [.striker], all: 18)
        let base = try selector.select(request(squad()))
        let duplicateLast = try selector.select(request(squad(strong)))
        #expect(duplicateLast == base)
        #expect(duplicateLast.picks.filter { $0.player == id("Striker") }.count == 1)

        let duplicateFirst = try selector.select(request([strong] + squad()))
        let st = try #require(pick(duplicateFirst, .ST_C))
        #expect(st.player == id("Striker"))
        #expect(st.rating.value > (try #require(pick(base, .ST_C))).rating.value)
        #expect(duplicateFirst.picks.filter { $0.player == id("Striker") }.count == 1)
    }

    @Test func anInvalidTacticThrows() throws {
        var broken = tactic
        broken.inPossession[.ST_C] = nil
        var req = request(squad())
        req.tactic = broken
        #expect(throws: TacticError.self) { try selector.select(req) }
    }

    @Test func missingPlayerDataThrows() throws {
        let players = changing("Striker", in: squad()) { $0.attributes = [:] }
        #expect(throws: RatingError.self) { try selector.select(request(players)) }
    }
}

private extension Lineup {
    func withIgnoredOverrides(_ ignored: [SlotID: OverrideProblem]) -> Lineup {
        Lineup(picks: picks, unfilled: unfilled, omissions: omissions, ignoredOverrides: ignored)
    }
}
