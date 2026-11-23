import Foundation
import Testing
@testable import LineupEngine

@Suite struct MoneyDisplayTests {
    private let dollarsMonthly = MoneyStyle(symbol: "$", period: .monthly)

    @Test func anAmountTakesTheSymbolGiven() {
        #expect(Display.money(1_250, symbol: "$") == "$1,250")
        #expect(Display.money(1_250, symbol: "€") == "€1,250")
        #expect(Display.money(0, symbol: "£") == "£0")
        #expect(Display.money(1_234_567, symbol: "$") == "$1,234,567")
        #expect(Display.money(-1_250, symbol: "$") == "-$1,250")
    }

    @Test func aWageIsShownInTheStylesPeriod() {
        #expect(Display.wage(perWeek: 807, dollarsMonthly) == "$3,497 a month")
        #expect(Display.wage(perWeek: 600, .weeklyPounds) == "£600 a week")
        #expect(Display.wage(perWeek: 807, MoneyStyle(symbol: "$", period: .yearly)) == "$41,964 a year")
    }

    @Test func aWageIsRoundedToAWholeUnitInItsPeriod() {
        // 3,500 a month is 807.69… a week; worked back, it is 3,500 again.
        #expect(Display.wage(perWeek: 3_500.0 * 12 / 52, dollarsMonthly) == "$3,500 a month")
        #expect(Display.wage(perWeek: 600.5, .weeklyPounds) == "£601 a week")
        #expect(Display.wage(perWeek: 600.49, .weeklyPounds) == "£600 a week")
    }

    @Test func aSalaryByTheYearIsFiftyTwoWeeksWhateverThePeriodShown() {
        // Caelan Avenell's $5,735 a month, kept by the week: 5,735 × 12 = 68,820 a year.
        let perWeek = WagePeriod.monthly.perWeek(5_735)
        #expect(Display.yearlyAmount(perWeek: perWeek, dollarsMonthly) == "$68,820")
        #expect(Display.yearly(perWeek: perWeek, dollarsMonthly) == "$68,820 a year")
        #expect(Display.yearlyAmount(perWeek: 600, .weeklyPounds) == "£31,200")
        #expect(Display.yearly(perWeek: 600, .weeklyPounds) == "£31,200 a year")
        #expect(Display.yearlyAmount(perWeek: 0, dollarsMonthly) == "$0")
        // Rounded to a whole unit: 600.01 a week is 31,200.52 a year.
        #expect(Display.yearlyAmount(perWeek: 600.01, .weeklyPounds) == "£31,201")
    }

    @Test func theImportSaysHowWagesWereRead() {
        #expect(Display.wagesRead(dollarsMonthly) == "Wages are in $ a month, as FMRTE shows them.")
        #expect(Display.wagesRead(.weeklyPounds) == "Wages are in £ a week, as FMRTE shows them.")
        #expect(Display.wagesRead(MoneyStyle(symbol: "€", period: .yearly)) == "Wages are in € a year, as FMRTE shows them.")
    }

    @Test func weeklyPoundsIsThePoundSignAndAWeek() {
        #expect(MoneyStyle.weeklyPounds == MoneyStyle(symbol: "£", period: .weekly))
    }
}

@Suite struct SavedWageTests {
    /// A player as JSON, his wage per week replaced by `wage` as written.
    private func json(wage: String) throws -> Data {
        let text = try #require(String(data: try JSONEncoder().encode(Player.fixture(name: "Scott Pollock")), encoding: .utf8))
        let replaced = text.replacingOccurrences(of: #""wagePerWeek":500"#, with: #""wagePerWeek":\#(wage)"#)
        #expect(replaced != text)
        return Data(replaced.utf8)
    }

    @Test func aPlayerSavedWithAWholeWeeklyWageOpens() throws {
        #expect(try JSONDecoder().decode(Player.self, from: json(wage: "600")).wagePerWeek == 600)
    }

    @Test func aPlayerKeepsAWeeklyWageThatIsNotWhole() throws {
        let player = try JSONDecoder().decode(Player.self, from: json(wage: "807.6923076923077"))
        #expect(player.wagePerWeek == 807.6923076923077)
        #expect(try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(player)) == player)
    }
}
