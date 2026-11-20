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

    /// What a field shows: the number in digits with no grouping, or nothing when it is blank.
    public func text(_ field: LeagueFormatField) -> String {
        self[field].map { String($0) } ?? ""
    }

    /// Sets a field from what was typed in it: the digits of the text are the number, and text with no digit is blank,
    /// so a letter typed never shows and nothing is negative from the keyboard. Digits too many to hold leave it blank.
    public mutating func set(_ field: LeagueFormatField, text: String) {
        let digits = text.filter { $0.isASCII && $0.isNumber }
        self[field] = digits.isEmpty ? nil : Int(digits)
    }

    private subscript(field: LeagueFormatField) -> Int? {
        get {
            switch field {
            case .promoted: promoted
            case .playOffs: playOffs
            case .relegated: relegated
            }
        }
        set {
            switch field {
            case .promoted: promoted = newValue
            case .playOffs: playOffs = newValue
            case .relegated: relegated = newValue
            }
        }
    }

    /// The format, when all three are entered.
    var format: LeagueFormat? {
        guard let promoted, let playOffs, let relegated else { return nil }
        return LeagueFormat(promoted: promoted, playOffs: playOffs, relegated: relegated)
    }
}
