import AppKit
import LineupAppCore
import SwiftUI

/// Every colour, typeface and measure the app draws with. Views take their look from here
/// and nowhere else, so a change to the visual direction is a change to this file.
public enum Theme {

    // MARK: Colour

    /// The six named colours. Each has a light and a dark value and follows the system's
    /// appearance. Backgrounds, text and separators are the system's own.
    public enum Colour {
        /// The app's accent: selection, primary buttons, the chosen fixture.
        public static let hoopBlue = adaptive(light: 0x1F4E9A, dark: 0x6C9BEF)
        /// The pitch, and nothing else.
        public static let turf = adaptive(light: turfLight, dark: turfDark)
        /// The pitch's mown stripes: turf made darker by `turfStripeDarkening`.
        public static let turfStripe = adaptive(light: turfLight.darkened(by: turfStripeDarkening),
                                                dark: turfDark.darkened(by: turfStripeDarkening))
        /// Pitch markings and the text on player tokens.
        public static let chalk = adaptive(light: 0xEEF3EC, dark: 0xDDE5DA)
        /// High importance; a player who is out.
        public static let claret = adaptive(light: 0x9B2335, dark: 0xE0707F)
        /// Medium importance; a caution.
        public static let amber = adaptive(light: 0xB7791F, dark: 0xE3B25C)
        /// Sharpness fixtures and anything about sharpness.
        public static let teal = adaptive(light: 0x1E8C8C, dark: 0x5CC4C4)
        /// Low importance has no colour of its own: the system's secondary grey.
        public static let lowImportance = Color.secondary

        /// How much darker the pitch's mown stripes are than the turf.
        public static let turfStripeDarkening = 0.06
        static let turfLight = HexColour(0x2E6B4E)
        static let turfDark = HexColour(0x24523D)

        /// A colour that takes `light` in the aqua appearance and `dark` in dark aqua.
        static func adaptive(light: UInt32, dark: UInt32) -> Color {
            adaptive(light: HexColour(light), dark: HexColour(dark))
        }

        /// A colour that takes `light` in the aqua appearance and `dark` in dark aqua.
        static func adaptive(light: HexColour, dark: HexColour) -> Color {
            let lightColour = nsColour(light)
            let darkColour = nsColour(dark)
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColour : lightColour
            })
        }

        static func nsColour(_ hex: HexColour) -> NSColor {
            NSColor(srgbRed: hex.redFraction, green: hex.greenFraction, blue: hex.blueFraction, alpha: 1)
        }
    }

    // MARK: Type

    /// Sizes on a 1.25 scale from 13 points.
    public enum TypeSize {
        public static let base: CGFloat = 13
        public static let step1: CGFloat = 16
        public static let step2: CGFloat = 20
        public static let step3: CGFloat = 25
        public static let step4: CGFloat = 31
    }

    /// The three typefaces: DIN Condensed Bold for numbers, DIN Alternate Bold for screen
    /// titles, and the system typeface for everything to be read.
    public enum Typeface {
        /// PostScript name of the face for ratings, values, dates and slot codes.
        public static let numberFaceName = "DINCondensed-Bold"
        /// PostScript name of the face for screen titles.
        public static let titleFaceName = "DINAlternate-Bold"

        /// Ratings, values, dates on the fixture strip, slot codes on the pitch.
        public static func number(_ size: CGFloat) -> Font {
            din(numberFaceName, size: size)
        }

        /// A screen's title.
        public static func title(_ size: CGFloat = TypeSize.step4) -> Font {
            din(titleFaceName, size: size)
        }

        /// Names, reasons, labels and forms.
        public static func text(_ size: CGFloat = TypeSize.base, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }

        /// How far a number at `size` moves down to sit level with system text at `textSize` beside it.
        /// DIN Condensed puts its figures at the top of a tall line (its ascender is its cap height and its
        /// descender is deep), so centred in a table cell its figures sit higher than the system's letters.
        /// Taking the line leading as split above and below, this is the gap between where the two faces'
        /// capitals are centred in their lines; nothing when the face is missing.
        public static func numberDrop(_ size: CGFloat, besideTextOf textSize: CGFloat = TypeSize.base) -> CGFloat {
            guard let number = NSFont(name: numberFaceName, size: size) else { return 0 }
            func capitalsAboveCentre(_ font: NSFont) -> CGFloat {
                let line = font.ascender - font.descender + font.leading
                let capitalsCentre = font.leading / 2 + (font.ascender - font.capHeight) + font.capHeight / 2
                return line / 2 - capitalsCentre
            }
            return capitalsAboveCentre(number) - capitalsAboveCentre(NSFont.systemFont(ofSize: textSize))
        }

        /// Whether a DIN face is installed under its PostScript name.
        public static func isInstalled(_ faceName: String) -> Bool {
            NSFont(name: faceName, size: TypeSize.base) != nil
        }

        /// The named DIN face, or the system typeface's condensed bold design when the face
        /// cannot be found.
        static func din(_ faceName: String, size: CGFloat) -> Font {
            if isInstalled(faceName) {
                return .custom(faceName, fixedSize: size)
            }
            return .system(size: size, weight: .bold).width(.condensed)
        }
    }

    // MARK: Space

    /// The spacing scale, in points.
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    // MARK: Layout

    public enum Layout {
        /// The sidebar's width when the window opens.
        public static let sidebarWidth: CGFloat = 200
        /// The widest a block of sentences runs before it wraps.
        public static let readingWidth: CGFloat = 520
        /// The smallest window the screens are laid out for.
        public static let minimumWindow = CGSize(width: 900, height: 600)
        /// The window's size when the app opens, and the size of the pictures.
        public static let defaultWindow = CGSize(width: 1200, height: 780)
        /// The coloured bar beside a notice or a warning.
        public static let markerWidth: CGFloat = 3
        /// The search field above a table.
        public static let searchFieldWidth: CGFloat = 220
        /// The least height a table keeps, so the text above it cannot squeeze it away.
        public static let tableMinimumHeight: CGFloat = 160
        /// The field for a tactic's name.
        public static let nameFieldWidth: CGFloat = 240
        /// The height of a row of controls, kept whether it holds menus or a sentence, so what is below it stays put.
        public static let controlRowHeight: CGFloat = 24
        /// The sheet that adds or edits a fixture.
        public static let fixtureEditorSize = CGSize(width: 460, height: 360)
        /// The widest a setting's control runs, so a slider is not stretched across a wide window.
        public static let settingControlWidth: CGFloat = 360
        /// The field for the club's name or the path to FMRTE's settings file.
        public static let settingFieldWidth: CGFloat = 440
    }

    // MARK: Badges

    /// A small label in an importance's colour: its words in the colour, on a faint fill of it, so the words read in
    /// both appearances whatever the colour's lightness.
    public enum Badge {
        public static let fillOpacity: Double = 0.16
        public static let horizontalPadding: CGFloat = 7
        public static let verticalPadding: CGFloat = 2
        public static let cornerRadius: CGFloat = 4
    }

    // MARK: Pitch

    /// How a pitch is drawn: its markings, stripes and the tokens on it.
    public enum Pitch {
        /// The turf beyond the touchlines and goal lines.
        public static let margin: CGFloat = 8
        /// Corner rounding of the turf.
        public static let cornerRadius: CGFloat = 6
        /// The width of the chalk lines.
        public static let lineWidth: CGFloat = 1.5
        /// How strongly the chalk lines show against the turf.
        public static let lineOpacity: Double = 0.55
        /// The number of mown stripes from goal line to goal line.
        public static let stripeCount = 12
        /// The least size a pitch keeps, so two side by side stay legible.
        public static let minimumSize = CGSize(width: 300, height: 380)

        /// The markings as fractions of the pitch, from the Laws of the Game (a 105 by 68 metre pitch).
        public enum Markings {
            /// Penalty area: 40.32 metres across, 16.5 deep.
            public static let penaltyAreaWidth: CGFloat = 40.32 / 68
            public static let penaltyAreaDepth: CGFloat = 16.5 / 105
            /// Goal area: 18.32 metres across, 5.5 deep.
            public static let goalAreaWidth: CGFloat = 18.32 / 68
            public static let goalAreaDepth: CGFloat = 5.5 / 105
            /// Penalty mark: 11 metres out.
            public static let penaltyMarkDistance: CGFloat = 11 / 105
            /// Centre circle and penalty arc: 9.15 metres, as a fraction of the pitch's width.
            public static let circleRadius: CGFloat = 9.15 / 68
            /// The centre and penalty marks.
            public static let markRadius: CGFloat = 2
        }

        /// The space between neighbouring tokens.
        public static let tokenGap: CGFloat = 4
        /// Corner rounding of a token.
        public static let tokenCornerRadius: CGFloat = 5
        /// Padding inside a token.
        public static let tokenPadding: CGFloat = 3
        /// The height of an empty slot's token, which holds only its code.
        public static let emptyTokenHeight: CGFloat = 26
        /// The fill behind a filled slot's token: chalk at this opacity.
        public static let tokenFillOpacity: Double = 0.16
        /// The outline of an empty slot: chalk at this opacity, dashed.
        public static let emptyTokenOpacity: Double = 0.4
        public static let emptyTokenDash: [CGFloat] = [3, 3]
        public static let emptyTokenLineWidth: CGFloat = 1
        /// The outline of the slot the selected one turns into, or turns from.
        public static let linkedLineWidth: CGFloat = 2
        /// The most lines a role name takes under its slot's code. Two fit six rows in the default window; the
        /// longest names (four words) are cut, and shown in full in the role menu and the slot's help.
        public static let roleNameLines = 2
        /// How far a role name may shrink to fit its token, before it is cut.
        public static let roleNameMinimumScale: CGFloat = 0.85
    }

    // MARK: Tables

    /// Column widths for the tables. The squad table's are chosen so its ten columns fit beside the sidebar at the
    /// default window size: number columns are as narrow as their headings allow; the name and status columns are
    /// the only ones that grow, and share what a wider window gives.
    public enum TableColumnWidth {
        public static let nameMinimum: CGFloat = 140
        public static let nameIdeal: CGFloat = 176
        public static let squad: CGFloat = 64
        public static let age: CGFloat = 28
        public static let positions: CGFloat = 70
        public static let ability: CGFloat = 40
        public static let potential: CGFloat = 54
        public static let condition: CGFloat = 58
        public static let sharpness: CGFloat = 64
        public static let jadedness: CGFloat = 64
        public static let statusMinimum: CGFloat = 120
        public static let statusIdeal: CGFloat = 220

        /// The fixtures table. The opponent and tactic columns share what a wider window gives.
        public static let fixtureDate: CGFloat = 90
        public static let opponentMinimum: CGFloat = 140
        public static let opponentIdeal: CGFloat = 220
        public static let importance: CGFloat = 90
        public static let tacticMinimum: CGFloat = 120
        public static let tacticIdeal: CGFloat = 200
        public static let fixtureState: CGFloat = 160
        public static let fixtureActions: CGFloat = 120
    }
}
