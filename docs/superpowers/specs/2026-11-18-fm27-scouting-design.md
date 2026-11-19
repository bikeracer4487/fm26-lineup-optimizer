# FM27 Lineup Optimizer: scouting needs and pasted candidates

Date: 18 November 2026
Status: approved by the owner on 18 November 2026 ("Approved"), with the calls this design made listed to him beforehand. A reviewer read it as a builder on 18 November 2026; the points it raised were settled in the text as this design's calls.

## Intent

The owner wants to decide which positions to scout, and then to judge the players he finds. In his words: "I'm trying to decide which positions I should be trying to scout and then I want to use the FMRTE data on those players' normally hidden attributes to determine both their actual fit into my tactic and their realistic potential growth."

Two things are asked for.

- **Where to scout.** For a tactic, the slots most in need, each marked as needing a better player, more depth, or both.
- **Who to sign.** The owner pastes a search result or a shortlist from FMRTE, and each pasted player is judged on what he would add today and where his ability could reach.

Today the app says where cover is thin (Depth) and nothing about a first choice who is not good enough. It reads FMRTE's search grid already, for the owner's own squads, and judges his own young players on their reach (Player Removal). Nothing judges a player from another club.

## Goals

1. For any saved tactic, the app lists the slots to scout for, and says of each whether it needs a better player or more depth, with the numbers behind it.
2. The owner can paste players from FMRTE and see, for each, the slots of that tactic he can play, where he would stand at each today, and, for a player of 23 or under, where his reach would put him.
3. Pasted players who answer a need are shown first, under the slot they answer.
4. FMRTE's hidden attributes are used: Professionalism, Ambition and Determination in the estimate of growth, and Consistency, Important Matches, Injury Proneness, Controversy and Temperament as cautions on the player.
5. Pasted players are read, judged and forgotten. Nothing about them is saved, and no other screen changes.

## Non-goals

- Comparing the squad with the league or with opponents. The owner chose to measure a slot against his own eleven and against what is about to change.
- A budget, or a judgement of what is affordable or whether a price is fair. Asking price and wage are shown as FMRTE pastes them.
- A saved shortlist. The owner chose read and forget; FMRTE is where the shortlist lives.
- The knock-on effect of a signing, such as a new left back freeing the present one to play elsewhere. Each player is judged slot by slot.
- Whether the player would join, what he would cost in wages after a move, or who else wants him.
- Retraining a pasted player into a position he does not play.
- Measuring decline with age. A first choice of 30 or over is named with his age, as elsewhere in the tool.
- Staff.

## Anti-goals

- A pasted player entering the squad book, the elevens, the plan, the marks, the mentoring file or any other advice.
- One blended score for a candidate. Today and later are two verdicts.
- A reach, or a need, presented as fact. Both are this tool's estimates, and each line shows its working.
- A paste that saves anything.

## Approaches considered

### What "needs a better player" is measured against

1. **The owner's own eleven: a first choice who rates well below the rest. Chosen** by the owner on 18 November 2026, together with 2.
2. **What is about to change: a first choice who is going or ageing, with nobody on course to take over. Chosen** with 1.
3. **Opponents: a first choice below what league rivals field there.** Dropped by the owner. It is the only measure that answers "good enough for this league", but it needs several opponents' squads pasted and kept, where the app keeps one ability average for each.

### What happens to a pasted list

1. **Read and forget. Chosen** by the owner ("1 is all the functionality I'd need"). The list is judged while it is held, and is gone at the next paste or when the app quits.
2. **Keep the last paste across a restart.** Dropped by the owner.
3. **A saved shortlist that pastes add to.** Dropped by the owner.

### How a candidate is judged

The owner left this to the builder. It is this design's call, stated to him before the design was written.

1. **Slot by slot. Chosen.** The candidate is rated at each slot he can play and set beside the first and second choice there, today and at his reach. It answers the question the owner asks ("is he better than my left back"), and it is how Player Removal judges his own young players, so the levels and the working are the same.
2. **Solve the elevens again with the candidate in the squad.** Dropped: it catches knock-on effects, but it gives one number for the team instead of an answer about a position, and growth does not fit it.
3. **Both.** Dropped: more work, and two answers that can disagree on one screen.

## The design

### The squad that stays

Scouting is for the squad the owner will have, so it is judged without the players who are going. A player is going when any of these holds:

- he is on loan at the club;
- the owner has marked him to sell or to loan out;
- Player Removal advises releasing, selling or terminating him (its `advisedToLeave`, worked out for the primary tactic as now). A loan for matches is not among them.

The elevens and the depth are solved once more for the chosen tactic from the players who are staying, with the code the Elevens screen uses. With nobody going they are the Elevens screen's own. Players out on loan are left out as now. Everything below is judged on these: "first choice" and "second choice" mean the first and second choice among the players who stay.

The Needs tab names everyone counted as going, with the reason, so the owner can see what the list rests on. Player Removal's advice is advice and not his decision; the Training screen already discounts cover that is advised to leave in the same way.

### Needs

Each slot of the tactic can carry a "Better player" line, a "More depth" line, both or neither.

**Better player.** The first of these that holds:

1. **Nobody.** The slot has no first choice, or its first choice is out of position there (familiarity under 10 in either phase).
2. **Weak.** For an outfield slot: the first choice's rating there is 5% or more under the average rating of the outfield first choices. First choices who are out of position are left out of the average. The line gives the gap: "rates 5.7% under the average of your outfield first choices".
3. **Ageing.** The first choice is 30 or over, and no player of the club's own who is 23 or under, staying and not first choice at another slot is close or on course to pass him at the slot (the reach bands Player Removal and the planner use; the planner already holds that a first choice at any slot is nobody's successor). The line names his age and says decline is not measured, so this is a prompt to look and not a finding.

When the slot's first choice in today's elevens is going, the line says so, naming him and why: "Canice Carroll, first choice today, is on loan here. Josh Ashby, the best who stays, rates 7.2% under the average of your outfield first choices."

A "Nobody" or "Weak" need is **eased** when a player of the club's own who is 23 or under and staying, the first choice himself included, has a reach rating at the slot that clears the weak line (95% of the outfield average); a "Nobody" need is measured against that same line. A player who is first choice at another slot eases nothing, since he cannot fill both (revised during the build on 18 November 2026: on the captured squad the need at left defensive midfield was shown as eased by the first choice at right defensive midfield). The need stays on the list, below the ones that are not eased, and its line names him: "Evan Humphries is 20; his reach would bring him level (this tool's estimate)."

**The goalkeeper.** Goalkeepers are rated on their own scale: on the captured squad the goalkeeper rates 83 where outfield first choices of like ability rate 106 to 124. So the goalkeeper is not compared with the outfield by rating. His current ability is compared with the average current ability of the outfield first choices, each taken through the same offset the tool already uses to scale a rating with ability (`ratingAbilityOffset`), against the same 5% line. The line shows the two abilities and says ability was compared. A goalkeeper's need is eased the same way: by a young goalkeeper whose reach, as ability through the offset, clears that line.

**More depth.** Fewer than two players who are staying count as cover at the slot, by Depth's own rule and Depth's own count (solid, rated at least 80% of the first choice, not injured, not first choice elsewhere). That count includes the slot's first choice when he qualifies, so a slot is not thin when it has its first choice and one more; the numbers and sentences are Depth's ("1 player counts as cover; 2 needed") and agree with the Elevens and Training screens. The line gives the count, who counts, and the drop to the next best. It names a player who counts as cover today and is going, as Training's needs do. It names a player out on loan who would count as cover on his return.

**Order.** The Needs tab shows two lists and makes no ranking between the two kinds, since nothing measures a weak first choice against a missing stand-in.

- Better players: "Nobody" first, then "Weak" by the size of the gap, then "Ageing" oldest first. Within the first two, eased needs come after the others.
- More depth: Depth's order (least cover, then the larger drop to the next best).

A slot with both lines is in both lists. Slots with neither are listed last as fine.

### The paste

The Candidates tab has a "Paste players" button. It reads the clipboard through the squad importer with FMRTE's settings file, as the opponent's squad paste does. Any FMRTE player grid with the importer's required columns is read. The search grid carries each player's club and asking price; the team grid carries neither, and the row then shows neither.

- **Left out.** A pasted player the owner already holds is left out, and one sentence says how many and who. He is taken to be held when his key and a held player's are both FMRTE ids and are the same, when his club or the club he is loaned to is the owner's club, or when a held player has the same name, age and potential ability. Keys that are names are not matched on their own, since a namesake at another club would be dropped. The last rule is needed because the owner's squads are keyed by FMRTE's id and the search grid has no id column. The rules are applied again each time the held players are judged, so a candidate the owner has since signed and imported drops out of the list.
- **On loan elsewhere.** A pasted player who is on loan from his club at a third club is judged like any other, and his row says where he is on loan. (The engine's own squads leave such a player out; a candidate is not left out.)
- **Refusals.** Each is a sentence from the engine, and none changes what is held: the clipboard is empty or the importer refuses the rows (its own sentences); the owner has no squad or no usable tactic (the advice's own notices); every pasted player is already the owner's.
- **Warnings.** The importer's note that players are identified by name is not shown, since no identity is kept. A player it reads as out of contract is shown as a free agent.
- **Money.** Asking price and wage are shown as the paste carried them: its currency symbol, and wages in FMRTE's period. No money is compared, so a paste in another currency than the squads' raises nothing.

### Judging a candidate

A candidate is judged at each slot of the chosen tactic he can play: familiarity of 10 or over in both of the slot's phases, Depth's line for an option. His rating there is the engine's full-fitness rating, the one Elevens and Depth use, under the rating profile in use. Condition, sharpness and jadedness play no part. An injury is marked on his row and changes nothing else.

**Today.** One of four, against the first and second choice at the slot:

| Level | Rule |
|---|---|
| Would start | he rates at least as high as the first choice, or the slot has none |
| Would make the second eleven | he rates at least as high as the second choice, or there is none who is in position |
| Would count as cover | he rates at least 80% of the first choice (`depthCoverShare`) |
| Below cover | under that |

The line names who he was compared with and gives the gap: "Would start: rates 6% above Evan Humphries, your first choice at left back." At a slot whose first choice is out of position, the candidate is compared with that player's rating there like any other first choice. When his familiarity is under 15 in either phase the line says he is not yet solid there, with the two numbers. When he would start at a slot with a "Nobody" or "Weak" need and his own rating is still under the weak line (for a goalkeeper, his ability), the line says the slot would still be weak with him, with the gap.

**Later.** For a candidate of 23 or under (`developingUpToAge`, the age Player Removal uses). His reach is `Reach.estimate`, unchanged: growth for his age scaled for Professionalism, Ambition and Determination, never above his potential. His reach rating at the slot, his level against the first and second choice (could pass the first choice, could make the second eleven, could become cover, markedly lower), his band (close, on course, possible, not expected) and the working are those Player Removal shows for the owner's own young players, from the same code, made to take a player who is not in the squad. A first choice who is himself developing is compared at his own reach, as now. At a slot with no first choice there is nobody to compare with and so no level: the line gives his reach rating and whether it clears the weak line.

The growth table rests on a player getting 20 to 30 matches a season. For a candidate who would not make the second eleven today, the line says the estimate assumes regular matches.

A candidate of 24 or over has no "Later": the line says he is judged as he is today, and from 30 it names his age and says decline is not measured.

**Cautions.** A candidate carries a caution, with the value, for each of these, on Player Removal's own lines (`removalRules`): Consistency below its low line, Important Matches below its line, Injury Proneness above its line, Controversy above its line, Temperament below its line, Professionalism below its low line. They carry no points and change no level.

**Answering a need.**

- He answers a "Better player" need today when he would start at that slot, and later when he is 23 or under and could pass the first choice there.
- He answers a "More depth" need when he would count as cover or better at that slot today and is solid there.

**His headline slot** is the first of: a slot where he answers a "Better player" need today; one where he answers a "More depth" need; one where he answers a "Better player" need later; otherwise the slot where his level today is best, then where his rating over the first choice's is greatest, then the earlier slot. His other slots are shown when his row is opened.

**The list.** Four parts, in this order, each candidate once, under his headline slot:

1. Answers a need today, grouped by slot: the "Better player" slots in their order, then the "More depth" slots in theirs, best rating first. A slot with both needs has a group under each kind.
2. Could answer a need later, grouped the same way, best reach rating first.
3. Would start at a slot where he answers no need, greatest margin first. That is a slot that is fine, or a slot with only a depth need where he is not yet solid.
4. The rest, one line each. A candidate who can play no slot of the tactic is here, with a sentence saying so.

A "Today / Later" control orders the candidates inside each slot's group by rating today or by reach rating. It does not move a candidate between parts.

    Scouting · Sample 4-2-3-1                         [ Needs | Candidates ]

    [ Paste players ]  [ Clear ]     Today · Later
    42 players read. Left out, already yours: Keegan Bloom, Ellis Brown.

    ANSWERS A NEED TODAY
    Left back · needs a better player
      A. Example   21   D L, WB L   Wrexham      asking £350K   wage £2.1K p/w
         Today   Would start: rates 6% above Evan Humphries, your first choice
         Later   Could pass the first choice · ability 112, towards 131 of 140
                 Professionalism 15, Ambition 12, Determination 14 (this tool's estimate)
         Caution Injury Proneness 16
      B. Example   27   D L         Barnet       asking £90K    wage £1.4K p/w
         Today   Would start: rates 1% above Evan Humphries, your first choice
         Later   Judged as he is today

    Goalkeeper · needs more depth
      C. Example   24   GK          Free agent                  wage £0
         Today   Would count as cover: rates 12% under Jonny Maxted

    COULD ANSWER A NEED LATER
    ...

### Held, not saved

The pasted players are held in the app's model and nowhere else. They are never written through `Store`. A new paste replaces them, "Clear" removes them, and they are gone when the app quits. While they are held they are judged again whenever the squad, the tactics, the marks or the chosen tactic changes, since judging is cheap. A paste does not plan and does not work the other advice out again.

### The screen

A "Scouting" screen in the sidebar, after Player Removal, with two tabs, "Needs" and "Candidates", and a tactic menu like the Elevens screen's. It stands behind the same gate as the other advisor screens (no squad, no tactic, advice failed) and carries the same line naming the day the advice rests on.

    Scouting · Sample 4-2-3-1                         [ Needs | Candidates ]

    Counted as going: Canice Carroll (on loan here), Alfie Potter (advised to leave), Ellis Brown (marked to sell)

    BETTER PLAYERS
    DM L   Canice Carroll, first choice today, is on loan here. Josh Ashby, the best who stays,
           rates 7.2% under the average of your outfield first choices.
    D L    Evan Humphries rates 5.5% under the average of your outfield first choices.
           He is 20; his reach would bring him level (this tool's estimate).
    ST C   Tyrone Marsh is 32, and nobody is on course to pass him. Decline is not measured.

    MORE DEPTH
    GK     1 player counts as cover; 2 needed: Jonny Maxted. Max Treml, out on loan at Wallingford, would count.
    D CL   1 player counts as cover; 2 needed: Darnell Johnson. The next best is 38% under him.

    FINE
    D R · DM R · AM C

(The lines above show the shape; the names and numbers are made up from the captured squad and are not what the build will print.)

The look follows the Tactics board direction and `Theme`. Every word about a need or a candidate is the engine's; Core holds headings and plain labels. Slots are "D L" on a token and "left back" in a sentence. The pictures of both tabs (empty, with needs, with candidates, with a refusal, with players left out), light and dark, are looked at before the work is called done.

### The command line

- `advise` prints the needs for its tactic after Depth. The command line takes no marks, so those going are the players on loan at the club and those advised to leave.
- A new `scout` command takes what `advise` takes and `--candidates <file>`, a saved paste, and prints the needs and then the candidates in the four parts.

### Parameters

One new entry in `EngineParameters`, a rules value so that it stays one pointer wide:

- the weak line, 0.95, labelled derived: the tool's own estimate, with no test behind it. On the captured first team's 4-2-3-1 the ten outfield first choices rate between 5.9% under and 9.2% over their average, and the line marks three of them (left back, left defensive midfielder, right attacking midfielder).

Everything else is read from entries that exist: `firstChoiceAgeNamedFrom` (30), Depth's four lines, `developingUpToAge`, the growth and personality entries behind `Reach.estimate`, `ratingAbilityOffset`, `markedlyLowerShare` and its youngest form, `onCourseBeforeAge`, and the lines in `removalRules` for the cautions. Each need and each verdict carries the weakest evidence among the entries it read. `FitnessModel.problems(in:)` refuses a weak line outside 0 to 1.

## Evidence

- The rating a candidate is judged on is built from his attributes under the profile in use (FM27 engine tests for outfield weights). The FM27 research found that results come from attributes and that current ability adds nothing once they are fixed, so a rating at the slot is the right measure of fit.
- The weak line (5%): the tool's own estimate.
- Comparing ratings across slots: untested. Ratings at different roles come from different weights and are not known to sit on exactly one scale; the Needs tab shows every gap so the owner can judge. The goalkeeper's comparison by ability is the tool's own choice.
- Ageing from 30: derived, as `firstChoiceAgeNamedFrom`. FM26 research puts the start of decline at 30 to 32; nothing measures it.
- Reach: this tool's estimate, as in Player Removal (growth by age from FM24 and FM26 tests, personality scaling carried over from FM26).
- Cautions: Player Removal's lines, carried over from FM26.
- What FMRTE's asking price is in the game's terms: not researched. It is shown under FMRTE's name for it.

## Known limits

- A signing's knock-on effects are not counted.
- The elevens that candidates are measured against leave out players advised to leave, which the owner may not follow. The Needs tab names them.
- A need at one of two like slots (left and right centre-back) is listed for each; one signing may answer both.
- Reach assumes regular matches, which a signing who is only cover will not get.
- FMRTE's shortlist is expected to paste in the search grid's layout. FMRTE's settings list no separate shortlist grid, but no shortlist has been pasted yet.
- What FMRTE pastes for a free agent (club, contract type, wage) has been seen only for a player of the owner's who was out of contract.

## Testing

- Engine, needs: each "Better player" rule gives its line where it holds and none where it does not, on each side of its number; the goalkeeper is compared by ability and never by rating; a going first choice is named and the best who stays is judged; a need is eased by a young player whose reach clears the line and not by one whose reach does not; "Ageing" is not raised when a young player is close or on course; "More depth" counts only cover that is staying and names cover that is going and cover out on loan; with nobody going the elevens are the Elevens screen's; the same inputs give the same lists in the same order.
- Engine, candidates: each level today on each side of its line; a candidate of 23 and one of 24; a candidate compared with a first choice who is developing; a slot he cannot play is not judged; each caution on each side of its line; answering each kind of need and not answering it; the headline slot by each step of its rule; the four parts and their order; held players are left out by each of the three rules, a namesake at another club is not, and a candidate imported into the squad since the paste drops out; a candidate on loan at a third club is judged; a slot with no first choice and one whose first choice is out of position; a candidate who would start and leave the slot weak; each refusal's sentence.
- Engine, on the captures: the needs for the captured squads under the sample tactic, written into the plan's closing section as what the advice showed. Candidates are built from captured rows read through the importer and given another club in the test.
- Core: a paste holds the players and saves nothing (the squad book, marks, mentoring file, plan and every stored file are unchanged); a refusal leaves what was held; "Clear" and a new paste; held players are judged again after an import, a tactic change and a mark; the tactic menu; saved state from before this design opens with no notice; no test touches the real clipboard or `~/Library/Application Support`.
- A real search result as a test fixture, taken with `tools/capture_fmrte_paste.sh` when the owner has one on the clipboard, with at least one free agent in it. Until then no player of another club has been through the importer, so the build ends with a hands-on check of the first real paste, and of a shortlist paste.
- Pictures, as above.

## Left to the builder

- The names of the types and functions, and how the engine's entry points are split between needs and candidates.
- How the outlook code in `Development` is opened up to take a player who is not in the squad.
- The exact wording of every sentence.
- The layout of both tabs within the Tactics board direction, and how the rest of a long paste is kept out of the way.
- Whether the Depth panel on the Elevens screen points to the Scouting screen.
- How the app decides that held candidates need judging again.
