import Foundation
import LineupEngine

/// The Mentoring tab for one squad: the hierarchy as entered, the suggested groups, the owner's own groups and the young
/// players the advice could not place, every sentence about the advice in the engine's words.
public struct MentoringSheet: Equatable, Sendable {
    public let squad: Squad
    /// "The U21s have not been imported yet." while the squad has not been; everything below is then empty.
    public let notReady: String?
    /// The engine's sentences for why the advice for this squad stopped; the suggestions and the players not placed
    /// are then empty, and the owner's groups are named from the saved state with nothing about how they are going.
    public let failures: [String]
    /// "Team Leader: Hart, Okafor." for each level with anyone in it, highest first, then "Everyone else: others.";
    /// empty while no level is entered, when `byAgeAloneText` says so.
    public let hierarchyLines: [String]
    /// "Social groups entered for 14 of 22."
    public let socialGroupsLine: String?
    /// "Updated Mon 2 Nov"; nil when the hierarchy has never been saved for this squad.
    public let updatedText: String?
    /// The engine's sentence when the hierarchy is old.
    public let staleText: String?
    /// The engine's sentence when no level is entered for this squad.
    public let byAgeAloneText: String?
    /// The engine's standing note on mentoring advice.
    public let noteText: String
    public let suggested: [SuggestedGroupCard]
    public let yours: [RecordedGroupCard]
    /// The engine's sentence for each young player not placed.
    public let notPlaced: [String]
}

/// One member of a group as its card lists him.
public struct MemberLine: Identifiable, Equatable, Sendable {
    public let id: PlayerID
    /// "Young (18)"; the name alone for a player no longer imported.
    public let nameText: String
    /// In a suggested group his pulls, in a recorded one his changes, in the engine's words joined with " · "; nil
    /// when there are none.
    public let detailText: String?
    /// The engine's words: making up the group, a different social group from the lead, no reading yet.
    public let notes: [String]

    var spokenParts: [String] { [nameText] + [detailText].compactMap { $0 } + notes }
}

/// A suggested group as its card shows it.
public struct SuggestedGroupCard: Identifiable, Equatable, Sendable {
    public var id: PlayerID { suggestion.lead }
    /// What *Record as set* records.
    public let suggestion: SuggestedGroup
    /// The engine's words: "Led by Hart (34, Team Leader)".
    public let leadText: String
    public let members: [MemberLine]
    /// The engine's sentences on why the group may not last.
    public let cautions: [String]
    /// The evidence note in brackets: "(FM26-era numbers)"; nil for FM27 evidence.
    public let noteText: String?
    private let spokenNote: String?

    /// The card as said to assistive technology.
    public var spokenText: String {
        ([leadText] + members.flatMap(\.spokenParts) + cautions.map { "Caution: \($0)" } + [spokenNote].compactMap { $0 })
            .joined(separator: ", ")
    }

    init(_ suggestion: SuggestedGroup) {
        self.suggestion = suggestion
        leadText = AdvisorText.lead(suggestion)
        members = suggestion.members.map { member in
            var notes: [String] = []
            if member.isMakingUp { notes.append(AdvisorText.makingUpTheGroup) }
            if member.inDifferentSocialGroup { notes.append(AdvisorText.otherSocialGroup(leadName: suggestion.leadName)) }
            return MemberLine(id: member.player, nameText: MentoringPresentation.nameText(member.name, age: member.age),
                              detailText: MentoringPresentation.joined(member.pulls.map(AdvisorText.pull)), notes: notes)
        }
        cautions = suggestion.cautions.map { AdvisorText.caution($0, leadName: suggestion.leadName) }
        spokenNote = AdvisorText.note(for: suggestion.basis)
        noteText = spokenNote.map { "(\($0))" }
    }
}

/// One of the owner's groups as its card shows it. When the advice for the squad stopped, the card has only its title,
/// its since-text and what Edit opens with.
public struct RecordedGroupCard: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// The members' names: "Okafor, Lane, Pike".
    public let titleText: String
    /// "since Mon 12 Oct".
    public let sinceText: String
    /// The engine's sentence when the group is doing harm or has stopped working; nil otherwise.
    public let stateText: String?
    public let members: [MemberLine]
    /// The engine's sentences.
    public let warnings: [String]
    /// The evidence note in brackets: "(this tool's estimate)"; nil for FM27 evidence, and when the advice stopped.
    public let noteText: String?
    /// What Edit opens with.
    public let draft: MentoringGroupDraft
    private let spokenNote: String?

    /// The card as said to assistive technology.
    public var spokenText: String {
        ([titleText, sinceText] + [stateText].compactMap { $0 } + members.flatMap(\.spokenParts)
            + warnings.map { "Warning: \($0)" } + [spokenNote].compactMap { $0 })
            .joined(separator: ", ")
    }

    /// A group as the engine read it.
    init(_ review: GroupReview, parameters: EngineParameters) {
        id = review.id
        titleText = review.members.map(\.name).joined(separator: ", ")
        sinceText = MentoringPresentation.sinceText(review.group.startedOn)
        stateText = AdvisorText.state(of: review, parameters: parameters)
        members = review.members.map { member in
            let changes = member.changes.compactMap(AdvisorText.change)
            let noReading = member.changes.allSatisfy { $0.change == .noReading }
            return MemberLine(id: member.player,
                              nameText: member.age.map { MentoringPresentation.nameText(member.name, age: $0) } ?? member.name,
                              detailText: MentoringPresentation.joined(changes),
                              notes: noReading ? [AdvisorText.noReadingYet] : [])
        }
        let names = Dictionary(review.members.map { ($0.player, $0.name) }, uniquingKeysWith: { first, _ in first })
        warnings = review.warnings.map { AdvisorText.warning($0, names: names) }
        draft = MentoringGroupDraft(editing: review.group)
        spokenNote = AdvisorText.note(for: review.basis)
        noteText = spokenNote.map { "(\($0))" }
    }

    /// A group as saved, named from `names`, for a squad whose advice stopped.
    init(saved group: MentoringGroup, names: (PlayerID) -> String) {
        id = group.id
        titleText = group.current.map { names($0.player) }.joined(separator: ", ")
        sinceText = MentoringPresentation.sinceText(group.startedOn)
        stateText = nil
        members = []
        warnings = []
        draft = MentoringGroupDraft(editing: group)
        spokenNote = nil
        noteText = nil
    }
}

/// One player in the hierarchy editor, with his entry to change.
public struct DynamicsRow: Identifiable, Equatable, Sendable {
    public let id: PlayerID
    public let name: String
    /// "Age 18".
    public let ageText: String
    /// His saved entry, or `.others` with no social group.
    public var dynamics: PlayerDynamics
}

/// One player the group editor offers.
public struct MemberChoice: Identifiable, Equatable, Sendable {
    public let id: PlayerID
    public let name: String
    /// His age and level: "18 · Others".
    public let detailText: String
    public let isChosen: Bool
    /// "In another group" when he cannot be chosen; nil when he can.
    public let unavailableText: String?
}

public enum MentoringPresentation {
    public static let headings: (hierarchy: String, suggested: String, yours: String, notPlaced: String) =
        (hierarchy: "Hierarchy", suggested: "Suggested groups", yours: "Your groups", notPlaced: "Not placed")
    public static let updateTitle = "Update"
    public static let recordTitle = "Record as set"
    public static let addTitle = "Add a group"
    public static let editTitle = "Edit"
    public static let endTitle = "End group"
    public static let saveTitle = "Save"
    public static let cancelTitle = "Cancel"
    static let everyoneElse = "Everyone else: others."
    static let inAnotherGroup = "In another group"
    static let notEntered = "Not entered"
    /// The letters of the secondary social groups the game shows.
    static let secondaryGroups = ["A", "B", "C", "D"]

    /// The levels, highest first, in the engine's names.
    public static let standingChoices: [(Standing, String)] = Standing.allCases.reversed().map { ($0, AdvisorText.name($0)) }

    /// Not entered, then each social group in the engine's names: Core, Secondary A to D, Others.
    public static let socialGroupChoices: [(SocialGroup?, String)] =
        [(nil, notEntered)]
        + ([SocialGroup.core] + secondaryGroups.map(SocialGroup.secondary) + [.others]).map { ($0, AdvisorText.name($0)) }

    /// The engine's sentence when the squad has no group to suggest; nil when it has one, when it has not been
    /// imported, and when its advice stopped.
    public static func noSuggestionsText(_ sheet: MentoringSheet) -> String? {
        guard sheet.notReady == nil, sheet.failures.isEmpty, sheet.suggested.isEmpty else { return nil }
        return AdvisorText.noGroupToSuggest
    }

    public static func squadTitle(_ squad: Squad) -> String {
        squad.displayName
    }

    /// The squad to show: the one asked for when it is imported, else the first imported in book order, else the first
    /// team.
    public static func squadShown(_ asked: Squad, imported: Set<Squad>) -> Squad {
        if imported.contains(asked) { return asked }
        return Squad.allCases.first { imported.contains($0) } ?? .firstTeam
    }

    // MARK: Building

    /// The tab for the squad. `players` are its current players in squad order; `names` every imported player's name,
    /// for naming the owner's groups when the advice stopped (the saved names then, and never a key).
    static func sheet(_ squad: Squad, advice: MentoringAdvice, players: [Player], ownClub: String?, state: MentoringState,
                      names: [PlayerID: String], asOf: Day, parameters: EngineParameters) -> MentoringSheet {
        let report: MentoringReport?
        let failures: [String]
        switch advice {
        case .needsSquad:
            return MentoringSheet(squad: squad, notReady: notImported(squad), failures: [], hierarchyLines: [],
                                  socialGroupsLine: nil, updatedText: nil, staleText: nil, byAgeAloneText: nil,
                                  noteText: AdvisorText.mentoringNote, suggested: [], yours: [], notPlaced: [])
        case .failed(let sentences):
            report = nil
            failures = sentences
        case .ready(let ready):
            report = ready
            failures = []
        }

        let present = notOutOnLoan(players, ownClub: ownClub)
        let levels = levelLines(present, dynamics: state.dynamics)
        let byAgeAlone = report?.byAgeAlone ?? levels.isEmpty
        let entered = present.filter { state.dynamics[$0.id]?.socialGroup != nil }.count
        let updatedOn = state.dynamicsUpdatedOn[squad]

        let yours: [RecordedGroupCard]
        if let report {
            yours = report.groups.map { RecordedGroupCard($0, parameters: parameters) }
        } else {
            yours = state.groups.filter { $0.isLive && $0.squad == squad }.sorted(by: MentoringState.order).map {
                RecordedGroupCard(saved: $0) { names[$0] ?? state.names[$0] ?? TrainingPresentation.unnamed }
            }
        }

        return MentoringSheet(
            squad: squad, notReady: nil, failures: failures,
            hierarchyLines: byAgeAlone ? [] : levels,
            socialGroupsLine: "Social groups entered for \(entered) of \(present.count).",
            updatedText: updatedOn.map { "Updated \(DayText.short($0))" },
            staleText: report.flatMap { report in
                updatedOn.flatMap { AdvisorText.staleHierarchy(report, updatedOn: $0, asOf: asOf) }
            },
            byAgeAloneText: byAgeAlone ? AdvisorText.mentoringByAgeAlone : nil,
            noteText: AdvisorText.mentoringNote,
            suggested: report?.suggestions.map(SuggestedGroupCard.init) ?? [],
            yours: yours,
            notPlaced: report?.notPlaced.map(AdvisorText.notPlaced) ?? [])
    }

    /// The squad's players not out on loan, in squad order, each with his saved entry or the default.
    static func dynamicsRows(_ players: [Player], ownClub: String?, dynamics: [PlayerID: PlayerDynamics]) -> [DynamicsRow] {
        notOutOnLoan(players, ownClub: ownClub).map {
            DynamicsRow(id: $0.id, name: $0.name, ageText: "Age \($0.age)", dynamics: dynamics[$0.id] ?? PlayerDynamics())
        }
    }

    /// The squad's players not out on loan, in squad order: those in the draft chosen, and one in another live group
    /// unavailable.
    static func memberChoices(_ draft: MentoringGroupDraft, players: [Player], ownClub: String?,
                              state: MentoringState) -> [MemberChoice] {
        let elsewhere = Set(state.groups.filter { $0.isLive && $0.id != draft.id }.flatMap(\.current).map(\.player))
        let chosen = Set(draft.members)
        return notOutOnLoan(players, ownClub: ownClub).map { player in
            let standing = state.dynamics[player.id]?.standing ?? .others
            return MemberChoice(id: player.id, name: player.name, detailText: "\(player.age) · \(AdvisorText.name(standing))",
                                isChosen: chosen.contains(player.id),
                                unavailableText: elsewhere.contains(player.id) ? inAnotherGroup : nil)
        }
    }

    // MARK: Words

    /// "Young (18)".
    static func nameText(_ name: String, age: Int) -> String {
        "\(name) (\(age))"
    }

    /// "since Mon 12 Oct".
    static func sinceText(_ day: Day) -> String {
        "since \(DayText.short(day))"
    }

    /// The parts joined with " · "; nil when there are none.
    static func joined(_ parts: [String]) -> String? {
        parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func notImported(_ squad: Squad) -> String {
        switch squad {
        case .firstTeam: "The first team has not been imported yet."
        case .u21: "The U21s have not been imported yet."
        case .u18: "The U18s have not been imported yet."
        }
    }

    /// One line for each level above others that has anyone in it, highest first, names in squad order, then one for
    /// everyone else when anyone is left; empty when nobody has a level.
    private static func levelLines(_ players: [Player], dynamics: [PlayerID: PlayerDynamics]) -> [String] {
        let standing = { (player: Player) in dynamics[player.id]?.standing ?? .others }
        let levels = Standing.allCases.reversed().filter { $0 != .others }.compactMap { level -> String? in
            let names = players.filter { standing($0) == level }.map(\.name)
            return names.isEmpty ? nil : "\(AdvisorText.name(level)): \(names.joined(separator: ", "))."
        }
        guard !levels.isEmpty else { return [] }
        return levels + (players.contains { standing($0) == .others } ? [everyoneElse] : [])
    }

    private static func notOutOnLoan(_ players: [Player], ownClub: String?) -> [Player] {
        players.filter {
            if case .loanedOut = LoanStatus.of($0, ownClub: ownClub) { false } else { true }
        }
    }
}
