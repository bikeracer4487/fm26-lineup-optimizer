# FM27 Lineup Optimizer: mentoring groups design

Date: 14 November 2026
Status: approved by the owner on 14 November 2026 ("Both designs are approved, write the build plans"); built (see the plan's closing sections)

Research behind it: `docs/Research/fm27-mentoring.md`. Finding numbers below ("finding 9") are that file's.

## 1. Intent

The owner wants to improve the personalities of the squad, the hidden attributes behind "the mentality of the team", by choosing good mentoring groups in Football Manager 27. The app already imports every player's personality attributes from FMRTE. It should say who ought to mentor whom, and then show whether the groups the owner set are working.

The research found the rules of mentoring only in outline and no measured speed for FM27 or any earlier version. So the app suggests groups from the rules that are known, and measures what really happens at each import. It predicts nothing.

## 2. Goals

1. For each squad, suggest mentoring groups that pull young players towards better values in the attributes worth raising, with the reason for each member.
2. Never suggest a group in which a member is likely to get worse in an attribute that counts.
3. Let the owner enter the squad hierarchy by hand, since FMRTE does not export it, and keep it easy to update.
4. Let the owner record the groups set in the game, and show each member's change since the group started, at every import.
5. Say when a recorded group is doing harm or has stopped working.
6. Keep every player's personality readings from now on, so that speeds can be measured later.

## 3. Non-goals

- A predicted gain per month, or any ranking of groups by a rate. No rate is known.
- Fitting rates from the owner's own readings, or comparing mentored with unmentored players. The readings are kept (goal 6); using them is a later piece of work.
- Player traits passing between members. Traits are not imported.
- Career first-team appearances. The research names them as a factor for the mentee. The owner found that FMRTE's grid offers this season's club appearances, starts and substitute appearances (14 November 2026), which are not career totals and say little about a young player that his age does not. They are left out here; they matter for the selling work.
- Personality types ("Balanced", "Perfectionist" and so on). The game works them out from the attributes the app already imports, so they add nothing to the advice, and a label worked out by the app could disagree with the one the game shows.
- Captain and vice-captain. The research gives captaincy no influence of its own, and a captain's standing is already in the hierarchy the owner enters.
- Moving a player between squads so that he can be mentored.
- Turning down a suggestion. The owner records whatever groups he likes; a suggestion he ignores stays on the screen.
- A screen for ended groups. They are kept in the saved file.
- Other ways of changing personality (praise, discipline, staff, youth intake).

## 4. Anti-goals

These would make the result a failure even if it runs:

- **A number that looks measured and is not.** No expected gain, no "points per season", no score that reads like a forecast.
- **Advice resting on a stale hierarchy without saying so.** The screen always shows when the hierarchy was last updated, and says when it is old.
- **Upkeep so heavy the owner stops doing it.** Only the few players who stand above the rest need entering; everyone else is "others" until changed. Social groups are optional and change nothing when left blank.
- **Harm presented as help.** A group where a senior member is worse than a junior one in an attribute that counts is never suggested, and is warned about when the owner records it.
- **Carried-over rules presented as FM27 fact.** Nearly everything here comes from FM24 and earlier. The screen says so, as the other advisor screens do.

## 5. Constraints

- The project's rules in `CLAUDE.md` apply unchanged: the engine decides and the app shows; every sentence about advice comes from the engine; every tunable number is in `EngineParameters` with an evidence label and a source; every rule has a test where it changes an outcome and one where it does not; the same inputs give the same groups; no view holds a literal colour, typeface or measure.
- The engine's evidence labels have nothing for "FM24 and earlier". Those numbers take "carried over from FM26", and the source text names the version they come from.
- Data from FMRTE: age, Determination, and the eight personality attributes, per squad, at each import. All are already imported.
- Data FMRTE cannot give: squad hierarchy, social groups, the mentoring groups set in the game. Its own label file has no entry for any of them.
- What the owner sees in FM27 (14 November 2026): a mentoring group is exactly three players, all from one squad, and a player is in one group only. The hierarchy's levels are Team Leader, Highly Influential, Influential and Others. Social groups are Core, Secondary A, Secondary B and Others at present. The U21 and U18 squads have their own Dynamics screen, which lists nobody at present, but each player's own page shows his level and social group.
- FM27 was four days old when the research was done. The numbers must be easy to change.

## 6. Approaches considered

1. **Measure only.** The owner records his groups; the app shows what changed. Nothing here can be wrong, but it gives no advice, and advice is what was asked for.
2. **Suggest by the known rules, record, and measure.** Groups are built from hierarchy, age and a plain table of which attribute values are worth having. What changed is shown from the imports. **Chosen.** The owner agreed to this shape on 14 November 2026 ("go ahead with the mentoring design"), after it was described as: suggest groups per squad, record the groups set, show each mentee's change at every import, warn when someone is being dragged down.
3. **Predict and optimise.** Give every possible group an expected gain per month from the research's suggested formula and choose the best set. Every rate in that formula is a guess, so the result would break the first anti-goal. It becomes possible once the readings from approach 2 have built up.

## 7. What exists today

- `Attribute` has Determination and the personality attributes (Adaptability, Ambition, Controversy, Loyalty, Pressure, Professionalism, Sportsmanship, Temperament), and the importer reads them for every squad.
- Player Removal already reads Professionalism, Ambition, Determination and others, and throws an error naming the player and column when one is missing. It has its own idea of a "mentor" (aged 30 or over with Professionalism 16 or over), which protects such a player from being moved on. That rule is not changed here.
- Training is the pattern for this work: an engine advisor, choices the owner makes kept in a versioned file (`TrainingState`), a reading taken at every import (`FamiliarityObservation`), and progress worked out from the readings (`RetrainingTracker`).
- `Advisors.report` is the one entry point that runs every advisor; the app works the advice out when it is first read after a change. It needs a usable primary tactic, and one error in it blanks every advisor screen.
- The top row has nine pills, which was the most that fit on one row at the default window width.

## 8. The design

### 8.1 The facts it rests on

| Fact | Evidence | Research |
|---|---|---|
| A group is exactly three players, from one squad, and a player is in one group only | The owner's observation in FM27 | section 5 above |
| How well the players get along, which the game shows as social groups, affects influence | Official, FM24 manual | finding 2 |
| Influence runs from the player higher in the hierarchy to the one lower; the mentor's age and standing and the mentee's age decide its strength | Official FM24 manual and an SI-verified guide | findings 2, 4 |
| A mentee is pulled towards the most influential member, not the group's average | Inference from how the game shows influence | section 4 |
| Values can fall as well as rise, and a senior player with poor values drags others down | SI-verified guide | section 3 |
| Mentoring stops being useful after a time | Official, FM24 manual | finding 2 |
| Professionalism 20 against 10 roughly doubles growth in ability | FM24 and FM26 tests | finding 11 |
| Pressure 1 costs about 0.15 expected points a game in FM27; in FM24 most of the effect lay between 1 and 6 | FM27 measured; FM24 test | findings 9, 10 |
| Ambition and Determination help development, with little gained above about 10 | Older tests and guides | section 5 |
| Loyalty, Adaptability, Temperament, Sportsmanship: no effect on results found | FM27 measured | finding 9 |

### 8.2 What the engine is handed

- The players of one squad, as imported.
- **Standing**: each player's place in the squad hierarchy, entered by the owner. Four levels, highest first, as FM27 names them: Team Leader, Highly Influential, Influential, Others. A player with nothing entered is "others".
- **Social group**, optional, entered by the owner: Core, a Secondary group by its letter, or Others. A player with nothing entered has no known group.
- The groups the owner has recorded, and the personality readings kept for their members.
- The players Player Removal advises moving on, when that advice exists.

Mentoring is its own entry point in the engine and is not part of `Advisors.report`. That report needs a usable primary tactic, and one error in it blanks every advisor screen; mentoring needs no tactic and must not be able to blank the others. The app works mentoring out separately, in the same way (when first read after a change), and hands it Player Removal's list when the advice has been worked out and an empty list when it has not. With no tactic, then, the "not advised to leave" rule has nothing to apply to, and everything else on the tab still works. This is the design's call.

### 8.3 What a value is worth

Four attributes count. Each has a weight per point and a ceiling above which more is worth nothing:

| Attribute | Weight | Counts up to | Why |
|---|---|---|---|
| Professionalism | 3 | 20 | The one attribute with a large tested effect on development |
| Pressure | 2 | 6 | The one attribute with a measured effect on results, nearly all of it below 6 |
| Determination | 1 | 10 | Helps development a little; nothing shown above about 10 |
| Ambition | 1 | 10 | The same |

The worth of a value is its weight times the value, stopping at the ceiling. A mentee's **gain** from a lead in one attribute is the lead's worth less his own; his gain from the lead is the sum over the four. A negative figure in any one attribute is **harm**.

When the lead and the mentee are known to be in different social groups, or either is in "Others", the gain counts for half: the game's manual says influence depends on how well the two get along. When both are in the same group, or either has no group entered, it counts in full. The half is this design's choice, "derived", and like the weights it only orders the choices.

The weights only decide who gets first call on a scarce lead; they are this design's choice and are labelled "derived". The ceilings carry the evidence of the findings behind them. Gain is never shown as a number (first anti-goal): the screen shows the two values, "Professionalism 8, towards 17".

The other four personality attributes are read and kept but do not count.

### 8.4 Who stands above whom

Within a squad, one player **stands above** another when his standing is higher, or when their standing is the same and he is at least five years older. The age rule is what makes advice possible in a squad where nobody has a standing entered; it is this design's stand-in, labelled "derived", and the screen says when a squad's groups rest on age alone.

A group's **lead** is its member who stands above every other member. A group has one.

### 8.5 Who can be in a suggested group

A **candidate** is a player who:

- belongs to the club (not on loan here, not out on loan);
- is 23 or younger (the research gives no cut-off, only that younger players take more; 23 is this design's line, "derived");
- is not advised to leave by Player Removal;
- is not in a recorded group; and
- is below the ceiling in at least one attribute that counts, so has something to gain.

A candidate already at every ceiling needs no mentoring and appears nowhere. Every other candidate ends up as a **mentee** in a suggested group, as the lead or the third player of one, or on the not-placed list with the reason.

A **lead** is a player of the same squad, not out on loan and not in a recorded group, who stands above the mentee, from whom the mentee's gain is above nothing, and who does him no harm. He may be on loan at the club or advised to leave; the suggestion then says so, because the group ends when he goes.

Injury does not matter either way: no source says it does.

### 8.6 Building the groups

A suggested group is exactly three players, as the game requires: one lead and two mentees, or one lead, one mentee and a third player who makes up the group (rule 3). A player is in one group at most.

The rules a set of suggested groups must meet:

1. No harm: no member who stands above another is worth less than him in any attribute that counts. This covers lead to mentee and one mentee to another.
2. Most to gain first: of the groups that meet rule 1, the one with the greatest gain is formed first, then the best among the players left, and so on until none can be formed. This gives the pair with most to gain first call on a lead; it does not prove that no other set of groups has a greater total.
3. A lead with only one mentee is suggested only if a third member can be found. He must belong to the club, be in the same squad, not be advised to leave, not be in any other group, be one the lead stands above (so the group still has one clear lead once recorded), and meet rule 1 with both. He may be any age. Of several, the youngest is taken. He is named as "making up the group", and once the group is recorded he is a member like any other. If there is none, the mentee is not placed.
4. The same inputs give the same groups whatever order the players arrive in.

Candidates left without a group are listed as **not placed**, each with the first of these reasons that applies:

- nobody in the squad stands above him;
- nobody who stands above him is better where it counts;
- those who are better where it counts would do him harm in a named attribute;
- the leads who suit him are leading others with more to gain;
- no third player could be found to make up a group with him and his lead.

### 8.7 Recorded groups

The owner's own groups may differ from the suggestions, so the engine reads each one fresh:

- Its lead, by section 8.4. If no member stands above all the others, the group says so: nobody is clearly leading it.
- For each other member and each counted attribute, the two values, so the owner sees which way he is being pulled.
- A warning for every pair where a member who stands above another is worth less in a counted attribute: "Hart stands above Young and has Professionalism 6 against 12: Young may be dragged down."
- A caution for a member known to be in a different social group from the lead: the influence on him is likely to be weaker.
- A warning when a member has left the squad, gone out on loan or is advised to leave.

**What changed.** Each member has his own joining day: the day the group was recorded, or the day he was added to it. His starting values are those of his last reading on or before that day, which is what the app held when he joined; if he has none, his first reading after it. For each member, the lead included, and each counted attribute, the engine gives the starting value, the latest value and the weeks between. From those:

- *no reading yet*: fewer than two readings;
- *improved*, *no change* or *worse*, per attribute, judged by worth (section 8.3). A move that stays above the ceiling, such as Pressure 14 to 13, is shown with its two values but counts as no change;
- the group is **doing harm** when any member, the lead included, is worth less in a counted attribute than when he joined. The research says a mentor can be dragged down too;
- the group has **stopped working** when thirteen weeks have passed with no change in worth in any member other than the lead, counted from the latest of the group's start, the last such change and the last time a member was added, up to the latest reading (not today's date, so a gap between imports is not taken for no change). When nobody is clearly leading, every member counts. The screen then advises regrouping. Thirteen weeks is the research's suggestion of three months; "derived".

### 8.8 Evidence

Every suggestion, warning and progress line carries the weakest evidence behind it, as the other advisors do. In practice that is "carried over from FM26" or "derived" for all of them. The screen carries one standing note in the engine's words: how fast mentoring works in FM27 has not been measured, and these groups follow the rules of earlier versions.

### 8.9 Errors

A player of the squad with no Determination or no value for a counted attribute is an error naming the player and the column, as in Player Removal. It stops the mentoring advice for that squad only: the Mentoring tab shows the sentence, and the other advisor screens and the other squads are not affected. A recorded group whose member is no longer in any squad is not an error: it is the warning in section 8.7.

### 8.10 The command line

`lineup-cli advise` prints the suggested groups and the not-placed list for each squad it is given, after the other advisors and from the mentoring entry point, by age alone unless a file of standings is passed. This is how the advice is checked on the captured squad.

## 9. Persistence

A new versioned file beside the others, handled by `Store` as `TrainingState` is: unreadable gives a notice and a fresh start, with the file kept aside.

It holds:

- each player's standing and social group, and for each squad the day they were last changed;
- the recorded groups: squad, the day started, the day ended if it has been, and for each member the day he joined and, if he was taken out, the day he left;
- every player's personality readings: at each import of a squad, Determination and the eight personality attributes for each of its players, one reading a day, a later import on the same day replacing the earlier;
- the names of players in recorded groups, so a group still reads properly after a member has left.

Readings are taken for every player, not only group members (goal 6).

## 10. The screen

Mentoring is the second of two tabs on the Training screen: **Retraining**, which is the screen as it is now, and **Mentoring**. The game keeps mentoring under Training too, and a tenth pill would not fit on the top row. Elevens already has tabs to copy.

The tab has a squad menu and four parts:

```
Training      [ Retraining | Mentoring ]                         Squad: First team ▾

HIERARCHY                                              Updated 2 Nov      [ Update ]
Team leaders: Hart, Okafor.  Highly influential: Byrne.  Influential: Mills, Shaw.
Everyone else: others.  Social groups entered for 14 of 22.

SUGGESTED GROUPS
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Led by Hart (34, team leader)                                                    │
│   Young (18)   Professionalism 8, towards 17 · Pressure 4, towards 12            │
│   Reid (19)    Professionalism 11, towards 17 · Determination 7, towards 15      │
│                In a different social group from Hart: likely a weaker influence  │
│   Carried over from FM26                                       [ Record as set ] │
└──────────────────────────────────────────────────────────────────────────────────┘

YOUR GROUPS                                                        [ Add a group ]
┌──────────────────────────────────────────────────────────────────────────────────┐
│ Okafor, Lane, Pike · since 12 Oct                                                │
│   Lane (20)    Professionalism 9 → 10 in 5 weeks · Pressure 5, no change         │
│   Pike (17)    No change yet                                                     │
│   ⚠ Okafor stands above Pike and has Ambition 6 against 9: Pike may be dragged   │
│     down.                                              [ Edit ]    [ End group ] │
└──────────────────────────────────────────────────────────────────────────────────┘

NOT PLACED
Dunn (17): nobody who stands above him in this squad is better where it counts.
```

- **Hierarchy.** One line for each level that has anyone in it, and how many players have a social group entered. *Update* opens the squad's players with two choices beside each: the level, and the social group, which may be left blank. When the entries are more than four weeks old the line says so and points to the game's Dynamics screen; for the U21 and U18 squads it points to each player's own page, since their Dynamics screen may list nobody. When no level has been entered for the squad, the part says the groups below go by age alone.
- **Suggested groups.** One card each. *Record as set* makes it a recorded group starting on the app's current date; the owner presses it after setting the group in the game.
- **Your groups.** One card each, with what changed and any warnings. *Add a group* and *Edit* choose members from the squad's players who are in no other group; a group is exactly three, and cannot be saved with more or fewer. *Edit* therefore swaps members: one put in is measured from that day, one taken out stops being shown, and the others keep their starting values. *End group* keeps it in the file with the day it ended and takes it off the screen. A group that has stopped working or is doing harm says so at the top of its card.
- **Not placed.** One line each.

The look is the Tactics board direction, as on the other advisor screens. Pressing *Record as set* moves the next card's button under the pointer, so the half-second guard the Training screen already has covers these buttons too.

Pictures: `training-mentoring-*`, light and dark, for at least: no squad imported, no hierarchy entered, suggestions, a recorded group with changes, a recorded group with a warning, a group that has stopped working, a squad whose advice failed on a missing value, and the hierarchy editor.

## 11. Testing

- Engine: each rule in sections 8.3 to 8.7 has a test where it changes the outcome and a test where it does not. The same players in a different order give the same groups. The words are tested where they are built.
- Core: recording, editing and ending groups; readings taken at import and replaced on the same day; the stale-hierarchy line; the rows each card shows.
- The captured first-team and U21 squads are run through the command line, by age alone and with a standings file, and the groups are read for sense before the screen is built.
- The pictures are looked at before the work is called done, and the app is built with `tools/build_app.sh`.

## 12. Sequence

1. Engine: worth, standing, and who stands above whom.
2. Engine: suggested groups and the not-placed list.
3. Engine: reading a recorded group, its warnings, and what changed.
4. Engine: the words, and mentoring added to `lineup-cli advise` from its own entry point.
5. Check the advice on the captured squads.
6. Core: the saved file, readings at import, the actions, the rows.
7. UI: the tab, its four parts and the hierarchy editor; pictures.
8. Build the app; record what changed and what is left.

## 13. Left to the builder

- How the groups are found, so long as the rules in section 8.6 hold. The engine's exact assignment solver suits giving mentees to leads; rule 1 between mentees and rule 3 need handling around it.
- The types' names and shapes, and how readings are kept small.
- Whether the mentoring file must be readable for the app to start, as with the other files.
- The exact wording of each sentence, in the plain style of the existing advisor words.
- How the hierarchy editor and the member chooser are laid out.

## 14. Open items for the owner

1. **The numbers that are this design's own:** the weights (3, 2, 1, 1), a mentee being 23 or younger, five years standing in for hierarchy, a different social group halving the gain, and thirteen weeks before a group is called stopped. Each is one line to change.
2. **Whether FMRTE's grid offers a career total of appearances.** Its label file names "All Time Career Appearances"; the owner found only this season's club figures. If the career figure can be a column, it can be added to the mentee rules later.
