import LineupEngine

extension SlotID {
    /// The slot's short name on screen: its code with a space for the underscore ("D L", "AM C", "GK"), without the
    /// "C" of the two positions that have no sides (striker and defensive midfield).
    public var displayName: String {
        switch self {
        case .ST_C: "ST"
        case .DM_C: "DM"
        default: rawValue.replacingOccurrences(of: "_", with: " ")
        }
    }

    /// The slot in words, for sentences: "left back", "central attacking midfield", "striker". Each row of the pitch
    /// is named the same way, left to right; no parentheses, so a name can sit inside them ("Wing-Back (left back)").
    public var longName: String { PositionText.plain(self) }
}
