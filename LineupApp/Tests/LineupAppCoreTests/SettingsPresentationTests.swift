import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@Suite struct SettingsPresentationTests {
    private let today = Day(year: 2026, month: 11, day: 13)!

    @Test func theConditionFloorIsTheEnginesUntilChanged() {
        var settings = AppSettings(currentDate: today)
        let engine = EngineParameters.fm27.conditionFloor.value
        #expect(settings.usesEngineConditionFloor)
        #expect(settings.conditionFloorPercent == Int((engine * 100).rounded()))
        #expect(AppSettings.engineConditionFloorTitle == "Use the engine's \(Int((engine * 100).rounded()))%")

        settings.conditionFloorPercent = 90
        #expect(!settings.usesEngineConditionFloor)
        #expect(settings.conditionFloor == 0.9)
        #expect(settings.conditionFloorPercent == 90)
    }

    @Test func theConditionFloorStaysBetweenFiftyAndAHundredPercent() {
        var settings = AppSettings(currentDate: today)
        settings.conditionFloorPercent = 40
        #expect(settings.conditionFloor == 0.5)
        settings.conditionFloorPercent = 120
        #expect(settings.conditionFloor == 1)
        #expect(AppSettings.conditionFloorPercentRange == 50...100)
    }

    @Test func theConditionFloorSaysWhatItDoes() {
        #expect(AppSettings.conditionFloorExplanation
            == "Players below this condition are left out of every match unless you pick them yourself.")
    }

    @Test func usingTheEnginesFloorAgainForgetsTheOwnersAndTurningItOffStartsFromTheEngines() {
        var settings = AppSettings(currentDate: today)
        settings.conditionFloorPercent = 70
        settings.usesEngineConditionFloor = true
        #expect(settings.conditionFloor == nil)
        settings.usesEngineConditionFloor = false
        #expect(settings.conditionFloor == EngineParameters.fm27.conditionFloor.value)
        // Turning it off again keeps a figure the owner set.
        settings.conditionFloorPercent = 70
        settings.usesEngineConditionFloor = false
        #expect(settings.conditionFloor == 0.7)
    }

    @Test func savingPlayersMovesInTenthsAndZeroIsOff() {
        var settings = AppSettings(currentDate: today)
        settings.savingPlayers = 0.30000000000000004
        #expect(settings.plan.savingPlayers == 0.3)
        settings.savingPlayers = 1.26
        #expect(settings.plan.savingPlayers == 1.3)
        #expect(AppSettings.savingPlayersText(0) == "Off")
        #expect(AppSettings.savingPlayersText(1) == "1.0")
        #expect(AppSettings.savingPlayersText(1.5) == "1.5")
        #expect(AppSettings.savingPlayersText(2) == "2.0")
    }

    @Test func horizonTextCountsFixtures() {
        #expect(AppSettings.horizonText(1) == "1 fixture")
        #expect(AppSettings.horizonText(5) == "5 fixtures")
    }

    @Test func anEmptyClubNameOrPathMeansTheUsualOne() {
        var settings = AppSettings(currentDate: today)
        #expect(settings.clubNameText == "" && settings.fmrteConfigPathText == "")
        settings.clubNameText = "Oxford City"
        settings.fmrteConfigPathText = "~/config.json"
        #expect(settings.clubName == "Oxford City" && settings.fmrteConfigPath == "~/config.json")
        // Spaces are kept while typing, so a name with a space in it can be typed.
        settings.clubNameText = "Oxford "
        #expect(settings.clubName == "Oxford ")
        settings.clubNameText = "  "
        settings.fmrteConfigPathText = ""
        #expect(settings.clubName == nil && settings.fmrteConfigPath == nil)
    }

    @Test func theClubHandedOnIsTrimmedAndABlankNameIsNone() {
        var settings = AppSettings(currentDate: today)
        #expect(settings.clubOverride == nil)
        settings.clubName = "  Oxford City "
        #expect(settings.clubOverride == "Oxford City")
        settings.clubName = "   "
        #expect(settings.clubOverride == nil)
        settings.clubName = ""
        #expect(settings.clubOverride == nil)
    }

    @MainActor @Test func theModelsClubIsTheTrimmedNameOrTheOneWorkedOut() throws {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = " Oxford City  "
        t.model.update(settings)
        #expect(t.model.ownClub == "Oxford City")
        settings.clubName = "  "
        t.model.update(settings)
        #expect(t.model.ownClub == nil)
    }
}
