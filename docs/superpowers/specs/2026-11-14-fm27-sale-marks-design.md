# FM27 Lineup Optimizer: marking players to sell or loan out

Date: 14 November 2026
Status: approved by the owner on 14 November 2026 ("Both designs are approved, write the build plans")

Research behind it: `docs/Research/fm27-selling-and-loans.md` and `docs/Research/fm27-playing-time-and-transfer-interest.md`.

## Intent

The owner believes that playing a player he means to sell or loan out makes the player more visible, and so brings more offers and a quicker move. He wants to mark such players and have the planner give them a little more playing time, without putting results at risk.

Two research passes found no test, in any version of the game, of whether playing a player brings offers. The belief is neither supported nor refuted. The likeliest route is indirect: matches raise reputation, and AI clubs weigh form and reputation. Both passes advise using it only to break ties.

## Goals

1. The owner can mark any of the club's own players "to sell" or "to loan out", and take the mark off.
2. A marked player is favoured slightly in low-importance and sharpness fixtures: enough to win a near-tie, not enough to start a clearly worse player.
3. A pick made for this reason says so, in the engine's words, and says the effect is untested.

## Non-goals

- An age limit on the mark. Development is already handled by the planner's rule for young players with room to grow; this rule is about being seen, which has nothing to do with age.
- Any effect in medium or high importance fixtures.
- New advice about selling. Player Removal already shows a contract running down and what a release would cost.
- New FMRTE columns (transfer status, value, reputation, average rating, appearances). They wait until a capture has them.
- Stopping the bonus when a player's ratings are poor. The app cannot see ratings.
- Treating a marked player as leaving in Training or Mentoring. A marked player can still be recommended for retraining or put forward as a mentee. This is a known limit.
- A setting for the size. It is one parameter, changed in one line.

## Anti-goals

- A bonus large enough to cost a match that matters.
- The reason presented as fact. It is the owner's belief and this tool's estimate, and the screen says so.

## Approaches considered

1. **Advice only:** the mark changes nothing in the planner. Dropped: it does not do what the owner asked for.
2. **A tie-breaker for every marked player, in lesser fixtures only. Chosen**, approved by the owner on 14 November 2026.
3. **A tie-breaker for marked players aged 23 or under only.** This followed from the first research pass, where development was the only supported reason. Dropped once the question became visibility, which is not about age.
4. **A larger bonus.** Dropped: all three research files argue against spending results on it.

## The design

- **The mark.** Two kinds: to sell, to loan out. Only a player of the club's own can be marked (not one on loan here). The app keeps the marks in a versioned file of their own through `Store`; unreadable gives a notice and a fresh start, with the file kept aside. A mark is dropped once every squad held has been imported without its player (squads are imported one at a time, so a player moved between two is briefly in neither, and his mark waits). A mark to loan out is dropped once he is out on loan, so a spent mark never favours him when he comes back. A mark on a player who becomes a loanee here (sold and loaned back, or the club's name changed) is dropped, and the rule ignores a loanee in any case. A mark can always be taken off.
- **The rule.** In the planner's importance rules, a marked player's value is multiplied by a factor in low-importance and sharpness fixtures, and by nothing in medium and high. Both kinds of mark use the same factor. It applies on top of the other rules, the one for young players included.
- **The number.** 1.03, in `EngineParameters`, labelled "derived". Its source names the two research files and says no test exists. Setting it to 1 switches the rule off.
- **The words.** The engine gives the reason on the pick: that he is marked to sell, or to loan out, and favoured for minutes, with the factor, as the other reasons show theirs. `AdvisorText` gives the names of the two marks and one sentence saying that whether playing a player brings offers is untested.
- **The screens.** On Player Removal, each of the club's own players has a control to mark him to sell, mark him to loan out, or clear the mark, and a marked row shows its mark. The untested sentence sits with the controls. Match Selection shows the reason on a pick as it shows every other reason, with no change to that screen.
- **Recalculation.** Changing a mark replans, as changing an override does.

## Testing

- Engine: the rule changes a pick between two near-equal players in a low-importance fixture; it does not in a medium or high one; it does not start a player who is clearly worse; an unmarked player is not affected; a factor of 1 gives no adjustment and no reason.
- Core: marking, changing and clearing; the file saved and read back; a mark on a player on loan here refused; the rows Player Removal shows.
- Pictures of Player Removal with marked rows, light and dark, looked at before the work is called done.

## Left to the builder

- Where the control sits on a Player Removal row and what it looks like, within the Tactics board direction.
- The types' names, and where the marks are handed to the planner.
- Whether `lineup-cli plan` takes a file of marks.
- The exact wording of the sentences.
