import AppKit
import CoreText
import LineupAppCore
import LineupEngine
import SwiftUI

/// Every colour, typeface and measure the app draws with: the Tactics board of the visual direction
/// (docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md). Views take their look from here and nowhere
/// else, so a change to the direction is a change to this file.
public enum Theme {

    // MARK: Colour

    /// The direction's colours. Each has one value in light and dark appearance alike: the board is white whatever
    /// the system is set to.
    public enum Colour {
        /// The window behind the board.
        public static let wall = hex(0xDDE2E8)
        /// The board's aluminium frame.
        public static let frame = hex(0xB9C0CA)
        /// The board, and behind text on the pitch.
        public static let board = hex(0xFCFDFE)
        /// Text, rules, outlines, primary buttons.
        public static let ink = hex(0x1B1F27)
        /// Secondary text.
        public static let mutedInk = hex(0x5E6673)
        /// Lines between table rows.
        public static let faintRule = hex(0xDFE3E9)
        /// A meter's block that is not lit.
        public static let unlitBlock = hex(0xE3E7EC)
        /// The outline of a pill that is not selected.
        public static let pillOutline = hex(0xC9CFD8)
        /// The club's name, the selected thing, the one main action on a screen, values on the pitch.
        public static let markerBlue = hex(0x1F56C4)
        /// Pitch lines; good levels.
        public static let markerGreen = hex(0x2F8F5B)
        /// Marker green as text.
        public static let greenText = hex(0x1F6E44)
        /// Poor levels; a player who is out.
        public static let markerRed = hex(0xD43D3D)
        /// Marker red as text.
        public static let redText = hex(0xB42323)
        /// Middling levels; cautions.
        public static let markerAmber = hex(0xD99A1C)
        /// Marker amber as text.
        public static let amberText = hex(0x8A5A00)
        /// The goalkeeper's magnet, and its text.
        public static let magnetYellow = hex(0xF5C542)
        public static let magnetYellowText = hex(0x2A2000)
        /// Text on a magnet or a button filled with marker or ink.
        public static let onMarker = hex(0xFFFFFF)
        /// Inside a text field.
        public static let field = hex(0xFFFFFF)
        /// The magnet on a fixture's note that is not chosen.
        public static let idleMagnet = hex(0x9AA3AF)

        /// A magnet's colour and the colour of the letters on it, by the line the player is in.
        public static func magnet(_ line: PitchLine) -> (fill: Color, text: Color) {
            switch line {
            case .goalkeeper: (magnetYellow, magnetYellowText)
            case .defence: (markerBlue, onMarker)
            case .midfield: (markerGreen, onMarker)
            case .attack: (markerRed, onMarker)
            }
        }

        /// A meter's lit blocks, by level.
        public static func meter(_ level: MeterLevel) -> Color {
            switch level {
            case .good: markerGreen
            case .middling: markerAmber
            case .poor: markerRed
            }
        }

        /// The colour for an sRGB hex value.
        static func hex(_ value: UInt32) -> Color {
            let colour = HexColour(value)
            return Color(.sRGB, red: colour.redFraction, green: colour.greenFraction, blue: colour.blueFraction)
        }
    }

    /// A sticky note's paper and the colour of the writing on it.
    public struct NotePaper: Sendable {
        public let paper: Color
        public let text: Color
    }

    /// The four sticky notes.
    public enum Note {
        public static let blueGrey = NotePaper(paper: Colour.hex(0xDDE6F2), text: Colour.hex(0x1D2B40))
        public static let yellow = NotePaper(paper: Colour.hex(0xFFE27A), text: Colour.hex(0x3A2E00))
        public static let pink = NotePaper(paper: Colour.hex(0xFFD3DA), text: Colour.hex(0x4A0D18))
        public static let green = NotePaper(paper: Colour.hex(0xCFF0E0), text: Colour.hex(0x0E3B27))

        /// A fixture's note: blue-grey for low, yellow for medium, pink for high, green for sharpness.
        public static func fixture(_ importance: Importance) -> NotePaper {
            switch importance {
            case .low: blueGrey
            case .medium: yellow
            case .high: pink
            case .sharpness: green
            }
        }

        /// Today's date in the game.
        public static let today = yellow
        /// A notice, an import's summary, warnings.
        public static let warning = pink
    }

    // MARK: Type

    /// The direction's sizes.
    public enum TypeSize {
        public static let small: CGFloat = 12.5
        public static let caption: CGFloat = 13
        public static let body: CGFloat = 14
        public static let button: CGFloat = 15
        public static let noteHeading: CGFloat = 16
        public static let heading: CGFloat = 18
        public static let boardTitle: CGFloat = 24
        public static let title: CGFloat = 28
    }

    /// A weight on the faces' weight axis.
    public enum Weight: CGFloat, CaseIterable, Sendable {
        case regular = 400, medium = 500, semibold = 600, bold = 700, extraBold = 800
    }

    /// The two typefaces, shipped in the UI target's resources and registered for this process when first used.
    /// Both are variable fonts, so a weight is set on the weight axis of a font descriptor, here and nowhere else.
    public enum Typeface {
        /// Bricolage Grotesque (700 and 800) for titles, names and the figures a panel is about; Figtree (400 to
        /// 800) for everything else, with tabular digits.
        public enum Face: String, CaseIterable, Sendable {
            case display = "Bricolage Grotesque"
            case text = "Figtree"

            /// The face's file in the resources' Fonts folder.
            var fileName: String {
                switch self {
                case .display: "BricolageGrotesque.ttf"
                case .text: "Figtree.ttf"
                }
            }
        }

        /// Titles, players' names, headings on notes and the figures that are the point of a panel.
        public static func display(_ size: CGFloat, weight: Weight = .extraBold) -> Font {
            font(.display, size: size, weight: weight)
        }

        /// Everything else, every number in a table among it.
        public static func text(_ size: CGFloat = TypeSize.body, weight: Weight = .regular) -> Font {
            font(.text, size: size, weight: weight)
        }

        /// The face at the size and weight, or the system typeface at that weight when the face is not loaded.
        public static func font(_ face: Face, size: CGFloat, weight: Weight) -> Font {
            guard isLoaded(face) else {
                return .system(size: size, weight: systemWeight(weight)).monospacedDigit()
            }
            return Font(ctFont(face, size: size, weight: weight))
        }

        /// The face as a Core Text font: the weight axis set to `weight`; for Bricolage Grotesque the optical size
        /// axis set to the size, within its range, as a browser sets it; for Figtree, tabular digits.
        public static func ctFont(_ face: Face, size: CGFloat, weight: Weight) -> CTFont {
            var variation: [NSNumber: NSNumber] = [NSNumber(value: Axis.weight): NSNumber(value: Double(weight.rawValue))]
            var attributes: [CFString: Any] = [kCTFontFamilyNameAttribute: face.rawValue]
            switch face {
            case .display:
                variation[NSNumber(value: Axis.opticalSize)] = NSNumber(value: Double(min(max(size, Axis.opticalSizeRange.lowerBound),
                                                                                        Axis.opticalSizeRange.upperBound)))
            case .text:
                attributes[kCTFontFeatureSettingsAttribute] = [[kCTFontOpenTypeFeatureTag: "tnum",
                                                                kCTFontOpenTypeFeatureValue: 1]]
            }
            attributes[kCTFontVariationAttribute] = variation
            return CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes(attributes as CFDictionary), size, nil)
        }

        /// The variation axes the faces are drawn with, by their four-letter tags.
        enum Axis {
            static let weight: UInt32 = 0x7767_6874        // 'wght'
            static let opticalSize: UInt32 = 0x6F70_737A   // 'opsz'
            /// Bricolage Grotesque's optical sizes.
            static let opticalSizeRange: ClosedRange<CGFloat> = 12...96
        }

        /// The faces that could not be loaded, in the order above; registering them the first time this is read.
        public static var missingFaces: [Face] {
            Face.allCases.filter { !registered.contains($0) }
        }

        public static func isLoaded(_ face: Face) -> Bool {
            registered.contains(face)
        }

        /// Registers each face's file for this process, once, and keeps those Core Text then finds by name.
        static let registered: Set<Face> = {
            var loaded: Set<Face> = []
            let folder = Bundle.module.resourceURL?.appendingPathComponent("Fonts", isDirectory: true)
            for face in Face.allCases {
                guard let url = folder?.appendingPathComponent(face.fileName),
                      FileManager.default.fileExists(atPath: url.path) else { continue }
                // An error here is usually that the face is registered already; the check below decides.
                _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                let probe = CTFontCreateWithFontDescriptor(
                    CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: face.rawValue] as CFDictionary),
                    TypeSize.body, nil)
                if CTFontCopyFamilyName(probe) as String == face.rawValue {
                    loaded.insert(face)
                }
            }
            return loaded
        }()

        static func systemWeight(_ weight: Weight) -> Font.Weight {
            switch weight {
            case .regular: .regular
            case .medium: .medium
            case .semibold: .semibold
            case .bold: .bold
            case .extraBold: .heavy
            }
        }
    }

    // MARK: Space

    /// The spacing scale, in points.
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    // MARK: The board

    /// The wall, the frame and the board inside it.
    public enum Board {
        /// The wall showing around the frame.
        public static let wallMargin: CGFloat = 16
        public static let frameWidth: CGFloat = 8
        public static let cornerRadius: CGFloat = 14
        /// The window's buttons sit on the wall above the frame, in this much room.
        public static let titleBarClearance: CGFloat = 28
        /// Inside the frame, round what is written on the board.
        public static let topInset: CGFloat = 18
        public static let sideInset: CGFloat = 24
        public static let bottomInset: CGFloat = 16
        /// Between the top row, the notices and the screen.
        public static let rowGap: CGFloat = 14
        /// Between the club's name, the pills and the date.
        public static let topRowGap: CGFloat = 28
        /// The least height of the top row.
        public static let topRowHeight: CGFloat = 52
    }

    /// The club's name with its hand-drawn underline.
    public enum Underline {
        public static let thickness: CGFloat = 5
        public static let cornerRadius: CGFloat = 3
        public static let tilt: Double = -1.2
        public static let gap: CGFloat = 3
    }

    /// The screens as pills across the top, and the same pills elsewhere.
    public enum Pill {
        public static let height: CGFloat = 40
        public static let horizontalPadding: CGFloat = 16
        public static let lineWidth: CGFloat = 2
        public static let gap: CGFloat = 6
    }

    /// Buttons: primary is ink, secondary an ink outline, the main action marker blue.
    public enum Button {
        public static let height: CGFloat = 36
        public static let horizontalPadding: CGFloat = 14
        public static let cornerRadius: CGFloat = 8
        public static let lineWidth: CGFloat = 2
        /// The one main action on a screen is a little larger.
        public static let mainHeight: CGFloat = 42
        public static let mainHorizontalPadding: CGFloat = 18
        /// Pressed or disabled, a button shows at these opacities.
        public static let pressedOpacity: Double = 0.75
        public static let disabledOpacity: Double = 0.4
    }

    /// Tabs written on the board: the chosen one underlined in marker blue.
    public enum Tab {
        public static let height: CGFloat = 32
        public static let horizontalPadding: CGFloat = 12
        public static let underline: CGFloat = 4
        public static let gap: CGFloat = 6
    }

    /// Text fields: white with an ink outline.
    public enum Field {
        public static let height: CGFloat = 34
        public static let horizontalPadding: CGFloat = 10
        public static let cornerRadius: CGFloat = 8
        public static let lineWidth: CGFloat = 2
    }

    /// A magnet: a circle with a short hard shadow below.
    public enum Magnet {
        /// On a pitch.
        public static let diameter: CGFloat = 44
        public static let shadowOffset: CGFloat = 3
        public static let shadowOpacity: Double = 0.28
        /// The ring round the selected magnet, and the space between them.
        public static let ringWidth: CGFloat = 3
        public static let ringGap: CGFloat = 2
        /// Before a position in a table.
        public static let tableDiameter: CGFloat = 14
        public static let tableShadowOffset: CGFloat = 1
        public static let tableShadowOpacity: Double = 0.3
        /// At the top of a fixture's note, and of an import's card.
        public static let noteDiameter: CGFloat = 16
        public static let cardDiameter: CGFloat = 18
        public static let pinShadowOffset: CGFloat = 2
        public static let pinShadowOpacity: Double = 0.25
        /// An empty slot: a dashed circle.
        public static let emptyDash: [CGFloat] = [4, 3]
        public static let emptyLineWidth: CGFloat = 2
    }

    /// A sticky note: flat paper with a short hard shadow.
    public enum Sticky {
        public static let shadowOffset: CGFloat = 2
        public static let shadowOpacity: Double = 0.18
        public static let horizontalPadding: CGFloat = 12
        public static let verticalPadding: CGFloat = 10
        /// The chosen fixture's note has a blue foot this deep.
        public static let footHeight: CGFloat = 5
        /// The yellow note with the date leans this way.
        public static let todayTilt: Double = 1.5
        /// A note with an import's summary or with warnings leans this way, and is this wide beside the cards.
        public static let warningTilt: Double = -1.3
        public static let summaryWidth: CGFloat = 264
        /// A notice's note is no wider than this.
        public static let noticeMaximumWidth: CGFloat = 640
    }

    /// Cards on the board: an ink outline, no fill, no shadow.
    public enum Card {
        public static let lineWidth: CGFloat = 2
        public static let cornerRadius: CGFloat = 10
        public static let smallCornerRadius: CGFloat = 8
        public static let padding: CGFloat = 14
    }

    /// Tables written on the board.
    public enum Table {
        public static let headingRule: CGFloat = 3
        public static let rowRule: CGFloat = 1
        public static let rowHeight: CGFloat = 42
        public static let headingHeight: CGFloat = 34
        /// The space before a column that follows a number.
        public static let columnLead: CGFloat = 18
    }

    /// Condition and sharpness as five blocks.
    public enum Meter {
        public static let blockWidth: CGFloat = 12
        public static let blockHeight: CGFloat = 14
        public static let blockCornerRadius: CGFloat = 2
        public static let blockGap: CGFloat = 3
    }

    /// A status stamped beside a player.
    public enum Stamp {
        public static let lineWidth: CGFloat = 2
        public static let tilt: Double = -1.5
        public static let horizontalPadding: CGFloat = 10
        public static let verticalPadding: CGFloat = 1
    }

    /// A rule across the board, as under a table's headings or over "Left out".
    public enum Rule {
        public static let heavy: CGFloat = 3
    }

    // MARK: Layout

    public enum Layout {
        /// The widest a block of sentences runs before it wraps.
        public static let readingWidth: CGFloat = 560
        /// The smallest window the screens are laid out for: small enough to sit beside the game.
        public static let minimumWindow = CGSize(width: 760, height: 560)
        /// The window's size when the app opens, and the size of the pictures.
        public static let defaultWindow = CGSize(width: 1200, height: 800)
        /// What the wall, the frame and the board's insets take from the window's width before a screen has it.
        public static let boardChromeWidth: CGFloat = 2 * (Board.wallMargin + Board.frameWidth + Board.sideInset)
        /// Below this window width, Match Selection puts the detail under the pitch and Tactics stacks its two pitches.
        public static let narrowWindowWidth: CGFloat = 1000
        /// `narrowWindowWidth` as a screen on the board measures it.
        public static let narrowScreenWidth: CGFloat = narrowWindowWidth - boardChromeWidth
        /// Below this screen height, Match Selection and Tactics scroll, their pitches sized by their width.
        public static let shortScreenHeight: CGFloat = 520
        /// The least height a table keeps, so the text above it cannot squeeze it away.
        public static let tableMinimumHeight: CGFloat = 160
        /// The field for a tactic's name.
        public static let nameFieldWidth: CGFloat = 240
        /// The search field above the squad table.
        public static let searchFieldWidth: CGFloat = 210
        /// The height of a row of controls, kept whether it holds menus or a sentence, so what is below it stays put.
        public static let controlRowHeight: CGFloat = 36
        /// The fixture editor's card.
        public static let fixtureEditorWidth: CGFloat = 480
        /// The picture of the fixture editor on its own.
        public static let fixtureEditorPicture = CGSize(width: 560, height: 420)
        /// The widest a setting's control runs, so a slider is not stretched across a wide window.
        public static let settingControlWidth: CGFloat = 360
        /// The field for the club's name or the path to FMRTE's settings file.
        public static let settingFieldWidth: CGFloat = 440
        /// The column of settings' names.
        public static let settingNameWidth: CGFloat = 220
    }

    // MARK: Pitch

    /// How a pitch is drawn on the board: white, in three-point green marker, with magnets on it.
    public enum Pitch {
        public static let lineWidth: CGFloat = 3
        public static let cornerRadius: CGFloat = 8
        /// The penalty areas' corners away from the goal line.
        public static let boxCornerRadius: CGFloat = 6
        /// The pitch's width to its height: a little taller than wide, so six rows of magnets with names beneath fit
        /// and a long surname has a fifth of the width.
        public static let aspectRatio: CGFloat = 500.0 / 536.0
        /// The least width a pitch keeps, so two side by side stay legible; its height follows from `aspectRatio`.
        public static let minimumWidth: CGFloat = 300
        /// The widest a pitch is drawn when the screen scrolls, so it is not taller than a window.
        public static let scrollingMaximumWidth: CGFloat = 480
        /// The space between neighbouring slots.
        public static let slotGap: CGFloat = 2
        /// A row of the pitch with nobody in it takes this share of a full row's height.
        public static let emptyRowWeight: CGFloat = 0.3

        /// The markings as fractions of the pitch, as drawn on the board.
        public enum Markings {
            public static let penaltyAreaWidth: CGFloat = 246.0 / 500.0
            public static let penaltyAreaDepth: CGFloat = 82.0 / 536.0
            /// The centre circle's diameter, as a fraction of the pitch's width.
            public static let circleDiameter: CGFloat = 102.0 / 500.0
        }

        /// The letters on a magnet, the surname and value beneath, and a role name beneath a tactic's slot.
        public static let initialsSize: CGFloat = TypeSize.button
        public static let slotCodeSize: CGFloat = TypeSize.caption
        public static let nameSize: CGFloat = TypeSize.body
        public static let valueSize: CGFloat = TypeSize.caption
        public static let roleSize: CGFloat = TypeSize.small
        /// The padding round words beneath a magnet, on the board's white.
        public static let labelPadding: CGFloat = 4
        /// How far a long surname or role may shrink to fit, before it is cut.
        public static let labelMinimumScale: CGFloat = 0.8
        /// The most lines a role name takes under its slot.
        public static let roleNameLines = 2
        /// An empty slot of the tactic editor.
        public static let emptySlotDiameter: CGFloat = 34
        /// The marks beside a magnet: a pin, a caution, a youth squad.
        public static let markSize: CGFloat = 11
        public static let youthMarkCornerRadius: CGFloat = 3
        public static let youthMarkPadding: CGFloat = 3
        public static let markOffset = CGSize(width: 6, height: -4)
    }

    // MARK: Match Selection

    public enum Match {
        /// The detail beside the pitch, and under it on a narrow screen.
        public static let detailMinimumWidth: CGFloat = 380
        public static let stackedDetailWidth: CGFloat = 560
        /// The space between the pitch and the detail.
        public static let pitchGap: CGFloat = 22
        /// A fixture's sticky note.
        public static let noteHeight: CGFloat = 76
        public static let noteMinimumWidth: CGFloat = 128
        public static let noteGap: CGFloat = 14
        /// Room above the notes for their magnets and their tilt.
        public static let notesTopPadding: CGFloat = 8
        /// The line beside the button that confirms a lineup, saying what confirming does.
        public static let confirmExplanationWidth: CGFloat = 200
        /// The value in its hand-drawn ring.
        public static let ringLineWidth: CGFloat = 3
        public static let ringTilt: Double = -3
        public static let ringPadding = CGSize(width: 18, height: 8)
        /// The plus or minus before a reason.
        public static let signDiameter: CGFloat = 20
        public static let signLineWidth: CGFloat = 2
        /// The four figures' cards.
        public static let figureGap: CGFloat = 10
        public static let figureLabelLines = 2
        /// The starts grid's columns.
        public static let startsNameWidth: CGFloat = 190
        public static let startsCellWidth: CGFloat = 96
        public static let startsCountWidth: CGFloat = 56
        /// The candidate picker, as a popover or drawn on its own.
        public static let pickerSize = CGSize(width: 460, height: 540)
    }

    // MARK: Columns

    /// Column widths for the tables on the board. The name and status columns share what a wider window gives.
    public enum Column {
        public static let nameMinimum: CGFloat = 170
        public static let squad: CGFloat = 84
        public static let age: CGFloat = 40
        public static let position: CGFloat = 118
        public static let ability: CGFloat = 158
        public static let meter: CGFloat = 122
        public static let jadedness: CGFloat = 80
        public static let statusMinimum: CGFloat = 150

        /// The fixtures table.
        public static let fixtureDate: CGFloat = 120
        public static let opponentMinimum: CGFloat = 160
        public static let importance: CGFloat = 170
        public static let tacticMinimum: CGFloat = 140
        public static let fixtureState: CGFloat = 170
        public static let fixtureActions: CGFloat = 150
    }
}
