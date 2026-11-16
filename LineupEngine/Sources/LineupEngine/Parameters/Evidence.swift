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
///
/// It is one pointer wide: the three are kept together off the stack and never change. `EngineParameters` holds about
/// a hundred of these and is handed down every call of the rating and selection code by value; with the values kept
/// inline it was 4.8 KB, and a planning test run on a test thread's small stack ran out of it.
public struct Parameter<Value: Sendable>: Sendable {
    private final class Storage: Sendable {
        let value: Value
        let evidence: Evidence
        let source: String

        init(value: Value, evidence: Evidence, source: String) {
            self.value = value; self.evidence = evidence; self.source = source
        }
    }

    private let storage: Storage

    public var value: Value { storage.value }
    public var evidence: Evidence { storage.evidence }
    public var source: String { storage.source }

    public init(_ value: Value, _ evidence: Evidence, source: String) {
        storage = Storage(value: value, evidence: evidence, source: source)
    }
}
