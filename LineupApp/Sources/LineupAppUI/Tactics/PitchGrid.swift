import LineupAppCore
import LineupEngine
import SwiftUI

/// Where each of the 24 slots sits on a pitch drawn from above with the attack at the top, and what it is called
/// there. Left-sided slots are on the left as the owner looks at the screen, as in the game's tactics screen.
public enum PitchLayout {
    /// Each row's share of the pitch's height, from the top: strikers, attacking midfield, midfield, defensive
    /// midfield with the wing-backs outside, defence, goalkeeper. Equal, so a token with a two-line role name fits
    /// every row; the goalkeeper's row then lies within his penalty area.
    public static let rowWeights: [CGFloat] = [1, 1, 1, 1, 1, 1]
    public static let columnCount = 5

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

    /// The slot's cell within `field`, the area inside the touchlines and goal lines.
    static func cell(of slot: SlotID, in field: CGRect) -> CGRect {
        let (row, column) = place(of: slot)
        let total = rowWeights.reduce(0, +)
        let top = rowWeights[..<row].reduce(0, +) / total * field.height
        let height = rowWeights[row] / total * field.height
        let width = field.width / CGFloat(columnCount)
        return CGRect(x: field.minX + CGFloat(column) * width, y: field.minY + top, width: width, height: height)
    }
}

/// The 24 slots laid out as a pitch, attack at the top: a view for each slot it is given, placed in its row and
/// column on the turf with chalk markings. The Tactics editor gives it every slot; a team sheet gives it the eleven.
public struct PitchGrid<Token: View>: View {
    let slots: [SlotID]
    let token: (SlotID) -> Token

    /// - Parameters:
    ///   - slots: the slots to draw a token for; the others are bare turf.
    ///   - token: the view for a slot. It is given its cell less the gap between tokens, centred.
    public init(slots: [SlotID] = SlotID.allCases, @ViewBuilder token: @escaping (SlotID) -> Token) {
        self.slots = slots
        self.token = token
    }

    public var body: some View {
        GeometryReader { geometry in
            let field = CGRect(origin: .zero, size: geometry.size)
                .insetBy(dx: Theme.Pitch.margin, dy: Theme.Pitch.margin)
            ZStack(alignment: .topLeading) {
                Turf()
                ForEach(slots, id: \.self) { slot in
                    let cell = PitchLayout.cell(of: slot, in: field)
                    token(slot)
                        .frame(width: max(cell.width - Theme.Pitch.tokenGap, 0),
                               height: max(cell.height - Theme.Pitch.tokenGap, 0))
                        .position(x: cell.midX, y: cell.midY)
                }
            }
        }
        .frame(minWidth: Theme.Pitch.minimumSize.width, minHeight: Theme.Pitch.minimumSize.height)
    }
}

/// The turf with its mown stripes and chalk markings.
struct Turf: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Pitch.cornerRadius)
            .fill(Theme.Colour.turf)
            .overlay {
                MownStripes(count: Theme.Pitch.stripeCount)
                    .fill(Theme.Colour.turfStripe)
            }
            .overlay {
                PitchMarkings()
                    .stroke(Theme.Colour.chalk.opacity(Theme.Pitch.lineOpacity), lineWidth: Theme.Pitch.lineWidth)
                    .padding(Theme.Pitch.margin)
            }
            .overlay {
                PitchMarks()
                    .fill(Theme.Colour.chalk.opacity(Theme.Pitch.lineOpacity))
                    .padding(Theme.Pitch.margin)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Pitch.cornerRadius))
            .accessibilityHidden(true)
    }
}

/// Every other band of `count` across the pitch.
struct MownStripes: Shape {
    let count: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let height = rect.height / CGFloat(count)
        for band in stride(from: 1, to: count, by: 2) {
            path.addRect(CGRect(x: rect.minX, y: rect.minY + CGFloat(band) * height, width: rect.width, height: height))
        }
        return path
    }
}

/// The lines of a pitch drawn in `rect`, the area inside the touchlines and goal lines, attack at the top.
struct PitchMarkings: Shape {
    func path(in rect: CGRect) -> Path {
        typealias M = Theme.Pitch.Markings
        var path = Path()
        path.addRect(rect)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        let radius = M.circleRadius * rect.width
        path.addEllipse(in: CGRect(x: rect.midX - radius, y: rect.midY - radius, width: radius * 2, height: radius * 2))

        for end in [PitchEnd.top, .bottom] {
            path.addRect(end.box(width: M.penaltyAreaWidth, depth: M.penaltyAreaDepth, in: rect))
            path.addRect(end.box(width: M.goalAreaWidth, depth: M.goalAreaDepth, in: rect))
            // The arc of the penalty area: the part of the circle round the penalty mark outside the area.
            let mark = end.point(atDepth: M.penaltyMarkDistance, in: rect)
            let beyond = (M.penaltyAreaDepth - M.penaltyMarkDistance) * rect.height
            guard beyond < radius else { continue }
            let half = acos(beyond / radius)
            let outwards: Double = end == .top ? .pi / 2 : -.pi / 2
            path.addArc(center: mark, radius: radius, startAngle: .radians(outwards - half),
                        endAngle: .radians(outwards + half), clockwise: false)
        }
        return path
    }
}

/// The centre mark and the two penalty marks.
struct PitchMarks: Shape {
    func path(in rect: CGRect) -> Path {
        typealias M = Theme.Pitch.Markings
        var path = Path()
        let points = [CGPoint(x: rect.midX, y: rect.midY)]
            + [PitchEnd.top, .bottom].map { $0.point(atDepth: M.penaltyMarkDistance, in: rect) }
        for point in points {
            path.addEllipse(in: CGRect(x: point.x - M.markRadius, y: point.y - M.markRadius,
                                       width: M.markRadius * 2, height: M.markRadius * 2))
        }
        return path
    }
}

/// One end of the pitch.
enum PitchEnd {
    case top, bottom

    /// A box against this goal line, centred, with its width a fraction of the pitch's width and its depth a
    /// fraction of its length.
    func box(width: CGFloat, depth: CGFloat, in rect: CGRect) -> CGRect {
        let size = CGSize(width: width * rect.width, height: depth * rect.height)
        let y = self == .top ? rect.minY : rect.maxY - size.height
        return CGRect(x: rect.midX - size.width / 2, y: y, width: size.width, height: size.height)
    }

    /// The point on the pitch's long axis `depth` of its length from this goal line.
    func point(atDepth depth: CGFloat, in rect: CGRect) -> CGPoint {
        let distance = depth * rect.height
        return CGPoint(x: rect.midX, y: self == .top ? rect.minY + distance : rect.maxY - distance)
    }
}
