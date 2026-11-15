import Foundation
import LineupEngine

extension AppModel {
    /// Why a draft cannot be saved, in plain words, as labels the owner reads. The first three serve the arrows sheet
    /// too: the three whose arrows are read are a group in the game.
    enum MentoringProblemLabel {
        static let notThree = "A group is exactly three players."
        static let notInSquad = "Every member must be a current player of this squad."
        static let onLoan = "A player out on loan cannot be in a group."
        static let inAnotherGroup = "A player already in another group cannot be added."
    }

    /// Replaces the entries of the squad's current players among those given, each recorded as entered for this squad
    /// (whatever squad an entry he had was entered for), keeping none that is `.others` with no social group, and dates
    /// the squad's hierarchy with the game's current date even when nothing changed: saving is the owner saying he has
    /// checked. A player not handed back keeps his entry: the editor leaves out the players out on loan. Other squads'
    /// players are left alone.
    public func setDynamics(_ entries: [PlayerID: PlayerDynamics], for squad: Squad) {
        let current = Set((self.squad.book.current[squad] ?? []).map(\.id))
        let today = settings.currentDate
        changeMentoring { state in
            for (id, entry) in entries where current.contains(id) {
                state.hierarchy[id] = entry.standing == .others && entry.socialGroup == nil
                    ? nil : HierarchyEntry(squad: squad, dynamics: entry)
            }
            state.dynamicsUpdatedOn[squad] = today
        }
    }

    /// Records a suggested group as set up in the game from today, its three members joining today, and says so in a
    /// notice naming them in the suggestion's order. Nothing happens if one of them is in a live group already, or
    /// within `trainingActionInterval` of the last training action: the card moves under the pointer, as a training
    /// card does.
    public func recordGroup(_ suggestion: SuggestedGroup, in squad: Squad) {
        trainingAction {
            let named = suggestion.members.map { ($0.player, $0.name) }
            guard Set(named.map(\.0)).count == Mentoring.groupSize,
                  !named.contains(where: { isInLiveGroup($0.0, except: nil) }) else { return }
            tellTraining(AdvisorText.recorded(names: named.map(\.1)))
            let today = settings.currentDate
            changeMentoring { state in
                state.groups.append(MentoringGroup(
                    id: UUID(), squad: squad, startedOn: today,
                    members: named.map { MentoringMember(player: $0.0, joinedOn: today) }))
                for (id, name) in named { state.names[id] = name }
            }
        }
    }

    /// The sentence saying why the draft cannot be saved; nil when it can.
    public func mentoringProblem(of draft: MentoringGroupDraft) -> String? {
        if let problem = trioProblem(draft.members, in: draft.squad) { return problem }
        if draft.members.contains(where: { isInLiveGroup($0, except: draft.id) }) { return MentoringProblemLabel.inAnotherGroup }
        return nil
    }

    /// Adds the group, or changes it: a member put in joins today, a member taken out leaves today and stays in the
    /// record, the others are untouched. Nothing happens while the draft has a problem, or for a group that is gone or
    /// has ended.
    public func saveGroup(_ draft: MentoringGroupDraft) {
        guard mentoringProblem(of: draft) == nil else { return }
        let today = settings.currentDate
        let held = Dictionary((squad.book.current[draft.squad] ?? []).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        if draft.isNew {
            changeMentoring { state in
                state.groups.append(MentoringGroup(
                    id: draft.id, squad: draft.squad, startedOn: today,
                    members: draft.members.map { MentoringMember(player: $0, joinedOn: today) }))
                for id in draft.members { state.names[id] = held[id] }
            }
        } else {
            changeMentoring { state in
                guard let index = state.groups.firstIndex(where: { $0.id == draft.id && $0.isLive }) else { return }
                let wanted = Set(draft.members)
                let present = Set(state.groups[index].current.map(\.player))
                for member in state.groups[index].members.indices
                where state.groups[index].members[member].leftOn == nil && !wanted.contains(state.groups[index].members[member].player) {
                    state.groups[index].members[member].leftOn = today
                }
                for id in draft.members where !present.contains(id) {
                    state.groups[index].members.append(MentoringMember(player: id, joinedOn: today))
                    state.names[id] = held[id]
                }
            }
        }
    }

    // MARK: Arrows

    /// A new draft of the arrows of `members` in the squad, filled from the readings kept for their pairs there: for
    /// opening the arrows sheet.
    public func arrowsDraft(for squad: Squad, members: [PlayerID]) -> ArrowsDraft {
        var draft = ArrowsDraft(id: UUID(), squad: squad, members: members, strengths: [:])
        draft.strengths = keptStrengths(of: draft.pairs, in: squad)
        return draft
    }

    /// The same draft (same id) with the player put in or taken out. Taking him out drops his pairs' strengths;
    /// putting him in fills the new pairs from the readings kept. A fourth player is not put in. Strengths set in the
    /// sheet for pairs that stay are kept as set.
    public func arrowsDraft(_ draft: ArrowsDraft, toggling player: PlayerID) -> ArrowsDraft {
        var changed = draft
        if let index = changed.members.firstIndex(of: player) {
            changed.members.remove(at: index)
            changed.strengths = changed.strengths.filter { $0.key.from != player && $0.key.to != player }
        } else {
            guard changed.members.count < Mentoring.groupSize else { return draft }
            changed.members.append(player)
            let new = changed.pairs.filter { $0.from == player || $0.to == player }
            changed.strengths.merge(keptStrengths(of: new, in: draft.squad)) { set, _ in set }
        }
        return changed
    }

    /// The sentence saying why the arrows cannot be saved; nil when they can: exactly three different players, every
    /// one a current player of the draft's squad and not out on loan. A player in a recorded group can be in it.
    public func arrowsProblem(of draft: ArrowsDraft) -> String? {
        trioProblem(draft.members, in: draft.squad)
    }

    /// Keeps the six arrows of the draft's three: a strength set becomes the pair's reading, dated the game's current
    /// date unless the strength kept is the same; a pair with none set loses its reading. The three's names are kept,
    /// as a group's members' are. Nothing happens while the draft has a problem. Saves without replanning; not under
    /// the half-second guard, since the sheet closes on Save.
    public func saveArrows(_ draft: ArrowsDraft) {
        guard arrowsProblem(of: draft) == nil else { return }
        let today = settings.currentDate
        let held = Dictionary((squad.book.current[draft.squad] ?? []).map { ($0.id, $0.name) },
                              uniquingKeysWith: { first, _ in first })
        changeMentoring { state in
            for pair in draft.pairs {
                state.setArrow(from: pair.from, to: pair.to, in: draft.squad, strength: draft.strengths[pair],
                               on: today)
            }
            for id in draft.members { state.names[id] = held[id] }
        }
    }

    /// The arrows sheet to open after a new group is saved: its three members, in the draft's order; nil for a change
    /// to a group, and for a new group that was not saved.
    public func arrowsDraft(afterSaving draft: MentoringGroupDraft) -> ArrowsDraft? {
        guard draft.isNew, mentoring.groups.contains(where: { $0.id == draft.id }) else { return nil }
        return arrowsDraft(for: draft.squad, members: draft.members)
    }

    /// Why the players cannot be a trio of the squad, a group's or one whose arrows are recorded: not exactly three
    /// different players, one not a current player of the squad, or one out on loan. Nil when they can.
    private func trioProblem(_ members: [PlayerID], in squad: Squad) -> String? {
        guard members.count == Mentoring.groupSize, Set(members).count == Mentoring.groupSize else {
            return MentoringProblemLabel.notThree
        }
        let held = Dictionary((self.squad.book.current[squad] ?? []).map { ($0.id, $0) },
                              uniquingKeysWith: { first, _ in first })
        guard members.allSatisfy({ held[$0] != nil }) else { return MentoringProblemLabel.notInSquad }
        for id in members {
            if case .loanedOut = self.squad.book.loanStatus(of: held[id]!, override: settings.clubOverride) {
                return MentoringProblemLabel.onLoan
            }
        }
        return nil
    }

    /// The readings kept in the squad for those of `pairs` that have one.
    private func keptStrengths(of pairs: [ArrowsDraft.Pair], in squad: Squad) -> [ArrowsDraft.Pair: ArrowStrength] {
        var strengths: [ArrowsDraft.Pair: ArrowStrength] = [:]
        for reading in mentoring.arrows where reading.squad == squad {
            let pair = ArrowsDraft.Pair(from: reading.from, to: reading.to)
            if pairs.contains(pair) { strengths[pair] = reading.strength }
        }
        return strengths
    }

    /// Ends the group as of the game's current date and keeps it. Nothing happens within `trainingActionInterval` of the
    /// last training action, or for a group that is gone or has already ended.
    public func endGroup(_ id: UUID) {
        trainingAction {
            let today = settings.currentDate
            changeMentoring { state in
                guard let index = state.groups.firstIndex(where: { $0.id == id && $0.isLive }) else { return }
                state.groups[index].endedOn = today
            }
        }
    }

    /// Takes a reading of each player of the imported squad, dated the import's day. Saves without replanning.
    func recordPersonality(after squad: Squad, on day: Day) {
        let imported = self.squad.book.current[squad] ?? []
        changeMentoring { $0.record(imported, on: day) }
    }

    // MARK: The advice

    /// The mentoring advice for the squad: every imported player, the club, the saved hierarchy, groups, readings,
    /// arrows and names, the game's current date, and as leaving Player Removal's list while the other advice is ready
    /// (none while it is not, so no tactic is needed). Worked out when first read after a change to the squads, the
    /// hierarchy, the groups or the arrows, or to the game's date, and kept until the next.
    public func mentoringAdvice(for squad: Squad) -> MentoringAdvice {
        _ = mentoringGeneration
        _ = adviceGeneration
        let asOf = settings.currentDate
        if let cached = mentoringCache[squad], cached.asOf == asOf { return cached.advice }
        let advice = workedOutMentoring(for: squad, asOf: asOf)
        mentoringCache[squad] = (asOf, advice)
        return advice
    }

    /// The Mentoring tab for the squad: its hierarchy, its suggested and recorded groups and the players not placed.
    public func mentoringSheet(for squad: Squad) -> MentoringSheet {
        let advice = mentoringAdvice(for: squad)
        return MentoringPresentation.sheet(
            squad, advice: advice, players: self.squad.book.current[squad] ?? [], ownClub: ownClub, state: mentoring,
            names: importedNames, asOf: settings.currentDate, parameters: planParameters)
    }

    /// The squads imported: those with at least one current player.
    public var importedSquads: Set<Squad> {
        Set(Squad.allCases.filter { !(squad.book.current[$0] ?? []).isEmpty })
    }

    /// The hierarchy editor's rows for the squad.
    public func dynamicsRows(for squad: Squad) -> [DynamicsRow] {
        MentoringPresentation.dynamicsRows(self.squad.book.current[squad] ?? [], ownClub: ownClub,
                                           dynamics: mentoring.dynamics(for: squad))
    }

    /// The players the group editor offers for the draft.
    public func memberChoices(for draft: MentoringGroupDraft) -> [MemberChoice] {
        MentoringPresentation.memberChoices(draft, players: squad.book.current[draft.squad] ?? [], ownClub: ownClub,
                                            state: mentoring)
    }

    /// The players the arrows sheet offers for the draft.
    public func arrowChoices(for draft: ArrowsDraft) -> [MemberChoice] {
        MentoringPresentation.arrowChoices(draft, players: squad.book.current[draft.squad] ?? [], ownClub: ownClub,
                                           state: mentoring)
    }

    /// The arrows sheet's six rows for the draft once three are chosen, each named from the imported players or the
    /// saved names.
    public func arrowRows(for draft: ArrowsDraft) -> [ArrowRow] {
        MentoringPresentation.arrowRows(draft,
                                        names: mentoring.names.merging(importedNames) { _, imported in imported })
    }

    /// What the engine is handed for the squad's mentoring advice, the arrows read in the game among it: the engine
    /// uses only the squad's own, and guesses every other.
    func mentoringRequest(for squad: Squad, asOf: Day) -> MentoringRequest {
        let leaving = AdvicePresentation.report(adviceState)?.removal.advisedToLeave ?? []
        return MentoringRequest(
            squad: squad, players: self.squad.book.allPlayers, ownClub: ownClub,
            dynamics: mentoring.dynamics(for: squad), dynamicsUpdatedOn: mentoring.dynamicsUpdatedOn[squad],
            groups: mentoring.groups, readings: mentoring.readings, arrows: mentoring.arrows, names: mentoring.names,
            leaving: leaving, asOf: asOf)
    }

    private func workedOutMentoring(for squad: Squad, asOf: Day) -> MentoringAdvice {
        timesMentoringWorkedOut += 1
        guard !(self.squad.book.current[squad] ?? []).isEmpty else { return .needsSquad }
        do {
            return .ready(try Mentoring.report(mentoringRequest(for: squad, asOf: asOf), parameters: planParameters))
        } catch {
            return .failed([ErrorDescriptions.describe(error)])
        }
    }

    /// Every imported player's name, the first held under a key.
    private var importedNames: [PlayerID: String] {
        Dictionary(squad.book.allPlayers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private func isInLiveGroup(_ player: PlayerID, except id: UUID?) -> Bool {
        mentoring.groups.contains { $0.isLive && $0.id != id && $0.current.contains { $0.player == player } }
    }
}
