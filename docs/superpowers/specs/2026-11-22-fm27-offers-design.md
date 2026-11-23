# FM27 Lineup Optimizer: terms to propose when selling or loaning out a player

Date: 22 November 2026
Status: written for the owner's approval. He chose the approach (the third of three, below) on 22 November 2026. Everything marked "this design's call" is the builder's, and is his to change.

Research: `docs/Research/fm27-sale-and-loan-offer-acceptance.md`, of 22 November 2026. The earlier `docs/Research/fm27-selling-and-loans.md` is about whether playing a player helps to sell him, and its loan rule was corrected that day.

## Intent

The owner wants the app to give him the numbers to type when he offers a player for sale or on loan: a fee, or a share of the wage and a loan fee, that a club will accept. He asked for full research first, with hidden values used where they help, and a new screen.

What the research found:

- **Nobody knows what a club accepts.** No test, datamine or statement by Sports Interactive, for FM27 or any earlier version, gives the fee or the loan terms an AI club accepts from a human manager. The forums of Sports Interactive, Reddit and YouTube could not be read, so a test published only there is not ruled out.
- **The buyer's money is the one hard limit.** Since FM26 a club offers only what it can afford. At the owner's level that is little: on day one of FM27 the median transfer budget is about £10K in the National League and £0 in National League North and South, and most clubs there have £0 to £2K a week of wage budget unspent.
- **The value on screen says little at this level.** Reports from FM24 have non-league players valued at £200K to £400K going for about £20K, or not at all. The only structure reported as accepted is a fee, add-ons and 20% of the next fee.
- **One loan rule is in circulation, with no sample behind it.** A borrower is taken to bear wages and fee of the player's value ÷ 48 a month, which is value ÷ 192 a week.
- **The values that bear on a deal can be read.** The game stores a transfer value for each player, which is the lower figure of the range on his profile. FMRTE's club Finances page shows a club's transfer budget remaining, wage budget, wage used and an approximate highest wage.

So a formula known to be right cannot be built. What can be built is a calculator that keeps every proposal inside the limits that are known, fills the rest with estimates that say they are estimates, and keeps a record of what clubs answered, so that the owner's own offers measure what nobody has published.

## Goals

1. A new screen, Offers, lists the players the owner has marked to sell or to loan out. For each it gives terms to ask of clubs in general, and terms for one named club once that club's finances are entered.
2. A proposal to a named club never asks for more money now than the club can spend, nor a share of the wage beyond the wage budget it has left.
3. When a club bids, the screen says whether to accept or what to send back.
4. The owner records what he proposed and what the club answered. The record is saved.
5. The screen says what his own offers have shown. Once enough are recorded, three numbers measured from them replace the three estimates they stand for: the line a sale is asked at, the line a loan is asked at, and how far a club comes up from its first bid.
6. Every figure says what it rests on. Nothing is shown as what a club will accept.

## Non-goals

- Pasting clubs or bids from FMRTE. The club's figures and the player's value are typed. FMRTE's saved layouts show a club search grid (`SearchClubsColumns`) that already carries `Finances.Balance`, and a grid of the club's transfer proposals (`ClubTransferProposals`), so both pastes look possible; each waits for a capture that shows the columns, as every new FMRTE column has.
- Saying which clubs to approach. No tool reads a player's list of interested clubs. The owner finds the club in the game.
- An offer for a player who is not marked. A bid for a player he does not mean to sell is a different question.
- The player's own terms with the buying club, beyond one caution when the club cannot pay his present wage.
- An intermediary's commission, TransferRoom, compensation for a player under 24, and what a release would cost beside a sale. Player Removal already shows the cost of a release.
- Running the research's reload tests for him. The record takes any proposal, so a test he runs can be logged.
- Any change to the plan, to another advisor or to the marks. The screen reads the squads and the marks and changes neither.

## Anti-goals

- A figure presented as a price a club will pay. Each one is a place to start.
- A measured number from too few deals, or one that hides how many it rests on.
- A proposal that asks a named club for more than its entered budget.
- A record the owner must keep for the calculator to work. It works with nothing recorded.

## Approaches

1. **Figures from the player alone.** One table of the marked players with an asking total and a wage share, from value and wage. Least typing. It ignores the buyer's budget, the one limit with support, so at this level it would often ask too much.
2. **Terms for one player and one club.** The owner enters the player's value and the club's finances and gets the terms to type, each with what it rests on. Every number that is not a hard limit stays an estimate for good.
3. **The same, with a record of answers (chosen).** As 2, and each answer is recorded; measured numbers replace estimates once there are enough. Against: more to build, and the record measures only what the owner tried.

The owner chose 3 on 22 November 2026.

## 1. What is entered

**His value** is typed once for each marked player: "the lower figure of the value on his profile", a whole amount in the save's currency. Where the game shows one figure, that figure. It is kept with the day it was typed, shown beside the field ("entered Sat 21 Nov"), and can be changed at any time. Without it the player has no suggestion, only a line asking for it, and nothing can be recorded for him: a club that bids before the value is typed waits for it. This design's call: typed, because the owner's FMRTE grids are not known to carry it. A caution stands under the field: the research found that once a player is transfer-listed with an asking price, the stored figure is that price, so the value should be read before he is listed.

**A value of 0** is a value: the game gives some obscure players a range that starts at nothing. The rules below then give what they give at 0, and say so in a line of their own ("The game gives him no value, so no fee is asked."): a sale asks no fee and 20% of his next fee, and a loan asks none of his wage. An ask or a round made on a value of 0 has no ratio and counts in no measure (section 6). This is this design's call; if most of the owner's marked players read 0, the calculator has little to say about them, and that is a limit of the evidence, not something a second anchor would mend: nothing in the research ties a fee to anything but the value and the buyer's budget.

**A club's figures** are typed for a named club, from FMRTE's club Finances page:

| Field on the screen | FMRTE's name | Needed for |
|---|---|---|
| Can spend on transfers | Transfer Budget Remaining | a sale to that club |
| Wage budget | Wage Budget | a loan to that club |
| Wages spent | Wage Used | a loan to that club |
| Highest wage it can offer | Max Wage (aprox.) | nothing; used when entered |

The club's name is free text. A club's figures are kept under its name (names compared by `PlayerID.normalise`) with the day entered, so they fill the fields the next time that club is named, with "entered Sat 21 Nov" beside them. The wage it has left is the wage budget less the wages spent, and 0 when that is below 0.

**Money.** Amounts are typed and shown in the squad book's money style, as wages already are: a wage figure is in the period FMRTE is set to (monthly, in the owner's save), and each wage field's label says the period. The engine keeps wages by the week. A loan fee is always by the month, as the game asks for it. Whether FMRTE's club page shows the wage budget in the period of its wage setting has not been checked; the first real entry is the owner's to compare with the game's own figure for a club.

**What a loan is for** is one of two: his development, or moving his wage. It starts as development for a player of 23 or under (`developingUpToAge`) and as moving his wage for one older, and the owner can switch it. It is kept with the player's value.

No silent defaults: a field left blank is blank, and the suggestion that needs it is replaced by a line naming the field.

## 2. The three lines and how they are measured

Three numbers carry most of the uncertainty. Each has an estimate from the research, and each can be replaced by a figure measured from the record (section 6).

| Number | What it is | Estimate | What the estimate rests on |
|---|---|---|---|
| The sale line | the total asked, as a share of his value | 1.0 | FM24 reports that players a club wants go for about their value |
| The loan line | what a borrower bears a week in wages and fee, as a share of his value | 1 ÷ 192 | the one loan rule in circulation, about FM22, no sample |
| The counter step | what to send back, as a multiple of a club's bid | 1.2 | an FM24 report that clubs come up 10 to 20% |

## 3. A sale

Write V for his value, L for the sale line, and T for the total asked: L × V.

**To clubs in general** (the game's "Offer to clubs"), with no club named:

- Ask T, with 20% of his next fee.
- A line says to offer him to clubs without transfer-listing him (carried over from FM24 and FM26, reports only).
- A line says that with no club interested, earlier reports are of no bid, or a bid at 5 to 10% of his value (carried over from FM24, one report).

**To a named club** whose transfer budget remaining is B:

- Money now is the smaller of T and B. It is never rounded above B.
- What is left of T is asked later: 44% of it in instalments over 12 months and 56% after 50 league appearances. The shares and the 50 are from the one FM27 example of the terms the game's own Director of Football proposed; the 12 months is this design's call.
- 20% of his next fee is asked on top. The fee, not the profit: at one percentage a share of the fee is never the smaller.
- When something is asked later, a caution says so: "Barnet can spend £35K now; the rest is asked later. Whether a club agrees to money beyond its budget is not known."
- When B is 0, everything is asked later, and the first line says the club has nothing to spend now.
- When the wage the club has left, or the highest wage it can offer, is entered and is under his present wage, a caution says he would have to take less to go there. It changes no figure.

**When the club bids**, write b for the total of its bid (money now and later together; a share of the next fee is not counted in a total anywhere in this design):

- b at or above T: accept.
- Otherwise counter once, at the smaller of T and the counter step × b. The counter keeps the club's own money now and adds the difference after 50 league appearances, with 20% of his next fee if the bid had none.
- When the club has already answered one counter of the owner's in this deal with another bid: no further counter. The line says to accept it or leave it, since earlier reports are of two or three chances before a club withdraws (carried over, one report).
- A measured counter step of 1 or less means clubs have not come up: the line is to accept or leave it.

**After a refusal or no reply**, the next suggestion steps down. The 10% and the limit of two are this design's calls, with no evidence.

- In a deal, when the owner's last round was refused or had no reply: 10% under the total he last recorded there (which need not have been the suggestion), at most the present T, and never under the highest bid that club has made.
- To clubs in general, when his last ask for the player has "No bid came": 10% under that ask's total, at most the present T.
- At most two steps down in a row. A run is the owner's rounds refused or unanswered since the club's last round in a deal, or the asks in a row with "No bid came". After two steps and a third refusal or silence there is no lower suggestion. In a deal the line says the club has turned down or not answered three proposals, and to leave it or ask what it would pay. To clubs in general it says three asks have drawn no bid, that earlier reports are that with no club interested no price brings one (carried over from FM24, reports only), and to find interest first: ask his agent about interest, or pitch him against a club's stated need.
- Retyping his value or a newly measured line changes T, and so the cap; it does not end a run.

Amounts are rounded to two significant figures (this design's call), money now always down.

## 4. A loan

Write W for his wage a week, V for his value and L for the loan line. What a borrower is taken to bear a week is L × V.

**The share of his wage to ask** is the smallest of:

- 100%;
- L × V ÷ W;
- for a named club, the wage it has left ÷ W;
- for a named club with a highest wage entered, that wage ÷ W;

rounded down to a step of 10%. The step is carried over from an older version's manual and a guide; the owner should check it against the game's loan screen, and it is one parameter.

**A fee a month** is asked only when the share is 100% and the borrower is taken to bear more than his wage: 4 × (what it bears a week − W), where for a named club what it bears is at most the wage it has left. The 4 is the rule's own weeks in a month. At the owner's level this is rare: a player on £500 a week needs a value above £96,000. A player with no wage has no share to ask, and the fee rule applies with a wage of 0.

**The other terms** follow what the loan is for:

| | For his development | To move his wage |
|---|---|---|
| Playing time asked | a starting place: Regular Starter, or First-Choice Goalkeeper for a goalkeeper | none: whatever the club offers |
| Recall | kept | kept |
| A fee to buy him later | refused | an optional one may be offered, at the sale's T |

**Playing time is recorded as one of two**: a starting place, or less. The game's loan screen for FM27 has not been read, and the levels FMRTE pastes for a contract are not one ladder (the captured squad has "Star Player", "Important Player", "Regular Starter", "Fringe Player", "Breakthrough Prospect", "Emergency Backup" and "First-Choice Goalkeeper"), so the tool keeps no list of levels and ranks none. A starting place is Regular Starter or anything the game ranks above it, and First-Choice Goalkeeper for a goalkeeper; the sheet's line says so, and the owner says which the club's answer is. The two names are FMRTE's own, from the capture. A goalkeeper is a player whose positions are goalkeeper only. For a loan to move his wage no playing time is asked, since each level asked for is reported to narrow the clubs that answer (this design's call; the research proposed one level under a starting place, on no evidence).

When a fee a month is asked with the recall kept, a caution says older versions did not allow the two together (carried over from FM11 and FM19, reports only).

**To clubs in general**, the same without the club's two limits, and a line saying that clubs are reported to open at none of the wage and Squad Player, and to accept more when the manager proposes the terms himself (carried over from FM24, one report).

**When the club answers with terms of its own:**

- For his development: accept when its playing time is a starting place, whatever the share, since matches are what the loan is for. Otherwise send back its share with a starting place.
- To move his wage: accept when its share is at or above the suggestion. Otherwise send back the smaller of the suggestion and its share plus one step.

**After a refusal or no reply**, the next suggestion drops the fee first, then one step of the share, each taken from the terms he last recorded and never above the present suggestion. In a deal the steps go on down to none of the wage; at none of the wage and refused, the line says this club does not want him on these terms, and there is no lower suggestion. To clubs in general the limit is the sale's: at most two steps down in a row, then the line that three asks have drawn no bid and that interest comes before a lower ask.

## 5. The record

Two things are recorded, both saved.

**An ask** is terms offered to clubs in general: the player, sale or loan, the day, the terms, and the value and wage it was worked out from. Its one answer is "No bid came", which the owner sets; it then lowers the next ask as section 3 and 4 say.

**A deal** is with one club: the player, sale or loan, the club's name and its figures as entered at the time, and its rounds in order. A round is a day, who proposed (the owner or the club), the terms, and the value and wage at the time. A round of the owner's has an answer: none yet, accepted, refused or no reply; it becomes "countered" when a round of the club's is recorded after it. A round of the club's can be marked accepted by the owner. A deal is agreed when any round was accepted, ended when the owner ends it, and open otherwise.

**Terms** are, for a sale: money now, money later (instalments and add-ons together; the suggestion says how to split it, the record keeps one figure), and the share of the next fee. For a loan: the share of the wage, the fee a month, the playing time (a starting place or less), whether the recall is kept, and a fee to buy him later, if any.

The record keeps the player's name and the club's name as text, so it reads when the player has gone. Recording is never required, and the owner may record terms other than the suggestion; the form opens filled with the suggestion and every field can be changed.

A deal or an ask recorded by mistake can be deleted, after a question.

## 6. What the offers have shown

Each ask and each round has a **ratio**:

- a sale: its total (now and later) ÷ the value at the time;
- a loan: what the borrower would bear a week (share × wage, plus the fee a month ÷ 4) ÷ the value at the time.

Each deal gives at most one figure each way:

- **Paid**: the highest ratio among the club's own rounds and the owner's rounds the club accepted.
- **Turned down**: the lowest ratio among the owner's rounds the club refused, and those it answered with a round of a lower ratio.

An ask gives no "paid". It is "turned down" at its ratio when a club's first round, in a deal for the same player and kind dated on or after the ask and before his next ask, has a lower ratio. A round or an ask that had no reply counts for neither: nothing says anyone weighed the price.

**A line is measured** for sales, and apart for loans, when at least 5 deals gave a "paid" and at least 5 deals or asks gave a "turned down" (this design's call), and the median paid is below the median turned down. It is midway between the two medians. With the medians the other way round there is no line, and the screen says clubs have paid more than others turned down. A median is taken as the trend's are: sorted by value, then player key, then day, the mean of the middle two for an even count, so the same record in any order gives the same line.

**The counter step is measured** from sales in which the owner countered and the deal was then agreed: a deal counts when a round of the owner's follows the club's first round and a later round, his or the club's, was accepted. Its figure is the agreed total ÷ the total of the club's first round. The median is taken, with at least 3 such deals (this design's call). A bid accepted outright is no such deal, whoever proposed first: no counter was tried, so it says nothing of how far a club comes up, and three of them must not switch the counter off.

An ask or a round made on a value of 0 has no ratio, and counts in none of the three measures.

A measured number replaces its estimate in every suggestion from then on, and the suggestion's working says so.

**Measure again from today.** A patch can change how clubs bid (27.1.0 "tweaked AI transfer balancing" with no detail). The owner can set a day to measure from, as Rest does: asks and rounds dated before it stay in the file and are left out of the measures. It asks first, and cannot be undone in the app.

**The sentences**, under a heading "What your offers have shown", for sales and for loans:

- "Sales: 7 deals recorded since Tue 17 Nov, 2 agreed."
- Measured: "Clubs have paid about 22% of a player's value and turned down about 80%, so sales are now asked at 51% (from 5 paid and 6 turned down; this tool's estimate)."
- Not measured: "The line for sales is not measured yet: it needs 5 paid and 5 turned down, and has 2 and 1. Until then a sale is asked at the player's value."
- No line: "Your sales show no line: clubs have paid about 60% of value and others turned down about 40%. A sale is still asked at the player's value."
- "Clubs have come up about 15% from a first bid (from 3 deals)." or "How far clubs come up is not measured yet: it needs 3 agreed sales in which you countered a bid, and has 1."
- With nothing recorded, one line for the whole part: "Nothing is recorded yet. Record what you propose and what clubs answer, and this part will say what your own offers show."

A loan's ratio is written as a share of value a month (the week's ratio × 4).

## 7. The words and the evidence

Every sentence is the engine's (`AdvisorText`, a new file for offers), shown as written. Each suggestion carries the weakest evidence among the numbers it used, as every other piece of advice does, and its lines say which is which: the club's budget is the club's own figure as entered; the rest is carried over or this tool's estimate. A measured number says how many deals it rests on and that it is this tool's estimate.

The screen's first line: "Terms to propose for the players you have marked to sell or to loan out. No test in any version of the game shows what a club accepts: every figure here is a place to start, and says what it rests on."

An evidence note stands at the foot, saying in a few lines what is known (a club offers only what it can afford, FM26, official), what is carried over from reports (the sale at about value, 20% of the next fee, the loan rule, the counter), and what is this design's own (the 10% steps, the 12 months, the counts needed to measure).

## 8. The screen

Offers stands after Scouting in the top row. It needs only the squads and the marks, so it has no gate on the advice.

A sketch, not a layout:

```
Offers
Terms to propose for the players you have marked to sell or to loan out. No test in any
version of the game shows what a club accepts: every figure here is a place to start, …

TO SELL
Sam Reed    Age 27 · D C · £1,950 a month · 14 months left
  His value [ 40,000 ]  the lower figure of the value on his profile · entered Sat 21 Nov
  To clubs in general
    Ask £40K, with 20% of his next fee.
    Offer him to clubs without transfer-listing him.
    With no club interested, earlier reports are of no bid, or a bid at 5 to 10% of his value.
    (carried over from FM24, reports only)                                  [Record this ask]
  To a club [ Barnet ]  Can spend [ 35,000 ]  Wage budget [ … ]  Wages spent [ … ]  Highest wage [ … ]
    Propose £35K now, £2.2K over 12 months and £2.8K after 50 league appearances,
    with 20% of his next fee.
    Barnet can spend £35K now; the rest is asked later. Whether a club agrees to money
    beyond its budget is not known.                     [Record my proposal] [Record their bid]
  Barnet · open
    Sat 21 Nov   They bid £8K now.
                 Counter once: £8K now and £1.6K after 50 league appearances, with 20% of his next fee.
                                  [Record my proposal] [Record their bid] [I accepted] [End]

TO LOAN OUT
Max Treml   Age 19 · GK · £650 a month · 26 months left      For his development ▾
  …

WHAT YOUR OFFERS HAVE SHOWN
  Sales: …
  Loans: …
  Measured from Tue 17 Nov.                                    [Measure again from today]

EARLIER OFFERS   3 deals for players no longer marked
```

- The players are those marked, in two parts, "To sell" and "To loan out", each in the squad's order. With nobody marked the screen says so and leads to Player Removal, where a player is marked.
- A recorded round is entered in a sheet, as the fixture and mentoring editors are, opened filled with the suggestion. The owner's round then shows "Accepted", "Refused" and "No reply" until one is pressed; "Record their bid" records a round of the club's.
- Under the deal's last round stands the suggestion for the next one, worked out from the rounds so far.
- Deals and asks for a player who is no longer marked (sold, out on loan, or the mark taken off) are listed at the foot under "Earlier offers", closed at every launch behind a line saying how many, with their rounds and nothing to press but the deletion. They still count in the measures.
- The buttons that record or answer a round are ignored within half a second of the last, as Training's and Scouting's are, since each moves the next button under the pointer.

## 9. Where it lives

- **Engine.** The suggestions, the record's types and the measures are in `Advisors/`, each a function of what it is handed: the player, sale or loan, his value, what the loan is for, the club's figures or none, the rounds so far, the measures and the parameters. The words are in `Reporting/`. Refusals of typed input (a blank field, a share over 100%, an amount below 0) are errors with sentences in `ErrorDescriptions`, with exhaustive switches.
- **Parameters.** One entry, `offerRules`, holding every number in this design, labelled derived, the weakest of them, with a source saying which rests on what, as `leagueStandingRules` and `jadednessTrendRules` do. `EngineParameters` stays under its size limit.
- **App.** A new saved file, `offers.json` (`StoreFile.offers`), versioned JSON through `Store`: each marked player's value, its day and what his loan is for; each club's figures and their day; the asks and the deals; and the day to measure from. Its absence is no notice, and saved state from before it opens with no notice and nothing recorded. The screen's rows, labels and which controls are offered are worked out in Core with tests; the views hold layout only.
- Recording, answering, deleting and "Measure again from today" save the file and nothing else. None plans, and no other advice reads the file.
- A value and a loan's purpose are kept under the player's key and stay when his mark is taken off, so marking him again finds them.

## 10. Tests and pictures

- Each rule has a test where it changes an outcome and one where it does not: the club's budget capping money now; the split of what is asked later; the wage left and the highest wage capping a share; the step; the fee appearing only at 100%; accept against counter; the single counter; the steps down; each purpose's terms.
- The measures: fewer than the counts needed gives none; the medians and the midway line; medians the wrong way round give no line; a round with no reply counts for nothing; an ask turned down by a later lower bid; the day to measure from; the same record in any order gives the same figures.
- Core: the rows for marked players; a value and a club's figures kept and filled in again; a deal's state from its rounds; earlier offers; the file saved and read back, and saved state from before it.
- Pictures in `.build/pictures-offers`, looked at before the screen is called done: nobody marked; a player with no value; a sale to clubs in general; a sale to a club that can pay all, part and nothing; a deal with a bid and its counter; a loan of each purpose; the measures before and after there are enough; earlier offers; the smallest window.

## 11. Limits to say in the plan's closing sections

- Every estimate is carried over from an older version or is this design's own, and the game was patched five days before this was written.
- The measures show only what the owner tried. If he never asks above the line, the line cannot rise; a higher ask that is accepted is what moves it.
- The lines put clubs of every level together, and a loan turned down for want of wage budget counts as turned down on price when the club's figures were not entered.
- A value typed weeks ago is used as typed. The day beside it is the only warning.
- Whether a club agrees to money beyond its budget is not known, and at this level most proposals will ask for some.
- The contract types FMRTE pastes other than full-time and youth are not interpreted (the captured squad has one written "4"), so a non-contract player, who is reported to bring no fee and to be barred from loans, is not recognised.
- The playing-time levels on FM27's loan screen have not been read; the owner says whether a club's answer is a starting place.
- The loan limits of the owner's league are not read. A club that has used its loans will refuse whatever is asked.

## Left to the builder

- The layout of a player's block and of the sheet, within the visual direction, and the names of the types and files.
- Whether asks and deals are one stored type or two.
- Whether `lineup-cli` gets a command that prints a suggestion for a player of the captured squad.
- The exact wording of each sentence, within the examples above.
- How a typed amount is read (digits, with the currency symbol and separators ignored), as the League screen's numbers are.

## This design's calls, for the owner to check

1. The screen is called Offers, stands after Scouting, and lists only marked players.
2. The value and the club's figures are typed; pasting waits for a capture.
3. A loan is for development at 23 or under and for moving a wage above, and he can switch it.
4. What is asked later is split 44% in instalments over 12 months and 56% after 50 league appearances.
5. A refusal or silence lowers the next ask by 10% for a sale and one step of the wage share for a loan, at most twice in a row; after that the screen says to find interest, not a lower price.
6. Amounts are rounded to two significant figures.
7. A line is measured from 5 deals each way and sits midway between the two medians; the counter step from 3 agreed sales.
8. "Measure again from today" is the answer to a patch, in place of recording the game's version on each deal.
9. A deal's later money is recorded as one figure.
10. A value of 0 is taken as it reads: no fee asked, none of the wage asked, and nothing measured from it.
11. Playing time is a starting place or less. A development loan asks a starting place; a loan to move a wage asks none.
12. The counter step is measured only from sales in which he countered.

A reviewer read this as a builder on 22 November 2026. Its four questions are answered in the text: a value of 0 (section 1), which deals measure the counter step (section 6), the playing-time levels (section 4) and how the steps down add up and where they stop (sections 3 and 4).
