import Testing
@testable import LineupEngine

@Suite struct AdvisorTextContractsTests {
    let money = MoneyStyle(symbol: "$", period: .monthly)
    /// Wages are kept by the week; a month is 52/12 of them.
    func week(_ month: Double) -> Double { month * 12 / 52 }

    func guide(tier: WageTier = .secondEleven, leavesHimOut: Bool = false, paid: PaidRange? = nil,
               ceiling: Double? = nil, starter: Double? = nil, highest: Double? = nil, left: Double? = nil,
               countsBack: Bool = false, shown: WageShown) -> WageGuide {
        WageGuide(tier: tier, slot: nil, leavesHimOut: leavesHimOut, paid: paid, ceilingPerWeek: ceiling,
                  starterSharePerWeek: starter, highestWagePerWeek: highest, budgetLeftPerWeek: left,
                  countsHisWageBack: countsBack, shown: shown, basis: .derived)
    }

    var paid: PaidRange { PaidRange(lowerQuartile: week(2786), highest: week(3905), count: 6) }

    func entry(part: ContractPart = .lastYear, standing: ContractStanding, action: RemovalAction? = nil,
               approachableFrom: Day? = nil) -> ContractEntry {
        ContractEntry(player: PlayerID(key: "a"), name: "A", part: part, ends: nil, approachableFrom: approachableFrom,
                      standing: standing, action: action, tier: .neither, slot: nil, presentWagePerWeek: 0, worth: nil,
                      reasons: [], isWanted: false)
    }

    @Test func fixedLines() {
        #expect(AdvisorText.contractsIntro == "Players worth renewing whose contracts are running down, most important first, with what your own squad is paid as a guide to a reasonable wage.")
        #expect(AdvisorText.nobodyInLastYear == "Nobody worth renewing is in the last year of his contract.")
        #expect(AdvisorText.listedAtYourChoice == "The tool does not recommend renewing him; he is listed at your choice.")
        #expect(AdvisorText.candidateAskNotKnown == "What he would ask of you is not known; check the agent's figure before you bid.")
        #expect(AdvisorText.candidateWageOtherCurrency == "His wage is in another currency than your squads', so it cannot be compared with them.")
        #expect(AdvisorText.wageEvidenceSentence == "A wage range is what your own players are paid now, not what a player will ask: no test in any version says what a player asks (this tool's estimate).")
    }

    @Test func standing() {
        #expect(AdvisorText.standingLine(entry(standing: .first(.D_L))) == "First choice at left back.")
        #expect(AdvisorText.standingLine(entry(standing: .second(.ST_C))) == "Second choice at striker.")
        #expect(AdvisorText.standingLine(entry(standing: .neither, action: .develop)) == "In neither eleven; Player Removal says keep and develop.")
        #expect(AdvisorText.standingLine(entry(standing: .neither)) == "In neither eleven.")
        let levels: [(CandidateLevel, String)] = [
            (.wouldStart, "he would start at left back"), (.wouldMakeSecond, "he would make the second eleven at left back"),
            (.wouldCountAsCover, "he would count as cover at left back"), (.belowCover, "he would be below cover at left back")]
        for (level, words) in levels {
            #expect(AdvisorText.standingLine(entry(standing: .outOnLoan(to: "Wallingford", level: level, slot: .D_L)))
                    == "Out on loan at Wallingford; \(words).")
        }
        #expect(AdvisorText.standingLine(entry(standing: .outOnLoan(to: "Wallingford", level: nil, slot: nil)))
                == "Out on loan at Wallingford; he can play no slot of this tactic.")
    }

    @Test func theReasons() {
        #expect(AdvisorText.contractReasonLine(.markedToSell) == "You have marked him to sell.")
        #expect(AdvisorText.contractReasonLine(.advisedToLeave(.sell)) == "Player Removal advises selling him.")
        #expect(AdvisorText.contractReasonLine(.advisedToLeave(.release)) == "Player Removal advises releasing him.")
        #expect(AdvisorText.contractReasonLine(.advisedToLeave(.terminate))
                == "Player Removal advises ending his contract by agreement.")
        for action in [RemovalAction.monitor, .develop, .play, .loanForMatches, .keep] {
            #expect(AdvisorText.contractReasonLine(.advisedToLeave(action)) == "Player Removal advises moving him on.")
        }
        let worth = RenewalWorth(player: PlayerID(key: "a"), slot: .DM_R, isGoalkeeperSlot: false, age: 26, ability: 76,
                                 ahead: .today, shareToday: 0.894, share: 0.894, meetsStandard: false, basis: .derived)
        #expect(AdvisorText.contractReasonLine(.underStandard(worth)) == AdvisorText.worthLine(worth))
        #expect(AdvisorText.contractReasonLine(.underStandard(worth))
                == "Rates 10.6% under the average of your first eleven, at right defensive midfield.")
        #expect(AdvisorText.contractReasonLine(.noSlot) == "He can play no slot of this tactic.")
        #expect(AdvisorText.contractReasonLine(.noStandard)
                == "Your first eleven has no outfield player in position, so nobody can be measured against it.")
        #expect(AdvisorText.contractReasonLine(.replaceFirst(slot: .DM_R, why: .firstChoice))
                == "He is first choice at right defensive midfield: sign a replacement before he goes.")
        #expect(AdvisorText.contractReasonLine(.replaceFirst(slot: .ST_C, why: .secondChoice))
                == "He is second choice at striker: sign a replacement before he goes.")
        #expect(AdvisorText.contractReasonLine(.replaceFirst(slot: .D_L, why: .cover))
                == "He counts as cover at left back: sign a replacement before he goes.")
        #expect(AdvisorText.contractReasonLine(.replaceFirst(slot: .D_L, why: .standIn))
                == "Too few players can step in at left back without him: sign a replacement before he goes.")
    }

    @Test func timing() {
        let day = Day(year: 2026, month: 12, day: 30)!
        #expect(AdvisorText.timingLine(entry(part: .approachable, standing: .neither)) == "Other clubs can approach him now.")
        #expect(AdvisorText.timingLine(entry(part: .lastYear, standing: .neither, approachableFrom: day)) == "Other clubs can approach him from Wed 30 Dec.")
        #expect(AdvisorText.timingLine(entry(part: .lastYear, standing: .neither)) == nil)
        #expect(AdvisorText.timingLine(entry(part: .noContract, standing: .neither)) == "He has no contract and can leave at any time.")
    }

    @Test func rangeLines() {
        let tierRange = guide(paid: paid, shown: .range(low: week(2786), high: week(3905), setBy: .tierHighest))
        #expect(AdvisorText.wageGuideLines(tierRange, money: money)
                == ["Most of your second eleven are paid $2,786 to $3,905 a month (this tool's estimate of a reasonable range)."])
        let all = guide(paid: PaidRange(lowerQuartile: week(3269), highest: week(3269), count: 3),
                        shown: .range(low: week(3269), high: week(3269), setBy: .tierHighest))
        #expect(AdvisorText.wageGuideLines(all, money: money)
                == ["Your second eleven are all paid $3,269 a month (this tool's estimate of a reasonable wage)."])
        let ceiling = guide(paid: paid, shown: .range(low: week(2786), high: week(3400), setBy: .ceiling))
        #expect(AdvisorText.wageGuideLines(ceiling, money: money).first
                == "A reasonable range is $2,786 to $3,400 a month: from what most of your second eleven are paid up to a backup's share of your wage budget (this tool's estimate).")
        let top = guide(paid: paid, shown: .range(low: week(2786), high: week(3400), setBy: .highestWage))
        #expect(AdvisorText.wageGuideLines(top, money: money).first
                == "A reasonable range is $2,786 to $3,400 a month: from what most of your second eleven are paid up to the most you can offer one player (this tool's estimate).")
        let upCeiling = guide(paid: paid, shown: .upTo(week(1870), setBy: .ceiling))
        #expect(AdvisorText.wageGuideLines(upCeiling, money: money).first
                == "Up to $1,870 a month: a backup's share of your wage budget is below what most of your second eleven are paid, $2,786 to $3,905 a month (this tool's estimate).")
        let upHighest = guide(paid: paid, shown: .upTo(week(1500), setBy: .highestWage))
        #expect(AdvisorText.wageGuideLines(upHighest, money: money).first
                == "Up to $1,500 a month: the most you can offer one player is below what most of your second eleven are paid, $2,786 to $3,905 a month.")
        let unpaid = guide(shown: .upTo(week(1870), setBy: .ceiling))
        #expect(AdvisorText.wageGuideLines(unpaid, money: money).first
                == "Up to $1,870 a month, a backup's share of your wage budget; too few of your second eleven are paid a wage to read a range from them (this tool's estimate).")
        #expect(AdvisorText.wageGuideLines(guide(shown: .none), money: money)
                == ["No range can be given: too few of your second eleven are paid a wage to read one from. Enter your wage budget for a ceiling."])
    }

    @Test func ceilingAndLimitLines() {
        let first = guide(tier: .firstEleven, paid: paid, ceiling: week(5200), starter: week(2980), shown: .none)
        #expect(AdvisorText.wageGuideLines(first, money: money)[1]
                == "By one rule of thumb a key player's share of your wage budget is $5,200 a month, kept for four players, and a starter's is $2,980 a month (this tool's estimate).")
        let backup = guide(ceiling: week(1870), shown: .none)
        #expect(AdvisorText.wageGuideLines(backup, money: money)[1]
                == "By one rule of thumb a backup's share of your wage budget is $1,870 a month (this tool's estimate).")
        let both = guide(highest: week(6500), left: week(2140), shown: .none)
        #expect(AdvisorText.wageGuideLines(both, money: money)[1]
                == "The most you can offer one player is $6,500 a month, and $2,140 a month of your wage budget is left.")
        #expect(AdvisorText.wageGuideLines(guide(highest: week(6500), shown: .none), money: money)[1]
                == "The most you can offer one player is $6,500 a month.")
        #expect(AdvisorText.wageGuideLines(guide(left: week(2140), shown: .none), money: money)[1]
                == "$2,140 a month of your wage budget is left.")
        #expect(AdvisorText.wageGuideLines(guide(left: week(2140), countsBack: true, shown: .none), money: money)[1]
                == "$2,140 a month of your wage budget is left, counting his present wage back.")
        #expect(AdvisorText.wageGuideLines(guide(highest: week(6500), left: week(2140), countsBack: true, shown: .none), money: money)[1]
                == "The most you can offer one player is $6,500 a month, and $2,140 a month of your wage budget is left, counting his present wage back.")
        #expect(AdvisorText.wageGuideLines(guide(shown: .none), money: money).count == 1)
    }

    @Test func theTiersAndThePlayerWhoIsLeftOut() {
        let rest = guide(tier: .firstEleven, leavesHimOut: true, paid: paid, shown: .range(low: week(2786), high: week(3905), setBy: .tierHighest))
        #expect(AdvisorText.wageGuideLines(rest, money: money)
                == ["Most of the rest of your first eleven are paid $2,786 to $3,905 a month (this tool's estimate of a reasonable range)."])
        #expect(AdvisorText.wageVerdictLine(.aboveTier(highest: week(3905)), figure: .agents, guide: rest, money: money)
                == "The agent's figure is above anything the rest of your first eleven are paid; the highest is $3,905 a month.")
        let restCeiling = guide(tier: .secondEleven, leavesHimOut: true, paid: paid,
                                shown: .range(low: week(2786), high: week(3400), setBy: .ceiling))
        #expect(AdvisorText.wageGuideLines(restCeiling, money: money).first
                == "A reasonable range is $2,786 to $3,400 a month: from what most of the rest of your second eleven are paid up to a backup's share of your wage budget (this tool's estimate).")
        let restUpTo = guide(tier: .secondEleven, leavesHimOut: true, paid: paid, shown: .upTo(week(1500), setBy: .highestWage))
        #expect(AdvisorText.wageGuideLines(restUpTo, money: money).first
                == "Up to $1,500 a month: the most you can offer one player is below what most of the rest of your second eleven are paid, $2,786 to $3,905 a month.")
        let neither = guide(tier: .neither, shown: .none)
        #expect(AdvisorText.wageGuideLines(neither, money: money)
                == ["No range can be given: too few of your players in neither eleven are paid a wage to read one from. Enter your wage budget for a ceiling."])
        #expect(AdvisorText.wageVerdictLine(.aboveTier(highest: week(3905)), figure: .agents, guide: neither, money: money)
                == "The agent's figure is above anything your players in neither eleven are paid; the highest is $3,905 a month.")
        let restNeither = guide(tier: .neither, leavesHimOut: true, shown: .none)
        #expect(AdvisorText.wageVerdictLine(.aboveTier(highest: week(3905)), figure: .agents, guide: restNeither, money: money)
                == "The agent's figure is above anything the rest of your players in neither eleven are paid; the highest is $3,905 a month.")
        #expect(AdvisorText.wageVerdictLine(.underTier, figure: .agents, guide: rest, money: money)
                == "The agent's figure is under what most of the rest of your first eleven are paid.")
        let firstGuide = guide(tier: .firstEleven, shown: .none)
        #expect(AdvisorText.wageGuideLines(guide(tier: .firstEleven, paid: paid, shown: .range(low: week(2786), high: week(3905), setBy: .tierHighest)), money: money).first?.hasPrefix("Most of your first eleven are paid") == true)
        #expect(AdvisorText.wageVerdictLine(.overCeiling(ceiling: week(5200)), figure: .agents, guide: firstGuide, money: money)
                == "The agent's figure is above a key player's share of your wage budget, $5,200 a month (this tool's estimate).")
    }

    @Test func verdicts() {
        let second = guide(shown: .none)
        func line(_ v: WageVerdict, _ f: WageFigure = .agents) -> String {
            AdvisorText.wageVerdictLine(v, figure: f, guide: second, money: money)
        }
        #expect(line(.overHighestWage(limit: week(6500))) == "The agent's figure is above the most you can offer one player, $6,500 a month.")
        #expect(line(.overCeiling(ceiling: week(1870))) == "The agent's figure is above a backup's share of your wage budget, $1,870 a month (this tool's estimate).")
        #expect(line(.aboveTier(highest: week(3905))) == "The agent's figure is above anything your second eleven are paid; the highest is $3,905 a month.")
        #expect(line(.withinTier, .presentWage) == "His wage now is within what your second eleven are paid.")
        #expect(line(.underTier, .presentWage) == "His wage now is under what most of your second eleven are paid.")
        #expect(line(.overBudgetLeft(by: week(860))) == "The agent's figure is $860 a month more than your wage budget has left; money or wages would have to move.")
        #expect(line(.timesPresentWage(2.44)) == "The agent's figure is 2.4 times his wage now.")
    }

    @Test func aPastedPlayer() {
        #expect(AdvisorText.candidateWageLead(level: .wouldStart, slot: .D_R) == "For wages he is set beside your first eleven: he would start at right back.")
        #expect(AdvisorText.candidateWageLead(level: .wouldMakeSecond, slot: .ST_C) == "For wages he is set beside your second eleven: he would make the second eleven at striker.")
        #expect(AdvisorText.candidateWageLead(level: .wouldCountAsCover, slot: .ST_C) == "For wages he is set beside your players in neither eleven: he would count as cover at striker.")
        #expect(AdvisorText.candidateWageLead(level: .belowCover, slot: .ST_C) == "For wages he is set beside your players in neither eleven: he would be below cover at striker.")
        #expect(AdvisorText.candidatePresentWage(perWeek: week(5536), money: money) == "He is paid $5,536 a month now.")
        #expect(AdvisorText.candidatePresentWage(perWeek: 0, money: money) == "He is paid no wage now.")
    }

    @Test func countsAndEvidence() {
        #expect(AdvisorText.notRecommendedLine(1) == "1 player not recommended for renewal")
        #expect(AdvisorText.notRecommendedLine(21) == "21 players not recommended for renewal")
        #expect(AdvisorText.notRenewingLine(1) == "1 player you are not renewing")
        #expect(AdvisorText.notRenewingLine(3) == "3 players you are not renewing")
        let rules = EngineParameters.fm27.wageRangeRules.value
        #expect(AdvisorText.contractsEvidenceNote(rules) == [
            AdvisorText.wageEvidenceSentence,
            "The shares of the wage budget are one author's rule of thumb for FM23: 7.5% for each of four key players, 4.3% for a starter and 2.7% for a backup.",
            "The wage budget, the wages spent and the most you can offer one player are the figures you typed from FMRTE.",
            "Other clubs can approach a player in his last 6 months; that is the game's rule (carried over from FM26).",
        ])
    }

    @Test func amountsWrittenAlikeAreWrittenOnce() {
        // Two weekly amounts that differ by pence but are both written $3,269 a month.
        let low = week(3269), high = week(3269) + 0.01
        #expect(low != high)
        let same = PaidRange(lowerQuartile: low, highest: high, count: 3)
        #expect(AdvisorText.wageGuideLines(guide(paid: same, shown: .range(low: low, high: high, setBy: .tierHighest)), money: money)
                == ["Your second eleven are all paid $3,269 a month (this tool's estimate of a reasonable wage)."])
        let ceiling = week(3400), low2 = week(3400) - 0.01
        #expect(AdvisorText.wageGuideLines(guide(paid: same, shown: .range(low: low2, high: ceiling, setBy: .ceiling)), money: money)
                == ["A reasonable wage is about $3,400 a month: what your second eleven are paid at the low end is also a backup's share of your wage budget (this tool's estimate)."])
        #expect(AdvisorText.wageGuideLines(guide(paid: same, shown: .range(low: low2, high: ceiling, setBy: .highestWage)), money: money)
                == ["A reasonable wage is about $3,400 a month: what your second eleven are paid at the low end is also the most you can offer one player (this tool's estimate)."])
        #expect(AdvisorText.wageGuideLines(guide(paid: same, shown: .upTo(week(1870), setBy: .ceiling)), money: money).first
                == "Up to $1,870 a month: a backup's share of your wage budget is below what your second eleven are all paid, $3,269 a month (this tool's estimate).")
        #expect(AdvisorText.wageGuideLines(guide(paid: same, shown: .upTo(week(1500), setBy: .highestWage)), money: money).first
                == "Up to $1,500 a month: the most you can offer one player is below what your second eleven are all paid, $3,269 a month.")
    }

    @Test func wordingsBeyondTheTable() {
        let first = guide(tier: .firstEleven, ceiling: week(5200), shown: .none)
        #expect(AdvisorText.wageGuideLines(first, money: money)[1]
                == "By one rule of thumb a key player's share of your wage budget is $5,200 a month, kept for four players (this tool's estimate).")
        #expect(AdvisorText.wageGuideLines(guide(shown: .upTo(week(1500), setBy: .highestWage)), money: money)
                == ["Up to $1,500 a month, the most you can offer one player; too few of your second eleven are paid a wage to read a range from them."])
    }
}
