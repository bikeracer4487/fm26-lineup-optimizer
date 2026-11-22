# FM27 Lineup Optimizer: the best five at each position, and hidden candidates

Date: 22 November 2026
Status: built on 22 November 2026 (plan: `docs/superpowers/plans/2026-11-22-fm27-scouting-best-five-and-hidden.md`), after the owner approved this text the same day ("Approved, proceed"), with the calls this design made listed to him beforehand. A reviewer read it as a builder the same day and had no question for him; the small points it raised were settled in the text as this design's calls. He chose how long a hidden player stays hidden (until he brings him back) and how the cut is made (the first of three, below). Everything marked "this design's call" is the builder's, and is his to change.

This design changes the Candidates tab of the Scouting screen. Where it differs from `2026-11-18-fm27-scouting-design.md`, this one wins: that design's "read and forget" still holds for the pasted players, and no longer holds for the short list of players the owner has hidden.

## Intent

The owner pastes 100 players or more at a time, and the Candidates tab shows nearly all of them open. In his words: "this results in SO many recommended players that the screen ends up looking cluttered." He wants two things.

- **Fewer players shown.** "If there are 20 players that would be better in a specific position, only display the top 5 best options."
- **A way to put a player aside.** "If I try to sign them and they end up declining or needing too much money or I can't afford the transfer cost."

He added a third while reading the design: "Next to the players positions, it should always display their CA and PA."

On his captured search of 109 players, against the captured squad and the sample 4-2-3-1, 76 rows are open at once in 12 groups. The largest are depth groups: 17 at central attacking midfield, 15 goalkeepers, 10 at left centre-back. Only "The rest" (33 players) starts closed.

## Goals

1. Each group on the Candidates tab shows at most its best five players, by the order the owner has chosen ("Order by": Today or Later).
2. The players a group leaves out are one click away, behind a line saying how many there are.
3. The owner can hide any candidate with one click. A hidden player is in no group, and the next best takes his place among the five.
4. A hidden player stays hidden across new pastes and across restarts, until the owner shows him again.
5. The tab says how many of the pasted players are hidden, and lists them with a way to show each again.
6. Every pasted player's line of details shows his current and potential ability beside his positions.

## Non-goals

- A reason or a note on a hidden player (declined, too dear).
- A saved shortlist, or anything else about a pasted player kept. Only what is needed to know a hidden player again is saved.
- A setting for the five.
- Any change to how a candidate is judged, which need he is listed under, or the order within a group.
- The Needs tab, the other screens, the plan and the other advice.
- The command line. `scout` prints every candidate, takes no hidden players, and changes only in that two of its parts are split by position (below).
- A list of every player ever hidden. Only those among the players pasted are listed.

## Anti-goals

- A player left out of view with nothing on screen saying so.
- A hidden player the owner cannot bring back.
- A player moving to another heading because someone else was hidden or the order was changed.
- A click meant for one player hiding the next, because the rows moved up under the pointer.

## Approaches

What happens to the players a best five leaves out:

1. **Cut each group where it stands (chosen).** Every player stays under the need he is listed under today. The group shows its best five, and a line under them opens the others. Against: a player left out at left centre-back does not move to right centre-back, even when that group has room; the owner sees him by opening the line.
2. **Players left out move on** to the next position they answer, so thin groups fill up. Against: the heading a player sits under then depends on who else was pasted, so players shift between headings when one is hidden or the order is changed.
3. **List a player under every position he answers.** Dropped: the same player several times is more clutter.

The owner chose 1 on 22 November 2026.

How long a hidden player stays hidden:

1. **Until the next paste or the app quits.** Nothing saved, as the first scouting design had it. Against: the same players are hidden again at every search.
2. **Until the owner shows him again (chosen).** Saved, across pastes and restarts.

The owner chose 2 on 22 November 2026.

## The rules

### The best five

- Every group but "The rest" shows the first five of its players, in the engine's order for the chosen "Order by", and no more. The five is one number in Core (this design's call: it is a rule about what a screen lists, as the earlier-matches window is, not a rating or selection rule).
- A group of five or fewer is shown whole, with no line.
- A group of more than five has a line under its five saying how many more there are, in the words the rest part's line uses: "12 more players", "1 more player". A click opens them under the five, in the same order; another closes them.
- Which lines are open is held in memory only: all closed at launch, and closed again by a new paste and by "Clear" (this design's call).
- Changing "Order by" changes which five are shown, since the order decides who is best.
- "The rest" is unchanged: closed behind its line, and whole when opened.

### Groups by position in the two mixed parts

"Would start where you have no need" and "Could pass a first choice where you have no need" are one group each today, with players of every position together. So that the five are the best at a position there too, each becomes one group for each slot that has a player, in the tactic's slot order, under a heading that is the position alone: "Right back". The order within each group is as it is today (this design's call; the owner was told and did not object).

This is the engine's change (`CandidatesReport.groups(orderedBy:)`), and `scout` on the command line prints those two parts by position as well.

### Hiding a player

- Every candidate's row, in every part and in the opened lines, has a "Hide" button.
- Hiding asks no question. The player leaves every group at once, for every tactic, and the next player in the group's order moves up.
- A hidden player is known again by his name (compared as the engine compares names, `PlayerID.normalise`) and his potential ability, both as pasted. Age is not used, since it changes at his birthday; the search grid has no id column. The match is the engine's (beside `Scouting.isHeld`), and so is the leaving out: `Scouting.candidates` is handed the hidden players and returns those it left out apart from the candidates, as it returns the players already the owner's.
- A pasted player who is already the owner's is left out as such, hidden or not, and is not counted as hidden.
- A hidden player is not judged, is in no group, and does not count towards the evidence note.
- A paste in which every player not the owner's is hidden is still read: the tab shows the lines and the hidden players, and no groups.

### Showing a player again

- Under the groups and above the evidence note, when any pasted player is hidden, a line says how many: "3 hidden players", "1 hidden player". It starts closed at every launch. A click opens the list.
- Each hidden player in the list has his name, the details line his row would have (age, positions, current and potential ability, club, on loan, asking price, wage), and a "Show again" button. None of his judgement is shown.
- "Show again" removes him from the saved list. He is judged with the others when the tab is next read, and appears where he belongs.
- "Hide" and "Show again" are both ignored within half a second of the last of either, as the Training screen's buttons are, since each moves the next row under the pointer.

### Ability on the details line

- The line under a candidate's name gains his current and potential ability straight after his positions, in the owner's words for them: "Age 30 · D/DM C · CA 78 · PA 82 · Darlington, out of contract · Asking $0 · $0 a week".
- It is on every row whether open or closed, in every part, the rest included, and on each player in the hidden list.
- Both are FMRTE's own numbers as pasted, shown as whole numbers with nothing worked out from them. "CA" and "PA" are plain labels and are Core's (this design's call: elsewhere the app writes "Ability 55, potential 140" in a sentence; here they are two figures on a line of figures, and the owner asked for them by these names).
- The command line is unchanged.

### What is saved

- A new file through `Store`, versioned JSON like the others (`StoreFile.scouting`, `scouting.json`), holding the hidden players: for each, his name as pasted and his potential ability. Nothing else about any pasted player is saved, and the pasted players are still held in memory only.
- The file's absence is no notice, and saved state from before this design opens with no notice and nobody hidden. A file that cannot be read gives the usual notice and a fresh start, and is kept aside.
- Hiding and showing again save the file and leave the candidates to be judged again when next read. Neither plans, works the other advice out again, or touches the squad book, the marks or any other file.
- "Clear" and a new paste leave the hidden players as they are.
- A hidden player who is in no paste stays saved and is shown nowhere.

## What the owner sees

    [Paste players] [Clear]                             Order by [ Today | Later ]
    109 players read.

    ANSWERS A NEED TODAY
    LEFT CENTRE-BACK · NEEDS MORE DEPTH
    Brad Walker                                                         [Hide]
    Age 30 · D/DM C · CA 78 · PA 82 · Darlington, out of contract · Asking $0 · $0 a week
      Today   Would count as cover: rates 4.1% under …
    … four more rows …
    ▸ 5 more players

    WOULD START WHERE YOU HAVE NO NEED
    RIGHT BACK
    …

    THE REST
    ▸ 33 more players

    HIDDEN
    ▸ 3 hidden players
        Abdi Sharif                                               [Show again]
        Age 26 · DM/M C · CA 84 · PA 90 · Connah's Quay Nomads · Asking $0 · $2,972 a week

    (evidence note)

(The shape only; the names are from the captured search, and the numbers, the abilities among them, are not what the build will print.)

On the captured search, against the captured first team and U21s by the command line's output, the 76 open rows become 47, with five groups carrying a line. The build's own count, on the first team alone (the squad the app's tests use), is 65 open rows before and 48 now, in 13 groups of which three carry a line; no test is pinned to either. No group can pass five however many players are pasted.

One thing was added while building: the hidden list stands under a heading of its own, "Hidden", since in the first picture its line sat under "The rest" and read as part of it.

## Where it lives

- **Engine.** The match for a hidden player and the leaving out in `Scouting.candidates`, which returns the hidden players as pasted (the whole player, not his name alone as for those already the owner's, since the list shows his details); the hidden players' type (Codable, as `FitnessReading` is, so Core can save it); the two parts grouped by slot in `groups(orderedBy:)`, for which the report keeps the tactic's slot order; the heading that is a position alone in `AdvisorText`. Each rule with a test where it changes an outcome and one where it does not.
- **Core.** The saved state and its file; `hideCandidate` and `showCandidateAgain` with their half-second guard (one clock for the two, apart from Training's, read after the candidates are judged again as Training's is); the sheet's cut (the rows shown, the rows behind the line, the line) and the hidden list; which lines are open, beside the open rows in `Navigation`, kept by group so a change of order or tactic leaves a group's line as it was. "Show again" removes every saved entry that matches the player. "Hide", "Show again", "hidden players" and "more players" are plain labels and are Core's.
- **Views.** The button on a row, the line under a group, the hidden list. Layout only; every measure from `Theme`.

## Limits this design accepts

- Two players with the same name and the same potential ability are hidden together.
- A hidden player whose potential ability changes in the game, or whose name FMRTE writes differently, shows again.
- A hidden player can be shown again only while he is among the players pasted.
- A player left out of a best five is not offered at another position he could answer, short of opening the line or his row.
- A hidden player the owner later signs stays in the file, to no effect.

## Tests and pictures

- Engine: a hidden player is left out and returned apart; a namesake with another potential ability is not; a held player who is also hidden is left out as held; the two parts come out one group for each slot in the tactic's order, with their order within unchanged.
- Core: a group of six shows five and "1 more player", a group of five shows five and no line; the order chosen decides the five; hiding moves the sixth up, saves the file, does not plan and survives a new model on the same directory; show again undoes it; a second click inside half a second does nothing; a paste where every player is hidden shows the hidden list; the details line carries the two abilities after the positions, on a row and in the hidden list; state saved before this design opens with no notice.
- Pictures, light and dark, looked at before the work is called done: a group over five with its line closed and open, a row's "Hide" button (in a part and in the rest), and the hidden list closed and open. The sample's paste has six players, so these need a longer one: the captured search has 109, and is read with its own layout file (`scouting-search.grids.json`), not the squads'.
- The project notes (`CLAUDE.md`) are brought into line, and the first scouting design gets a line pointing here.

## Left to the builder

- The names of the types, functions and picture variants.
- Where "Hide" sits on the row and how the hidden list is drawn, within `Theme` and the Tactics board direction. The row's name is already a button that opens it; "Hide" must not be inside that button.
- What VoiceOver says for "Hide", "Show again" and the two lines.
- How the open lines are closed at a paste and at "Clear".
- The words `StoreFile` uses for the new file in its notices.
