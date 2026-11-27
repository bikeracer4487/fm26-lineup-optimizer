import Testing
@testable import LineupEngine

@Suite struct AdvisorTextRenewalTests {
    func worth(slot: SlotID, age: Int = 26, ability: Int = 90, ahead: WorthAhead, shareToday: Double,
               share: Double, line: Double = 0.95) -> RenewalWorth {
        RenewalWorth(player: PlayerID(key: "a"), slot: slot, isGoalkeeperSlot: slot == .GK, age: age, ability: ability,
                     ahead: ahead, shareToday: shareToday, share: share, meetsStandard: share > line, line: line,
                     basis: .derived)
    }

    @Test func aWorthToday() {
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 1.029, share: 1.029))
                == "Rates 2.9% above the average of your first eleven, at centre-back.")
        #expect(AdvisorText.worthLine(worth(slot: .DM_R, ahead: .today, shareToday: 0.894, share: 0.894))
                == "Rates 10.6% under the average of your first eleven, at right defensive midfield.")
        #expect(AdvisorText.worthLine(worth(slot: .GK, ahead: .today, shareToday: 1.029, share: 1.029))
                == "Rates 2.9% above the average of your first eleven by ability, at goalkeeper.")
        #expect(AdvisorText.worthLine(worth(slot: .GK, ahead: .today, shareToday: 0.894, share: 0.894))
                == "Rates 10.6% under the average of your first eleven by ability, at goalkeeper.")
    }

    @Test func aWorthAtHisReach() {
        #expect(AdvisorText.worthLine(worth(slot: .AM_L, age: 20, ability: 79, ahead: .reach(109.2), shareToday: 0.9,
                                            share: 1.078))
                == "Ability 79, could reach about 109 (this tool's estimate): that would rate 7.8% above the average of your first eleven, at left attacking midfield.")
        #expect(AdvisorText.worthLine(worth(slot: .AM_L, age: 20, ability: 60, ahead: .reach(80), shareToday: 0.8,
                                            share: 0.904))
                == "Ability 60, could reach about 80 (this tool's estimate): that would rate 9.6% under the average of your first eleven, at left attacking midfield.")
        #expect(AdvisorText.worthLine(worth(slot: .GK, age: 20, ability: 79, ahead: .reach(109.2), shareToday: 0.9,
                                            share: 1.078))
                == "Ability 79, could reach about 109 (this tool's estimate): that would rate 7.8% above the average of your first eleven by ability, at goalkeeper.")
    }

    @Test func aWorthAfterAFall() {
        #expect(AdvisorText.worthLine(worth(slot: .DM_R, age: 30, ability: 70, ahead: .decline(to: 64, seasons: 2),
                                            shareToday: 0.936, share: 0.896))
                == "He is 30. This tool expects him to lose about 6 points of ability over the next two seasons, from 70 to about 64 (its own estimate: no test measures decline): that would rate 10.4% under the average of your first eleven, at right defensive midfield. Rates 6.4% under it today.")
        #expect(AdvisorText.worthLine(worth(slot: .GK, age: 30, ability: 70, ahead: .decline(to: 64, seasons: 2),
                                            shareToday: 0.936, share: 0.896))
                == "He is 30. This tool expects him to lose about 6 points of ability over the next two seasons, from 70 to about 64 (its own estimate: no test measures decline): that would rate 10.4% under the average of your first eleven by ability, at goalkeeper. Rates 6.4% under it today.")
        // Above the standard today, and the seasons from the rules: one, words up to ten, digits above.
        #expect(AdvisorText.worthLine(worth(slot: .D_C, age: 35, ability: 150, ahead: .decline(to: 141, seasons: 1),
                                            shareToday: 1.2, share: 1.13))
                == "He is 35. This tool expects him to lose about 9 points of ability over the next season, from 150 to about 141 (its own estimate: no test measures decline): that would rate 13.0% above the average of your first eleven, at centre-back. Rates 20.0% above it today.")
        #expect(AdvisorText.worthLine(worth(slot: .D_C, age: 30, ability: 150, ahead: .decline(to: 120, seasons: 10),
                                            shareToday: 1.2, share: 1.13)).contains("over the next ten seasons, from 150 to about 120"))
        #expect(AdvisorText.worthLine(worth(slot: .D_C, age: 30, ability: 150, ahead: .decline(to: 117, seasons: 11),
                                            shareToday: 1.2, share: 1.13)).contains("over the next 11 seasons, from 150 to about 117"))
    }

    @Test func aGapThatRoundsToNothingIsLevelWith() {
        // Exactly the standard, a hair under and a hair over: none of them "0.0%".
        for share in [1, 0.99996, 1.00004] {
            #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: share, share: share))
                    == "Rates level with the average of your first eleven, at centre-back.", "\(share)")
            #expect(AdvisorText.worthLine(worth(slot: .GK, ahead: .today, shareToday: share, share: share))
                    == "Rates level with the average of your first eleven by ability, at goalkeeper.", "\(share)")
        }
        #expect(AdvisorText.worthLine(worth(slot: .AM_L, age: 20, ability: 60, ahead: .reach(80), shareToday: 0.8,
                                            share: 0.99996))
                == "Ability 60, could reach about 80 (this tool's estimate): that would rate level with the average of your first eleven, at left attacking midfield.")
        #expect(AdvisorText.worthLine(worth(slot: .DM_R, age: 30, ability: 70, ahead: .decline(to: 64, seasons: 2),
                                            shareToday: 1.0001, share: 0.99996))
                == "He is 30. This tool expects him to lose about 6 points of ability over the next two seasons, from 70 to about 64 (its own estimate: no test measures decline): that would rate level with the average of your first eleven, at right defensive midfield. Rates level with it today.")
        // A gap of 0.06% is not nothing.
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 0.9994, share: 0.9994))
                == "Rates 0.1% under the average of your first eleven, at centre-back.")
    }

    @Test func aGapThatReadsAsTheLinesOwnIsWrittenToTwoDecimals() {
        // Either side of the line, 5% under: one decimal would read "5.0% under" for both.
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 0.9504, share: 0.9504))
                == "Rates 4.96% under the average of your first eleven, at centre-back.")
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 0.9496, share: 0.9496))
                == "Rates 5.04% under the average of your first eleven, at centre-back.")
        #expect(AdvisorText.worthLine(worth(slot: .GK, ahead: .today, shareToday: 0.9504, share: 0.9504))
                == "Rates 4.96% under the average of your first eleven by ability, at goalkeeper.")
        #expect(AdvisorText.worthLine(worth(slot: .GK, ahead: .today, shareToday: 0.9496, share: 0.9496))
                == "Rates 5.04% under the average of your first eleven by ability, at goalkeeper.")
        #expect(AdvisorText.worthLine(worth(slot: .AM_L, age: 20, ability: 60, ahead: .reach(80), shareToday: 0.8,
                                            share: 0.9496))
                == "Ability 60, could reach about 80 (this tool's estimate): that would rate 5.04% under the average of your first eleven, at left attacking midfield.")
        // Exactly at the line, and a gap that reads otherwise, as before.
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 0.95, share: 0.95))
                == "Rates 5.00% under the average of your first eleven, at centre-back.")
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 0.9444, share: 0.9444))
                == "Rates 5.6% under the average of your first eleven, at centre-back.")
        // 5% above is on no line's edge.
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 1.0504, share: 1.0504))
                == "Rates 5.0% above the average of your first eleven, at centre-back.")
        // With the line at 10% under, 5% under is nowhere near it, and 10% under is.
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 0.9504, share: 0.9504, line: 0.9))
                == "Rates 5.0% under the average of your first eleven, at centre-back.")
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 0.8996, share: 0.8996, line: 0.9))
                == "Rates 10.04% under the average of your first eleven, at centre-back.")
    }

    @Test func aReachFlooredAtTodaySaysSo() {
        // His reach would rate lower by ability than he rates today, so he is held at today's share.
        #expect(AdvisorText.worthLine(worth(slot: .AM_L, age: 21, ability: 95, ahead: .reach(98.2), shareToday: 0.97,
                                            share: 0.97))
                == "Ability 95, could reach about 98 (this tool's estimate), which by ability would rate lower than he rates today: 3.0% under the average of your first eleven, at left attacking midfield.")
        #expect(AdvisorText.worthLine(worth(slot: .AM_L, age: 21, ability: 95, ahead: .reach(98.2), shareToday: 0.99996,
                                            share: 0.99996))
                == "Ability 95, could reach about 98 (this tool's estimate), which by ability would rate lower than he rates today: level with the average of your first eleven, at left attacking midfield.")
        #expect(AdvisorText.worthLine(worth(slot: .AM_L, age: 21, ability: 95, ahead: .reach(98.2), shareToday: 0.9496,
                                            share: 0.9496))
                == "Ability 95, could reach about 98 (this tool's estimate), which by ability would rate lower than he rates today: 5.04% under the average of your first eleven, at left attacking midfield.")
        // A reach that lifts him above today reads as before.
        #expect(AdvisorText.worthLine(worth(slot: .AM_L, age: 21, ability: 95, ahead: .reach(98.2), shareToday: 0.97,
                                            share: 0.98))
                == "Ability 95, could reach about 98 (this tool's estimate): that would rate 2.0% under the average of your first eleven, at left attacking midfield.")
    }
}
