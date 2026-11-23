# FM27 Lineup Optimizer: terms to propose when selling or loaning out a player

Date: 22 November 2026
Status: built, by `docs/superpowers/plans/2026-11-22-fm27-offers.md`, on 22 November 2026. The passages changed during the build are marked "revised" (sections 1, 3, 4, 5, 6, 7 and 8, and the list left to the builder), and those changed by the fixes after the whole-branch review the same day are marked "revised after the whole-branch review" (sections 1, 3, 5, 6 and 8, and the list left to the builder). Those the owner changed after using the build, the same day, are marked "revised on 22 November 2026 at the owner's request" (sections 5 and 8, and the calls): every marked player's block now offers sale terms or loan terms, whatever his mark. It was written for the owner's approval, and a reviewer read it as a builder the same day (see the foot). He chose the approach (the third of three, below) on 22 November 2026. Everything marked "this design's call" is the builder's, and is his to change, and so are the plan's own calls beyond the design, listed in the plan.

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

The club's name is free text. A club's figures are kept under its name (names compared by `PlayerID.normalise`) with the day entered, so they fill the fields the next time that club is named, with "entered Sat 21 Nov" beside them. The wage it has left is the wage budget less the wages spent, and 0 when that is below 0. *Revised during the build: the four fields appear once a club is named, since nothing typed in them with no name could be kept; a blank figure typed for a club with no entry saves nothing.*

**Money.** Amounts are typed and shown in the squad book's money style, as wages already are: a wage figure is in the period FMRTE is set to (monthly, in the owner's save), and each wage field's label says the period. The engine keeps wages by the week. A loan fee is always by the month, as the game asks for it. *Revised during the build (the plan's call 6): a club's three wage figures are kept by the week too, converted from FMRTE's period when typed, so a later change of that period shows them converted, not misread. Money is written in full, "£35,000", as the rest of the app writes it, not "£35K" as the examples below have it (the plan's call 5).* Whether FMRTE's club page shows the wage budget in the period of its wage setting has not been checked; the first real entry is the owner's to compare with the game's own figure for a club. *Revised after the whole-branch review: beside each amount field the screen shows how the tool read it, in the money style: "£40,000" beside his value, "£15,000" beside "Can spend on transfers", "£9,000 a week" (in FMRTE's period) beside each wage figure, and nothing beside a blank field; the sheet a round is recorded in does the same beside its money fields, not beside its percentages. So 40 typed for "40K" is seen at once.*

**What a loan is for** is one of two: his development, or moving his wage. It starts as development for a player of 23 or under (`developingUpToAge`) and as moving his wage for one older, and the owner can switch it. It is kept with the player's value. *Revised after the whole-branch review: the first time a loan ask or a loan round is recorded for a player with no purpose saved, the purpose then in force is saved with it, so it no longer follows his age: a player of 23 in the middle of a deal does not switch to moving his wage on his 24th birthday.*

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

- Money now is the smaller of T and B. It is never rounded above B. *Revised after the whole-branch review: when T is at or under B, money now is T exactly and nothing is asked later; only when B caps it is money now B rounded down. The first build rounded it down even when the club could pay the whole total, which asked a few pounds later of a club that could pay them now.*
- What is left of T is asked later: 44% of it in instalments over 12 months and 56% after 50 league appearances. The shares and the 50 are from the one FM27 example of the terms the game's own Director of Football proposed; the 12 months is this design's call. *Revised during the build (the plan's call 7): the instalments are 44% rounded, and the money after appearances is what remains, so the parts always add up to what is asked later.*
- 20% of his next fee is asked on top. The fee, not the profit: at one percentage a share of the fee is never the smaller.
- When something is asked later, a caution says so: "Barnet can spend £35K now; the rest is asked later. Whether a club agrees to money beyond its budget is not known." *Revised after the whole-branch review: the caution names the budget as entered, not the rounded money now: "Barnet can spend £35,400 now; the rest is asked later. …".*
- When B is 0, everything is asked later, and the first line says the club has nothing to spend now.
- When the wage the club has left, or the highest wage it can offer, is entered and is under his present wage, a caution says he would have to take less to go there. It changes no figure.

**When the club bids**, write b for the total of its bid (money now and later together; a share of the next fee is not counted in a total anywhere in this design):

- b at or above T: accept.
- Otherwise counter once, at the smaller of T and the counter step × b. The counter keeps the club's own money now and adds the difference after 50 league appearances, with 20% of his next fee if the bid had none.
- When the club has already answered one counter of the owner's in this deal with another bid: no further counter. The line says to accept it or leave it, since earlier reports are of two or three chances before a club withdraws (carried over, one report).
- A measured counter step of 1 or less means clubs have not come up: the line is to accept or leave it.
- *Revised during the build: the counter asks the larger of the club's share of the next fee and 20%, and its sentence writes the club's own later money and the difference added as one figure: "Counter once: £8,000 now and £1,600 later, after 50 league appearances, with 20% of his next fee."*
- *Revised during the build: a deal with any accepted round, the owner's or the club's, gets "The deal is agreed." in place of a suggestion; the first build told the owner to accept what was already agreed. The same holds for a loan. While the owner's last round has no answer the suggestion is "Waiting for Barnet's answer." (the plan's call 2).*

**After a refusal or no reply**, the next suggestion steps down. The 10% and the limit of two are this design's calls, with no evidence.

- In a deal, when the owner's last round was refused or had no reply: 10% under the total he last recorded there (which need not have been the suggestion), at most the present T, and never under the highest bid that club has made. *Revised after the whole-branch review: the floor wins over the cap: the total is the larger of the club's highest bid and the smaller of T and the lowered total, so when his value was retyped lower since the club bid, the step down proposes that bid's total. The line "Lowered after …" is given only when the new total is below the total he last recorded, in an ask and in a deal, for a sale as for a loan; on a value of 0, or when the floor gives back what he last proposed, nothing was lowered and it is not said.*
- To clubs in general, when his last ask for the player has "No bid came": 10% under that ask's total, at most the present T.
- At most two steps down in a row. A run is the owner's rounds refused or unanswered since the club's last round in a deal, or the asks in a row with "No bid came". After two steps and a third refusal or silence there is no lower suggestion. In a deal the line says the club has turned down or not answered three proposals, and to leave it or ask what it would pay. To clubs in general it says three asks have drawn no bid, that earlier reports are that with no club interested no price brings one (carried over from FM24, reports only), and to find interest first: ask his agent about interest, or pitch him against a club's stated need.
- Retyping his value or a newly measured line changes T, and so the cap; it does not end a run.
- *Revised during the build: to clubs in general, an ask still waiting (no "No bid came" set yet) changes nothing: the suggestion is the present terms from his present value, never the terms of an ask recorded earlier. The plan's words "the first ask's terms" were read as the first recorded ask and corrected. A step down from an ask of nothing (a value of 0) stays at nothing, and the line that three asks have drawn no bid is given only once the run of asks with no bid passes two. The same holds for a loan.*

Amounts are rounded to two significant figures (this design's call), money now always down. *Revised after the whole-branch review: money now is rounded down only when the club's budget caps it (above).*

## 4. A loan

Write W for his wage a week, V for his value and L for the loan line. What a borrower is taken to bear a week is L × V.

**The share of his wage to ask** is the smallest of:

- 100%;
- L × V ÷ W;
- for a named club, the wage it has left ÷ W;
- for a named club with a highest wage entered, that wage ÷ W;

rounded down to a step of 10%. The step is carried over from an older version's manual and a guide; the owner should check it against the game's loan screen, and it is one parameter. *Revised during the build: the line naming the limit says the share "is within" it, with the club's figure a week, since the share is rounded down and "is" contradicted the figure beside it: "40% is within what Barnet have left in their wage budget: £200 a week."*

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
- *Revised during the build (the plan's call 1): a loan gets one counter too. When the club has already answered a counter of the owner's with terms of its own, the line is to accept it or leave it, as for a sale; without that limit the suggestion would repeat one counter for ever.*

**After a refusal or no reply**, the next suggestion drops the fee first, then one step of the share, each taken from the terms he last recorded and never above the present suggestion. In a deal the steps go on down to none of the wage; at none of the wage and refused, the line says this club does not want him on these terms, and there is no lower suggestion. To clubs in general the limit is the sale's: at most two steps down in a row, then the line that three asks have drawn no bid and that interest comes before a lower ask.

## 5. The record

Two things are recorded, both saved.

**An ask** is terms offered to clubs in general: the player, sale or loan, the day, the terms, and the value and wage it was worked out from. Its one answer is "No bid came", which the owner sets; it then lowers the next ask as section 3 and 4 say.

**A deal** is with one club: the player, sale or loan, the club's name and its figures as entered at the time, and its rounds in order. A round is a day, who proposed (the owner or the club), the terms, and the value and wage at the time. A round of the owner's has an answer: none yet, accepted, refused or no reply; it becomes "countered" when a round of the club's is recorded after it. *Revised after the whole-branch review: nothing stored changes; the round's line ends " Countered." in place of " No answer yet." when a round of the club's follows it in the deal. The first build left it reading "No answer yet." for good.* A round of the club's can be marked accepted by the owner. A deal is agreed when any round was accepted, ended when the owner ends it, and open otherwise.

**Terms** are, for a sale: money now, money later (instalments and add-ons together; the suggestion says how to split it, the record keeps one figure), and the share of the next fee. For a loan: the share of the wage, the fee a month, the playing time (a starting place or less), whether the recall is kept, and a fee to buy him later, if any.

The record keeps the player's name and the club's name as text, so it reads when the player has gone. Recording is never required, and the owner may record terms other than the suggestion; the form opens filled with the suggestion and every field can be changed. *Revised after the whole-branch review: only the owner's own round or ask opens filled with the suggestion. The club's bid or offer never does, since Save is the default button and a stray Return would record a bid at his own ask: a sale opens with the money now blank and the money later and the share of the next fee at 0; a loan with the share of his wage blank, the fee a month at 0, the playing time as it is today for the loan's purpose, the recall kept and no fee to buy him. A blank field the kind needs is refused by name.*

A deal or an ask recorded by mistake can be deleted, after a question. *Revised during the build: the questions read "Delete this deal and its rounds from the record?" and "Delete this ask from the record?".*

*Revised during the build: a deal opened for a club with no figure entered keeps no figures. A round joins only an open deal of the player's present kind with that club; a deal of the other kind (his mark changed since) stays apart.*

*Revised on 22 November 2026 at the owner's request: a round joins the open deal of the round's own kind with that club, which is the kind his block shows when it is recorded from the block, and the deal's kind when it is recorded from the deal's card. A sale and a loan with one club can both be open. A loan round or ask for a player on a youth contract or one already out on loan is refused with the engine's sentence, and nothing is saved.*

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

A measured number replaces its estimate in every suggestion from then on, and the suggestion's working says so. *Revised during the build: the working gives the figure the record shows, not a claim about the terms, since terms lowered, a counter capped at the ask, or a value of 0 are not at the line: "The line your own offers show is 51% of his value (this tool's estimate).", for a loan "The line your own offers show is 2.1% of his value a month (this tool's estimate).", and for the counter step "Your own agreed sales show clubs coming up 15% over a bid (this tool's estimate)."*

**Measure again from today.** A patch can change how clubs bid (27.1.0 "tweaked AI transfer balancing" with no detail). The owner can set a day to measure from, as Rest does: asks and rounds dated before it stay in the file and are left out of the measures. It asks first, and cannot be undone in the app. *Revised after the whole-branch review: the question reads "Measure again from today? Offers recorded before today stay in the record and are left out of what is measured. This cannot be undone in the app."*

**The sentences**, under a heading "What your offers have shown", for sales and for loans:

- "Sales: 7 deals recorded since Tue 17 Nov, 2 agreed."
- Measured: "Clubs have paid about 22% of a player's value and turned down about 80%, so sales are now asked at 51% (from 5 paid and 6 turned down; this tool's estimate)."
- Not measured: "The line for sales is not measured yet: it needs 5 paid and 5 turned down, and has 2 and 1. Until then a sale is asked at the player's value."
- No line: "Your sales show no line: clubs have paid about 60% of value and others turned down about 40%. A sale is still asked at the player's value."
- "Clubs have come up about 15% from a first bid (from 3 deals)." or "How far clubs come up is not measured yet: it needs 3 agreed sales in which you countered a bid, and has 1."
- With nothing recorded, one line for the whole part: "Nothing is recorded yet. Record what you propose and what clubs answer, and this part will say what your own offers show."

A loan's ratio is written as a share of value a month (the week's ratio × 4).

*Revised during the build: the counter step's line reads "Clubs have come up about 15% from a first bid (from 3 agreed sales you countered; this tool's estimate).", a kind with nothing in the window reads "Loans: nothing recorded.", and the loans' lines follow the sales' ("Borrowers have borne about 1.2% of a player's value a month and turned down about 3.0%, so loans are now asked at 2.1% …").*

*Revised after the whole-branch review: a club's bid counts as "paid" whether or not it was accepted, so "Clubs have paid …" read as false under "none agreed". The lines now read:*

- *"Clubs have offered or paid about 22% of a player's value and turned down about 80%, so sales are now asked at 51% (from 5 offered or paid and 6 turned down; this tool's estimate)."*
- *"The line for sales is not measured yet: it needs 5 offered or paid and 5 turned down, and has 2 and 1. Until then a sale is asked at the player's value."*
- *"Your sales show no line: clubs have offered or paid about 60% of value and others turned down about 40%. A sale is still asked at the player's value."*
- *"Borrowers have offered or agreed to bear about 1.2% of a player's value a month and turned down about 3.0%, so loans are now asked at 2.1% (from 5 offered or agreed and 5 turned down; this tool's estimate).", "The line for loans is not measured yet: it needs 5 offered or agreed and 5 turned down, and has 1 and 0. Until then a loan is asked at what the loan rule says a borrower bears." and "Your loans show no line: borrowers have offered or agreed to bear about … of value a month and others turned down about …".*

*An ask alone opens no deal, so the first line said "Sales: nothing recorded." while an ask stood on the screen. The reading now counts the asks of its kind in the window, and with asks and no deal the first line is "Sales: 1 ask recorded since Fri 13 Nov, and no deal yet." ("2 asks" in the plural), followed by the line saying what is not measured yet; with deals it is as before, and with neither "Sales: nothing recorded.". The same holds for loans.*

## 7. The words and the evidence

Every sentence is the engine's (`AdvisorText`, a new file for offers), shown as written. Each suggestion carries the weakest evidence among the numbers it used, as every other piece of advice does, and its lines say which is which: the club's budget is the club's own figure as entered; the rest is carried over or this tool's estimate. A measured number says how many deals it rests on and that it is this tool's estimate.

The screen's first line: "Terms to propose for the players you have marked to sell or to loan out. No test in any version of the game shows what a club accepts: every figure here is a place to start, and says what it rests on."

An evidence note stands at the foot, saying in a few lines what is known (a club offers only what it can afford, FM26, official), what is carried over from reports (the sale at about value, 20% of the next fee, the loan rule, the counter), and what is this design's own (the 10% steps, the 12 months, the counts needed to measure). *Revised during the build: the counter is said as "a counter of up to 20% over a bid", since the counter is capped at the ask.*

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

- The players are those marked, in two parts, "To sell" and "To loan out", each in the squad's order. With nobody marked the screen says so and leads to Player Removal, where a player is marked. *Revised on 22 November 2026 at the owner's request: the parts still list who is marked which, and each block has a two-way control beside the player's name, "Sale terms" and "Loan terms", which starts at his mark's kind and is saved with his value. It changes only which terms his block works out: the ask of clubs in general, the proposal to a club, and what "Record this ask", "Record my proposal" and "Record their bid" record from those two places. The loan's purpose menu stands beside it whenever loan terms are shown. A loan cannot be worked out for a player on a youth contract or one already out on loan: the control offers sale terms only, and the engine's sentence stands under it ("A player on a youth contract cannot be loaned out; he can be sold or released." or "He is out on loan already, so only a sale can be worked out."). His deals and asks of both kinds stay in his block whatever the control shows; each card's heading names its kind ("Barnet · sale · open"), "No bid came" is offered on his latest ask of each kind, and a card's next step and the rounds recorded from its buttons follow the deal's kind. The line saying an open deal with the club named is below is about a deal of the kind shown.*
- A recorded round is entered in a sheet, as the fixture and mentoring editors are, opened filled with the suggestion. *Revised after the whole-branch review: the owner's own round or ask opens filled with the suggestion; "Record their bid" opens blank (section 5). How each amount was read is shown beside its field (section 1).* The owner's round then shows "Accepted", "Refused" and "No reply" until one is pressed; "Record their bid" records a round of the club's.
- Under the deal's last round stands the suggestion for the next one, worked out from the rounds so far.
- Deals and asks for a player who is no longer marked (sold, out on loan, or the mark taken off) are listed at the foot under "Earlier offers", closed at every launch behind a line saying how many, with their rounds and nothing to press but the deletion. They still count in the measures. *Revised on 22 November 2026 at the owner's request: "Earlier offers" holds only the deals and asks of players who hold no mark or are in no squad; a deal of the other kind than his mark's stays in his block.* *Revised on 22 November 2026 again, after the review of that change: "nothing to press but the deletion" no longer holds for an open deal. Wherever its card is shown (under "Earlier offers", or a loan deal of a player who can no longer be loaned), an open deal offers what records its outcome: "Accepted", "Refused" and "No reply" on the owner's last round with no answer, "I accepted" on the club's, and "End"; only the next step and the two "Record…" buttons are withheld, since no terms can be worked out for him. Otherwise a deal the club accepted in the game after the player left could never be recorded as agreed, and the measures would lose it. An agreed or ended card still offers only the deletion.*
- The buttons that record or answer a round are ignored within half a second of the last, as Training's and Scouting's are, since each moves the next button under the pointer.
- *Revised during the build:*
  - *The mark sets the kind (the plan's call 4): a player marked to sell gets sale terms only, and one marked to loan out loan terms only.* *Revised on 22 November 2026 at the owner's request: the mark no longer sets the kind; the control above does, starting at the mark's.*
  - *"Record my proposal" and "Record their bid" are offered beside a club's line naming a figure it needs, not only under its terms: a club's bid needs no figures, and could not otherwise be recorded. The sheet then opens blank.*
  - *A loan to move his wage has no playing-time menu in the sheet, since such a loan asks none. The club's own offer for a development loan opens at less than a starting place.*
  - *The sheet closes only when something was recorded: recording says recorded, refused with the engine's sentence (shown in the sheet), or ignored (a second click within the half second, or a blank club), and the sheet stays open for the last two.*
  - *Under "Earlier offers" each card's heading and each ask names the player ("Old Boy · Barnet · ended"), since nothing else says whose they are.* *Revised on 22 November 2026 at the owner's request: every card's heading names the deal's kind too ("Old Boy · Barnet · sale · ended").*

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
- Whether `lineup-cli` gets a command that prints a suggestion for a player of the captured squad. *Revised during the build: it gets none (the plan's call 3), since the captured squad has no values.*
- The exact wording of each sentence, within the examples above.
- How a typed amount is read (digits, with the currency symbol and separators ignored), as the League screen's numbers are. *Revised after the whole-branch review: one function reads every typed amount, the League screen's three numbers included: the ASCII digits of the text, at most 12 of them (digits beyond the twelfth are dropped, so a long paste no longer clears a saved value), blank with none. No K or M is read; the reading beside the field shows what was taken.*

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
13. *Revised on 22 November 2026 at the owner's request:* the mark no longer sets the kind; every marked player can be shown sale terms or loan terms, except that a player on a youth contract or out on loan can be shown sale terms only.

A reviewer read this as a builder on 22 November 2026. Its four questions are answered in the text: a value of 0 (section 1), which deals measure the counter step (section 6), the playing-time levels (section 4) and how the steps down add up and where they stop (sections 3 and 4).
