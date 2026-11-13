# FM27 Lineup Optimizer: visual direction

Date: 13 November 2026
Status: chosen by the owner on 13 November 2026 ("Let's go with Option C, the Tactics Board look")

## How this was chosen

The first screens were built to a restrained direction: system chrome, colour only where it carried meaning, numbers in DIN Condensed Bold. On opening the app the owner called it "extremely bland and boring with no styling or theming to speak of", and the numbers "oddly smushed together, and maybe even taken from the wrong font family". Three directions were then drawn as mock-ups of the Squad and Match Selection screens: a matchday programme, a floodlit dark look, and a coach's tactics board. The owner chose the tactics board.

The mock-ups are on the owner's design canvas, not in this repository, because they show player data. This document carries their colours, type and shapes; once the app is restyled, the pictures the app draws of itself are the reference.

## The idea

The app is the whiteboard in the manager's office. The window is a wall with a framed white board on it. What is on the board is written in marker, held by magnets, or stuck on as a note. Players are magnets. Fixtures are sticky notes. The pitch is drawn in green marker.

One person uses it, beside Football Manager 27, to decide who starts the next few matches and to see why.

## Colour

Every colour has one value, used in light and dark system appearance alike: the board is a white board whatever the system is set to. A chalkboard for dark appearance may follow if the owner asks.

| Name | Value | Used for |
|---|---|---|
| Wall | `#DDE2E8` | The window behind the board |
| Frame | `#B9C0CA` | The board's aluminium frame |
| Board | `#FCFDFE` | The board, and behind text on the pitch |
| Ink | `#1B1F27` | Text, rules, outlines, primary buttons |
| Muted ink | `#5E6673` | Secondary text |
| Faint rule | `#DFE3E9` | Lines between table rows; an unlit meter block is `#E3E7EC`; an unselected pill's outline is `#C9CFD8` |
| Marker blue | `#1F56C4` | The club's name and its underline, the selected thing, the one main action on a screen, values on the pitch |
| Marker green | `#2F8F5B` | Pitch lines; good levels. As text: `#1F6E44` |
| Marker red | `#D43D3D` | Poor levels; a player who is out. As text: `#B42323` |
| Marker amber | `#D99A1C` | Middling levels; cautions. As text: `#8A5A00` |
| Magnet yellow | `#F5C542` | The goalkeeper's magnet (its text is `#2A2000`) |

Magnets are coloured by line: goalkeeper yellow, defence blue, midfield green, attack red. The midfield magnet uses the darker green (`#1F6E44`), because white letters on marker green fall short of the contrast the app keeps to. The same colours mark a player's position in tables.

Sticky notes, each with its own text colour:

| Note | Paper | Text | Used for |
|---|---|---|---|
| Blue-grey | `#DDE6F2` | `#1D2B40` | A Low fixture |
| Yellow | `#FFE27A` | `#3A2E00` | A Medium fixture; today's date in the game |
| Pink | `#FFD3DA` | `#4A0D18` | A High fixture; an import's summary and warnings |
| Green | `#CFF0E0` | `#0E3B27` | A Sharpness fixture |

## Type

Two typefaces, both open-licensed and shipped inside the app:

- **Bricolage Grotesque**, weights 700 and 800: screen titles, the club's name, players' names, figures that are the point of a panel (a match-day value), and headings on notes.
- **Figtree**, weights 400 to 800: everything else, including every number in a table. Digits are tabular so columns line up.

Sizes: 12.5, 13, 14 (body), 15, 16, 18, 24, 28. No condensed or display face is used for data.

## Shapes

- **The board.** Sixteen points of wall around a frame eight points wide with a fourteen-point corner. Everything is inside it.
- **Navigation.** Across the top of the board: the club's name in marker blue with a hand-drawn underline (five points thick, rounded, tilted about one degree), then the screens as pills. The current screen's pill is filled with ink. There is no sidebar.
- **Magnets.** Circles with a short hard shadow below (no blur). On the pitch a magnet is 44 points across with the player's initials; his surname and value sit beneath on the board's white. The selected magnet has an ink ring. In tables a 14-point magnet sits before the position.
- **Sticky notes.** Flat paper, a short hard shadow, tilted between half a degree and one and a half, each a little differently. A fixture's note has a small magnet at its top; the chosen fixture's magnet is blue and its note has a blue foot.
- **Cards on the board** (an import, a figure): a two-point ink outline with an eight to ten point corner, no fill, no shadow.
- **Tables.** A three-point ink rule under the headings, faint rules between rows, rows 42 points high. No stripes.
- **Meters.** Condition and sharpness are five small blocks lit in green, amber or red, with the percentage beside them.
- **Status.** An outlined pill in marker red or amber, tilted about a degree and a half, like a stamp.
- **Buttons.** Primary: filled with ink, white text, eight-point corner. Secondary: a two-point ink outline. The one main action on a screen (confirming a lineup) is filled with marker blue.
- **The pitch.** White, drawn in three-point green marker: touchlines, halfway line, centre circle, both penalty areas.

Nothing moves unless the owner moved it.

## Principles kept from the first direction

1. **Reasons are content.** Every pick and every dropped regular shows its reasons in full, in the engine's own sentences, each marked with a green plus or a red minus for what it did to his value.
2. **Say what to do next.** An empty board says what is missing and has the button that fixes it.
3. **Errors are sentences**, shown where the action was taken.
4. **Mark what rests on older numbers.**
5. **It fits beside the game.** The window works down to 760 points wide: the screen pills wrap, the detail goes under the pitch.

## Not decided here

Icons, the app's own icon, and the advisor screens (they follow this direction when they are built).
