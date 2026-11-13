import LineupAppCore
import LineupEngine
import SwiftUI

/// Where each of the 24 slots sits on a pitch drawn from above with the attack at the top, and what it is called
/// there. Left-sided slots are on the left as the owner looks at the screen, as in the game's tactics screen.
public enum PitchLayout {
    /// The rows from the top: strikers, attacking midfield, midfield, defensive midfield with the wing-backs outside,
    /// defence, goalkeeper.
    public static let rowCount = 6
    public static let columnCount = 5

    /// Each row's share of the pitch's height when `slots` are drawn: a row with a slot in it takes a full share, so a
    /// magnet with the words beneath it fits, and a row with none a smaller one (`Theme.Pitch.emptyRowWeight`). With
    /// every slot drawn, as in the Tactics editor, the rows are equal.
    public static func rowWeights(for slots: [SlotID]) -> [CGFloat] {
        let used = Set(slots.map { place(of: $0).row })
        return (0..<rowCount).map { used.contains($0) ? 1 : Theme.Pitch.emptyRowWeight }
    }

    /// The row (0 at the top) and column (0 at the left) of each slot.
    public static func place(of slot: SlotID) -> (row: Int, column: Int) {
        switch slot {
        case .ST_L: (0, 1)
        case .ST_C: (0, 2)
        case .ST_R: (0, 3)
        case .AM_L: (1, 0)
        case .AM_CL: (1, 1)
        case .AM_C: (1, 2)
        case .AM_CR: (1, 3)
        case .AM_R: (1, 4)
        case .M_L: (2, 0)
        case .M_CL: (2, 1)
        case .M_C: (2, 2)
        case .M_CR: (2, 3)
        case .M_R: (2, 4)
        case .WB_L: (3, 0)
        case .DM_L: (3, 1)
        case .DM_C: (3, 2)
        case .DM_R: (3, 3)
        case .WB_R: (3, 4)
        case .D_L: (4, 0)
        case .D_CL: (4, 1)
        case .D_C: (4, 2)
        case .D_CR: (4, 3)
        case .D_R: (4, 4)
        case .GK: (5, 2)
        }
    }

    /// The slot's cell within `field`, the area inside the touchlines and goal lines, its rows weighted as given.
    static func cell(of slot: SlotID, in field: CGRect, rowWeights: [CGFloat]) -> CGRect {
        let (row, column) = place(of: slot)
        let total = rowWeights.reduce(0, +)
        let top = rowWeights[..<row].reduce(0, +) / total * field.height
        let height = rowWeights[row] / total * field.height
        let width = field.width / CGFloat(columnCount)
        return CGRect(x: field.minX + CGFloat(column) * width, y: field.minY + top, width: width, height: height)
    }
}

/// The 24 slots laid out as a pitch, attack at the top: a view for each slot it is given, placed in its row and
/// column on a pitch drawn in green marker. The Tactics editor gives it every slot; a team sheet gives it the eleven.
public struct PitchGrid<Token: View>: View {
    let slots: [SlotID]
    let aspectRatio: CGFloat
    let token: (SlotID) -> Token

    /// - Parameters:
    ///   - slots: the slots to draw a view for; the others are bare pitch.
    ///   - aspectRatio: the pitch's width to its height.
    ///   - token: the view for a slot. It is given its cell less the gap between slots, centred.
    public init(slots: [SlotID] = SlotID.allCases, aspectRatio: CGFloat = Theme.Pitch.aspectRatio,
                @ViewBuilder token: @escaping (SlotID) -> Token) {
        self.slots = slots
        self.aspectRatio = aspectRatio
        self.token = token
    }

    public var body: some View {
        let weights = PitchLayout.rowWeights(for: slots)
        GeometryReader { geometry in
            let field = CGRect(origin: .zero, size: geometry.size)
            ZStack(alignment: .topLeading) {
                BoardPitch()
                ForEach(slots, id: \.self) { slot in
                    let cell = PitchLayout.cell(of: slot, in: field, rowWeights: weights)
                    token(slot)
                        .frame(width: max(cell.width - Theme.Pitch.slotGap, 0),
                               height: max(cell.height - Theme.Pitch.slotGap, 0))
                        .position(x: cell.midX, y: cell.midY)
                }
            }
        }
        // Fit, never stretched: the largest pitch of its shape within the space given, and never below its least size.
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(minWidth: Theme.Pitch.minimumWidth, minHeight: Theme.Pitch.minimumWidth / aspectRatio)
    }
}

/// The pitch drawn on the board in green marker: touchlines and goal lines, the halfway line, the centre circle and
/// both penalty areas.
struct BoardPitch: View {
    var body: some View {
        let inset = Theme.Pitch.lineWidth / 2
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Pitch.cornerRadius)
                .strokeBorder(Theme.Colour.markerGreen, lineWidth: Theme.Pitch.lineWidth)
            PitchMarkings()
                .stroke(Theme.Colour.markerGreen, lineWidth: Theme.Pitch.lineWidth)
                .padding(inset)
        }
        .accessibilityHidden(true)
    }
}

/// The lines inside the pitch's outline, drawn in `rect`, attack at the top.
struct PitchMarkings: Shape {
    func path(in rect: CGRect) -> Path {
        typealias M = Theme.Pitch.Markings
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        let radius = M.circleDiameter * rect.width / 2
        path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2))
        let width = M.penaltyAreaWidth * rect.width
        let depth = M.penaltyAreaDepth * rect.height
        let corner = Theme.Pitch.boxCornerRadius
        // Each penalty area: three sides from the goal line, its far corners rounded.
        for top in [true, false] {
            let goalLine = top ? rect.minY : rect.maxY
            let far = top ? rect.minY + depth : rect.maxY - depth
            let toward: CGFloat = top ? -1 : 1
            let left = rect.midX - width / 2
            let right = rect.midX + width / 2
            path.move(to: CGPoint(x: left, y: goalLine))
            path.addLine(to: CGPoint(x: left, y: far + toward * corner))
            path.addQuadCurve(to: CGPoint(x: left + corner, y: far), control: CGPoint(x: left, y: far))
            path.addLine(to: CGPoint(x: right - corner, y: far))
            path.addQuadCurve(to: CGPoint(x: right, y: far + toward * corner), control: CGPoint(x: right, y: far))
            path.addLine(to: CGPoint(x: right, y: goalLine))
        }
        return path
    }
}
