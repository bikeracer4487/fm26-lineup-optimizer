import Testing
@testable import LineupEngine

@Suite struct AdvisorTextRenewalTests {
    func worth(slot: SlotID, age: Int = 26, ability: Int = 90, ahead: WorthAhead, shareToday: Double,
               share: Double) -> RenewalWorth {
        RenewalWorth(player: PlayerID(key: "a"), slot: slot, isGoalkeeperSlot: slot == .GK, age: age, ability: ability,
                     ahead: ahead, shareToday: shareToday, share: share, meetsStandard: share > 0.95, basis: .derived)
    }

    @Test func aWorthToday() {
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 1.029, share: 1.029))
                == "Rates 2.9% above the average of your first eleven, at centre-back.")
        #expect(AdvisorText.worthLine(worth(slot: .DM_R, ahead: .today, shareToday: 0.894, share: 0.894))
                == "Rates 10.6% under the average of your first eleven, at right defensive midfield.")
        // Exactly the standard reads as above.
        #expect(AdvisorText.worthLine(worth(slot: .D_C, ahead: .today, shareToday: 1, share: 1))
                == "Rates 0.0% above the average of your first eleven, at centre-back.")
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
}
