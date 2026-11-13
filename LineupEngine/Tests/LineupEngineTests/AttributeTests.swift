import Testing
@testable import LineupEngine

@Test func everyAttributeColumnInTheCaptureMapsToAnAttribute() throws {
    let paths = try Fixtures.gridColumns("u21", grid: "SearchPlayersColumns")
        .filter { $0.split(separator: ".").first?.hasSuffix("Attributes") == true }
    #expect(paths.count == 62)
    #expect(Set(paths.compactMap(Attribute.fromFMRTEPath)).count == 62)
    #expect(Attribute.allCases.count == 62)
}

@Test func renamedAttributesUseCanonicalNames() {
    #expect(Attribute.fromFMRTEPath("GoalKeeperAttributes.AerialAbility")?.rawValue == "Aerial Reach")
    #expect(Attribute.fromFMRTEPath("MentalAttributes.Workrate")?.rawValue == "Work Rate")
    #expect(Attribute.fromFMRTEPath("PhysicalAttributes.Jumping")?.rawValue == "Jumping Reach")
    #expect(Attribute.fromFMRTEPath("HiddenAttributes.InjuryProness")?.rawValue == "Injury Proneness")
    #expect(Attribute.fromFMRTEPath("Contract.Club") == nil)
}

@Test func catalogNameLookupMatchesRawValue() {
    #expect(Attribute(catalogName: "Balance") == .balance)
    #expect(Attribute(catalogName: "Work Rate") == .workRate)
    #expect(Attribute(catalogName: "Workrate") == nil)
}
