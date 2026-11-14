# FM27 Lineup Optimizer: money as FMRTE shows it

Date: 14 November 2026
Status: approved by the owner on 14 November 2026 ("Approved, build the wage period and currency change next"). Built on 14 November 2026 (commits a97e73d and 81ee4cd) and reviewed; the limits left are at the end.

## Intent

The owner set FMRTE to show wages monthly and in US dollars, to match what the game shows him. FMRTE then pastes Scott Pollock's wage as `$3,497` where it used to paste `£600`. The column keeps its internal name, "wage per week", so the app reads $3,497 as a weekly wage: release costs come out about 4.3 times too high, with a pound sign in front. The app should read wages in whatever period and currency FMRTE is set to, and show money the way FMRTE and the game do.

## Goals

1. Wages are right whichever period FMRTE shows: weekly, monthly or yearly.
2. The app shows money as FMRTE pasted it: its currency symbol, and wages by FMRTE's period ("$3,497 a month").
3. Squads imported in different currencies are noticed and said, since they cannot be compared.
4. Nothing is guessed: a period the app does not know stops the import with a sentence naming it.

## Non-goals

- Converting between currencies. The app has no exchange rate and takes none from anywhere.
- A currency or period setting in the app. FMRTE's own setting is the only one.
- Changing the capture tool or the test captures. The captures hold only FMRTE's column layouts and stay weekly pounds; tests that need another period write the settings they need.
- Showing a different period from the one FMRTE is set to.

## Anti-goals

- A wage silently read in the wrong period.
- A figure in one currency shown with another's symbol.

## Approaches considered

1. **Tell the owner to keep FMRTE on weekly pounds.** No code, but the app's figures would never match the game's, which is why he changed the setting.
2. **A period and currency setting in the app.** Two settings the owner must keep in step with FMRTE by hand; the day they differ, the figures are wrong with no sign of it.
3. **Read both from FMRTE at each import. Chosen**, approved by the owner on 14 November 2026. FMRTE's settings file, which the app already reads for the column layouts, holds the period (`Wages`: Weekly, Monthly or Yearly), and every pasted amount carries its currency symbol.

## The design

- **The period** comes from the entry `Wages` at the top of FMRTE's settings file: `Weekly`, `Monthly` or `Yearly`. A file with no such entry, as the test captures are, is weekly, FMRTE's own default. Any other word stops the import with a sentence that names the word and says what to set.
- **The currency** is the symbol in front of the pasted wage. The importer already accepts £, $ and €. Every row of one paste must carry the same symbol; a row that differs stops the import, naming the player.
- **One basis inside the engine.** A player's wage is kept per week, as a number that need not be whole, worked out from the pasted amount: a monthly wage times 12 over 52, a yearly wage over 52. Release costs, the wage rules of Player Removal and every comparison then work as they do now. A squad file saved before this change holds whole weekly wages and opens unchanged.
- **How money is shown** is kept with the squads: the period and symbol of the most recent import, and each squad's symbol. Until a squad is imported again after this change, money is shown as weekly pounds, as it was read.
- **Showing it.** A wage is shown in FMRTE's period, worked back from the weekly figure and rounded to a whole unit, so a monthly wage pasted as $3,497 is shown as "$3,497 a month". Costs and other amounts are shown with the symbol. Every sentence that names money takes the symbol and period from the squads' record; none writes a pound sign of its own.
- **Squads in different currencies.** When the squads held do not all carry the same symbol, the squad warnings say which squad is in which and ask for every squad to be imported with the same currency set in FMRTE. The advice is still worked out; the warning is what tells the owner not to trust wage comparisons until he has.
- **Telling the owner what was read.** An import's summary says how wages were read: "Wages are in $ a month, as FMRTE shows them."
- **The command line** shows money in the style of the squads it was given, the last one given deciding the period.

## Testing

- The importer: weekly, monthly and yearly settings; no `Wages` entry; an unknown word; rows with different symbols.
- A monthly wage of $3,497 is 807 a week inside the engine and is shown again as "$3,497 a month".
- Release cost for that player with 9 months left: 807 × 52 ÷ 12 × 9.5, shown with a dollar sign. The game quoted $34,000 for him.
- A squad file saved before this change opens, and its money is shown as weekly pounds.
- The first team in dollars and the U21s in pounds gives the warning; both in dollars does not.
- Player Removal's figures and reasons, and the release-cost sentence, in dollars a month and in pounds a week.

## Left to the builder

- The types' names and where the style is handed to the advisors.
- Whether the old `Display.pounds` and `Display.perWeek` are replaced or kept as the weekly-pounds case of the new ones.
- The exact wording of the new sentences, in the plain style of the existing ones.

## Known limits and small faults left

Found by the review of the built change, and left for the owner to decide:

- While squads are held in different currencies, Player Removal shows every figure with the symbol of the most recent import and compares wages across the currencies. The warning that says so is on the Squad screen only. It clears once every squad has been imported again in one currency. Showing each player's costs in his own squad's currency, or repeating the warning on Player Removal, would close it.
- A squad imported before this change while FMRTE showed pounds by the month or the year has no currency recorded, counts as weekly pounds, and raises no warning; its wages stay wrong until it is imported again.
- The period is read from FMRTE's settings file at the moment of the import, not from the paste. If FMRTE has not yet saved a changed setting, or the setting is changed after the rows were copied, the period is wrong, and only the import summary's line ("Wages are in $ a month, as FMRTE shows them.") shows it.
- The warning sentence repeats a currency when two squads share one ("the U21s' are in £ and the U18s' are in £").
- A release cost that falls exactly on a half can round either way by one unit; it is shown as "about".
- Small things in the code: the weeks-to-months conversion is written in two places; one branch of the importer that cannot be reached would give the wrong sentence if it ever were; one comment still says "whole pounds"; a settings file whose `Wages` entry is empty gives an odd word in the sentence.
- No picture shows an import summary in dollars.
