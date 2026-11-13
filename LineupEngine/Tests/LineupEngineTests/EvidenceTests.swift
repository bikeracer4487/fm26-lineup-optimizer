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
