/// How well a tunable number is backed. Every parameter carries one.
public enum Evidence: String, Sendable, CaseIterable, Codable {
    case fm27Measured, fm27Official, fm27Observation, carriedOverFM26, derived
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
