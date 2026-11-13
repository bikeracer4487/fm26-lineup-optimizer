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
    public var longName: String {
        switch self {
        case .GK: "goalkeeper"
        case .D_L: "left back"
        case .D_CL: "left centre-back"
        case .D_C: "centre-back"
        case .D_CR: "right centre-back"
        case .D_R: "right back"
        case .WB_L: "left wing-back"
        case .DM_L: "left defensive midfield"
        case .DM_C: "defensive midfield"
        case .DM_R: "right defensive midfield"
        case .WB_R: "right wing-back"
        case .M_L: "left midfield"
        case .M_CL: "left-centre midfield"
        case .M_C: "central midfield"
        case .M_CR: "right-centre midfield"
        case .M_R: "right midfield"
        case .AM_L: "left attacking midfield"
        case .AM_CL: "left-centre attacking midfield"
        case .AM_C: "central attacking midfield"
        case .AM_CR: "right-centre attacking midfield"
        case .AM_R: "right attacking midfield"
        case .ST_L: "left striker"
        case .ST_C: "striker"
        case .ST_R: "right striker"
        }
    }
}
