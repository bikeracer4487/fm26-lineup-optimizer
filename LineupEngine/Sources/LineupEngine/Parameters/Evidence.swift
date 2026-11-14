/// How well a tunable number is backed. Every parameter carries one.
public enum Evidence: String, Sendable, CaseIterable, Codable {
    case fm27Measured, fm27Official, fm27Observation, carriedOverFM26, derived

    /// The least well backed of `evidence`: derived, then carried over from FM26, FM27 observation, FM27 official and
    /// FM27 measured. Nil when the list is empty.
    public static func weakest(_ evidence: [Evidence]) -> Evidence? {
        evidence.max { strength($0) > strength($1) }
    }

    /// Higher is better backed.
    private static func strength(_ evidence: Evidence) -> Int {
        switch evidence {
        case .derived: 0
        case .carriedOverFM26: 1
        case .fm27Observation: 2
        case .fm27Official: 3
        case .fm27Measured: 4
        }
    }
}

/// A tunable value together with its evidence level and where it came from.
public struct Parameter<Value: Sendable>: Sendable {
    public let value: Value
    public let evidence: Evidence
    public let source: String

    public init(_ value: Value, _ evidence: Evidence, source: String) {
        self.value = value
        self.evidence = evidence
        self.source = source
    }
}
