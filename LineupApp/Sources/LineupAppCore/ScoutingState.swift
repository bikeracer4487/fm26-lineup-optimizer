import LineupEngine

/// The pasted players the owner has hidden on the Scouting screen. Kept in a file of its own, and the only thing about
/// a pasted player that is saved: for each, his name as pasted and his potential ability, by which the engine knows him
/// again in a later paste.
public struct ScoutingState: Equatable, Codable, Sendable {
    /// In the order they were hidden.
    public var hidden: [HiddenCandidate] = []

    public init() {}
}
