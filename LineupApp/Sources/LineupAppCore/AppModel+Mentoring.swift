import Foundation
import LineupEngine

extension AppModel {
    /// Why a draft cannot be saved, in plain words, as labels the owner reads.
    enum MentoringProblemLabel {
        static let notThree = "A group is exactly three players."
        static let notInSquad = "Every member must be a current player of this squad."
        static let onLoan = "A player out on loan cannot be in a group."
        static let inAnotherGroup = "A player already in another group cannot be added."
    }

    /// Replaces the entries of the squad's current players with those given, keeping none that is `.others` with no
    /// social group, and dates the squad's hierarchy with the game's current date even when nothing changed: saving is
    /// the owner saying he has checked. Other squads' entries are left alone.
    public func setDynamics(_ entries: [PlayerID: PlayerDynamics], for squad: Squad) {
        let current = Set((self.squad.book.current[squad] ?? []).map(\.id))
        let today = settings.currentDate
        changeMentoring { state in
            for id in current { state.dynamics[id] = nil }
            for (id, entry) in entries where current.contains(id) && !(entry.standing == .others && entry.socialGroup == nil) {
                state.dynamics[id] = entry
            }
            state.dynamicsUpdatedOn[squad] = today
        }
    }

    /// Records a suggested group as set up in the game from today, its three members joining today, and says so in a
    /// notice. Nothing happens if one of them is in a live group already, or within `trainingActionInterval` of the last
    /// training action: the card moves under the pointer, as a training card does.
    public func recordGroup(_ suggestion: SuggestedGroup, in squad: Squad) {
        trainingAction {
            let named = [(suggestion.lead, suggestion.leadName)] + suggestion.members.map { ($0.player, $0.name) }
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
        guard draft.members.count == Mentoring.groupSize, Set(draft.members).count == Mentoring.groupSize else {
            return MentoringProblemLabel.notThree
        }
        let held = Dictionary((squad.book.current[draft.squad] ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard draft.members.allSatisfy({ held[$0] != nil }) else { return MentoringProblemLabel.notInSquad }
        for id in draft.members {
            if case .loanedOut = squad.book.loanStatus(of: held[id]!, override: settings.clubOverride) {
                return MentoringProblemLabel.onLoan
            }
        }
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

    /// The mentoring advice for the squad: every imported player, the club, the saved hierarchy, groups, readings and
    /// names, the game's current date, and as leaving Player Removal's list while the other advice is ready (none while
    /// it is not, so no tactic is needed). Worked out when first read after a change to the squads, the hierarchy or
    /// the groups, or to the game's date, and kept until the next.
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
                                           dynamics: mentoring.dynamics)
    }

    /// The players the group editor offers for the draft.
    public func memberChoices(for draft: MentoringGroupDraft) -> [MemberChoice] {
        MentoringPresentation.memberChoices(draft, players: squad.book.current[draft.squad] ?? [], ownClub: ownClub,
                                            state: mentoring)
    }

    private func workedOutMentoring(for squad: Squad, asOf: Day) -> MentoringAdvice {
        timesMentoringWorkedOut += 1
        guard !(self.squad.book.current[squad] ?? []).isEmpty else { return .needsSquad }
        let leaving = AdvicePresentation.report(adviceState)?.removal.advisedToLeave ?? []
        let request = MentoringRequest(
            squad: squad, players: self.squad.book.allPlayers, ownClub: ownClub, dynamics: mentoring.dynamics,
            dynamicsUpdatedOn: mentoring.dynamicsUpdatedOn[squad], groups: mentoring.groups,
            readings: mentoring.readings, names: mentoring.names, leaving: leaving, asOf: asOf)
        do {
            return .ready(try Mentoring.report(request, parameters: planParameters))
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
