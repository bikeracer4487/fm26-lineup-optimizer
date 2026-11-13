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
    }

    // MARK: Tables

    /// Column widths for the squad table, chosen so its ten columns fit beside the sidebar at the default
    /// window size. Number columns are as narrow as their headings allow; the name and status columns are the
    /// only ones that grow, and share what a wider window gives.
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
    }
}
