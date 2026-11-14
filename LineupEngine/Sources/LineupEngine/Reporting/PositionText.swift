/// Positions and slots in football words, for sentences: "left back", "centre-back", "defensive midfield". No
/// parentheses, so a name can sit inside them.
public enum PositionText {
    /// A position as the game's position ratings name it; it has no left-of-centre or right-of-centre distinction.
    public static func plain(_ position: Position) -> String {
        switch position {
        case .goalkeeper: "goalkeeper"
        case .defenderLeft: "left back"
        case .defenderCentral: "centre-back"
        case .defenderRight: "right back"
        case .wingBackLeft: "left wing-back"
        case .wingBackRight: "right wing-back"
        case .defensiveMidfielder: "defensive midfield"
        case .midfielderLeft: "left midfield"
        case .midfielderCentral: "central midfield"
        case .midfielderRight: "right midfield"
        case .attackingMidLeft: "left attacking midfield"
        case .attackingMidCentral: "central attacking midfield"
        case .attackingMidRight: "right attacking midfield"
        case .striker: "striker"
        }
    }

    /// A slot of the pitch, each row named left to right: "left centre-back" for D_CL.
    public static func plain(_ slot: SlotID) -> String {
        switch slot {
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
