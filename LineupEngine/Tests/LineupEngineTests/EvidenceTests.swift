import Testing
@testable import LineupEngine

@Test func parameterCarriesItsEvidence() {
    let p = Parameter(0.85, .carriedOverFM26, source: "docs/Research/physical-condition.md")
    #expect(p.value == 0.85)
    #expect(p.evidence == .carriedOverFM26)
    #expect(!p.source.isEmpty)
}

@Test func evidenceHasFiveLevels() {
    #expect(Evidence.allCases.map(\.rawValue) ==
        ["fm27Measured", "fm27Official", "fm27Observation", "carriedOverFM26", "derived"])
}

@Test func weakestOrdersDerivedBelowCarriedOverBelowFM27() {
    // Weakest to strongest: derived, carried over from FM26, FM27 observation, FM27 official, FM27 measured.
    #expect(Evidence.weakest(Evidence.allCases) == .derived)
    #expect(Evidence.weakest([.fm27Measured, .carriedOverFM26, .fm27Observation]) == .carriedOverFM26)
    #expect(Evidence.weakest([.fm27Official, .fm27Observation]) == .fm27Observation)
    #expect(Evidence.weakest([.fm27Measured, .fm27Official]) == .fm27Official)
    #expect(Evidence.weakest([.fm27Measured]) == .fm27Measured)
    #expect(Evidence.weakest([.fm27Observation, .derived, .fm27Measured]) == .derived)
}

@Test func weakestOfNothingIsNil() {
    #expect(Evidence.weakest([]) == nil)
}
