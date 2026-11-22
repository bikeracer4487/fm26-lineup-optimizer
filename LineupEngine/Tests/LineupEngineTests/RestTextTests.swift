import Testing
@testable import LineupEngine

extension RestTrend {
    /// Nothing measured: no reading of his.
    static let unmeasured = RestTrend(squad: .firstTeam, seen: nil, imports: 0, importsNeeded: 4, passesOn: nil,
                                      drift: nil, gain: nil, restWillNotClear: false, basis: .derived)
}

/// The Rest advisor's sentences about each listed player's trend, each squad's drift, the club's gain and the game's
/// messages, compared whole.
@Suite struct RestTextTests {
    let parameters = EngineParameters.fm27

    func trend(seen: SeenTrend? = nil, imports: Int = 4, passesOn: Day? = nil, drift: MeasuredRate? = nil,
               gain: MeasuredRate? = nil, restWillNotClear: Bool = false, squad: Squad = .firstTeam) -> RestTrend {
        RestTrend(squad: squad, seen: seen, imports: imports, importsNeeded: 4, passesOn: passesOn, drift: drift,
                  gain: gain, restWillNotClear: restWillNotClear, basis: .derived)
    }

    func advice(_ trend: RestTrend, level: RestLevel = .watch, jadedness: Int = 300, days: Int? = nil) -> RestAdvice {
        RestAdvice(player: PlayerID(key: "p"), name: "P", level: level, jadedness: jadedness, limit: 400, limitNotes: [],
                   condition: 1, consecutiveStarts: 0, days: days, reasons: [], basis: .derived, trend: trend)
    }

    func lines(_ trend: RestTrend, level: RestLevel = .watch) -> [String] {
        AdvisorText.trendLines(of: advice(trend, level: level), parameters: parameters)
    }

    func seen(_ perWeek: Double, days: Int = 35, starts: Int = 6, readings: Int = 6) -> SeenTrend {
        SeenTrend(perWeek: perWeek, days: days, starts: starts, readings: readings)
    }

    let notStarted = "He has not started a match for you in that time: the rise is from training and any matches for "
        + "another side."
    let saves = "Without a start he falls about 30 a week, and a start adds about 61, so a match off saves about 61."
    let rises = "He rises about 16 a week without a start, so leaving him out of matches will not bring it down. Lighter "
        + "training, or rest from training, will."
    let holds = "He holds steady without a start, so leaving him out of matches will not bring it down. Lighter "
        + "training, or rest from training, will."

    // MARK: Not measured yet

    @Test func withNoTrendItSaysHowManyImportsItNeedsAndHas() {
        #expect(lines(trend(imports: 2))
                == ["His trend is not measured yet: it needs 4 imports of his squad, and has 2."])
        // A player with one import after the summer, and one with none.
        #expect(lines(trend(imports: 1))
                == ["His trend is not measured yet: it needs 4 imports of his squad, and has 1."])
        #expect(lines(trend(imports: 0))
                == ["His trend is not measured yet: it needs 4 imports of his squad, and has 0."])
    }

    @Test func theImportsNeededAreFewestOwnIntervalsAndOne() {
        let t = RestTrend(squad: .firstTeam, seen: nil, imports: 2, importsNeeded: 6, passesOn: nil, drift: nil,
                          gain: nil, restWillNotClear: false, basis: .derived)
        #expect(AdvisorText.trendLines(of: advice(t), parameters: parameters)
                == ["His trend is not measured yet: it needs 6 imports of his squad, and has 2."])
    }

    // MARK: His trend as seen

    @Test func risingFallingAndSteady() {
        #expect(lines(trend(seen: seen(45)))
                == ["Rising about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)."])
        #expect(lines(trend(seen: seen(-45)))
                == ["Falling about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)."])
        let steady = "Holding steady over the last 5 weeks, in which he started 6 matches (from 6 readings)."
        #expect(lines(trend(seen: seen(3))) == [steady])
        #expect(lines(trend(seen: seen(-3))) == [steady])
        // Within steadyPerWeek either way, the line itself included.
        #expect(lines(trend(seen: seen(5))) == [steady])
        #expect(lines(trend(seen: seen(-5))) == [steady])
        #expect(lines(trend(seen: seen(5.4))).first?.hasPrefix("Rising about 5 a week") == true)
        #expect(lines(trend(seen: seen(-5.4))).first?.hasPrefix("Falling about 5 a week") == true)
    }

    @Test func theFiguresAreWholeNumbers() {
        #expect(lines(trend(seen: seen(44.6))).first?.hasPrefix("Rising about 45 a week") == true)
        #expect(lines(trend(seen: seen(-44.4))).first?.hasPrefix("Falling about 44 a week") == true)
    }

    @Test func oneStartAndNone() {
        #expect(lines(trend(seen: seen(-45, starts: 1)))
                == ["Falling about 45 a week over the last 5 weeks, in which he started 1 match (from 6 readings)."])
        #expect(lines(trend(seen: seen(-45, starts: 0)))
                == ["Falling about 45 a week over the last 5 weeks, in which he did not start a match (from 6 readings)."])
    }

    @Test func theWeeksAreRoundedAndAtLeastOne() {
        #expect(lines(trend(seen: seen(-45, days: 7, readings: 2)))
                == ["Falling about 45 a week over the last week, in which he started 6 matches (from 2 readings)."])
        #expect(lines(trend(seen: seen(-45, days: 3))).first?.contains("over the last week,") == true)
        #expect(lines(trend(seen: seen(-45, days: 10))).first?.contains("over the last week,") == true)
        #expect(lines(trend(seen: seen(-45, days: 11))).first?.contains("over the last 2 weeks,") == true)
    }

    // MARK: When he passes the line

    @Test func thePassDateFollowsTheTrend() {
        #expect(lines(trend(seen: seen(45), passesOn: Day(iso: "2027-11-07")!))
                == ["Rising about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings).",
                    "At that rate he passes 400 around Sun 7 Nov."])
    }

    @Test func thePassDateNamesTheThreshold() {
        var q = parameters
        q.jadedThreshold = Parameter(450, .derived, source: "test")
        let t = trend(seen: seen(45), passesOn: Day(iso: "2027-11-07")!)
        #expect(AdvisorText.trendLines(of: advice(t), parameters: q).last == "At that rate he passes 450 around Sun 7 Nov.")
    }

    // MARK: What a match off would do

    let own = RateSource.own(intervals: 3)

    @Test func aMatchOffSavesTheGainWhenTheDriftFalls() {
        let base = "Falling about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)."
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-30.0 / 7, own), gain: MeasuredRate(61, own)))
                == [base, saves])
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-30.0 / 7, .squad(.firstTeam)), gain: MeasuredRate(61, own)))
                == [base, saves + " (the first team's rate without a start; his own rate for a start)"])
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-30.0 / 7, .squad(.firstTeam)), gain: MeasuredRate(61, .club)))
                == [base, saves + " (the first team's rate without a start; the club's rate for a start)"])
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-30.0 / 7, own), gain: MeasuredRate(61, .club)))
                == [base, saves + " (his own rate without a start; the club's rate for a start)"])
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-30.0 / 7, .squad(.u21)), gain: MeasuredRate(61, .club)))
                == [base, saves + " (the U21s' rate without a start; the club's rate for a start)"])
    }

    @Test func aFallingDriftWithinTheSteadyBandHoldsSteadyAndAMatchOffStillSaves() {
        let base = "Falling about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)."
        let steadySaves = "He holds steady without a start, and a start adds about 61, so a match off saves about 61."
        // −5 a week, the band's edge included.
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-5.0 / 7, own), gain: MeasuredRate(61, own)))
                == [base, steadySaves])
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-3.0 / 7, .squad(.firstTeam)), gain: MeasuredRate(61, own)))
                == [base, steadySaves + " (the first team's rate without a start; his own rate for a start)"])
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-0.1, own), gain: MeasuredRate(61, .club)))
                == [base, steadySaves + " (his own rate without a start; the club's rate for a start)"])
        // Just past the band, he falls.
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-5.1 / 7, own), gain: MeasuredRate(61, own))).last
                == "Without a start he falls about 5 a week, and a start adds about 61, so a match off saves about 61.")
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-30.0 / 7, own), gain: MeasuredRate(61, own))).last == saves)
    }

    @Test func aRisingDriftWillNotBeBroughtDownByMatchesOff() {
        let base = "Rising about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)."
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(16.0 / 7, own), gain: MeasuredRate(61, own)))
                == [base, rises])
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(16.0 / 7, .squad(.firstTeam)), gain: MeasuredRate(61, own)))
                == [base, rises + " (the first team's rate without a start; his own rate for a start)"])
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(16.0 / 7, .squad(.firstTeam)), gain: MeasuredRate(61, .club)))
                == [base, rises + " (the first team's rate without a start; the club's rate for a start)"])
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(16.0 / 7, own), gain: MeasuredRate(61, .club)))
                == [base, rises + " (his own rate without a start; the club's rate for a start)"])
    }

    @Test func aDriftWithinTheSteadyBandHoldsSteady() {
        let base = "Rising about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)."
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(0, own), gain: MeasuredRate(61, own))) == [base, holds])
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(0.5, .squad(.firstTeam)), gain: MeasuredRate(61, own)))
                == [base, holds + " (the first team's rate without a start; his own rate for a start)"])
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(0.5, .squad(.firstTeam)), gain: MeasuredRate(61, .club)))
                == [base, holds + " (the first team's rate without a start; the club's rate for a start)"])
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(0.5, own), gain: MeasuredRate(61, .club)))
                == [base, holds + " (his own rate without a start; the club's rate for a start)"])
        // Just past the band, he rises.
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(5.1 / 7, own), gain: MeasuredRate(61, own))).last?
            .hasPrefix("He rises about 5 a week without a start") == true)
    }

    @Test func aGainOfNothingOrLessSaysNothingOfAMatchOff() {
        let base = "Falling about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)."
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-30.0 / 7, own), gain: MeasuredRate(0, own))) == [base])
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-30.0 / 7, own), gain: MeasuredRate(-5, .club))) == [base])
    }

    @Test func aMatchOffNeedsAStartAndBothRates() {
        let base = "Falling about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)."
        #expect(lines(trend(seen: seen(-45), drift: MeasuredRate(-30.0 / 7, own))) == [base])
        #expect(lines(trend(seen: seen(-45), gain: MeasuredRate(61, own))) == [base])
        // No start in his trend: nothing of a match off.
        #expect(lines(trend(seen: seen(-45, starts: 0), drift: MeasuredRate(-30.0 / 7, own), gain: MeasuredRate(61, own)))
                == ["Falling about 45 a week over the last 5 weeks, in which he did not start a match (from 6 readings)."])
        // No trend as seen: nothing of a match off either.
        #expect(lines(trend(imports: 3, drift: MeasuredRate(-30.0 / 7, own), gain: MeasuredRate(61, own)))
                == ["His trend is not measured yet: it needs 4 imports of his squad, and has 3."])
    }

    // MARK: A rise with no start

    @Test func aRiseWithNoStartIsFromTrainingAndOtherSides() {
        #expect(lines(trend(seen: seen(45, starts: 0)))
                == ["Rising about 45 a week over the last 5 weeks, in which he did not start a match (from 6 readings).",
                    notStarted])
        // Not when he started, and not when he is not rising.
        #expect(!lines(trend(seen: seen(45, starts: 1))).contains(notStarted))
        #expect(!lines(trend(seen: seen(5, starts: 0))).contains(notStarted))
    }

    // MARK: Rest from matches will not clear it

    @Test func whenRestWillNotClearItTheLighterTrainingLineIsGivenWithTheDriftsBracketOnly() {
        let base = "Holding steady over the last 5 weeks, in which he started 6 matches (from 6 readings)."
        #expect(lines(trend(seen: seen(3), drift: MeasuredRate(16.0 / 7, .squad(.firstTeam)), restWillNotClear: true),
                      level: .rest)
                == [base, rises + " (the first team's rate without a start)"])
        #expect(lines(trend(seen: seen(3), drift: MeasuredRate(0.5, .squad(.u18)), restWillNotClear: true), level: .rest)
                == [base, holds + " (the U18s' rate without a start)"])
        #expect(lines(trend(seen: seen(3), drift: MeasuredRate(16.0 / 7, own), restWillNotClear: true), level: .rest)
                == [base, rises])
        // With no trend as seen, after the line saying so; and with a gain of nothing, in place of line 4.
        #expect(lines(trend(imports: 2, drift: MeasuredRate(16.0 / 7, .squad(.firstTeam)), restWillNotClear: true),
                      level: .rest)
                == ["His trend is not measured yet: it needs 4 imports of his squad, and has 2.",
                    rises + " (the first team's rate without a start)"])
        #expect(lines(trend(seen: seen(3), drift: MeasuredRate(16.0 / 7, .squad(.firstTeam)), gain: MeasuredRate(0, .club),
                            restWillNotClear: true), level: .rest)
                == [base, rises + " (the first team's rate without a start)"])
    }

    @Test func theLighterTrainingLineIsGivenOnce() {
        let base = "Rising about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)."
        #expect(lines(trend(seen: seen(45), drift: MeasuredRate(16.0 / 7, .squad(.firstTeam)), gain: MeasuredRate(61, .club),
                            restWillNotClear: true), level: .rest)
                == [base, rises + " (the first team's rate without a start; the club's rate for a start)"])
    }

    @Test func theLinesComeInTheOrderOfTheCopy() {
        // Rising with no start, and rest will not clear it: the lighter-training line stands where line 4 does,
        // before the line on the rise with no start.
        #expect(lines(trend(seen: seen(45, starts: 0), passesOn: Day(iso: "2027-11-07")!,
                            drift: MeasuredRate(16.0 / 7, .squad(.firstTeam)), restWillNotClear: true), level: .rest)
                == ["Rising about 45 a week over the last 5 weeks, in which he did not start a match (from 6 readings).",
                    "At that rate he passes 400 around Sun 7 Nov.",
                    rises + " (the first team's rate without a start)",
                    notStarted])
    }

    // MARK: Days until clear

    @Test func noClearingLineWhenRestFromMatchesWillNotClearIt() {
        #expect(AdvisorText.clear(in: advice(trend(restWillNotClear: true), level: .rest)) == nil)
        #expect(AdvisorText.clear(in: advice(trend(restWillNotClear: false), level: .rest, days: 4)) == "Clear in about 4 days")
    }

    // MARK: Above the rows

    let since = Day(iso: "2027-08-24")!

    @Test func eachSquadsDriftInSquadOrderWithTheCautionOnlyWhenItIsNotBelowNothing() {
        let trends = FitnessTrends(
            players: [:],
            squadDrift: [.u18: SharedRate(value: 0.5, readings: 12, since: since),
                         .firstTeam: SharedRate(value: 16.0 / 7, readings: 38, since: since),
                         .u21: SharedRate(value: -2, readings: 20, since: since)],
            clubGain: nil, measuredFrom: nil)
        let caution = "At this training load, leaving players out of matches cannot bring jadedness down."
        #expect(AdvisorText.squadTrendLines(trends, parameters: parameters) == [
            SquadTrendLine(text: "First team: a player who does not start rises about 16 a week (from 38 readings since "
                               + "Tue 24 Aug; this tool's estimate).", caution: caution),
            SquadTrendLine(text: "U21s: a player who does not start falls about 14 a week (from 20 readings since Tue 24 "
                               + "Aug; this tool's estimate).", caution: nil),
            SquadTrendLine(text: "U18s: a player who does not start holds steady (from 12 readings since Tue 24 Aug; this "
                               + "tool's estimate).", caution: caution),
        ])
    }

    @Test func aSteadyFallingDriftHasNoCautionAndAnUnmeasuredSquadNoLine() {
        let trends = FitnessTrends(players: [:], squadDrift: [.u21: SharedRate(value: -0.5, readings: 9, since: since)],
                                   clubGain: nil, measuredFrom: nil)
        #expect(AdvisorText.squadTrendLines(trends, parameters: parameters) == [
            SquadTrendLine(text: "U21s: a player who does not start holds steady (from 9 readings since Tue 24 Aug; this "
                               + "tool's estimate).", caution: nil),
        ])
        #expect(AdvisorText.squadTrendLines(.none, parameters: parameters).isEmpty)
    }

    @Test func theClubsGain() {
        let trends = FitnessTrends(players: [:], squadDrift: [:], clubGain: SharedRate(value: 31.2, readings: 14, since: since),
                                   measuredFrom: nil)
        #expect(AdvisorText.clubGainLine(trends) == "A start adds about 31 (from 14 readings; this tool's estimate).")
        #expect(AdvisorText.clubGainLine(.none) == nil)
    }

    @Test func theDayTheTrendIsMeasuredFrom() {
        let trends = FitnessTrends(players: [:], squadDrift: [:], clubGain: nil, measuredFrom: since)
        #expect(AdvisorText.trendMeasuredFrom(trends) == "Trend measured from Tue 24 Aug.")
        #expect(AdvisorText.trendMeasuredFrom(.none) == nil)
    }

    // MARK: The game's messages

    @Test func whatTheGamesMessagesMean() {
        #expect(AdvisorText.gameMessagesHeading == "What the game's messages mean")
        #expect(AdvisorText.gameMessages(parameters: parameters) == [
            "'Tired after last match' and 'Very tired after last match' describe condition after a match and clear in "
                + "days. They are not a reason for a holiday. (this tool's reading of the wording)",
            "The game calls a player jaded above 400. No test in any version shows a cost below that; above 0, condition "
                + "comes back more slowly. (FM27 tests)",
            "A holiday costs about 0.5% of sharpness a day and the matches missed. A full rest day after each match, and "
                + "lighter training below full condition, cost less. (FM27 tests; the holiday's effect is carried over "
                + "from FM24)",
        ])
    }

    @Test func theGamesMessagesTakeTheirFiguresFromTheParameters() {
        var q = parameters
        q.jadedThreshold = Parameter(450, .derived, source: "test")
        q.sharpnessDecayPerDay = Parameter(0.01, .derived, source: "test")
        let messages = AdvisorText.gameMessages(parameters: q)
        #expect(messages[1].hasPrefix("The game calls a player jaded above 450."))
        #expect(messages[2].hasPrefix("A holiday costs about 1% of sharpness a day"))
    }

    // MARK: Squads

    @Test func squadNamesAndPossessives() {
        #expect(Squad.allCases.map { AdvisorText.name($0) } == ["First team", "U21s", "U18s"])
        #expect(Squad.allCases.map { AdvisorText.possessive($0) } == ["the first team's", "the U21s'", "the U18s'"])
    }
}
