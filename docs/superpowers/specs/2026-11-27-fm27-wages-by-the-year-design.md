# FM27 Lineup Optimizer: wages by the year

Date: 27 November 2026
Status: approved by the owner on 27 November 2026 ("Looks good. Proceed."). A small change, built with no plan.

It wins over `2026-11-14-fm27-money-as-fmrte-shows-it-design.md` where they differ: that design's goal 2 (wages shown by FMRTE's period) and its non-goal "showing a different period from the one FMRTE is set to" no longer hold. How a paste is read is unchanged.

## Intent

The owner reads every wage and wage budget in the game, which shows them "p/a". The app asked for the club's figures and gave salaries and ranges by the month, because FMRTE on his Mac is set to Monthly and the app followed FMRTE. He had to convert each figure. He also found it odd that the amount he typed was repeated beside its field ("241757" and then "$241,757 a month").

## Goals

1. Every wage, wage budget and wage range is shown and typed by the year, whatever FMRTE is set to: Contracts, Offers, Scouting, Player Removal and the command line.
2. Figures already typed are kept and read the same: they are kept by the week, so 241,757 a month shows as 2,901,084 a year.
3. A field for an amount shows the amount once, with a comma between each group of three digits, and nothing beside it.

## Non-goals

- A setting for the period. It is a year.
- Changing how a paste is read. FMRTE's "Wages" setting still says what period the pasted wages are in, and the import's line still says so.
- The loan fee on Offers. It stays by the month (this design's call: the game's loan screen is taken to ask a monthly fee; the owner's to change).
- The words of the loan rule and of what the owner's own loans have shown ("his value ÷ 192 a week", "of his value a month"), which describe the rule and are not wages.

## Anti-goals

- A saved figure changing its worth because the period it is shown in changed.
- An amount read differently from what the field shows.

## Approaches considered

1. **Set FMRTE's "Wages" to Yearly.** No code: the app follows at the next import. Dropped: the app would still follow FMRTE, not the game, and a change of FMRTE's setting would change every label again.
2. **A period setting in the app.** Dropped: the owner has one game and it shows a year; a setting is one more thing to keep right for nothing.
3. **Always a year, decided in one place (chosen).** The squad book's `moneyStyle`, which every screen and the command line already take their style from, gives the currency of the latest import with the period a year. The style an import read its wages in is still kept on the book and on the import's result.

## Design

- `MoneyStyle.byYear` is the same currency with the period a year. `SquadBook.moneyStyle` returns it; `SquadBook.money` still holds how the latest import wrote money.
- Scouting shows a pasted player's wage through the paste's own currency by the year.
- The import's line says both when they differ: "Wages were read in $ a month, as FMRTE shows them, and are shown by the year."; with FMRTE set to Yearly it is "Wages are in $ a year, as FMRTE shows them."
- The fields' labels follow the style, as now: "Wage budget, a year", "The agent's figure, a year".
- An amount field's text is the kept amount with commas (`TypedNumber.grouped`). It is read as before: the ASCII digits typed, at most 12, so the commas are dropped when it is read. The line beside each field that said how it was read is removed, on Contracts (the three figures, the agent's figure) and on Offers (his value, a club's four figures, the editor's money fields). The fields are widened for a ten-digit amount with its commas.

## Left to the builder

The wording of doc comments, the tests, and the pictures. Typing into a field whose text gains commas as it is typed cannot be checked in a picture; it is left to the owner in the running app.
