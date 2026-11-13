import SwiftUI

// The names the screens used before the board look, on the board's values, so the app builds while the screens move
// over one at a time. Removed once no screen uses them.
extension Theme.Colour {
    static let hoopBlue = markerBlue
    static let turf = markerGreen
    static let turfStripe = markerGreen
    static let chalk = board
    static let claret = redText
    static let amber = amberText
    static let teal = greenText
    static let lowImportance = mutedInk
    static let separator = faintRule
}

extension Theme.TypeSize {
    static let base: CGFloat = body
    static let step1: CGFloat = noteHeading
    static let step2: CGFloat = 20
    static let step3: CGFloat = boardTitle
    static let step4: CGFloat = title
}

extension Theme.Typeface {
    static func number(_ size: CGFloat) -> Font { text(size, weight: .bold) }
    static func title(_ size: CGFloat = Theme.TypeSize.title) -> Font { display(size) }
    static func numberDrop(_ size: CGFloat, besideTextOf textSize: CGFloat = Theme.TypeSize.body) -> CGFloat { 0 }
}

extension Theme.Layout {
    static let markerWidth: CGFloat = 3
    static let fixtureEditorSize = CGSize(width: 460, height: 360)
}

extension Theme {
    enum Badge {
        static let fillOpacity: Double = 0.16
        static let horizontalPadding: CGFloat = 7
        static let verticalPadding: CGFloat = 2
        static let cornerRadius: CGFloat = 4
    }

    enum TableColumnWidth {
        static let nameMinimum: CGFloat = 140
        static let nameIdeal: CGFloat = 176
        static let squad: CGFloat = 64
        static let age: CGFloat = 28
        static let positions: CGFloat = 70
        static let ability: CGFloat = 40
        static let potential: CGFloat = 54
        static let condition: CGFloat = 58
        static let sharpness: CGFloat = 64
        static let jadedness: CGFloat = 64
        static let statusMinimum: CGFloat = 120
        static let statusIdeal: CGFloat = 220
        static let fixtureDate: CGFloat = 90
        static let opponentMinimum: CGFloat = 140
        static let opponentIdeal: CGFloat = 220
        static let importance: CGFloat = 90
        static let tacticMinimum: CGFloat = 120
        static let tacticIdeal: CGFloat = 200
        static let fixtureState: CGFloat = 160
        static let fixtureActions: CGFloat = 120
    }
}

extension Theme.Pitch {
    static let margin: CGFloat = 8
    static let lineOpacity: Double = 1
    static let stripeCount = 12
    static let tokenGap: CGFloat = 4
    static let tokenCornerRadius: CGFloat = 5
    static let tokenPadding: CGFloat = 3
    static let emptyTokenHeight: CGFloat = 26
    static let tokenFillOpacity: Double = 0.16
    static let emptyTokenOpacity: Double = 0.4
    static let emptyTokenDash: [CGFloat] = [3, 3]
    static let emptyTokenLineWidth: CGFloat = 1
    static let linkedLineWidth: CGFloat = 2
    static let roleNameMinimumScale: CGFloat = 0.85
}

extension Theme.Pitch.Markings {
    static let goalAreaWidth: CGFloat = 18.32 / 68
    static let goalAreaDepth: CGFloat = 5.5 / 105
    static let penaltyMarkDistance: CGFloat = 11 / 105
    static let circleRadius: CGFloat = 9.15 / 68
    static let markRadius: CGFloat = 2
}

extension Theme.Match {
    static let detailWidth: CGFloat = 380
    static let stripCellWidth: CGFloat = 140
    static let stripCellPadding: CGFloat = 8
    static let stripCellCornerRadius: CGFloat = 6
    static let chosenLineWidth: CGFloat = 2
    static let otherLineWidth: CGFloat = 1
    static let chosenFillOpacity: Double = 0.12
    static let tokenSlotSize: CGFloat = 13
    static let tokenNameSize: CGFloat = 13
    static let tokenValueSize: CGFloat = 20
    static let tokenSlotOpacity: Double = 0.75
    static let tokenNameMinimumScale: CGFloat = 0.8
    static let markSize: CGFloat = 10
    static let cautionLineWidth: CGFloat = 2
    static let youthMarkSize: CGFloat = 11
    static let youthMarkCornerRadius: CGFloat = 2
    static let youthMarkLineWidth: CGFloat = 1
    static let youthMarkPadding: CGFloat = 2
    static let figureLabelWidth: CGFloat = 150
    static let figureWidth: CGFloat = 56
}
