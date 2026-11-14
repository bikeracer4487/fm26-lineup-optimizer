import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@Suite struct InitialsTests {
    @Test func initialsAreTheFirstNameAndTheSurnameLetters() {
        #expect(BoardText.initials("Evan Humphries") == "EH")
        #expect(BoardText.initials("Evan Peter Humphries") == "EH")
    }

    @Test func aSurnameWithParticlesGivesTheLetterOfItsMainWord() {
        #expect(BoardText.initials("Dillon De Silva") == "DS")
        #expect(BoardText.initials("Kauan Bitencourt de Oliveira") == "KO")
        #expect(BoardText.initials("Jan van der Berg") == "JB")
    }

    @Test func aOneWordNameGivesOneLetter() {
        #expect(BoardText.initials("Ronaldinho") == "R")
        #expect(BoardText.initials("  ") == "")
    }

    @Test func lettersAreCapitals() {
        #expect(BoardText.initials("ángel di maría") == "ÁM")
    }
}

@Suite struct PitchLineTests {
    @Test func eachOfTheFourteenPositionsBelongsToALine() {
        let expected: [Position: PitchLine] = [
            .goalkeeper: .goalkeeper,
            .defenderLeft: .defence, .defenderCentral: .defence, .defenderRight: .defence,
            .wingBackLeft: .defence, .wingBackRight: .defence,
            .defensiveMidfielder: .midfield,
            .midfielderLeft: .midfield, .midfielderCentral: .midfield, .midfielderRight: .midfield,
            .attackingMidLeft: .attack, .attackingMidCentral: .attack, .attackingMidRight: .attack,
            .striker: .attack,
        ]
        #expect(expected.count == Position.allCases.count)
        for position in Position.allCases {
            #expect(PitchLine(position) == expected[position], "\(position)")
        }
    }

    @Test func aSlotIsInTheLineOfItsPosition() {
        #expect(PitchLine(SlotID.GK) == .goalkeeper)
        #expect(PitchLine(SlotID.WB_R) == .defence)
        #expect(PitchLine(SlotID.DM_C) == .midfield)
        #expect(PitchLine(SlotID.AM_CL) == .attack)
    }

    @Test func aPlayersLineIsThatOfThePositionHeKnowsBest() {
        #expect(PitchLine.main(familiarity: [.defenderCentral: 15, .defensiveMidfielder: 20, .striker: 1]) == .midfield)
        #expect(PitchLine.main(familiarity: [.goalkeeper: 20, .striker: 2]) == .goalkeeper)
    }

    /// Two positions known as well: the one listed first in the engine's order, so the line never depends on
    /// dictionary order.
    @Test func aTieGoesToThePositionListedFirst() {
        #expect(PitchLine.main(familiarity: [.defensiveMidfielder: 20, .defenderCentral: 20]) == .defence)
        #expect(PitchLine.main(familiarity: [.striker: 18, .attackingMidLeft: 18, .midfielderLeft: 18]) == .midfield)
    }

    @Test func noFamiliarityGivesNoLine() {
        #expect(PitchLine.main(familiarity: [:]) == nil)
    }
}

@Suite struct MeterTests {
    @Test func blocksLightOneForEachTwentyFromTen() {
        #expect(Meter(percent: 100).lit == 5)
        #expect(Meter(percent: 85).lit == 4)
        #expect(Meter(percent: 84).lit == 4)
        #expect(Meter(percent: 70).lit == 4)
        #expect(Meter(percent: 69).lit == 3)
        #expect(Meter(percent: 54).lit == 3)
        #expect(Meter(percent: 9).lit == 0)
        #expect(Meter(percent: 0).lit == 0)
        #expect(Meter(percent: 10).lit == 1)
    }

    @Test func theLevelIsGoodFromEightyFiveMiddlingFromSeventyElsePoor() {
        #expect(Meter.goodFrom == 85)
        #expect(Meter.middlingFrom == 70)
        #expect(Meter(percent: 100).level == .good)
        #expect(Meter(percent: 85).level == .good)
        #expect(Meter(percent: 84).level == .middling)
        #expect(Meter(percent: 70).level == .middling)
        #expect(Meter(percent: 69).level == .poor)
        #expect(Meter(percent: 54).level == .poor)
        #expect(Meter(percent: 9).level == .poor)
        #expect(Meter(percent: 0).level == .poor)
    }

    @Test func eachBlockIsLitOrNot() {
        let meter = Meter(percent: 54)
        #expect((0..<Meter.blocks).map(meter.isLit) == [true, true, true, false, false])
    }

    /// A fraction is read as the percentage the table writes beside the meter: rounded down.
    @Test func aFractionGoesByItsWholePercentage() {
        #expect(Meter(fraction: 0.849) == Meter(percent: 84))
        #expect(Meter(fraction: 0.84) == Meter(percent: 84))
        #expect(Meter(fraction: 1) == Meter(percent: 100))
    }
}

@Suite struct ReasonDirectionTests {
    @Test func aFactorAboveOneRaisesBelowOneLowersAndOneDoesNothing() {
        #expect(ReasonDirection(factor: 1.45, cost: 0) == .raised)
        #expect(ReasonDirection(factor: 0.9, cost: 0) == .lowered)
        #expect(ReasonDirection(factor: 1, cost: 0) == .unchanged)
    }

    @Test func aCostLowersAndABonusRaises() {
        #expect(ReasonDirection(factor: 1, cost: 6.5) == .lowered)
        #expect(ReasonDirection(factor: 1, cost: -2) == .raised)
    }

    /// One part raising and the other lowering: what it did to the value is not plain from the reason, so it gets
    /// no sign.
    @Test func aFactorAndACostPullingapartAreUnchanged() {
        #expect(ReasonDirection(factor: 1.2, cost: 3) == .unchanged)
    }

    @Test func aFitnessLineGoesByItsFactor() {
        #expect(ReasonDirection(fitnessFactor: 0.8) == .lowered)
        #expect(ReasonDirection(fitnessFactor: 1) == .unchanged)
    }

    @Test func aPicksReasonsAreMarkedInTheOrderTheEngineWritesThem() {
        let adjustments = [
            Adjustment(kind: .consecutiveStarts, factor: 0.9, reason: "Has started the last 2 matches (×0.90)"),
            Adjustment(kind: .needsSharpness, factor: 1.45, reason: "Needs minutes (×1.45)"),
            Adjustment(kind: .savedForLater, cost: 4, reason: "Saved for a bigger match"),
        ]
        let reasons = ["Rating 106.9: …", "Projected sharpness 54% (×0.80)"] + adjustments.map(\.reason) + ["Chosen by you"]
        let marked = MarkedReason.marks(reasons: reasons,
                                        fitness: FitnessFactors(condition: 1, sharpness: 0.8, jadedness: 1),
                                        adjustments: adjustments)
        #expect(marked.map(\.text) == reasons)
        #expect(marked.map(\.direction) == [.unchanged, .lowered, .lowered, .raised, .lowered, .unchanged])
    }

    @Test func everyFitnessLineBelowOneIsLowered() {
        let reasons = ["Rating 100.0: …", "Condition 80% (×0.90)", "Sharpness 60% (×0.85)", "Jadedness 300 (×0.95)"]
        let marked = MarkedReason.marks(reasons: reasons,
                                        fitness: FitnessFactors(condition: 0.9, sharpness: 0.85, jadedness: 0.95),
                                        adjustments: [])
        #expect(marked.map(\.direction) == [.unchanged, .lowered, .lowered, .lowered])
    }

    @Test func aPickWithOnlyHisRatingHasNoSign() {
        let marked = MarkedReason.marks(reasons: ["Rating 100.0: …"],
                                        fitness: FitnessFactors(condition: 1, sharpness: 1, jadedness: 1), adjustments: [])
        #expect(marked == [MarkedReason(text: "Rating 100.0: …", direction: .unchanged)])
    }
}

@Suite struct NoteTiltTests {
    @Test func aTiltRepeatsForTheSamePlace() {
        for index in 0..<12 {
            #expect(NoteTilt.degrees(at: index) == NoteTilt.degrees(at: index))
        }
    }

    @Test func neighboursTiltDifferently() {
        for index in 0..<20 {
            #expect(NoteTilt.degrees(at: index) != NoteTilt.degrees(at: index + 1))
        }
    }

    @Test func everyTiltIsBetweenHalfADegreeAndOneAndAHalf() {
        for index in 0..<20 {
            #expect((0.5...1.5).contains(abs(NoteTilt.degrees(at: index))))
        }
    }
}

@Suite struct BoardWordsTests {
    @Test func theBoardIsTitledWithTheClubElseTheAppsName() {
        #expect(BoardText.boardTitle(ownClub: "Oxford City") == "Oxford City")
        #expect(BoardText.boardTitle(ownClub: nil) == "Lineup Optimizer")
    }

    @Test func aFixtureNoteNamesItsImportance() {
        #expect(Importance.low.noteText == "Low importance")
        #expect(Importance.medium.noteText == "Medium importance")
        #expect(Importance.high.noteText == "High importance")
        #expect(Importance.sharpness.noteText == "Sharpness match")
    }

    @Test func theDateNoteWritesTheDayWithItsYear() {
        #expect(DayText.shortWithYear(Day(year: 2026, month: 11, day: 13)!) == "Fri 13 Nov 2026")
    }

    @Test func aMissingTypefaceIsNamedOnceInANotice() {
        #expect(BoardText.fontNotice(missing: []) == nil)
        #expect(BoardText.fontNotice(missing: ["Figtree"])
                == "The typeface Figtree could not be loaded, so the system typeface is used in its place.")
        #expect(BoardText.fontNotice(missing: ["Bricolage Grotesque", "Figtree"])
                == "The typefaces Bricolage Grotesque and Figtree could not be loaded, so the system typeface is used in their place.")
    }

    @Test func aStatusIsAStampInSentenceCase() {
        let stamps = PlayerStatus.stamps([.outOnLoan(to: "Banbury United"), .injured, .outOfContract])
        #expect(stamps == [StatusStamp(text: "Out on loan to Banbury United", isOut: true),
                           StatusStamp(text: "Injured", isOut: true),
                           StatusStamp(text: "Out of contract", isOut: false)])
        #expect(PlayerStatus.stamps([]) == [])
        #expect(PlayerStatus.stamps([.onLoan(from: nil), .banned])
                == [StatusStamp(text: "On loan", isOut: false), StatusStamp(text: "Banned", isOut: true)])
    }
}

@Suite struct SquadColumnSortTests {
    @Test func choosingAColumnSortsByItAscending() {
        let sort = SquadSort().choosing(.age)
        #expect(sort == SquadSort(column: .age, ascending: true))
        #expect(sort.comparators.count == 1)
    }

    @Test func choosingTheSameColumnAgainTurnsItRound() {
        let sort = SquadSort().choosing(.age).choosing(.age)
        #expect(sort == SquadSort(column: .age, ascending: false))
        #expect(sort.choosing(.age) == SquadSort(column: .age, ascending: true))
    }

    @Test func choosingAnotherColumnStartsAscending() {
        #expect(SquadSort(column: .age, ascending: false).choosing(.name) == SquadSort(column: .name, ascending: true))
    }

    @Test func noColumnChosenKeepsTheRowsAsGiven() {
        #expect(SquadSort().comparators.isEmpty)
    }

    @Test func eachColumnHasItsHeading() {
        #expect(SquadColumn.allCases.map(\.title) == ["Name", "Squad", "Age", "Position", "Ability now and potential",
                                                       "Condition", "Sharpness", "Jadedness", "Status"])
    }

    @Test func aColumnSortsTheRowsByItsValue() {
        func player(_ name: String, age: Int, ability: Int) -> Player {
            Player(id: PlayerID(key: name), name: name, squad: .firstTeam, age: age, positionsText: "D C",
                   currentAbility: ability, potentialAbility: 100, attributes: [:], familiarity: [.defenderCentral: 20],
                   condition: 1, sharpness: 1, jadedness: 0, isInjured: false, isBanned: false, club: nil, loanedTo: nil,
                   contractType: .fullTime, monthsLeft: 10, wagePerWeek: 1, askingPrice: nil, nationalities: [], extras: [:])
        }
        let rows = [SquadRow(player("Ann", age: 30, ability: 50), loan: .own),
                    SquadRow(player("Bea", age: 20, ability: 70), loan: .own)]
        #expect(SquadRow.sorted(rows, using: SquadSort().choosing(.age).comparators).map(\.name) == ["Bea", "Ann"])
        #expect(SquadRow.sorted(rows, using: SquadSort(column: .ability, ascending: false).comparators).map(\.name)
                == ["Bea", "Ann"])
        #expect(rows[0].line == .defence)
        #expect(rows[0].conditionMeter == Meter(percent: 100))
    }
}

@MainActor @Suite struct BoardModelTests {
    @Test func theModelsBoardTitleIsItsClub() throws {
        let t = try TestModel()
        #expect(t.model.boardTitle == "Lineup Optimizer")
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        #expect(t.model.boardTitle == "Oxford City")
    }

    @Test func aNoticeCanBeAddedFromOutsideTheModel() throws {
        let t = try TestModel()
        let before = t.model.notices.count
        t.model.addNotice("A typeface could not be loaded.")
        #expect(t.model.notices.count == before + 1)
        #expect(t.model.notices.last?.text == "A typeface could not be loaded.")
    }

    @Test func aTokenCarriesItsInitialsAndLine() throws {
        let model = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        guard case .ready(let plans) = model.planState, let plan = plans.first else {
            Issue.record("no plan"); return
        }
        let tokens = model.tokens(for: plan)
        #expect(!tokens.isEmpty)
        for token in tokens {
            #expect(token.initials == BoardText.initials(token.name))
            #expect(token.line == PitchLine(token.slot))
        }
    }

    @Test func aPicksDetailMarksEachReasonAndSaysWhichFactorsLower() throws {
        let model = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        guard case .ready(let plans) = model.planState, let plan = plans.first,
              case .planned(let lineup, _) = plan.body else {
            Issue.record("no plan"); return
        }
        for pick in lineup.picks {
            let detail = try #require(model.pickDetail(at: pick.slot, in: plan))
            #expect(detail.markedReasons == MarkedReason.marks(reasons: pick.reasons, fitness: pick.fitness,
                                                               adjustments: pick.adjustments))
            #expect(detail.cards.map(\.label).count == 4)
            #expect(detail.valueText == MatchText.oneDecimal(pick.value))
            #expect(detail.cards[2].direction == ReasonDirection(fitnessFactor: pick.fitness.sharpness))
            #expect(detail.cards[0].direction == .unchanged)
            #expect(detail.positionLine == "\(detail.slotText), \(detail.squadText)")
            #expect(detail.valueLabel == "Match-day value \(detail.valueText)")
        }
    }
}

@Suite struct BoardWordsFromCoreTests {
    @Test func aFactorOfOneIsUnchangedNotGood() {
        #expect(ReasonDirection(fitnessFactor: 1) == .unchanged)
        let figure = PickFigure(label: "Condition", figure: "100%", factor: "×1.00", direction: .unchanged)
        #expect(figure.direction == .unchanged)
        #expect(PickFigure(label: "Rating", figure: "106.9", factor: nil).direction == .unchanged)
    }

    @Test func negativeNumbersHaveATrueMinusSign() {
        #expect(BoardText.signed(-168) == "\u{2212}168")
        #expect(BoardText.signed(0) == "0")
        #expect(BoardText.signed(12) == "12")
        #expect(MatchText.oneDecimal(-12) == "\u{2212}12.0")
        #expect(MatchText.oneDecimal(124.44) == "124.4")
    }

    @Test func aTokenSaysWhoHeIsWhereAndHisValue() {
        let planned = TokenContent(slot: .D_L, player: PlayerID(key: "a"), name: "Evan Humphries", surname: "Humphries",
                                   initials: "EH", value: "124.4", marks: [])
        #expect(planned.spokenText == "Evan Humphries, D L, 124.4")
        let confirmed = TokenContent(slot: .GK, player: PlayerID(key: "b"), name: "Matty Taylor", surname: "Taylor",
                                     initials: "MT", value: nil, marks: [])
        #expect(confirmed.spokenText == "Matty Taylor, GK")
    }

    @Test func aLeftOutRowSaysWhoWhereAndWhy() {
        let row = LeftOutRow(player: PlayerID(key: "a"), name: "Dejan Tetek", slotText: "DM R", reason: "Left out: injured")
        #expect(row.spokenText == "Dejan Tetek, DM R: Left out: injured")
    }

    @Test func aColumnHeadingSaysWhatClickingItDoes() {
        #expect(SquadColumn.age.sortHelp == "Sort by age")
        #expect(SquadColumn.ability.sortHelp == "Sort by ability now and potential")
    }

    @Test func aSquadRowWritesJadednessWithATrueMinus() {
        let player = Player(id: PlayerID(key: "p"), name: "Ann", squad: .firstTeam, age: 20, positionsText: "D C",
                            currentAbility: 50, potentialAbility: 100, attributes: [:], familiarity: [.defenderCentral: 20],
                            condition: 1, sharpness: 1, jadedness: -125, isInjured: false, isBanned: false, club: nil,
                            loanedTo: nil, contractType: .fullTime, monthsLeft: 10, wagePerWeek: 1, askingPrice: nil,
                            nationalities: [], extras: [:])
        #expect(SquadRow(player, loan: .own).jadednessText == "\u{2212}125")
    }
}

@MainActor @Suite struct NavigationHoldsWorkInProgressTests {
    @Test func theSquadSortAndTheFixtureBeingEditedAreKeptInTheNavigation() {
        let navigation = Navigation()
        #expect(navigation.squadSort == SquadSort())
        #expect(navigation.fixtureEditing == nil)
        navigation.squadSort = SquadSort().choosing(.age)
        var draft = FixtureDraft(date: Day(year: 2026, month: 11, day: 20)!)
        draft.opponent = "Rovers"
        navigation.fixtureEditing = FixtureEditing(draft: draft)
        navigation.screen = .squad
        #expect(navigation.squadSort == SquadSort(column: .age, ascending: true))
        #expect(navigation.fixtureEditing?.draft.opponent == "Rovers")
    }
}
