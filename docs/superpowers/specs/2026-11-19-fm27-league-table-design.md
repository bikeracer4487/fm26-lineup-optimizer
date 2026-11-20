# FM27 Lineup Optimizer: the league table

Date: 19 November 2026
Status: approved by the owner on 19 November 2026 ("Approved"), with the twelve calls listed under "Calls made in this design". Revised the same day in one place, marked "revised" below, which the owner accepted.

## Intent

The suggested importance of a league match rests on where the club stands in the league. Today the owner says so himself, by picking one of four situations from a menu on the Fixtures screen, and he has to guess which fits (his question of 18 November 2026: which situation for which places in a league of 24 with one promoted, six in the play-offs and four relegated). The earlier design left the table out because FMRTE was thought to export none. It does: the owner pasted his league's standings from FMRTE on 19 November 2026, and FMRTE's settings file has a column layout for that grid.

So the owner pastes the league table and says once how the league works. The app then says what place he is in and how many matches are left, works out what his league matches are worth, and raises a league match further when it is against a side he is battling for a place.

## Goals

1. The owner can paste his league's standings from FMRTE, and the app reads every team's matches played, wins, draws, losses, goals for, goals against and points.
2. The owner says once how many teams are promoted automatically, how many are in the play-offs and how many are relegated. The app works out how many play-off teams get a bye.
3. A League screen shows the table with those lines drawn on it, the owner's place, points and matches left, and, for each line, in a sentence, where he stands against it.
4. The league situation is worked out from the table, so the owner does not have to choose it. He can still choose it by hand, and his choice wins.
5. A league match against a side within 6 points of him (3 with one match left) is suggested as more important in his last ten matches, and the suggestion says why.
6. A league fixture's opponent is picked from the teams of the table, so fixtures and table teams match.
7. Saved state from before this design opens with no notice and gives the same suggestions as before, until a table is pasted.

## Non-goals

- Results, or keeping the table up to date by itself. The app never sees a result. The owner pastes the table again after each round; the screen shows the day the table was pasted and says when it is known to be out of date.
- Predicting the finish, or a chance of any finish. No team's remaining fixtures are known and nothing measures a team's strength over a run of matches.
- The other teams' fixtures, or home and away.
- Leagues that do not play everyone twice (the owner's word, 19 November 2026: every league does), split seasons, groups, or two-legged ties.
- Places that matter for other reasons: continental places in a top division, a relegation play-off, prize money by place. Only the lines the three numbers give are counted. In a top division the owner can enter 1 as "promoted automatically" to stand for the champion.
- Play-off matches themselves. They are not league matches; the owner enters them as he likes and sets their importance by hand.
- Setting a fixture's chosen importance for the owner. The suggestion changes; "Use it" is pressed as now.
- More than one league, or a league kept for each squad. One table, for the first team's league.
- Using the table in the planner, the game plan advice, "Their strength" or any advisor other than the suggested importance.

## Anti-goals

- A judgement shown as a fact. "Cannot be caught" is arithmetic; "in a fight" is the tool's own line. Each sentence says which it is.
- A paste that changes a fixture's chosen importance, the plan, the squad book or any file but the league's own.
- A table that silently stops counting when it is old. An old table is still used, and says it is old.
- A team name matched loosely. Names are compared as the squad book compares them (case and spacing do not matter) and nothing looser.

## Approaches considered

### Turning the table into what a league match is worth

1. **Lines and gaps. Chosen** by the owner on 19 November 2026 ("Go with your recommendation"). The three numbers give lines on the table; for each line the app measures the gap in points between the owner and the nearest side across it, and reads the situation from how close the lines are and how many matches are left. Every reading can be said in a sentence with its numbers.
2. **Arithmetic only.** Something is at stake until it is settled for certain. Exact, but nearly the whole season would read as a fight, which helps no more than the menu does. Dropped. The arithmetic is kept inside the chosen way, for "settled".
3. **Chances.** Play the rest of the season out many times and give odds for each finish. It needs every team's remaining fixtures, which the paste does not carry, and a measure of each side's strength; the odds would have nothing behind them. Dropped.

### Raising a match against a side the owner is battling

1. **A factor on the match's score, with its own reason line. Chosen** with the first approach above. It sits beside the factor for the opponent's strength, shows in the list of reasons, and does little when the base is already low.
2. **Such a match takes the top base (100) whatever the situation.** Dropped: a match between two sides with nothing left to play for would read as a title decider.

## The design

### The league's format

The owner enters three whole numbers, once, on the League screen:

- **Promoted automatically**: the places from 1st that go up without a play-off.
- **In the play-offs**: the places after those that enter the play-offs.
- **Relegated**: the places from the bottom that go down.

Each is 0 or more, and together they are at most the number of teams in the pasted table when one is held. A number that breaks this is refused in the engine's sentence and the format kept as it was. Until all three have been entered there is no format, and nothing is worked out from the table (no silent default); the screen says what is missing.

**Byes (the owner's rule, 19 November 2026).** The number of play-off teams that get a bye in the first round is the next power of two at or above the play-off count, minus the count: 6 gives 2, 5 gives 3, 7 gives 1, 3 gives 1, and 0, 1, 2, 4 and 8 give none. The byes go to the highest of the play-off places. It is shown, not entered: "2nd and 3rd get a bye."

**The lines.** A line lies between two places. With T teams, P promoted, O in the play-offs, B byes and R relegated:

| Line | Lies after place | Exists when |
|---|---|---|
| Promotion | P | P is over 0 |
| Bye | P + B | B is over 0 |
| Play-off | P + O | O is over 0 |
| Relegation | T − R | R is over 0 |

For the owner's league (24, 1, 6, 4): after 1st, 3rd, 7th and 20th.

**Matches in a season.** Each team plays 2 × (T − 1) matches; a team's matches left are that less its matches played.

### Reading the paste

- **Where the columns come from.** FMRTE copies rows with no header, as for squads. FMRTE's settings file holds the layout of its standings grid under `ColumnsSettings`, as it does for player grids (key `CompetitionStandings`; `CompetitionGroupStandings` has the same columns). The reader takes every grid in the file whose columns include both `TeamName` and `Points`, and uses the one whose number of columns is the paste's number of fields; none fitting, or two that fit with different columns, is an error in a sentence. The paths, as FMRTE writes them: `Position`, `TeamName`, `GamesPlayed`, `Wins`, `Draws`, `Loses`, `GoalsScored`, `GoalsAllowed`, `Points`.
- **What is required.** `TeamName`, `GamesPlayed`, `Wins`, `Draws`, `Loses`, `GoalsScored`, `GoalsAllowed` and `Points`. A missing column, or a blank or non-numeric cell, is an error naming the team and the column. `Position` is used when the grid has it.
- **The splitter.** `ClipboardText.rows` refuses a first line of fewer than 20 fields, since it was written for player grids. The standings reader needs the same splitting (line endings, quotes, ragged rows) without that floor.
- **The order of the table.** With a `Position` column, the places are the game's own: they must be 1 to T, each once, or the paste is refused. This takes the game's word on ties, whose rules differ by league. Without the column, the order is points, then goal difference, then goals for, then name, and the screen says the order was worked out.
- **Checks.** At least two teams. No team twice (names compared as above). A team whose wins, draws and losses do not add up to its matches played, or that has played more than a season holds, refuses the paste, naming the team. A team whose points are not three for a win and one for a draw is kept, with the pasted points used, and raises a warning in a sentence ("Marine have 35 points where their results give 38; the table's points are used"), since the game deducts points.
- **The owner's club.** It must be one of the teams, by the app's own club name (the settings' override, else the squad book's). If it is not, or no club is known yet, the paste is refused in a sentence that names the club looked for.
- **What is kept.** The teams as read, in order, the warnings, and the day (the game's current date, as the app has it). A later paste replaces it whole. A refused paste leaves what was held. "Remove table" on the League screen drops the table and keeps the format.

### Where the owner stands

One engine function is handed the table, the format, the owner's club name and the parameters, and returns the reading. Every number below is in `EngineParameters` with a label and a source.

Take the owner's points as *p*, his matches left as *m*, and "the most a team can reach" as its points plus 3 for each match it has left.

**The margin.** 6 points; 3 when *m* is 1 (the owner's rule, 19 November 2026). With *m* at 0 the season in the table is over and nothing below applies: the reading gives his place and points, says the season is over and to paste the new season's table when it starts, and has no situation and no sides he is battling. Such a table changes no suggestion.

**Each line, when the owner is above it** (his place is at or before the place the line lies after, call it *k*):

- *Safe*: fewer than *k* other teams can still reach *p* or more. This assumes he loses every match left and counts a team that can only draw level as able to pass him.
- Otherwise the gap is *p* less the points of the side in place *k* + 1, the first below the line.

**Each line, when the owner is below it:**

- *Out of reach*: at least *k* other teams already have more points than the most he can reach.
- Otherwise the gap is the points of the side in place *k*, the last above the line, less *p*.

Both tests ignore that the other sides play each other, so a line can be called open that is in fact settled, never the other way round. The sentences say "can still", not "will".

**A line that is not settled is one of three:**

| State | When |
|---|---|
| Close | the gap is within the margin |
| Within reach | the gap is over the margin and at most one point for each match he has left (*m*) |
| Far | anything more |

**The situation**, the first of these that holds:

| What the lines show | Situation |
|---|---|
| Every line is settled (safe or out of reach), or there are no lines | Nothing to play for |
| The promotion, play-off or relegation line is close, and *m* is 10 or fewer | Title race or relegation fight |
| Any line is close or within reach | In contention |
| Otherwise (something is open, all of it far) | Mid-table |

The bye line counts for "In contention" at most: a bye is worth having, and less than a place. The ten matches are carried over from the old app's table, which gave its top value only in the last ten league matches. The one point for each match left is this tool's estimate, with no test behind it.

**The sides he is battling (revised).** Every other team whose points are within the margin of his, above or below, once he has 10 matches or fewer left; before that, nobody. With the margin at 3 and one match left, a side 3 points away still counts. Nothing else is asked of them: not which line lies between, and not matches in hand (the owner's rule, kept as he gave it). The approved text counted them at any time. Writing the tests showed that at the start of a season every team is within 6 points of every other, so every league match would have taken the ×1.2 and been suggested High for the first weeks. The ten matches are the line that already gates "Title race or relegation fight". The owner accepted the revision on 19 November 2026 ("that's a good catch, we'll keep your recommendation").

**On the owner's table** (pasted 19 November 2026; kept as a test fixture): Oxford City are 5th on 74 points with 3 matches left. Promotion is out of reach (Chester have 87; the most Oxford City can reach is 83). The bye line is close (Spalding, 3rd, are 3 ahead). The play-off line is close (Morecambe, 8th, are 6 behind). Relegation: safe. The situation is "Title race or relegation fight". The sides he is battling are Spalding, Hednesford, Buxton, Macclesfield and Morecambe.

**The words.** All of them are the engine's (`AdvisorText`), with these as models; the builder writes one for each case of each line:

- "You are 5th on 74 points with 3 matches left."
- "Automatic promotion is out of reach: Chester have 87 points and the most you can reach is 83."
- "A bye in the play-offs is 3 points away: Spalding, in 3rd, have 77."
- "Your play-off place is not safe: Morecambe, in 8th, are 6 points behind you."
- "You cannot be relegated."
- "League matches read as Title race or relegation fight: your play-off place is within 6 points with 3 matches left (this tool's estimate)."
- "Within 6 points of you: Spalding, Hednesford, Buxton, Macclesfield and Morecambe."

The reading carries the weakest evidence among the parameters it read, shown as the evidence note is shown elsewhere.

### The suggested importance

- **Which fixtures the table speaks for.** A table with *m* matches left speaks for the owner's next *m* league matches and no more, so that an old table, or league fixtures saved for the next season, are not read by it. Those are, in date order, the first *m* league fixtures dated after the day the table was pasted, together with any on that day with no lineup confirmed; a confirmed one among them counts as one of the *m*. A league fixture beyond them is suggested as with no table. When saved league fixtures go beyond them, the League screen says so: "The table has 3 matches left, so it is used for your next 3 league fixtures; the 2 after them are read without it."
- **The situation used.** The owner's choice by hand when he has made one; else, for a fixture the table speaks for, the table's, when a table and a format are held; else in contention, as now.
- **The reason line.** When the situation is the table's, the first reason names what the table found, not only the situation: "League match, your play-off place is within 6 points: 100". When it is the owner's by hand, the line is today's.
- **A side he is battling.** For a league fixture whose opponent is one of those sides, the score is multiplied by 1.2 (this tool's estimate; the same size as a much stronger opponent), after the opponent's strength, with a reason: "Buxton are level on points with you (×1.2)", "Spalding are 3 points ahead of you (×1.2)", "Morecambe are 6 points behind you (×1.2)". It applies whichever way the situation was set, to a fixture the table speaks for. The "bigger match follows" rule measures the next fixture the same way, with this factor in.
- **Nothing else changes.** Cups and friendlies, the schedule rules, the Sharpness rule and the levels' lines are as they are. The fixture the engine is handed does not change shape; the suggestion is handed the reading beside the situation.

### The League screen

A new screen, "League", after Fixtures in the top row. From the top:

- The heading row, with "Paste table".
- The format: the three numbers, each with its label, and the bye line under them.
- "Table pasted on Sat 18 Apr.", with "Remove table" beside it. When a league fixture with a confirmed lineup is dated after that day, a caution: "A league match has been played since; paste the table again." The table is still used.
- Any warning from the paste, and the refusal of the last paste if it was refused.
- When the League situation is set by hand and differs from the table's: a line saying both, with "Use the table".
- The reading: the sentences above, in the order place, promotion, bye, play-off, relegation, situation, sides within the margin; then the evidence note.
- League fixtures still to play whose opponent is not in the table, named by opponent and date, with nothing to press (the fixture is edited on Fixtures).
- The table: place, team, played, won, drawn, lost, for, against, goal difference, points. A rule is drawn across at each line with its name ("promoted", "bye", "play-offs", "relegated"). The owner's row is marked, and the sides within the margin carry a small mark.

      League                                              [ Paste table ]
      Promoted automatically [1]   In the play-offs [6]   Relegated [4]
      2nd and 3rd get a bye.
      Table pasted on Sat 18 Apr.

      You are 5th on 74 points with 3 matches left.
      Automatic promotion is out of reach: Chester have 87 points and the most you can reach is 83.
      A bye in the play-offs is 3 points away: Spalding, in 3rd, have 77.
      Your play-off place is not safe: Morecambe, in 8th, are 6 points behind you.
      You cannot be relegated.
      League matches read as Title race or relegation fight: ...
      Within 6 points of you: Spalding, Hednesford, Buxton, Macclesfield and Morecambe.

        1  Chester          42  25  12   5   65  33  +32   87
        ─────────────────────────────────────────── promoted
        2  South Shields    42  27   5  10   76  38  +38   86
        3  Spalding         42  22  11   9   64  34  +30   77   ·
        ─────────────────────────────────────────── bye
        4  Hednesford       41  24   3  14   74  42  +32   75   ·
        5  Oxford City      43  22   8  13   57  37  +20   74   you
        ...

With no table: an empty state that says to copy the league's standings in FMRTE and press "Paste table". With a table and no format: the table is shown without lines, and a line says to enter the three numbers.

"Paste table" reads the clipboard and FMRTE's settings file as the squad and opponent pastes do. It saves the league file, works the suggestions out again, and does not plan.

### The League situation menu

The menu on Fixtures stays. When a table and a format are held it gains a first entry, "From the table", which shows the table's reading beside it. Picking one of the four sets it by hand, and that wins; picking "From the table" gives it back to the table.

Whenever the app goes from having no reading to having one (a table and a format are both held where one of them was missing before: the first paste with the format entered, or the format entered after the first paste, or a paste after "Remove table"), the menu is set to "From the table", dropping an earlier choice by hand, since that choice was a guess made without a table. Until that moment a choice by hand stands, so pasting a table before entering the format changes no suggestion. Later pastes, and later changes to the format, leave the menu as the owner has it. "Remove table" leaves the choice by hand as it is (none, if the menu was on "From the table", which then reads as in contention).

### The fixture editor

When the draft's competition is League and a table is held, the opponent is a menu of the table's teams other than the owner's, in alphabetical order, in place of the text box. A saved opponent that matches a team shows as that team, in the table's spelling. One that matches none is kept as the menu's current entry with a caution under it ("Buxton FC is not in the league table"), until the owner picks a team. With any other competition, or no table, the text box is shown as now with the name kept.

### Storage

A new file, the league's: the format (absent until entered), the table as read with its day and warnings (absent until pasted). Versioned JSON through `Store` like the others; its absence is no notice; an unreadable one gives a notice and a fresh start, with the file kept aside. The settings' `leagueSituation` keeps its meaning (the owner's choice by hand; absent is none).

### The command line

`advise` takes `--league-table <paste.tsv>` (read through `--grids`, which must then carry the standings layout) and `--league-format <promoted>,<play-offs>,<relegated>`; both or neither. With them it prints a League part with the reading's sentences, and the suggestions use the reading. `--league-situation`, when given, is the choice by hand and wins.

### The test fixture

The owner's paste of 19 November 2026 is kept under `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/` with the standings grid's column layout beside it, as squads are. It was pasted into the conversation, not captured with the tool, so the fixture is rebuilt from the appendix below, as the capture `scouting-search` was rebuilt: the 24 rows as given, every field in double quotes, fields separated by one tab, and the layout written from the nine paths in the appendix. The first paste of a table in the real app is left to the owner, and shows whether FMRTE's clipboard matches the rebuilt fixture. `tools/capture_fmrte_paste.sh` and the captures' README are brought up to date so a standings paste can be captured the same way. This widens one rule in CLAUDE.md: what is taken from `~/Library/Application Support` is FMRTE's column layouts for the player grids and the standings grid, and nothing else.

## Rules that apply as everywhere

- Every number above is a `Parameter` with a label and a source: the margin and its last-match value (derived; the owner's rule of 19 November 2026), the points for each match left and the factor for a side he is battling (derived; this tool's estimate, no test), the last ten matches (carried over from FM26), three points for a win.
- Every rule gets a test where it changes an outcome and one where it does not; the owner's table is one of the cases.
- Every word about the reading comes from the engine. Core holds labels and headings; the view holds layout.
- Errors, refusals and warnings are sentences in `ErrorDescriptions`, with no `default` in a `switch`.
- The screen's pictures are drawn and looked at: the table with lines, no table, a table with no format, a refused paste, a table out of date, the menu with "From the table", and the editor's opponent menu with a name not in the table.

## Calls made in this design, for the owner to check

The owner chose the approach, the margin, the byes rule and the three numbers. These are this design's:

1. The game's own `Position` column sets the places when the paste has it.
2. A team whose points do not fit its results is kept with a warning, since the game deducts points.
3. The League situation menu switches to "From the table" at the moment a reading first exists (a table and the three numbers), not at a paste made before the numbers are entered.
4. An old table is still used, with a caution.
5. The bye line can lift the situation to "In contention" and no higher.
6. The reason line on a suggestion names what the table found.
7. A paste is refused when the owner's club is not in it.
8. In a top division, 1 "promoted automatically" stands for the champion; continental places are not covered.
9. The owner's table and FMRTE's standings layout are kept as a test fixture in this public repository.
10. A side within the margin gets the ×1.2 whatever lies between the two clubs, including two mid-table sides with no line near, and (revised) only in the owner's last ten matches.
11. A table speaks only for as many of the owner's coming league fixtures as it has matches left, and a table whose season is over changes no suggestion.
12. "Remove table" exists, and keeps the three numbers.

## Left to the builder

- The types' names and where the reader lives beside the importer.
- Whether the numbers sit in one parameter entry or several, within the size limit on `EngineParameters`.
- The controls for the three numbers, and fitting an eleventh screen into the top row.
- The exact sentences, to the models above.
- How the mark on a side within the margin is drawn, to `Theme`.

## Appendix: the owner's paste of 19 November 2026

FMRTE's layout for the grid, read from the owner's settings file that day (key `CompetitionStandings`; `CompetitionGroupStandings` holds the same nine): `Position`, `TeamName`, `GamesPlayed`, `Wins`, `Draws`, `Loses`, `GoalsScored`, `GoalsAllowed`, `Points`, in that order. The paste had nine fields a row in the same order, each in double quotes, the place written as a bare number. Shown here with the quotes left off and the fields spaced out; the owner's club is Oxford City.

    1   Chester               42  25  12   5  65  33  87
    2   South Shields         42  27   5  10  76  38  86
    3   Spalding              42  22  11   9  64  34  77
    4   Hednesford            41  24   3  14  74  42  75
    5   Oxford City           43  22   8  13  57  37  74
    6   Buxton                42  21  11  10  62  48  74
    7   Macclesfield          43  22   7  14  66  51  73
    8   Morecambe             42  18  14  10  45  35  68
    9   Southport             42  19   8  15  51  44  65
    10  Chorley               41  16  14  11  50  47  62
    11  Scarborough Athletic  42  15  13  14  64  60  58
    12  Merthyr               42  15  11  16  57  60  56
    13  Hebburn               42  14  13  15  52  49  55
    14  Spennymoor            42  14  12  16  42  41  54
    15  King's Lynn           43  14  11  18  38  40  53
    16  Brackley              43  14  11  18  49  58  53
    17  Worksop               41  14   7  20  44  56  49
    18  Hereford              42  11  12  19  31  44  45
    19  Bedford               43  12   9  22  58  82  45
    20  Darlington            42  10  13  19  47  61  43
    21  Harborough            42   9  12  21  36  56  39
    22  Radcliffe             42   9  10  23  47  79  37
    23  Marine                42   8  11  23  34  71  35
    24  AFC Telford           42   5  12  25  27  70  27

Every row's wins, draws and losses add up to its matches played, and every row's points are three for a win and one for a draw, so the fixture raises no warning.
