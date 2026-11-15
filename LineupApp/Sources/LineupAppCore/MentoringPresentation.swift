import Foundation
import LineupEngine

/// The Mentoring tab for one squad: the hierarchy as entered, the suggested groups, the owner's own groups and the
/// players of the club's own, of any age, with something to gain whom the advice could not place, every sentence about
/// the advice in the engine's words.
public struct MentoringSheet: Equatable, Sendable {
    public let squad: Squad
    /// "The U21s have not been imported yet." while the squad has not been; everything below is then empty.
    public let notReady: String?
    /// The engine's sentences for why the advice for this squad stopped; the suggestions and the players not placed
    /// are then empty, and the owner's groups are named from the saved state with nothing about how they are going.
    public let failures: [String]
    /// "Team Leader: Hart, Okafor." for each level with anyone in it, highest first, then "Everyone else: others.";
    /// empty while no level is entered, when `needsHierarchyText` says so.
    public let hierarchyLines: [String]
    /// "Social groups entered for 14 of 22."
    public let socialGroupsLine: String?
    /// "Updated Mon 2 Nov"; nil when the hierarchy has never been saved for this squad.
    public let updatedText: String?
    /// The engine's sentence when the hierarchy is old.
    public let staleText: String?
    /// The engine's sentence when no level above Others is entered for the squad's players not out on loan: the advice
    /// then has nothing to go on.
    public let needsHierarchyText: String?
    /// The engine's standing note on mentoring advice.
    public let noteText: String
    public let suggested: [SuggestedGroupCard]
    public let yours: [RecordedGroupCard]
    /// The engine's sentence for each player not placed.
    public let notPlaced: [String]
}

/// One arrow of a group as its card lists it: who to whom, its strength and whether it was read, and what it gives.
public struct ArrowLine: Identifiable, Equatable, Sendable {
    /// The two players' keys; never shown.
    public let id: String
    /// The engine's "McEachran → Clark".
    public let titleText: String
    /// The strength in the game's word, then "read" and its day, or the engine's "expected, not read":
    /// "Significant · read Sat 14 Nov", "Light · expected, not read".
    public let strengthText: String
    /// The engine's pulls joined with " · ", or its "nothing to gain".
    public let detailText: String
    /// The tool's guess, not read in the game.
    public let isGuess: Bool
    /// "McEachran to Clark": the title as said, since a screen reader reads the arrow sign as "right arrow".
    private let spokenTitle: String

    var spokenParts: [String] { [spokenTitle, strengthText, detailText] }

    init(_ arrow: GroupArrow) {
        id = "\(arrow.arrow.from.key)→\(arrow.arrow.to.key)"
        titleText = AdvisorText.arrowTitle(arrow)
        spokenTitle = "\(arrow.fromName) to \(arrow.toName)"
        let read = arrow.arrow.readOn.map(MentoringPresentation.readOn) ?? AdvisorText.expectedNotRead
        strengthText = "\(AdvisorText.name(arrow.arrow.strength)) · \(read)"
        detailText = MentoringPresentation.joined(arrow.pulls.map(AdvisorText.pull)) ?? AdvisorText.nothingToGain
        isGuess = !arrow.arrow.isRead
    }
}

/// One member of a recorded group as its card lists him.
public struct MemberLine: Identifiable, Equatable, Sendable {
    public let id: PlayerID
    /// "Young (18)"; the name alone for a player no longer imported.
    public let nameText: String
    /// His changes in the engine's words joined with " · "; nil when there are none.
    public let detailText: String?
    /// The engine's words: no reading yet.
    public let notes: [String]

    var spokenParts: [String] { [nameText] + [detailText].compactMap { $0 } + notes }
}

/// A suggested group as its card shows it.
public struct SuggestedGroupCard: Identifiable, Equatable, Sendable {
    public var id: String { suggestion.id }
    /// What *Record as set* records.
    public let suggestion: SuggestedGroup
    /// The three names in the suggestion's order: "Hart, Young, Reid".
    public let titleText: String
    /// Each arrow above None, in the suggestion's order.
    public let arrows: [ArrowLine]
    /// The engine's sentence to set the group in the game and record its arrows, when it rests on a guess.
    public let promptText: String?
    /// The engine's sentences on why the group may not last.
    public let cautions: [String]
    /// The evidence note in brackets: "(FM26-era numbers)"; nil for FM27 evidence.
    public let noteText: String?
    /// Its three members in the suggestion's order, for its Record arrows button.
    public let arrowsDraftMembers: [PlayerID]
    /// "Record arrows" beside Record as set while the group rests on a guess; nil once it rests on readings.
    public let recordArrowsTitle: String?
    private let spokenNote: String?

    /// The card as said to assistive technology: its title, each arrow, the prompt, the cautions and the note.
    public var spokenText: String {
        ([titleText] + arrows.flatMap(\.spokenParts) + [promptText].compactMap { $0 }
            + cautions.map { "Caution: \($0)" } + [spokenNote].compactMap { $0 })
            .joined(separator: ", ")
    }

    init(_ suggestion: SuggestedGroup) {
        self.suggestion = suggestion
        titleText = suggestion.members.map(\.name).joined(separator: ", ")
        arrows = suggestion.arrows.map(ArrowLine.init)
        promptText = suggestion.isRead ? nil : AdvisorText.setAndRecordArrows
        let names = Dictionary(suggestion.members.map { ($0.player, $0.name) }, uniquingKeysWith: { first, _ in first })
        cautions = suggestion.cautions.map { AdvisorText.caution($0, names: names) }
        spokenNote = AdvisorText.note(for: suggestion.basis)
        noteText = spokenNote.map { "(\($0))" }
        arrowsDraftMembers = suggestion.members.map(\.player)
        recordArrowsTitle = suggestion.isRead ? nil : MentoringPresentation.recordArrowsTitle
    }
}

/// One of the owner's groups as its card shows it. When the advice for the squad stopped, the card has only its title,
/// its since-text, what Edit opens with and its members for its Arrows button.
public struct RecordedGroupCard: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// The members' names: "Okafor, Lane, Pike".
    public let titleText: String
    /// "since Mon 12 Oct".
    public let sinceText: String
    /// The engine's sentence when the group is doing harm, shows no influence or has stopped working; nil otherwise.
    public let stateText: String?
    /// Each arrow above None between its present members, in the engine's order.
    public let arrows: [ArrowLine]
    /// The engine's prompt to record the group's arrows while any is a guess.
    public let arrowsPromptText: String?
    public let members: [MemberLine]
    /// The engine's sentences.
    public let warnings: [String]
    /// The evidence note in brackets: "(this tool's estimate)"; nil for FM27 evidence, and when the advice stopped.
    public let noteText: String?
    /// What Edit opens with.
    public let draft: MentoringGroupDraft
    /// Its current members, for its Arrows button.
    public let arrowsDraftMembers: [PlayerID]
    private let spokenNote: String?

    /// The card as said to assistive technology: its title and since when, each arrow, the prompt, the warnings, the
    /// state, each member with what has changed, and the note.
    public var spokenText: String {
        ([titleText, sinceText] + arrows.flatMap(\.spokenParts) + [arrowsPromptText].compactMap { $0 }
            + warnings.map { "Warning: \($0)" } + [stateText].compactMap { $0 } + members.flatMap(\.spokenParts)
            + [spokenNote].compactMap { $0 })
            .joined(separator: ", ")
    }

    /// A group as the engine read it.
    init(_ review: GroupReview, parameters: EngineParameters) {
        id = review.id
        titleText = review.members.map(\.name).joined(separator: ", ")
        sinceText = MentoringPresentation.sinceText(review.group.startedOn)
        stateText = AdvisorText.state(of: review, parameters: parameters)
        arrows = review.arrows.map(ArrowLine.init)
        arrowsPromptText = AdvisorText.arrowsToRead(review)
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
        arrowsDraftMembers = review.group.current.map(\.player)
        spokenNote = AdvisorText.note(for: review.basis)
        noteText = spokenNote.map { "(\($0))" }
    }

    /// A group as saved, named from `names`, for a squad whose advice stopped.
    init(saved group: MentoringGroup, names: (PlayerID) -> String) {
        id = group.id
        titleText = group.current.map { names($0.player) }.joined(separator: ", ")
        sinceText = MentoringPresentation.sinceText(group.startedOn)
        stateText = nil
        arrows = []
        arrowsPromptText = nil
        members = []
        warnings = []
        draft = MentoringGroupDraft(editing: group)
        arrowsDraftMembers = group.current.map(\.player)
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

/// One player the group editor or the arrows sheet offers.
public struct MemberChoice: Identifiable, Equatable, Sendable {
    public let id: PlayerID
    public let name: String
    /// His age and level: "18 · Others"; nil for a member who is no longer imported in the squad.
    public let detailText: String?
    public let isChosen: Bool
    /// Why he cannot be put in: "In another group" (never in the arrows sheet), or, for a member of the group being
    /// changed or a player in the arrows draft, "No longer in the squad" or "Out on loan"; nil when he can.
    public let unavailableText: String?
    /// Whether ticking his row does anything: a player chosen can always be taken out; one not chosen can be put in
    /// when nothing stops him and fewer than three are chosen.
    public let canToggle: Bool
}

/// One arrow in the arrows sheet: who to whom, and the strength set for it.
public struct ArrowRow: Identifiable, Equatable, Sendable {
    public let id: ArrowsDraft.Pair
    /// "Hart → Young".
    public let titleText: String
    /// "Hart to Young": the title as said, for its menu, since a screen reader reads the arrow sign as "right arrow".
    public let spokenTitle: String
    /// Nil: not read.
    public let strength: ArrowStrength?
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
    public static let levelLabel = "Level"
    public static let socialGroupLabel = "Social group"
    static let everyoneElse = "Everyone else: others."
    static let inAnotherGroup = "In another group"
    static let noLongerInSquad = "No longer in the squad"
    static let outOnLoan = "Out on loan"
    static let notEntered = "Not entered"
    static let noGroupRecorded = "No group recorded yet."
    static let notRead = "Not read"
    public static let recordArrowsTitle = "Record arrows"
    public static let arrowsTitle = "Arrows"
    /// The letters of the secondary social groups the game shows.
    static let secondaryGroups = ["A", "B", "C", "D"]

    /// The levels, highest first, in the engine's names.
    public static let standingChoices: [(Standing, String)] = Standing.allCases.reversed().map { ($0, AdvisorText.name($0)) }

    /// Not entered, then each social group in the engine's names: Core, Secondary A to D, Others.
    public static let socialGroupChoices: [(SocialGroup?, String)] =
        [(nil, notEntered)]
        + ([SocialGroup.core] + secondaryGroups.map(SocialGroup.secondary) + [.others]).map { ($0, AdvisorText.name($0)) }

    /// Not read, then the game's four strengths in the engine's names, weakest first.
    public static let strengthChoices: [(ArrowStrength?, String)] =
        [(nil, notRead)] + ArrowStrength.allCases.map { ($0, AdvisorText.name($0)) }

    /// The engine's sentence when the squad has no group to suggest; nil when it has one, when it has not been
    /// imported, and when its advice stopped.
    public static func noSuggestionsText(_ sheet: MentoringSheet) -> String? {
        guard sheet.notReady == nil, sheet.failures.isEmpty, sheet.suggested.isEmpty else { return nil }
        return AdvisorText.noGroupToSuggest
    }

    /// The muted line in place of the owner's groups when the squad has none; nil when it has one, and when it has not
    /// been imported.
    public static func noRecordedGroupsText(_ sheet: MentoringSheet) -> String? {
        guard sheet.notReady == nil, sheet.yours.isEmpty else { return nil }
        return noGroupRecorded
    }

    /// The heading over the players not placed; nil when there is nobody to list, so the part is not drawn.
    public static func notPlacedHeading(_ sheet: MentoringSheet) -> String? {
        sheet.notPlaced.isEmpty ? nil : headings.notPlaced
    }

    public static let squadMenuLabel = "Squad"

    public static func squadTitle(_ squad: Squad) -> String {
        squad.displayName
    }

    /// The squad to show: the one asked for when it is imported, else the first imported in book order, else the first
    /// team.
    public static func squadShown(_ asked: Squad, imported: Set<Squad>) -> Squad {
        if imported.contains(asked) { return asked }
        return Squad.allCases.first { imported.contains($0) } ?? .firstTeam
    }

    /// The squads the menu offers: those imported, in book order; with none imported, the one shown.
    public static func squadChoices(imported: Set<Squad>) -> [Squad] {
        let choices = Squad.allCases.filter { imported.contains($0) }
        return choices.isEmpty ? [squadShown(.firstTeam, imported: imported)] : choices
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
                                  socialGroupsLine: nil, updatedText: nil, staleText: nil, needsHierarchyText: nil,
                                  noteText: AdvisorText.mentoringNote, suggested: [], yours: [], notPlaced: [])
        case .failed(let sentences):
            report = nil
            failures = sentences
        case .ready(let ready):
            report = ready
            failures = []
        }

        let present = notOutOnLoan(players, ownClub: ownClub)
        let dynamics = state.dynamics(for: squad)
        let levels = levelLines(present, dynamics: dynamics)
        // The engine's rule, for a squad whose advice stopped: no level above Others among its players not out on loan.
        let needsHierarchy = report?.needsHierarchy ?? levels.isEmpty
        let entered = present.filter { dynamics[$0.id]?.socialGroup != nil }.count
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
            hierarchyLines: needsHierarchy ? [] : levels,
            socialGroupsLine: "Social groups entered for \(entered) of \(present.count).",
            updatedText: updatedOn.map { "Updated \(DayText.short($0))" },
            staleText: report.flatMap { report in
                updatedOn.flatMap { AdvisorText.staleHierarchy(report, updatedOn: $0, asOf: asOf) }
            },
            needsHierarchyText: needsHierarchy ? AdvisorText.mentoringNeedsHierarchy : nil,
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

    /// First, the members of the group being changed and any player in the draft who are not among the squad's players
    /// not out on loan, in the group's order, each named from the saved names and saying why he is not: he can only be
    /// taken out, and once out cannot be put back. Then the squad's players not out on loan, in squad order: those in
    /// the draft chosen, one in another live group unavailable, and nobody else can be put in once three are chosen.
    static func memberChoices(_ draft: MentoringGroupDraft, players: [Player], ownClub: String?,
                              state: MentoringState) -> [MemberChoice] {
        let elsewhere = Set(state.groups.filter { $0.isLive && $0.id != draft.id }.flatMap(\.current).map(\.player))
        let saved = draft.isNew ? [] : state.groups.first { $0.id == draft.id }?.current.map(\.player) ?? []
        return choices(squad: draft.squad, members: draft.members, alsoListed: saved, inAnotherGroup: elsewhere,
                       players: players, ownClub: ownClub, state: state)
    }

    /// The arrows sheet's choices, as the group editor's are made: first any player in the draft who is not among the
    /// squad's players not out on loan, saying why, who can only be taken out; then the squad's players not out on
    /// loan, in squad order, those in the draft chosen. A player in a recorded group is listed and can be chosen:
    /// arrows may be read for any three. Nobody else can be put in once three are chosen.
    static func arrowChoices(_ draft: ArrowsDraft, players: [Player], ownClub: String?,
                             state: MentoringState) -> [MemberChoice] {
        choices(squad: draft.squad, members: draft.members, alsoListed: [], inAnotherGroup: [], players: players,
                ownClub: ownClub, state: state)
    }

    /// The rows of a chooser of three for the squad. `members` are those chosen; `alsoListed` are players listed first
    /// with them when they are not offered; `elsewhere` are offered as in another group, and cannot be put in.
    private static func choices(squad: Squad, members: [PlayerID], alsoListed: [PlayerID],
                                inAnotherGroup elsewhere: Set<PlayerID>, players: [Player], ownClub: String?,
                                state: MentoringState) -> [MemberChoice] {
        let chosen = Set(members)
        let isFull = chosen.count >= Mentoring.groupSize
        let offered = notOutOnLoan(players, ownClub: ownClub)
        let offeredIDs = Set(offered.map(\.id))
        let held = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let dynamics = state.dynamics(for: squad)

        var gone: [PlayerID] = []
        for id in alsoListed + members where !offeredIDs.contains(id) && !gone.contains(id) { gone.append(id) }
        let goneRows = gone.map { id in
            let player = held[id]
            return MemberChoice(id: id, name: state.names[id] ?? player?.name ?? TrainingPresentation.unnamed,
                                detailText: player.map { detailText($0, dynamics: dynamics) },
                                isChosen: chosen.contains(id),
                                unavailableText: player == nil ? noLongerInSquad : outOnLoan, canToggle: chosen.contains(id))
        }
        return goneRows + offered.map { player in
            let isChosen = chosen.contains(player.id)
            let unavailable = elsewhere.contains(player.id) ? inAnotherGroup : nil
            return MemberChoice(id: player.id, name: player.name, detailText: detailText(player, dynamics: dynamics),
                                isChosen: isChosen, unavailableText: unavailable,
                                canToggle: isChosen || (unavailable == nil && !isFull))
        }
    }

    /// "18 · Others": his age and his level as entered for the squad.
    private static func detailText(_ player: Player, dynamics: [PlayerID: PlayerDynamics]) -> String {
        "\(player.age) · \(AdvisorText.name(dynamics[player.id]?.standing ?? .others))"
    }

    // MARK: The editors

    /// "First team hierarchy".
    public static func hierarchyEditorTitle(_ squad: Squad) -> String {
        switch squad {
        case .firstTeam: "First team hierarchy"
        case .u21: "U21 hierarchy"
        case .u18: "U18 hierarchy"
        }
    }

    /// Where in the game to read the levels and social groups: the Dynamics screen for the first team; each player's
    /// own page for the U21s and U18s, whose Dynamics screen may list nobody.
    public static func hierarchyEditorHint(_ squad: Squad) -> String {
        let blank = "A social group can be left not entered."
        return switch squad {
        case .firstTeam:
            "Set each player's level and social group as the game's Dynamics screen shows them. \(blank)"
        case .u21, .u18:
            "Set each player's level and social group as his own page in the game shows them: the "
                + "\(squad.displayName)' Dynamics screen may list nobody. \(blank)"
        }
    }

    /// Under the hierarchy editor's hint: the engine's sentence that social groups do not change the advice.
    public static let hierarchyEditorNote = AdvisorText.socialGroupsNotUsed

    /// "Add a first-team group" for a new group; "Change the group" for one recorded.
    public static func groupEditorTitle(_ draft: MentoringGroupDraft) -> String {
        guard draft.isNew else { return "Change the group" }
        return switch draft.squad {
        case .firstTeam: "Add a first-team group"
        case .u21: "Add a U21 group"
        case .u18: "Add a U18 group"
        }
    }

    /// "Record first-team arrows".
    public static func arrowsEditorTitle(_ squad: Squad) -> String {
        switch squad {
        case .firstTeam: "Record first-team arrows"
        case .u21: "Record U21 arrows"
        case .u18: "Record U18 arrows"
        }
    }

    public static let arrowsEditorHint =
        "Choose three players, then set each arrow as the game's Mentoring screen shows it."

    /// The six arrows of the draft's three once three different players are chosen, in member order (the first to each
    /// of the others, then the second, then the third), each with the strength set; none before. Named from `names`,
    /// never by a key.
    public static func arrowRows(_ draft: ArrowsDraft, names: [PlayerID: String]) -> [ArrowRow] {
        guard hasThree(draft) else { return [] }
        let name = { (id: PlayerID) in names[id] ?? TrainingPresentation.unnamed }
        return draft.pairs.map { pair in
            ArrowRow(id: pair, titleText: "\(name(pair.from)) → \(name(pair.to))",
                     spokenTitle: "\(name(pair.from)) to \(name(pair.to))", strength: draft.strengths[pair])
        }
    }

    /// The same draft (same id) with every pair of its three that has no strength set to None, and those set kept: the
    /// game shows only the arrows above None, so the rest are None. Unchanged unless three different players are chosen.
    public static func settingTheRestToNone(_ draft: ArrowsDraft) -> ArrowsDraft {
        guard hasThree(draft) else { return draft }
        var changed = draft
        for pair in draft.pairs where changed.strengths[pair] == nil { changed.strengths[pair] = ArrowStrength.none }
        return changed
    }

    /// "Set the rest to None", with the engine's name for None; nil when there is nothing to set: fewer than three
    /// chosen, or every pair set.
    public static func setTheRestToNoneTitle(_ draft: ArrowsDraft) -> String? {
        guard hasThree(draft), draft.pairs.contains(where: { draft.strengths[$0] == nil }) else { return nil }
        return "Set the rest to \(AdvisorText.name(ArrowStrength.none))"
    }

    /// Three different players are chosen.
    private static func hasThree(_ draft: ArrowsDraft) -> Bool {
        draft.members.count == Mentoring.groupSize && Set(draft.members).count == Mentoring.groupSize
    }

    /// "2 of 3 chosen".
    public static func chosenText(_ count: Int) -> String {
        "\(count) of \(Mentoring.groupSize) chosen"
    }

    // MARK: Words

    /// "Young (18)".
    static func nameText(_ name: String, age: Int) -> String {
        "\(name) (\(age))"
    }

    /// "read Sat 14 Nov": beside an arrow read in the game, the day as `DayText.short` writes it.
    public static func readOn(_ day: Day) -> String {
        "read \(DayText.short(day))"
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
