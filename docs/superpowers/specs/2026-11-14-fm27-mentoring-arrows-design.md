# FM27 Lineup Optimizer: mentoring from the game's own arrows

Date: 14 November 2026
Status: approved by the owner on 14 November 2026 ("Yes, you can save my readings", in answer to the request to approve it with his answer on the fixture); built, by `docs/superpowers/plans/2026-11-14-fm27-mentoring-arrows.md`

This changes the mentoring advice built to `docs/superpowers/specs/2026-11-14-fm27-mentoring-design.md` ("the first design"). Where the two differ, this one wins. What is not mentioned here stays as the first design has it.

## 1. Intent

The first design worked out who influences whom from rules of earlier versions of the game: a hierarchy level, an age gap, a shared social group. On 14 November 2026 the owner read what the game itself shows. In the game a mentoring group is three players with an arrow each way between every pair, and each arrow is None, Light, Average or Significant. He read 24 groups, 124 ordered pairs, and re-read the surprising ones. The readings show that the rules predict the arrows poorly, and that the game hands the answer over for nothing: set a group, look at it.

So the app should take the arrows the owner reads as the measure of influence, guess only where no arrow has been read, say plainly which is which, and keep doing what the game does not do: tell him which arrows are worth having, and which would pull a player the wrong way.

## 2. What the readings showed

All from the owner's first team, FM27, 14 November 2026. Evidence label for everything in this section: FM27 observation.

| Finding | Readings behind it |
|---|---|
| A pair's arrow was the same in every group it was read in. | Two pairs with an arrow were each read in two groups with a different third player; every re-read of a surprising pair agreed. |
| Team Leaders are far stronger than anyone else. | Of the 8 arrows the two Team Leaders gave, 6 were Average or Significant. Of 18 arrows from every other senior with a level, 1 was. |
| A player at "Others" gives nothing, whatever his age. | Dozens of pairs, including seniors five and six years older in the same social group. One exception, confirmed on re-reading. |
| Age alone creates no influence. | A group of three at "Others" aged 25, 20 and 19 had no arrow. An Influential player of 23 gave Light to a 20-year-old. |
| Players of 24 and over rarely receive. | Of four such players, one took Light from two seniors; the rest took nothing in eight tries. |
| Some players take nothing from anyone. | One 18-year-old took nothing from four seniors, a Team Leader among them; one 24-year-old nothing from four. |
| A shared social group made no reliable difference. | Team Leaders gave Significant across social groups and Average inside their own. |
| Several arrows are explained by nothing the app imports. | A Highly Influential player reaches four juniors and not two others; both Team Leaders give nothing to a player who takes Light from two lesser seniors. Level, age, reputation, date joined, caps, relationships and personality were all checked. |
| The game's own groups are not chosen for the players' good. | One of its four groups paired a player of Determination 14 with a Team Leader of 7; another had no arrow at all. |

Not known: whether an arrow changes the longer a group stays together, and whether injury is what stops the 18-year-old receiving.

## 3. Goals

1. The owner can record the arrows the game shows for any three players, whether or not they are a group he keeps.
2. Suggested groups rest on recorded arrows wherever one has been read, and on a stated guess where none has.
3. Every arrow the screen shows says whether it was read, and when, or is the app's guess.
4. An arrow that would pull a player down in an attribute that counts is shown as a warning with its strength, and no group with one is suggested.
5. A group the owner has recorded whose arrows are all None is called out at once, not after thirteen weeks.
6. A squad with no hierarchy entered gets no suggestions by age alone; the tab says what to enter.

## 4. Non-goals

- Predicting an arrow from anything but the player's level and age. The readings show nothing else that helps.
- A planner of which trios to try in order to learn the most. A suggestion that rests on guesses is itself the thing to try.
- Any forecast of how fast a value will change. Still unknown; the readings at each import still measure it.
- Using social groups in the advice. They are kept as entered and no longer change anything (section 8.4).
- Asking the owner to re-read arrows on a schedule. Whether they change with time is not known; the day each was read is shown.

## 5. Anti-goals

- A guess shown as if it had been read.
- A strong arrow shown as good news when it pulls the wrong way.
- Advice by age alone, which the readings show does not work.
- Making the owner type an arrow twice: an arrow read once for a pair serves every group that pair is in.

## 6. Constraints

- The project's rules in `CLAUDE.md` apply unchanged.
- The numbers that come from the owner's readings take the evidence label "FM27 observation", with a source that names the readings and their date. The guesses built on them are "derived".
- The saved mentoring file must still open: a file written before this change has no arrows and loses nothing.
- The owner's readings name real players. Player data goes in the repository only as a test fixture (section 11).

## 7. Approaches considered

1. **Tune the first design's rules to the readings** (Team Leaders stronger, drop age alone, drop social groups). Cheap, and still wrong for every pair the rules cannot explain, of which the readings found several in one squad.
2. **Record arrows and use them; guess, labelled, where none is read. Chosen.** The game computes the arrows and shows them for free; the app adds the judgement of which are worth having.
3. **Record arrows and suggest nothing until every pair has been read.** Honest, but a squad of twenty has 380 ordered pairs; the owner would never get advice.

## 8. The design

### 8.1 An arrow

An **arrow** is from one player to another in the same squad and has a strength: None, Light, Average or Significant, the game's four. A **reading** is an arrow the owner entered, with the day he read it. One reading is kept for each ordered pair: a later reading replaces an earlier one, and the owner can take a reading away by setting the arrow back to "not read" (he may have entered it wrongly). A reading belongs to the pair, not to a group, because the same pair read the same in every group (section 2).

A reading is used only while both players are in the squad it was read in. Nothing deletes it when a player moves; it simply is not used, as with a hierarchy entry.

### 8.2 The guess where nothing has been read

For an ordered pair with no reading, the engine guesses from the source's level and the target's age:

| Source's level | Target 23 or younger | Target 24 or older |
|---|---|---|
| Team Leader | Average | None |
| Highly Influential or Influential | Light | None |
| Others | None | None |

and None in any case when the target stands at the same level as the source or above it, or is a player who **takes nothing**: one with readings of None from at least three different sources at Influential or above and no reading above None. The three is this design's choice, "derived".

A guess is always shown as a guess. The table is "derived"; the findings it is built from are "FM27 observation".

The first design's rule that a player five years older at the same level stands above another is removed, and with it the parameter. So is the halving for a different social group.

### 8.3 What an arrow is worth

The first design's worth of a value stands: Professionalism weight 3 up to 20, Pressure 2 up to 6, Determination 1 up to 10, Ambition 1 up to 10.

An arrow's **gain** for its target is the first design's gain from the source (the source's worth less the target's, summed over the four attributes) times the arrow's strength: None 0, Light 1, Average 2, Significant 3. The strengths' numbers only order the choices; "derived". An arrow of any strength above None is **harmful** when the source is worth less than the target in any one counted attribute, however much he offers in the others.

Gain is still never shown as a number. The screen shows the strength in the game's word and the two values.

### 8.4 Building the suggestions

A **candidate** is as in the first design, without the age line: a player of the club's own, not advised to leave, not in a recorded group, below the ceiling in at least one counted attribute. Age now acts through the arrows: a player of 24 or over is guessed to take nothing, and comes in only where a reading says otherwise.

A suggested group is any three players of the squad, not out on loan and in no recorded group, such that:

1. No arrow among the six, read or guessed, is harmful.
2. At least one candidate in it has an arrow into him with gain above nothing.

There is no "lead" and no "making up the group": the six arrows say who influences whom. A candidate's gain in a group is the greatest gain of any one arrow into him, not the sum: how two arrows into one player combine is not known, and adding them would spend two seniors on one junior. The group's value is the sum of its candidates' gains. Rule 1 still looks at every arrow. This is the design's call, "derived".

A suggestion **rests on** the arrows that give its candidates their gain. It is called read when every one of those was read, and a guess when any was guessed; a guess carries the line asking the owner to set the group in the game and record its arrows.

A member of a suggested group who is the source of an arrow with gain and is on loan at the club or advised to leave carries the first design's caution, since the group ends when he goes. Such a player is still never a candidate.

Groups are found as now, most to gain first: the group of greatest value is taken, its three players are set aside, and so on until no group meets the two rules. Ties: the group that uses fewer players with a level above Others, so that a senior is not spent in a group where he adds nothing and is free for a junior later; then more of the group's arrows read; then the players' keys.

In a squad where nobody has a level above Others, every guess is None, so nothing is suggested by guessing; the tab says the hierarchy must be entered first. Arrows the owner has read in that squad are facts and still count: a group whose read arrows meet the two rules is suggested. The first design's "by age alone" is removed.

Candidates in no suggested group are listed as not placed, with the first reason that applies: he takes nothing, by his readings; no arrow into him is above None (read or guessed); every arrow into him that has gain is in a group that would harm someone; the players who could influence him are already in a group.

### 8.5 Reading a recorded group

For each recorded group the engine gives its six arrows, read or guessed, and from them:

- a warning for each harmful arrow, naming its strength: "Ashby's influence on Nelson is Significant, and Ashby's Ambition is 6 against Nelson's 13.";
- **no influence**, at once, when all six arrows have been read and all are None;
- a prompt to read the arrows when any of the six is still a guess;
- everything the first design reads from the personality readings (what has changed, doing harm, stopped after thirteen weeks), with two changes. The rule about who stands above whom is replaced by the arrows. And the members watched for "stopped" are those with an arrow above None into them, read or guessed; when no member has one, the group is never called stopped, because nothing was expected of it. "Doing harm" still looks at every member.

The mark "Lead" on a recorded group's card is removed: the arrows say more.

### 8.6 Social groups

The entry stays where it is and is kept in the saved file. It no longer changes any advice, and the caution about a different social group is removed. The hierarchy editor says so in one line.

### 8.7 Errors and evidence

As the first design. Each suggestion and each warning carries the weakest evidence behind it, as now. The weights and the strengths' numbers are "derived", so that note reads "this tool's estimate" whether the arrows were read or not. What tells read from guessed is on each arrow's own line, and in whether the suggestion is called read or a guess (section 8.4).

## 9. Persistence

The mentoring file gains the readings: for each ordered pair, the squad, the strength and the day read. A file without them opens as it does now. Names are kept for the players in readings, as for group members.

## 10. The screen

On the Mentoring tab:

- **A new action, "Record arrows"**, beside "Add a group". It opens a sheet: choose three players of the squad, then set each of the six arrows to None, Light, Average, Significant or not read. Arrows already read for those pairs are filled in. Saving keeps the readings and records no group. A recorded group's card has the same action, opened on its three members, and the group editor leads into it after a new group is saved.
- **Cards show arrows, not a lead.** A suggested or recorded group lists each arrow above None on its own line: who to whom, the strength in the game's word, then the two values of each attribute the target would gain in. A read arrow carries its day; a guess is muted and says "expected, not read".

```
SUGGESTED GROUPS
┌──────────────────────────────────────────────────────────────────────────────────┐
│ McEachran, Clark, Humphries                                                      │
│   McEachran → Clark       Significant · read 14 Nov                              │
│                           Professionalism 10, towards 12 · Determination 7,      │
│                           towards 12                                             │
│   McEachran → Humphries   Average · read 14 Nov      nothing to gain             │
│   This tool's estimate                                         [ Record as set ] │
└──────────────────────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Maxted, Nelson, Thompson                                                         │
│   Maxted → Nelson         Light · expected, not read                             │
│                           Professionalism 9, towards 13 · Determination 5,       │
│                           towards 13                                             │
│   Maxted → Thompson       Light · read 14 Nov        nothing to gain             │
│   Set this group in the game and record its arrows.                              │
│   This tool's estimate                     [ Record arrows ]   [ Record as set ] │
└──────────────────────────────────────────────────────────────────────────────────┘

YOUR GROUPS                                      [ Record arrows ]   [ Add a group ]
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Ashby, Clark, Nelson · since 14 Nov                                              │
│   ⚠ Ashby's influence on Nelson is Significant, and Ashby's Ambition is 6        │
│     against Nelson's 13.                                                         │
│   Ashby → Clark    Significant · read 14 Nov                                     │
│   Ashby → Nelson   Significant · read 14 Nov                                     │
│   Clark → Nelson   Light · read 14 Nov                                           │
│   Clark   Professionalism 10, no change …        [ Arrows ]  [ Edit ]  [ End ]   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

- **Hierarchy part.** When no level above Others is entered for the squad, it says that mentoring needs the hierarchy and that age alone creates no influence. The line about groups going by age alone is removed.
- **Not placed** reads as section 8.4 says.

The pictures gain: the arrows sheet; a suggestion resting on readings; one resting on a guess; a recorded group with a harmful strong arrow; a recorded group with no influence; a squad with no hierarchy.

## 11. The owner's readings as a fixture

The tests of sections 8.2 to 8.5 run on what the owner actually read. Two files under `LineupEngine/Tests/LineupEngineTests/Fixtures/mentoring/` hold it, both saved with his agreement on 14 November 2026, because they name his real players in a public repository and the project's rule lets player data in only as a fixture:

- `arrow-readings-2026-11-14.json`: the 24 groups he read, with every arrow that was above None and the pairs he read a second time.
- `first-team-2026-11-14.json`: each first-team player's age, the level and social group he entered, and the four personality values the advice counts. It was copied from the app's saved state on his instruction ("Yes, copy those from the app's saved state"), in place of a fresh capture; nothing else was taken from there.

With them a test says how often the guess of section 8.2 agrees with what he read, so a later change to the guess can be seen to help or not.

## 12. Testing

- Engine, each rule both ways: a reading replaces a guess; the guess table, cell by cell; a player who takes nothing; gain scaled by strength; a harmful arrow of each strength; a group needs an arrow with gain; no hierarchy gives no suggestion; a group with six read Nones has no influence; a moved player's readings are not used.
- On the fixture: the suggestions for the first team contain no harmful arrow; the guess is compared with every reading and the count of agreements is pinned.
- Core: recording arrows, replacing one, the sheet filled from earlier readings, the file opening without readings, names kept.
- Pictures looked at; the app built.

## 13. Sequence

1. Engine: arrows, readings, the guess, and who takes nothing.
2. Engine: gain by strength, harm, and the suggestions rebuilt on arrows.
3. Engine: recorded groups read from arrows; the words.
4. The fixture, and the check of the guess against it.
5. Core: readings kept and recorded; the cards' rows.
6. UI: the arrows sheet, the cards, the pictures.
7. Build; documents.

## 13a. Added on 15 November 2026: when a recorded group should be broken up

The owner's request, after using the built tab: "the app doesn't tell me when an existing mentoring group is no longer optimal. I like the ability to manually choose and save mentoring groups, but the app should still indicate when a mentoring group should be dismantled." Asked whether that meant a group that has run its course, or also players who would do better in other groups: "It should cover both cases." Built without a plan.

**A group that gives nothing.** A recorded group is read for what it still gives (`GroupReview.gain`). A member gains when an arrow above None into him, read or guessed, comes from a member worth more than him over the counted attributes together, as a suggestion counts a gain. When no member of the club's own who is staying gains (none at all, or only a player on loan here or advised to leave), the card says to break the group up. While any of its six arrows is a guess it says that this is what the tool expects, and to record the arrows first. While no player of the squad has a level above Others every guess is None, so nothing is said until all six are read. Doing harm and no influence are said first; "stopped working" is said only for a group that still gives something, or of which that is not known.

**A regrouping.** For each recorded group of the squad, and each two of them, the engine groups their present members with the free players in no suggested group, by the rule that forms the suggestions. The new groups' value is compared with the value of the groups broken up, where a recorded group with a harmful arrow or with no gain has none. A group of which it is not known what it gives (a guess among its arrows, in a squad with no level entered) is never broken up. A regrouping counts when the new value is greater and at least 1.5 times the old (`mentoringRegroupFactor`, this design's choice: a regrouping often rests on arrows not yet read, and the guess is wrong for about one pair in six). The one with the greatest difference is shown; of two the same, the one that breaks up fewer groups. It is shown under the owner's groups as "Regrouping to try": the engine's sentences (what to break up, who would be left in no group, and that it rests on a guess when an arrow the new groups rest on, or any arrow of a group to break up, has not been read), then the groups as cards with their arrows and nothing to press. Each group to break up says so on its card. Ending the group in the app frees its players, and the groups are then suggested in the ordinary way.

Limits. The suggested groups are left as they are, so a free player in a suggestion is never taken for a regrouping. Three or more groups are never broken up together. The groups are found greedily, as the suggestions are, so a better regrouping can exist and not be shown. The count behind it is the one that orders suggestions; it predicts nothing, and no number is shown. What a group has already changed in its members is not weighed against breaking it up.

## 13b. Added on 15 November 2026: a member who will go

The owner recorded a suggested group of Ellis Brown, Matty Taylor and Dejan Tetek. Its card said Brown was advised to leave; the suggestion had said nothing, because 8.4 gave the caution only to the source of an arrow with gain, and Brown only made up the three. When the owner ended the group, the same three were suggested again: with all six of their arrows now read, they won every tie on "more arrows read".

Two changes to 8.4, built with no plan:

- **The caution** is carried by any member of a suggested group who is on loan at the club or advised to leave, whatever he gives. A group needs its three, so it ends when he goes.
- **Ties** go first to the group with fewer members who will go (on loan at the club or advised to leave), then as before: fewer players above Others, more arrows read, the keys. So a player who is staying makes up a group before one who is going, even when the other group's arrows have all been read and even when the one staying has a level above Others. A greater value still comes first, so a group is never worth less for it, and a player who will go is still used when nobody else free can make up the group.

On the owner's saved state of 8 September 2026 (in the game), ending that group now suggests Matty Taylor, Dillon De Silva and Dejan Tetek, resting on the same read arrow. A recorded group is not looked at again for this: the card says a member is advised to leave, as before, and the owner ends the group to be offered another.

## 14. Left to the builder

- The types' names, and how the readings are keyed and saved.
- How the group of greatest value is found, so long as the rules of section 8.4 hold and the same inputs give the same groups.
- The layout of the arrows sheet.
- The exact wording of each sentence.

## 15. Open items for the owner

1. **Saving the readings as a fixture** (section 11): they name his real players, in a public repository, as the captured squads already do.
2. **Whether arrows change with time.** If a group left in place for some weeks shows a different colour, the app should ask for arrows to be read again; until then it only shows the day.
3. **The 18-year-old who takes nothing.** If he starts to receive once fit, injury is the block, and the app could then treat an injured player as taking nothing for the time being.
