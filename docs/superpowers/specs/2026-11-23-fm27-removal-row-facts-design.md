# Player Removal: ability, salary and contract end on every row

23 November 2026. A small change; this is the short design.

## What the owner asked for

On Player Removal he wants to see each player's current ability, potential ability, salary by the year and the
date his contract ends, beside the advice, so the facts he weighs a sale or a release on are on the page that
advises it.

## What was found

- Current and potential ability are imported already and only need showing.
- The app shows wages in the period FMRTE is set to (the owner's is Monthly, in dollars). A yearly figure on this
  page is a second period on one screen: the reasons under a row still say "Paid $5,735 a month".
- The contract's end date was not in the data: the team grid carried only months left, rounded down.

## Approaches to the end date

1. **Estimate it from months left** ("about Jun 2030"). Needs nothing from the owner; can be a month out.
2. **Read the exact date from FMRTE.** The owner adds a column to the team grid and the importer reads it.

The owner chose 2 on 23 November 2026 and added the column: FMRTE's `Contract.ContractExpiryDate`, now the last
column of his team grid (107 columns). His first-team paste of that day carries it on all 30 rows, as
month/day/year ("6/30/2030"; the join date beside it, "9/13/2027", shows the month comes first).

## The design

**Import.** The importer reads `Contract.ContractExpiryDate` into a new field of the player, the day his contract
ends, when the pasted grid has the column.

- A grid without the column gives no date and no error: the search grid has none, and neither do the captures or a
  squad saved before this change.
- With the column, a player who has a contract and a blank cell, or a cell that is not a month/day/year date that
  exists, is refused in a sentence naming the player and the column, as every other bad cell is.
- A player with no contract has no end date.
- The field is optional in the saved squad file, so saved state from before it opens with no notice. Each squad
  gains the dates at its next import; the U21s and U18s are pasted from the same grid.

**Words.** The engine gives both new values, as it gives every word about a player:

- his salary by the year: his weekly wage × 52, in whole units of the squads' currency ("$68,820");
- the day his contract ends, with the year and no weekday ("30 Jun 2030"); for a player with no date, his months
  left as the app words them today ("28 months left"), and for one with no contract, that he has none.

**The table.** Four columns are added between Age and Score:

    Level     Action     Name           Squad       Age  CA  PA   Salary a year  Contract ends  Score
    Critical  Terminate  Scott Pollock  First team   25  78  82   $68,820        30 Jun 2027       85

The sentence on what releasing him costs moves from the table's last column into the opened row, above his
reasons, to make room.

**Young players.** Each row gains one line with the same four facts:
"CA 82 · PA 162 · $3,492 a year · contract ends 30 Jun 2030".

**The capture.** The owner's paste of 23 November 2026 is kept as a test fixture, `first-team-with-expiry`, with its
grid layouts, and the importer is tested on it.

## What does not change

- No advice, score or reason. The cost of a release is still the wages for the months left plus half a month; the
  exact date could sharpen it, and that is a later change if the owner wants it.
- The reasons' own wording ("Contract ends in 10 months", "Paid $5,735 a month").
- The loans to the club part, and every other screen. Offers still says "10 months left".

## Calls this design makes (the owner's to change)

- A yearly salary is shown on this page only, beside reasons that speak in FMRTE's period.
- Without a date, the cell falls back to months left and does not estimate a date.
- The cost sentence moves into the opened row.
- The loans to the club part is left as it is: a loaned player's salary and contract are his own club's.
