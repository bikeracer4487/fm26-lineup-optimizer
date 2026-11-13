# FM27 Lineup Optimizer: visual direction

Date: 13 November 2026
Status: first direction, for the owner to react to in the running app

The design document (section 12) asked for a visual pass with mock-ups before any screen was built. On 13 November 2026 the owner asked for a usable app first. So the order changes: the first screens are built to this direction, every colour, typeface and measure comes from one `Theme` file, and the running app is the mock-up. A reaction from the owner changes that file and this document, not the screens.

## What the app is for

One person, managing Oxford City in Football Manager 27, deciding who starts the next few matches and seeing why. He builds a team from young players and reads this beside the game, on the same Mac.

## The one bold thing

The team sheet on a pitch. Match Selection shows the eleven where they play, on a pitch drawn from above, with the reasons for the selected player beside it. Everything else in the app is quiet, native macOS: a sidebar, tables, forms. If a screen competes with the pitch for attention, the screen is wrong.

## Colour

Colour carries meaning; it is not decoration. Six named colours, each with a light and a dark value in `Theme`.

| Name | Light | Dark | Used for |
|---|---|---|---|
| Hoop blue | `#1F4E9A` | `#6C9BEF` | The app's accent: Oxford City's hoops. Selection, primary buttons, the chosen fixture |
| Turf | `#2E6B4E` | `#24523D` | The pitch, and nothing else. Its mown stripes are 6% darker |
| Chalk | `#EEF3EC` | `#DDE5DA` | Pitch markings and the text on player tokens |
| Claret | `#9B2335` | `#E0707F` | High importance; a player who is out (injured, banned, under the floor) |
| Amber | `#B7791F` | `#E3B25C` | Medium importance; a caution (out of position, a rule overridden) |
| Teal | `#1E8C8C` | `#5CC4C4` | Sharpness fixtures and anything about sharpness |

Low importance has no colour of its own: it is the system's secondary grey. Backgrounds, text and separators are the system's, so the app follows light and dark mode and the owner's contrast settings.

## Type

- **Numbers** (ratings, values, dates on the fixture strip, slot codes on the pitch): DIN Condensed Bold. It is the typeface of stadium signs and shirt numbers, it ships with macOS, and its narrow figures line up in columns.
- **Screen titles**: DIN Alternate Bold.
- **Everything to be read** (names, reasons, labels, forms): the system typeface, in sentence case.

Sizes follow a 1.25 scale from 13 points: 13, 16, 20, 25, 31. Numbers in tables are right-aligned. If either DIN face is missing, `Theme` falls back to the system typeface with its condensed bold design.

## Layout

A sidebar lists the screens. Each screen has one job, stated in its title.

```
+-----------+----------------------------------------------------------+
| Squad     |  Sat 14 Nov   Tue 17 Nov   Sat 21 Nov   Tue 24 Nov  ...   |  the fixture strip:
| Tactics   |  v Opp A      v Opp B      v Opp C      v Opp D           |  date, opponent, importance
| Fixtures  |  low          medium       HIGH         sharpness         |
| Match     +--------------------------------+-------------------------+
|  Selection|            [ ST ]              |  Tyrone Marsh    ST_C   |
| Settings  |    [AML]   [AMC]   [AMR]       |  rating 120.7 → 142.5   |
|           |      [DM]       [DM]           |  - Projected sharpness… |
|           |  [DL] [DC]   [DC] [DR]         |  - Needs minutes: …     |
|           |            [ GK ]              |  Left out               |
|           |          the pitch             |  - Potter: sharpness…   |
+-----------+--------------------------------+-------------------------+
```

Text is left-aligned. The pitch is the only centred element. Tables are plain: no zebra stripes beyond the system's, no cards around rows.

## Principles

1. **Reasons are content.** Every pick and every dropped regular shows its reasons in full, in the engine's own sentences. They are never hidden in a tooltip.
2. **Say what to do next.** An empty screen says what is missing and has the button that fixes it: "No squad yet. Copy your first team in FMRTE, then import it here."
3. **Errors are sentences.** The engine already writes them in plain words; the app shows them as written, where the action was taken.
4. **Mark what rests on older numbers.** Advice from numbers carried over from FM26, or from this tool's own estimates, carries a small note saying so.
5. **Nothing moves unless the owner moved it.** No entrance animations. A lineup that changes because a setting changed may cross-fade.

## Not decided here

Whether First XI, Second XI and Depth are one screen or three; icons; the app's own icon; the advisor screens. They come with the advisors.
