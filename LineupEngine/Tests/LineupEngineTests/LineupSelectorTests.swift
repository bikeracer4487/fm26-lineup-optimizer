import Foundation
import Testing
@testable import LineupEngine

@Suite struct LineupSelectorTests {
    let selector = LineupSelector(catalog: try! RoleCatalog.fm27(), profile: try! RatingProfile.carriedOver(), parameters: .fm27)
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
            "Rating \(oneDecimal(st.rating.value)): striker familiarity 20 in possession, striker familiarity 20 out of possession",
            "Condition 90% (×0.94)",
        ])

        let fit = try #require(pick(lineup, .AM_L))
        #expect(fit.reasons == [
            "Rating \(oneDecimal(fit.rating.value)): left attacking midfield familiarity 20 in possession, left midfield familiarity 20 out of possession",
        ])
    }

    @Test func everyFactorBelowFullIsExplainedInOrder() throws {
        let lineup = try selector.select(request(changing("Striker", in: squad()) {
            $0.condition = 0.90; $0.sharpness = 0.75; $0.jadedness = 300
        }))
        let st = try #require(pick(lineup, .ST_C))
        #expect(Array(st.reasons.dropFirst()) == ["Condition 90% (×0.94)", "Sharpness 75% (×0.92)", "Jadedness 300 (×0.90)"])
    }

    @Test func twoLowFactorsAreBothNamedAndTheLowerIsTheLimit() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let lineup = try selector.select(request(changing("Striker", in: squad(rival)) { $0.condition = 0.90; $0.sharpness = 0.50 }))
        let omission = try #require(lineup.omissions.first)
        guard case .lowerMatchDayValue(let ideal, let today, let limiting) = omission.cause else {
            Issue.record("expected lowerMatchDayValue, got \(omission.cause)"); return
        }
        #expect(limiting == .sharpness)
        #expect(omission.reason
            == "Left out: fitness lowers him from \(oneDecimal(ideal)) to \(oneDecimal(today)) (condition 90%, sharpness 50%)")
    }

    @Test func sharpnessIsTheLimitWhenItTiesJadednessBelowCondition() throws {
        // Condition 90% (0.94); sharpness 30% and jadedness 500 both 0.70. A high fixture, so 500 is not excluded.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let players = changing("Striker", in: squad(rival)) { $0.condition = 0.90; $0.sharpness = 0.30; $0.jadedness = 500 }
        let lineup = try selector.select(request(players, importance: .high))
        let omission = try #require(lineup.omissions.first)
        guard case .lowerMatchDayValue(let ideal, let today, let limiting) = omission.cause else {
            Issue.record("expected lowerMatchDayValue, got \(omission.cause)"); return
        }
        #expect(limiting == .sharpness)
        #expect(omission.reason == "Left out: fitness lowers him from \(oneDecimal(ideal)) to \(oneDecimal(today))"
            + " (condition 90%, sharpness 30%, jadedness 500)")
    }

    @Test func aPercentageIsRoundedDown() {
        #expect(Display.percent(0.846) == "84%")
        #expect(Display.percent(0.85) == "85%")
        #expect(Display.percent(0.84) == "84%")
        #expect(Display.percent(1) == "100%")
    }

    // Each factor on its own against a rival at familiarity 17 (factor 0.95, a rating exactly 5% lower).

    @Test func lowSharpnessAloneCostsAStart() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        // Sharpness 50% is a factor of 0.78, below the rival's 0.95.
        let lineup = try selector.select(request(changing("Striker", in: squad(rival)) { $0.sharpness = 0.50 }))
        #expect(pick(lineup, .ST_C)?.player == id("Rival Striker"))
        let omission = try #require(lineup.omissions.first)
        #expect(omission.reason.hasPrefix("Left out: sharpness 50% lowers him from"))
    }

    @Test func slightlyLowSharpnessDoesNotCostAStart() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        // Sharpness 90% is a factor of 0.968, above the rival's 0.95.
        let lineup = try selector.select(request(changing("Striker", in: squad(rival)) { $0.sharpness = 0.90 }))
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.player == id("Striker"))
        #expect(abs(st.fitness.sharpness - 0.968) < 1e-9)
        #expect(lineup.omissions.isEmpty)
    }

    @Test func jadednessAloneCostsAStart() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        // Jadedness 300 is a factor of 0.90, below the rival's 0.95, and under the 400 threshold.
        let lineup = try selector.select(request(changing("Striker", in: squad(rival)) { $0.jadedness = 300 }))
        #expect(pick(lineup, .ST_C)?.player == id("Rival Striker"))
        let omission = try #require(lineup.omissions.first)
        #expect(omission.reason.hasPrefix("Left out: jadedness 300 lowers him from"))
    }

    @Test func jadednessAgainstAWeakerRivalDoesNotCostAStart() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 10])
        // Jadedness 300 (0.90) still beats a rival at familiarity 10 (0.80).
        let lineup = try selector.select(request(changing("Striker", in: squad(rival)) { $0.jadedness = 300 }))
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.player == id("Striker"))
        #expect(st.fitness.jadedness == 0.90)
        #expect(lineup.omissions.isEmpty)
    }

    // MARK: - Thresholds come from the parameters

    func selector(_ change: (inout EngineParameters) -> Void) throws -> LineupSelector {
        var parameters = EngineParameters.fm27
        change(&parameters)
        return LineupSelector(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.carriedOver(), parameters: parameters)
    }

    @Test func aRaisedConditionFloorKeepsOutAPlayerTheDefaultLetsStart() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 10])
        let players = changing("Striker", in: squad(cover)) { $0.condition = 0.88 }
        #expect(pick(try selector.select(request(players)), .ST_C)?.player == id("Striker"))

        let strict = try selector { $0.conditionFloor = Parameter(0.90, .derived, source: "test: raised floor") }
        let lineup = try strict.select(request(players))
        #expect(pick(lineup, .ST_C)?.player == id("Cover Striker"))
        let omission = try #require(lineup.omissions.first)
        #expect(omission.cause == .excluded(.belowConditionFloor(0.88)))
        #expect(omission.reason == "Left out: below the 90% condition floor at 88%")
        let chosen = try strict.select(request(players, overrides: [.ST_C: id("Striker")]))
        #expect(pick(chosen, .ST_C)?.reasons.last == "Chosen by you, overriding: condition 88% is below the 90% floor")
    }

    @Test func aLoweredJadedThresholdKeepsOutAPlayerTheDefaultLetsStart() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 9])
        let players = changing("Striker", in: squad(cover)) { $0.jadedness = 350 }
        #expect(pick(try selector.select(request(players, importance: .medium)), .ST_C)?.player == id("Striker"))

        let strict = try selector { $0.jadedThreshold = Parameter(300, .derived, source: "test: lowered threshold") }
        let lineup = try strict.select(request(players, importance: .medium))
        #expect(pick(lineup, .ST_C)?.player == id("Cover Striker"))
        let omission = try #require(lineup.omissions.first)
        #expect(omission.cause == .excluded(.jaded(350)))
        #expect(omission.reason == "Left out: jadedness 350 is above 300")
        // A high-importance fixture ignores the jaded rule whatever its threshold.
        #expect(pick(try strict.select(request(players, importance: .high)), .ST_C)?.player == id("Striker"))
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

    @Test func justBelowTheFloorIsShownBelowTheFloor() throws {
        // 0.8499 fails the 0.85 floor, so the text must not show 85%.
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 10])
        let players = changing("Striker", in: squad(cover)) { $0.condition = 0.8499 }

        let left = try selector.select(request(players))
        let omission = try #require(left.omissions.first)
        #expect(omission.cause == .excluded(.belowConditionFloor(0.8499)))
        #expect(omission.reason == "Left out: below the 85% condition floor at 84%")

        let chosen = try selector.select(request(players, overrides: [.ST_C: id("Striker")]))
        let st = try #require(pick(chosen, .ST_C))
        #expect(st.reasons.contains { $0.hasPrefix("Condition 84% (×") })
        #expect(st.reasons.last == "Chosen by you, overriding: condition 84% is below the 85% floor")
    }

    @Test func percentagesAreRoundedDownSoNoneReachesAHundredUnlessItIs() throws {
        let lineup = try selector.select(request(changing("Striker", in: squad()) { $0.condition = 0.995; $0.sharpness = 0.999 }))
        let st = try #require(pick(lineup, .ST_C))
        #expect(Array(st.reasons.dropFirst()) == ["Condition 99% (×1.00)", "Sharpness 99% (×1.00)"])
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
        #expect(omission.cause == .displacedByOverride(by: [id("Rival Striker")]))
    }

    @Test func aFitPlayerSqueezedOutElsewhereIsToldYourChoiceMovedOthers() throws {
        // Ideal: Striker (all 12, natural at ST and AM (C)) at ST_C, Playmaker at AM_C. Overriding the
        // rival into ST_C moves the Striker to AM_C, so the fit Playmaker, whose own slot was not
        // overridden, loses his place because of the override.
        let striker = Player.fixture(name: "Striker", all: 12, familiarity: [.striker: 20, .attackingMidCentral: 20])
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let players = squad().filter { $0.name != "Striker" } + [striker, rival]
        try #require(pick(try selector.select(request(players)), .ST_C)?.player == id("Striker"))

        let lineup = try selector.select(request(players, overrides: [.ST_C: id("Rival Striker")]))
        try #require(pick(lineup, .AM_C)?.player == id("Striker"))
        #expect(lineup.omissions.map(\.player) == [id("Playmaker")])
        let omission = try #require(lineup.omissions.first)
        #expect(omission.cause == .displacedByOverride(by: [id("Rival Striker")]))
        #expect(omission.reason == "Left out: your choice of Rival Striker moved others into his place")

        // Every applied override is named, in slot order.
        let two = try selector.select(request(players, overrides: [.ST_C: id("Rival Striker"), .GK: id("Goalkeeper")]))
        #expect(two.omissions.first?.cause == .displacedByOverride(by: [id("Goalkeeper"), id("Rival Striker")]))
        #expect(two.omissions.first?.reason == "Left out: your choice of Goalkeeper and Rival Striker moved others into his place")
        let three = try selector.select(request(players, overrides: [.ST_C: id("Rival Striker"), .GK: id("Goalkeeper"),
                                                                     .D_L: id("Left Back")]))
        #expect(three.omissions.first?.cause == .displacedByOverride(by: [id("Goalkeeper"), id("Left Back"), id("Rival Striker")]))
        #expect(three.omissions.first?.reason
            == "Left out: your choice of Goalkeeper, Left Back and Rival Striker moved others into his place")
    }

    @Test func anOverrideIntoOneTwinSlotDisplacesAnUnfitPlayerFromTheOther() throws {
        // As on the real data: a midfielder chosen at one centre-back slot moves the fit centre-back
        // across, and the unfit one, whose own slot was not overridden, drops out.
        let spareHolder = natural("Spare Holder", at: [.defensiveMidfielder], all: 9)
        let players = changing("Right Centre Back", in: squad(spareHolder)) { $0.sharpness = 0.54 }
        // His slot in the ideal eleven, which ignores availability, found by ruling him out.
        let ruledOut = try selector.select(request(changing("Right Centre Back", in: players) { $0.isInjured = true }))
        let idealSlot = try #require(ruledOut.omissions.first { $0.player == id("Right Centre Back") }).slot
        try #require([SlotID.D_CL, .D_CR].contains(idealSlot))
        let otherSlot: SlotID = idealSlot == .D_CL ? .D_CR : .D_CL
        #expect(picked(try selector.select(request(players)), "Right Centre Back"))

        let lineup = try selector.select(request(players, overrides: [otherSlot: id("Left Holder")]))
        #expect(pick(lineup, otherSlot)?.player == id("Left Holder"))
        #expect(pick(lineup, idealSlot)?.player == id("Left Centre Back"))
        #expect(lineup.omissions.map(\.player) == [id("Right Centre Back")])
        let omission = try #require(lineup.omissions.first)
        #expect(omission.slot == idealSlot)
        #expect(omission.cause == .displacedByOverride(by: [id("Left Holder")]))
        #expect(omission.reason == "Left out: your choice of Left Holder moved others into his place")
    }

    @Test func aPlayerLeftOutWithOrWithoutTheOverridesKeepsHisFitnessReason() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let players = changing("Striker", in: squad(rival)) { $0.condition = 0.86 }
        try #require(pick(try selector.select(request(players)), .ST_C)?.player == id("Rival Striker"))
        let elsewhere = try selector.select(request(players, overrides: [.D_L: id("Right Back"), .D_R: id("Left Back")]))
        let ownSlot = try selector.select(request(players, overrides: [.ST_C: id("Rival Striker")]))
        for lineup in [elsewhere, ownSlot] {
            #expect(pick(lineup, .ST_C)?.player == id("Rival Striker"))
            let omission = try #require(lineup.omissions.first { $0.player == id("Striker") })
            guard case .lowerMatchDayValue(let ideal, let today, let limiting) = omission.cause else {
                Issue.record("expected lowerMatchDayValue, got \(omission.cause)"); continue
            }
            #expect(limiting == .condition)
            #expect(omission.reason == "Left out: condition 86% lowers him from \(oneDecimal(ideal)) to \(oneDecimal(today))")
        }
    }

    @Test func anIdealPlayerOverriddenIntoHisOwnSlotIsNotAnOmission() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let players = changing("Striker", in: squad(rival)) { $0.condition = 0.86 }
        try #require(try selector.select(request(players)).omissions.map(\.player) == [id("Striker")])
        let lineup = try selector.select(request(players, overrides: [.ST_C: id("Striker")]))
        #expect(pick(lineup, .ST_C)?.player == id("Striker"))
        #expect(lineup.omissions.isEmpty)
    }

    @Test func anIdealPlayerOverriddenIntoAnotherSlotIsNotAnOmission() throws {
        // A spare playmaker fills AM_C, so the striker has nowhere to go.
        let spare = natural("Spare Playmaker", at: [.attackingMidCentral], all: 9)
        let lineup = try selector.select(request(squad(spare), overrides: [.ST_C: id("Playmaker")]))
        #expect(pick(lineup, .ST_C)?.player == id("Playmaker"))
        #expect(pick(lineup, .AM_C)?.player == id("Spare Playmaker"))
        #expect(!lineup.omissions.contains { $0.player == id("Playmaker") })
        // The striker whose slot the playmaker took is the one omission.
        #expect(lineup.omissions.map(\.player) == [id("Striker")])
        #expect(lineup.omissions.first?.cause == .displacedByOverride(by: [id("Playmaker")]))
        #expect(lineup.omissions.first?.reason == "Left out: you chose Playmaker for striker")
    }

    @Test func aPlayerDisplacedByYourOverrideIsToldSo() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let players = changing("Striker", in: squad(rival)) { $0.condition = 0.95 }
        let lineup = try selector.select(request(players, overrides: [.ST_C: id("Rival Striker")]))
        let omission = try #require(lineup.omissions.first)
        #expect(lineup.omissions.count == 1)
        #expect(omission.player == id("Striker") && omission.slot == .ST_C)
        #expect(omission.cause == .displacedByOverride(by: [id("Rival Striker")]))
        #expect(omission.reason == "Left out: you chose Rival Striker for striker")

        // Without the override he starts: his condition factor (0.97) beats the rival's familiarity (0.95).
        let free = try selector.select(request(players))
        #expect(pick(free, .ST_C)?.player == id("Striker"))

        // With other overrides too, only the one in his own slot is named.
        let more = try selector.select(request(players, overrides: [.ST_C: id("Rival Striker"), .GK: id("Goalkeeper")]))
        #expect(more.omissions.first?.cause == .displacedByOverride(by: [id("Rival Striker")]))
        #expect(more.omissions.first?.reason == "Left out: you chose Rival Striker for striker")
    }

    @Test func aPlayerWhoLosesOnMeritWithoutAnOverrideIsBlamedOnFitness() throws {
        // A rival a little weaker than the striker at full fitness, but stronger than him at condition 0.95.
        let rival = natural("Rival Striker", at: [.striker])
        let players = changing("Striker", in: squad(rival)) { $0.condition = 0.95; $0.attributes[.finishing] = 11 }
        let lineup = try selector.select(request(players))
        #expect(pick(lineup, .ST_C)?.player == id("Rival Striker"))
        let omission = try #require(lineup.omissions.first)
        #expect(omission.player == id("Striker"))
        guard case .lowerMatchDayValue(let ideal, let today, let limiting) = omission.cause else {
            Issue.record("expected lowerMatchDayValue, got \(omission.cause)"); return
        }
        #expect(limiting == .condition)
        #expect(omission.reason == "Left out: condition 95% lowers him from \(oneDecimal(ideal)) to \(oneDecimal(today))")
    }

    @Test func anExcludedPlayerWhoseSlotWasOverriddenKeepsHisExclusion() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let lineup = try selector.select(request(squad(rival), overrides: [.ST_C: id("Rival Striker")], rejected: [id("Striker")]))
        #expect(lineup.omissions.first?.cause == .excluded(.rejected))
    }

    @Test func anOverriddenPlayerIsNotAlsoPlacedByTheSolver() throws {
        let lineup = try selector.select(request(squad(), overrides: [.ST_C: id("Playmaker")]))
        #expect(lineup.picks.filter { $0.player == id("Playmaker") }.count == 1)
        #expect(pick(lineup, .ST_C)?.player == id("Playmaker"))
        let amc = try #require(pick(lineup, .AM_C))
        #expect(amc.player != id("Playmaker"))
        #expect(!lineup.omissions.contains { $0.player == id("Playmaker") })
        #expect(Set(lineup.picks.map(\.player)).count == 11)
    }

    @Test func twoPlayersOverriddenIntoEachOthersSlotsAreBothPlaced() throws {
        let full = try selector.select(request(squad(), overrides: [.D_L: id("Right Back"), .D_R: id("Left Back")]))
        #expect(full.ignoredOverrides.isEmpty)
        #expect(pick(full, .D_L)?.player == id("Right Back"))
        #expect(pick(full, .D_R)?.player == id("Left Back"))
        #expect(pick(full, .D_L)?.isOverride == true && pick(full, .D_R)?.isOverride == true)
        #expect(Set(full.picks.map(\.player)).count == 11)
        #expect(full.picks.count == 11)

        // Ten players: an overridden full-back left among the candidates would also fill the empty ST_C.
        let short = try selector.select(request(squad().filter { $0.name != "Striker" },
                                                overrides: [.D_L: id("Right Back"), .D_R: id("Left Back")]))
        #expect(short.ignoredOverrides.isEmpty)
        #expect(short.picks.count == 10)
        #expect(Set(short.picks.map(\.player)).count == 10)
        #expect(short.unfilled == [.ST_C])
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
        // Below the floor, the Striker is not available, so the Cover Striker is the first choice among those who are.
        #expect(lineup.omissions.map(\.player) == [id("Cover Striker")])
        #expect(lineup.omissions.first?.cause == .displacedByOverride(by: [id("Striker")]))
        #expect(lineup.omissions.first?.reason == "Left out: you chose Striker for striker")
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

    @Test func anOverrideIntoASlotTheTacticDoesNotUseIsReported() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let lineup = try selector.select(request(squad(rival), overrides: [.M_C: id("Rival Striker")]))
        #expect(lineup.ignoredOverrides == [.M_C: .slotNotInTactic])
        #expect(lineup == (try selector.select(request(squad(rival)))).withIgnoredOverrides(lineup.ignoredOverrides))
    }

    @Test func anOverrideIntoAnUnusedSlotDoesNotCountAsASecondUse() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let lineup = try selector.select(request(squad(rival), overrides: [.M_C: id("Rival Striker"), .ST_C: id("Rival Striker")]))
        #expect(lineup.ignoredOverrides == [.M_C: .slotNotInTactic])
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.player == id("Rival Striker"))
        #expect(st.isOverride)
    }

    @Test func overrideProblemsAreCheckedInOrder() throws {
        // An unused slot is reported as such even for someone not in the squad.
        let unused = try selector.select(request(squad(), overrides: [.M_C: id("Nobody")]))
        #expect(unused.ignoredOverrides == [.M_C: .slotNotInTactic])

        // A player used twice is reported as used twice even when his exclusion cannot be overridden.
        let injured = changing("Striker", in: squad()) { $0.isInjured = true }
        let twice = try selector.select(request(injured, overrides: [.ST_C: id("Striker"), .AM_C: id("Striker")]))
        #expect(twice.ignoredOverrides == [.ST_C: .usedTwice, .AM_C: .usedTwice])
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

    @Test func aPairingWorthZeroStillFillsASlot() throws {
        // With the lowest familiarity step at factor 0, an outfielder in goal is worth exactly 0.
        var parameters = EngineParameters.fm27
        parameters.familiaritySteps = Parameter(
            parameters.familiaritySteps.value.dropLast() + [FamiliarityStep(minimum: 0, factor: 0)],
            .derived, source: "test: zero lowest familiarity step")
        let zeroing = LineupSelector(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.carriedOver(), parameters: parameters)
        let spareDefender = natural("Spare Defender", at: [.defenderCentral])
        let players = changing("Goalkeeper", in: squad(spareDefender)) { $0.isInjured = true }
        let lineup = try zeroing.select(request(players))
        let gk = try #require(pick(lineup, .GK))
        #expect(gk.rating.value == 0 && gk.value == 0)
        #expect(lineup.unfilled.isEmpty)
        #expect(lineup.picks.count == 11)
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

    // MARK: - Profiles

    @Test func theSelectorUsesTheProfileItIsGiven() throws {
        // Two strikers: one fast and a poor finisher, one slow and a fine finisher, otherwise equal.
        let fast = Player.fixture(name: "Fast Striker", attributes: [.pace: 17, .acceleration: 17, .finishing: 6, .composure: 6,
                                                                      .firstTouch: 6, .technique: 6],
                                  familiarity: [.striker: 20])
        let finisher = Player.fixture(name: "Finishing Striker", attributes: [.pace: 6, .acceleration: 6, .finishing: 17, .composure: 17,
                                                                               .firstTouch: 17, .technique: 17],
                                      familiarity: [.striker: 20])
        let players = squad(fast, finisher).filter { $0.name != "Striker" }
        let carried = try selector.select(request(players))
        let fm27 = try LineupSelector(catalog: RoleCatalog.fm27(), profile: RatingProfile.fm27EngineTests(), parameters: .fm27)
            .select(request(players))
        #expect(pick(carried, .ST_C)?.player == id("Finishing Striker"))
        #expect(pick(fm27, .ST_C)?.player == id("Fast Striker"))
        // The rest of the eleven is the same under both.
        for slot in carried.picks.map(\.slot) where slot != .ST_C {
            #expect(pick(carried, slot)?.player == pick(fm27, slot)?.player, "\(slot)")
        }
        #expect(pick(carried, .GK)?.rating != pick(fm27, .GK)?.rating)
    }

    @Test func missingPlayerDataThrows() throws {
        let players = changing("Striker", in: squad()) { $0.attributes = [:] }
        #expect(throws: RatingError.self) { try selector.select(request(players)) }
    }

    // MARK: - Adjustments

    /// `base` with the given adjustments for every slot and for single slots.
    func adjusted(_ base: SelectionRequest, every: [PlayerID: [Adjustment]] = [:],
                  slots: [PlayerID: [SlotID: [Adjustment]]] = [:], projected: Bool = false) -> SelectionRequest {
        var request = base
        request.adjustments = every
        request.slotAdjustments = slots
        request.fitnessIsProjected = projected
        return request
    }

    @Test func aRequestWithoutAdjustmentsGivesTheSameLineupAsBefore() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        var players = changing("Striker", in: squad(rival)) { $0.condition = 0.86 }
        players = changing("Playmaker", in: players) { $0.sharpness = 0.75; $0.jadedness = 300 }
        let base = request(players)
        let lineup = try selector.select(base)
        for pick in lineup.picks {
            #expect(pick.value == pick.rating.value * pick.fitness.product, "\(pick.slot)")
            #expect(pick.adjustments.isEmpty)
        }
        let playmaker = try #require(pick(lineup, .AM_C))
        #expect(Array(playmaker.reasons.dropFirst()) == ["Sharpness 75% (×0.92)", "Jadedness 300 (×0.90)"])
        // Empty lists, and adjustments for someone not in the squad, change nothing.
        #expect(try selector.select(adjusted(base, every: [id("Striker"): [], id("Nobody"): [Adjustment(kind: .development, factor: 0.5, reason: "x")]],
                                             slots: [id("Striker"): [.ST_C: []]])) == lineup)
    }

    @Test func aFactorBelowOneCanCostAPlayerHisPlace() throws {
        // The rival's rating is exactly 5% lower.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let base = request(squad(rival))
        try #require(pick(try selector.select(base), .ST_C)?.player == id("Striker"))
        let held = Adjustment(kind: .savedForLater, factor: 0.90, reason: "kept fresher for the cup final")
        let lineup = try selector.select(adjusted(base, every: [id("Striker"): [held]]))
        #expect(pick(lineup, .ST_C)?.player == id("Rival Striker"))
    }

    @Test func aFactorCloseToOneDoesNot() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let held = Adjustment(kind: .savedForLater, factor: 0.99, reason: "kept fresher for the cup final")
        let lineup = try selector.select(adjusted(request(squad(rival)), every: [id("Striker"): [held]]))
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.player == id("Striker"))
        #expect(st.value == st.rating.value * st.fitness.product * 0.99)
        #expect(st.adjustments == [held])
        #expect(lineup.omissions.isEmpty)
    }

    @Test func aCostIsSubtractedInRatingPoints() throws {
        let players = changing("Striker", in: squad()) { $0.condition = 0.90 }
        let cost = Adjustment(kind: .consecutiveStarts, cost: 2.5, reason: "a fourth start in a row")
        let lineup = try selector.select(adjusted(request(players), every: [id("Striker"): [cost]]))
        let st = try #require(lineup.picks.first { $0.player == id("Striker") })
        #expect(abs(st.value - (st.rating.value * st.fitness.product - 2.5)) < 1e-9)

        // A negative cost is a bonus.
        let bonus = Adjustment(kind: .needsSharpness, cost: -1.5, reason: "needs minutes for sharpness")
        let raised = try selector.select(adjusted(request(players), every: [id("Striker"): [bonus]]))
        let boosted = try #require(raised.picks.first { $0.player == id("Striker") })
        #expect(abs(boosted.value - (boosted.rating.value * boosted.fitness.product + 1.5)) < 1e-9)
    }

    @Test func aSlotAdjustmentAppliesOnlyInThatSlot() throws {
        let base = request(squad())
        let st = try #require(pick(try selector.select(base), .ST_C))
        let boost = Adjustment(kind: .development, factor: 1.5, reason: "learning the goalkeeper's role")

        let elsewhere = try #require(pick(try selector.select(adjusted(base, slots: [id("Striker"): [.GK: [boost]]])), .ST_C))
        #expect(elsewhere.player == id("Striker"))
        #expect(elsewhere.value == st.value)
        #expect(elsewhere.adjustments.isEmpty)
        #expect(elsewhere.reasons == st.reasons)

        let here = try #require(pick(try selector.select(adjusted(base, slots: [id("Striker"): [.ST_C: [boost]]])), .ST_C))
        #expect(here.value == st.value * 1.5)
        #expect(here.adjustments == [boost])
    }

    @Test func anAdjustmentNeverLeavesASlotEmpty() throws {
        // Eleven players for eleven slots: the only goalkeeper must play, however costly.
        let cost = Adjustment(kind: .savedForLater, cost: 1_000, reason: "kept back for the cup final")
        let lineup = try selector.select(adjusted(request(squad()), every: [id("Goalkeeper"): [cost]]))
        #expect(lineup.unfilled.isEmpty)
        #expect(lineup.picks.count == 11)
        let gk = try #require(pick(lineup, .GK))
        #expect(gk.player == id("Goalkeeper"))
        #expect(gk.value < 0)
        #expect(abs(gk.value - (gk.rating.value - 1_000)) < 1e-9)
    }

    @Test func adjustmentReasonsAppearOnThePickInKindOrder() throws {
        let players = changing("Striker", in: squad()) { $0.condition = 0.90 }
        let saved = Adjustment(kind: .savedForLater, reason: "kept fresher for the cup final")
        let loaned = Adjustment(kind: .loanedIn, reason: "on loan from Wallingford")
        let streak = Adjustment(kind: .consecutiveStarts, reason: "a fourth start in a row")
        let savedHere = Adjustment(kind: .savedForLater, reason: "kept back from striker duty")
        let chosen = adjusted(request(players, overrides: [.ST_C: id("Striker")]),
                              every: [id("Striker"): [saved, loaned]],
                              slots: [id("Striker"): [.ST_C: [savedHere, streak]]])
        let st = try #require(pick(try selector.select(chosen), .ST_C))
        #expect(st.adjustments == [loaned, streak, saved, savedHere])
        #expect(Array(st.reasons.dropFirst()) == [
            "Condition 90% (×0.94)",
            "on loan from Wallingford", "a fourth start in a row", "kept fresher for the cup final", "kept back from striker duty",
            "Chosen by you",
        ])
    }

    @Test func projectedFitnessIsLabelledAsProjected() throws {
        let players = changing("Striker", in: squad()) { $0.condition = 0.90; $0.sharpness = 0.75; $0.jadedness = 300 }
        let projected = try #require(pick(try selector.select(adjusted(request(players), projected: true)), .ST_C))
        #expect(Array(projected.reasons.dropFirst())
            == ["Projected condition 90% (×0.94)", "Projected sharpness 75% (×0.92)", "Projected jadedness 300 (×0.90)"])
        let today = try #require(pick(try selector.select(request(players)), .ST_C))
        #expect(Array(today.reasons.dropFirst()) == ["Condition 90% (×0.94)", "Sharpness 75% (×0.92)", "Jadedness 300 (×0.90)"])
        #expect(projected.value == today.value)
    }

    @Test func aProjectedFitnessExclusionSaysItIsProjected() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 10])
        let low = changing("Striker", in: squad(cover)) { $0.condition = 0.78 }
        let projected = try selector.select(adjusted(request(low), projected: true))
        #expect(projected.omissions.first?.cause == .excluded(.belowConditionFloor(0.78)))
        #expect(projected.omissions.first?.reason == "Left out: projected condition 78% is below the 85% floor")
        let chosen = try selector.select(adjusted(request(low, overrides: [.ST_C: id("Striker")]), projected: true))
        #expect(pick(chosen, .ST_C)?.reasons.last == "Chosen by you, overriding: projected condition 78% is below the 85% floor")

        let jaded = changing("Striker", in: squad(cover)) { $0.jadedness = 450 }
        let projectedJaded = try selector.select(adjusted(request(jaded), projected: true))
        #expect(projectedJaded.omissions.first?.reason == "Left out: projected jadedness 450 is above 400")
        let chosenJaded = try selector.select(adjusted(request(jaded, overrides: [.ST_C: id("Striker")]), projected: true))
        #expect(pick(chosenJaded, .ST_C)?.reasons.last == "Chosen by you, overriding: projected jadedness 450 is above 400")

        // Exclusions that are not projected read as they do today.
        let injured = try selector.select(adjusted(request(changing("Striker", in: squad(cover)) { $0.isInjured = true }), projected: true))
        #expect(injured.omissions.first?.reason == "Left out: injured")
        let banned = try selector.select(adjusted(request(changing("Striker", in: squad(cover)) { $0.isBanned = true }), projected: true))
        #expect(banned.omissions.first?.reason == "Left out: banned for this fixture")
        let rejected = try selector.select(adjusted(request(squad(cover), rejected: [id("Striker")]), projected: true))
        #expect(rejected.omissions.first?.reason == "Left out: rejected for this fixture")
    }

    @Test func aFitnessExclusionTodayReadsAsBefore() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 10])
        let low = changing("Striker", in: squad(cover)) { $0.condition = 0.78 }
        #expect(try selector.select(request(low)).omissions.first?.reason == "Left out: below the 85% condition floor at 78%")
        let chosen = try selector.select(request(low, overrides: [.ST_C: id("Striker")]))
        #expect(pick(chosen, .ST_C)?.reasons.last == "Chosen by you, overriding: condition 78% is below the 85% floor")
        let jaded = changing("Striker", in: squad(cover)) { $0.jadedness = 450 }
        #expect(try selector.select(request(jaded)).omissions.first?.reason == "Left out: jadedness 450 is above 400")
    }

    @Test func aProjectedFitnessOmissionSaysItIsProjected() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        for change in [{ (p: inout Player) in p.condition = 0.86 }, { (p: inout Player) in p.condition = 0.86; p.sharpness = 0.75 }] {
            let players = changing("Striker", in: squad(rival), change)
            let today = try #require(try selector.select(request(players)).omissions.first)
            let projected = try #require(try selector.select(adjusted(request(players), projected: true)).omissions.first)
            #expect(today.reason.hasPrefix("Left out: condition 86%") || today.reason.hasPrefix("Left out: fitness lowers"))
            #expect(projected.cause == today.cause)
            #expect(projected.reason == today.reason.replacingOccurrences(of: "Left out: ", with: "Left out: projected "))
        }
    }

    @Test func anIdealPlayerLeftOutByAnAdjustmentSaysWhy() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let held = Adjustment(kind: .savedForLater, factor: 0.90, reason: "kept fresher for the cup final")
        let base = request(squad(rival))
        let lineup = try selector.select(adjusted(base, every: [id("Striker"): [held]]))
        let omission = try #require(lineup.omissions.first)
        #expect(lineup.omissions.count == 1)
        #expect(omission.player == id("Striker") && omission.slot == .ST_C)
        #expect(omission.cause == .heldBack([.savedForLater]))
        #expect(omission.reason == "Left out: kept fresher for the cup final")

        // Several, in Kind order; one that neither scales him down nor costs him is not named.
        let streak = Adjustment(kind: .consecutiveStarts, cost: 5, reason: "a fourth start in a row")
        let neutral = Adjustment(kind: .loanedIn, reason: "on loan from Wallingford")
        let several = try selector.select(adjusted(base, every: [id("Striker"): [held, neutral]], slots: [id("Striker"): [.ST_C: [streak]]]))
        #expect(several.omissions.first?.cause == .heldBack([.consecutiveStarts, .savedForLater]))
        #expect(several.omissions.first?.reason == "Left out: a fourth start in a row; kept fresher for the cup final")

        // An adjustment in another slot does not explain his omission from his ideal slot.
        let tired = changing("Striker", in: squad(rival)) { $0.condition = 0.86 }
        let otherSlot = try selector.select(adjusted(request(tired), slots: [id("Striker"): [.GK: [held]]]))
        guard case .lowerMatchDayValue = otherSlot.omissions.first?.cause else {
            Issue.record("expected lowerMatchDayValue, got \(String(describing: otherSlot.omissions.first?.cause))"); return
        }
        // An exclusion keeps its cause.
        let injured = try selector.select(adjusted(request(changing("Striker", in: squad(rival)) { $0.isInjured = true }),
                                                   every: [id("Striker"): [held]]))
        #expect(injured.omissions.first?.cause == .excluded(.injured))
        // So does a displacement by an override.
        let overridden = try selector.select(adjusted(request(squad(rival), overrides: [.ST_C: id("Rival Striker")]),
                                                      every: [id("Striker"): [Adjustment(kind: .savedForLater, factor: 0.99, reason: "x")]]))
        #expect(overridden.omissions.first?.cause == .displacedByOverride(by: [id("Rival Striker")]))
    }

    // MARK: - The cause that would bring him back

    let development = Adjustment(kind: .development, factor: 1.10, reason: "Young player with room to grow: favoured for minutes (×1.10)")

    @Test func aRivalsFavourNotHisOwnRunIsNamedWhenOnlyTheFavourDecides() throws {
        // Striker 90.0 × 0.97 = 87.3; the rival 85.5 × 1.10 = 94.1. Without the run he is still out (90.0); without the
        // rival's favour he starts.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let run = Adjustment(kind: .consecutiveStarts, factor: 0.97, reason: "Has started the last 3 matches in quick succession (×0.97)")
        let lineup = try selector.select(adjusted(request(squad(rival)), every: [id("Striker"): [run], id("Rival Striker"): [development]]))
        let omission = try #require(lineup.omissions.first)
        #expect(lineup.omissions.count == 1 && omission.player == id("Striker") && omission.slot == .ST_C)
        #expect(omission.cause == .preferred(by: [id("Rival Striker")], [.development]))
        #expect(omission.reason == "Left out: Rival Striker is preferred: Young player with room to grow: favoured for minutes (×1.10)")
    }

    @Test func hisFitnessNotARivalsFavourIsNamedWhenAThirdPlayerWouldTakeTheSlot() throws {
        // No Playmaker. Quinn (ST 13, AM (C) 20) is favoured ×1.14 at ST_C only; Reed (15 at both) is next. Without Quinn's
        // favour Reed takes ST_C and the Striker, at 90% condition, is still out; at full condition he starts.
        let quinn = Player.fixture(name: "Quinn", familiarity: [.striker: 13, .attackingMidCentral: 20])
        let reed = Player.fixture(name: "Reed", familiarity: [.striker: 15, .attackingMidCentral: 15])
        let players = changing("Striker", in: squad(quinn, reed).filter { $0.name != "Playmaker" }) { $0.condition = 0.90 }
        let favour = Adjustment(kind: .needsSharpness, factor: 1.14, reason: "Needs minutes: sharpness 72% (×1.14)")
        let lineup = try selector.select(adjusted(request(players), slots: [id("Quinn"): [.ST_C: [favour]]]))
        #expect(pick(lineup, .ST_C)?.player == id("Quinn") && pick(lineup, .AM_C)?.player == id("Reed"))
        let omission = try #require(lineup.omissions.first { $0.player == id("Striker") })
        guard case .lowerMatchDayValue(let ideal, let today, .condition) = omission.cause else {
            Issue.record("expected lowerMatchDayValue, got \(omission.cause)"); return
        }
        #expect(omission.reason == "Left out: condition 90% lowers him from \(oneDecimal(ideal)) to \(oneDecimal(today))")
    }

    @Test func aCostThatDecidesIsNamed() throws {
        // 90.0 − 5 = 85.0, below the rival's 85.5.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let cost = Adjustment(kind: .savedForLater, cost: 5, reason: "Kept fresher for Wealdstone")
        let omission = try #require(try selector.select(adjusted(request(squad(rival)), every: [id("Striker"): [cost]])).omissions.first)
        #expect(omission.cause == .heldBack([.savedForLater]))
        #expect(omission.reason == "Left out: Kept fresher for Wealdstone")
    }

    @Test func aCostUnderOnePointBesideALargerOneIsNotNamed() throws {
        // 90.0 − 5.3 = 84.7, below the rival's 85.5.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let small = Adjustment(kind: .consecutiveStarts, cost: 0.3, reason: "a little tired")
        let large = Adjustment(kind: .savedForLater, cost: 5, reason: "Kept fresher for Wealdstone")
        let omission = try #require(try selector.select(adjusted(request(squad(rival)), every: [id("Striker"): [small, large]])).omissions.first)
        #expect(omission.cause == .heldBack([.savedForLater]))
        #expect(omission.reason == "Left out: Kept fresher for Wealdstone")
    }

    @Test func aCostUnderOnePointThatAloneDecidesIsNamed() throws {
        // The rival rates about 0.16 below the Striker (Vision 9): 90.0 − 0.3 falls below him.
        let close = Player.fixture(name: "Close Striker", attributes: [.vision: 9], familiarity: [.striker: 20])
        let small = Adjustment(kind: .consecutiveStarts, cost: 0.3, reason: "a little tired")
        try #require(pick(try selector.select(request(squad(close))), .ST_C)?.player == id("Striker"))
        let omission = try #require(try selector.select(adjusted(request(squad(close)), every: [id("Striker"): [small]])).omissions.first)
        #expect(omission.cause == .heldBack([.consecutiveStarts]))
        #expect(omission.reason == "Left out: a little tired")
    }

    @Test func heldBackAndUnfitAreBothNamedWhenOnlyBothTogetherDecide() throws {
        // 90.0 × 0.94 − 5 = 79.6 against the rival's 85.5. Without the cost 84.6; at full fitness 85.0; without both 90.0.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let cost = Adjustment(kind: .savedForLater, cost: 5, reason: "Kept fresher for Wealdstone")
        let players = changing("Striker", in: squad(rival)) { $0.condition = 0.90 }
        let omission = try #require(try selector.select(adjusted(request(players), every: [id("Striker"): [cost]])).omissions.first)
        let rating = try #require(pick(try selector.select(request(changing("Striker", in: squad(rival)) { _ in })), .ST_C)).rating.value
        #expect(omission.cause == .heldBack([.savedForLater]))
        #expect(omission.reason
            == "Left out: Kept fresher for Wealdstone; condition 90% lowers him from \(oneDecimal(rating)) to \(oneDecimal(rating * 0.94))")
        // Projected, the fitness phrase says so, with no second "Left out: ".
        let projected = try #require(try selector.select(adjusted(request(players), every: [id("Striker"): [cost]], projected: true)).omissions.first)
        #expect(projected.reason
            == "Left out: Kept fresher for Wealdstone; projected condition 90% lowers him from \(oneDecimal(rating)) to \(oneDecimal(rating * 0.94))")
    }

    @Test func heldBackAndARivalsFavourAreBothNamedWhenOnlyBothTogetherDecide() throws {
        // Striker 90.0 × 0.80 = 72.0; the rival 85.5 × 1.10 = 94.1. Without his ×0.80, 90.0 still loses to 94.1; without the
        // rival's favour, 72.0 still loses to 85.5; without both he starts.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let sharp = Adjustment(kind: .needsSharpness, factor: 0.80, reason: "Already sharp: others need the minutes more (×0.80)")
        let omission = try #require(try selector.select(adjusted(request(squad(rival)),
                                                                 every: [id("Striker"): [sharp], id("Rival Striker"): [development]])).omissions.first)
        #expect(omission.cause == .heldBack([.needsSharpness]))
        #expect(omission.reason == "Left out: Already sharp: others need the minutes more (×0.80); "
            + "Rival Striker is preferred: Young player with room to grow: favoured for minutes (×1.10)")
    }

    @Test func twoFavouredRivalsEachNameOnlyTheRegularTheyDisplaced() throws {
        let rivalStriker = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let rivalPlaymaker = Player.fixture(name: "Rival Playmaker", familiarity: [.attackingMidCentral: 17])
        let lineup = try selector.select(adjusted(request(squad(rivalStriker, rivalPlaymaker)),
                                                  every: [id("Rival Striker"): [development], id("Rival Playmaker"): [development]]))
        let striker = try #require(lineup.omissions.first { $0.player == id("Striker") })
        #expect(striker.cause == .preferred(by: [id("Rival Striker")], [.development]))
        #expect(striker.reason == "Left out: Rival Striker is preferred: Young player with room to grow: favoured for minutes (×1.10)")
        let playmaker = try #require(lineup.omissions.first { $0.player == id("Playmaker") })
        #expect(playmaker.cause == .preferred(by: [id("Rival Playmaker")], [.development]))
        #expect(playmaker.reason == "Left out: Rival Playmaker is preferred: Young player with room to grow: favoured for minutes (×1.10)")
    }

    @Test func favouredPlayersAlongOneChainAreNamedInChainOrder() throws {
        // No Playmaker. Versatile (ST 17, AM (C) 20) is favoured at ST_C and holds it; Apprentice (AM (C) 17) is favoured
        // at AM_C and holds it. Without the favours the Striker takes ST_C, Versatile moves to AM_C and Apprentice drops out.
        let versatile = Player.fixture(name: "Versatile", familiarity: [.striker: 17, .attackingMidCentral: 20])
        let apprentice = Player.fixture(name: "Apprentice", familiarity: [.attackingMidCentral: 17])
        let players = squad(versatile, apprentice).filter { $0.name != "Playmaker" }
        let retraining = Adjustment(kind: .retraining, factor: 1.10, reason: "favoured up front")
        let lineup = try selector.select(adjusted(request(players), slots: [id("Versatile"): [.ST_C: [retraining]],
                                                                         id("Apprentice"): [.AM_C: [development]]]))
        #expect(pick(lineup, .ST_C)?.player == id("Versatile") && pick(lineup, .AM_C)?.player == id("Apprentice"))
        let omission = try #require(lineup.omissions.first { $0.player == id("Striker") })
        #expect(omission.cause == .preferred(by: [id("Versatile"), id("Apprentice")], [.development, .retraining]))
        #expect(omission.reason == "Left out: Versatile is preferred: favoured up front. "
            + "Apprentice is preferred: Young player with room to grow: favoured for minutes (×1.10)")
    }

    @Test func withNoAdjustmentsTheCausesAndReasonsAreTodays() throws {
        // Condition: only full fitness brings him back. Sharpness and condition together: the same, named together.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let tired = try #require(try selector.select(request(changing("Striker", in: squad(rival)) { $0.condition = 0.86 })).omissions.first)
        guard case .lowerMatchDayValue(let ideal, let today, .condition) = tired.cause else {
            Issue.record("expected lowerMatchDayValue, got \(tired.cause)"); return
        }
        #expect(tired.reason == "Left out: condition 86% lowers him from \(oneDecimal(ideal)) to \(oneDecimal(today))")
        let both = try #require(try selector.select(request(changing("Striker", in: squad(rival)) {
            $0.condition = 0.90; $0.sharpness = 0.50
        })).omissions.first)
        guard case .lowerMatchDayValue(let ideal2, let today2, .sharpness) = both.cause else {
            Issue.record("expected lowerMatchDayValue, got \(both.cause)"); return
        }
        #expect(both.reason == "Left out: fitness lowers him from \(oneDecimal(ideal2)) to \(oneDecimal(today2)) (condition 90%, sharpness 50%)")
        // Empty adjustment tables are the same as none.
        let players = changing("Striker", in: squad(rival)) { $0.condition = 0.86 }
        #expect(try selector.select(adjusted(request(players), every: [:], slots: [:])) == (try selector.select(request(players))))
    }

    @Test func theMinimumLossIsListedWithEvidenceAndSource() {
        let m = EngineParameters.fm27.omissionReasonMinimumLoss
        #expect(m.value == 1.0)
        #expect(m.evidence == .derived)
        #expect(m.source == "an adjustment that costs a player less than one rating point is not given as the reason he was left out")
    }

    // MARK: - The best available eleven

    @Test func aFirstChoiceAmongTheAvailablePlayersWhoIsLeftOutSaysWhy() throws {
        // The injured Star Playmaker holds AM_C in the ideal eleven. Among the players who can play, the Playmaker is
        // first choice there, ahead of the Cover Playmaker.
        let star = natural("Star Playmaker", at: [.attackingMidCentral], all: 14)
        let cover = natural("Cover Playmaker", at: [.attackingMidCentral], all: 8)
        let players = changing("Star Playmaker", in: squad(star, cover)) { $0.isInjured = true }
        try #require(pick(try selector.select(request(players)), .AM_C)?.player == id("Playmaker"))

        let held = Adjustment(kind: .savedForLater, factor: 0.50, reason: "kept fresher for the cup final")
        let lineup = try selector.select(adjusted(request(players), every: [id("Playmaker"): [held]]))
        #expect(pick(lineup, .AM_C)?.player == id("Cover Playmaker"))
        try #require(lineup.omissions.map(\.player) == [id("Star Playmaker"), id("Playmaker")])
        let injured = lineup.omissions[0]
        #expect(injured.slot == .AM_C)
        #expect(injured.cause == .excluded(.injured))
        #expect(injured.reason == "Left out: injured")
        let firstChoice = lineup.omissions[1]
        #expect(firstChoice.slot == .AM_C)
        #expect(firstChoice.cause == .heldBack([.savedForLater]))
        #expect(firstChoice.reason == "Left out: kept fresher for the cup final")

        // The ideal eleven's omissions come first, in slot order, then the available eleven's.
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let both = try selector.select(adjusted(request(players + [rival]), every: [id("Playmaker"): [held], id("Striker"): [held]]))
        #expect(both.omissions.map(\.player) == [id("Star Playmaker"), id("Striker"), id("Playmaker")])
        #expect(both.omissions.map(\.slot) == [.AM_C, .ST_C, .AM_C])

        // The cause is worked out as for the ideal eleven: here, the manager's choice for his slot.
        let chosen = try selector.select(request(players, overrides: [.AM_C: id("Cover Playmaker")]))
        let displaced = try #require(chosen.omissions.first { $0.player == id("Playmaker") })
        #expect(chosen.omissions.map(\.player) == [id("Star Playmaker"), id("Playmaker")])
        #expect(displaced.slot == .AM_C)
        #expect(displaced.cause == .displacedByOverride(by: [id("Cover Playmaker")]))
        #expect(displaced.reason == "Left out: you chose Cover Playmaker for central attacking midfield")
    }

    @Test func withNobodyExcludedTheOmissionsAreAsBefore() throws {
        // Nobody is excluded (a player out on loan is in neither eleven), so the available eleven is the ideal one:
        // the Playmaker, second choice behind the held-back Star Playmaker, is not listed although he is held back too.
        let star = natural("Star Playmaker", at: [.attackingMidCentral], all: 14)
        let cover = natural("Cover Playmaker", at: [.attackingMidCentral], all: 8)
        let away = Player.fixture(name: "Away Playmaker", all: 15, familiarity: [.attackingMidCentral: 20], loanedTo: "Wallingford")
        let held = Adjustment(kind: .savedForLater, factor: 0.50, reason: "kept fresher for the cup final")
        let lineup = try selector.select(adjusted(request(squad(star, cover, away)),
                                                  every: [id("Star Playmaker"): [held], id("Playmaker"): [held]]))
        #expect(pick(lineup, .AM_C)?.player == id("Cover Playmaker"))
        #expect(lineup.omissions.map(\.player) == [id("Star Playmaker")])
        #expect(lineup.omissions.first?.cause == .heldBack([.savedForLater]))

        // A fit squad with no adjustments has no omissions.
        #expect(try selector.select(request(squad(star, cover, away))).omissions.isEmpty)
    }

    @Test func aPlayerIsNeverListedTwice() throws {
        // Ideal: Playmaker at AM_C, Versatile at ST_C. With the Playmaker injured, the available eleven moves Versatile
        // to AM_C. Held back, he plays nowhere, and is listed once, for his slot in the ideal eleven.
        let versatile = Player.fixture(name: "Versatile", all: 12, familiarity: [.striker: 20, .attackingMidCentral: 20])
        var players = squad().filter { $0.name != "Striker" && $0.name != "Playmaker" }
        players += [natural("Playmaker", at: [.attackingMidCentral], all: 14), versatile,
                    natural("Backup Striker", at: [.striker], all: 10), natural("Cover Playmaker", at: [.attackingMidCentral], all: 8)]
        try #require(pick(try selector.select(request(players)), .ST_C)?.player == id("Versatile"))
        let injured = changing("Playmaker", in: players) { $0.isInjured = true }
        try #require(pick(try selector.select(request(injured)), .AM_C)?.player == id("Versatile"))

        let held = Adjustment(kind: .savedForLater, factor: 0.50, reason: "kept fresher for the cup final")
        let lineup = try selector.select(adjusted(request(injured), every: [id("Versatile"): [held]]))
        #expect(!picked(lineup, "Versatile"))
        #expect(lineup.omissions.map(\.player) == [id("Playmaker"), id("Versatile")])
        #expect(lineup.omissions.map(\.slot) == [.AM_C, .ST_C])
        #expect(lineup.omissions.last?.cause == .heldBack([.savedForLater]))
    }

    @Test func anOverrideBeatsAnAdjustment() throws {
        let rival = Player.fixture(name: "Rival Striker", familiarity: [.striker: 17])
        let held = Adjustment(kind: .savedForLater, cost: 1_000, reason: "kept back for the cup final")
        let base = adjusted(request(squad(rival)), every: [id("Striker"): [held]])
        try #require(pick(try selector.select(base), .ST_C)?.player == id("Rival Striker"))

        var chosen = base
        chosen.overrides = [.ST_C: id("Striker")]
        let lineup = try selector.select(chosen)
        let st = try #require(pick(lineup, .ST_C))
        #expect(st.player == id("Striker"))
        #expect(st.isOverride)
        #expect(st.adjustments == [held])
        #expect(st.value < 0)
        #expect(Array(st.reasons.suffix(2)) == ["kept back for the cup final", "Chosen by you"])
        #expect(lineup.omissions.isEmpty)
    }
}

private extension Lineup {
    func withIgnoredOverrides(_ ignored: [SlotID: OverrideProblem]) -> Lineup {
        Lineup(picks: picks, unfilled: unfilled, omissions: omissions, ignoredOverrides: ignored)
    }
}
