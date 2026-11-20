import LineupEngine

/// The league table the owner pasted, the format he entered and the day he pasted it. Kept in a file of its own.
public struct LeagueState: Equatable, Codable, Sendable {
    /// How many places are promoted, play off and are relegated; nil until all three are entered and fit the table.
    public var format: LeagueFormat?
    public var table: LeagueTable?
    /// The game's date when the table was pasted.
    public var pastedOn: Day?

    public init() {}
}

/// What the League screen's reading is, worked out from the state each time.
public enum LeagueReadingState: Equatable, Sendable {
    case noTable, noFormat
    case read(LeagueReading)
    /// The engine's sentence for why the table and format cannot be read.
    case failed(String)
}

/// The three numbers as the owner is typing them: any may still be blank.
public struct LeagueFormatDraft: Equatable, Sendable {
    public var promoted, playOffs, relegated: Int?

    public init(promoted: Int? = nil, playOffs: Int? = nil, relegated: Int? = nil) {
        self.promoted = promoted; self.playOffs = playOffs; self.relegated = relegated
    }

    public init(_ format: LeagueFormat?) {
        self.init(promoted: format?.promoted, playOffs: format?.playOffs, relegated: format?.relegated)
    }

    /// The format, when all three are entered.
    var format: LeagueFormat? {
        guard let promoted, let playOffs, let relegated else { return nil }
        return LeagueFormat(promoted: promoted, playOffs: playOffs, relegated: relegated)
    }
}
