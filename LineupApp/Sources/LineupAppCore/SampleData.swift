import Foundation
import Synchronization
import LineupEngine

/// An environment whose clipboard, FMRTE settings file and clock are set by code, for the sample data and the tests;
/// or, for the sample data in a window the owner clicks in, the Mac's own monotonic clock.
final class ScriptedInput: Sendable {
    enum Config: Sendable {
        case data(Data)
        /// Reads the file at the path the model asks for, or at `otherwise` when it asks for the usual place.
        case readFile(otherwise: String)
        case failure(any Error)
    }

    private struct State {
        var clipboard: String?
        var config: Config
        var uptime: TimeInterval = 0
        var tick: TimeInterval = 1
        var readings: [TimeInterval] = []
    }

    let today: Day
    /// Whether the clock is the Mac's monotonic clock rather than `uptime`.
    let usesRealClock: Bool
    private let state: Mutex<State>

    init(today: Day, clipboard: String? = nil, config: Config = .data(Data()), usesRealClock: Bool = false) {
        self.today = today
        self.usesRealClock = usesRealClock
        self.state = Mutex(State(clipboard: clipboard, config: config))
    }

    var clipboard: String? {
        get { state.withLock { $0.clipboard } }
        set { state.withLock { $0.clipboard = newValue } }
    }

    var config: Config {
        get { state.withLock { $0.config } }
        set { state.withLock { $0.config = newValue } }
    }

    /// What the clock reads next.
    var uptime: TimeInterval {
        get { state.withLock { $0.uptime } }
        set { state.withLock { $0.uptime = newValue } }
    }

    /// How far the clock moves on after each reading: a second by default, so actions made one after another are
    /// never taken for a double-click; 0 to hold it where a test sets it.
    var tick: TimeInterval {
        get { state.withLock { $0.tick } }
        set { state.withLock { $0.tick = newValue } }
    }

    /// The clock's next readings, in order, taken before it reads `uptime` again: so a test can have an action start at
    /// one time and finish at a later one.
    var readings: [TimeInterval] {
        get { state.withLock { $0.readings } }
        set { state.withLock { $0.readings = newValue } }
    }

    var environment: AppEnvironment {
        AppEnvironment(
            today: { [today] in today },
            clipboard: { self.clipboard },
            fmrteConfig: { path in
                switch self.config {
                case .data(let data): return data
                case .readFile(let otherwise): return try Data(contentsOf: URL(fileURLWithPath: path ?? otherwise))
                case .failure(let error): throw error
                }
            },
            now: {
                if self.usesRealClock { return ProcessInfo.processInfo.systemUptime }
                return self.state.withLock { state in
                    if !state.readings.isEmpty { return state.readings.removeFirst() }
                    defer { state.uptime += state.tick }
                    return state.uptime
                }
            })
    }
}

/// Why the sample data could not be built, in plain words.
public struct SampleDataError: Error, Equatable, CustomStringConvertible {
    public let description: String
}

public enum SampleData {
    /// The date the sample squads were exported, used as today and as the import date.
    static let date = Day(year: 2026, month: 11, day: 13)!
    /// The captures come from a team grid with no club column, so the club is named.
    static let clubName = "Oxford City"

    private struct SampleFixture: Decodable {
        let date: Day
        let opponent: String
        let importance: Importance
        let competition: Competition?
        let opponentStrength: OpponentStrength?
    }

    /// A model on a temporary directory, filled from the engine's captures under `repositoryRoot`: both squads, the
    /// sample 4-2-3-1 as the primary tactic, the five sample fixtures with their competitions and opponents' strengths,
    /// the sample history, and the first retraining the advisors recommend, accepted.
    @MainActor public static func model(repositoryRoot: URL) throws -> AppModel {
        try build(repositoryRoot: repositoryRoot).model
    }

    /// The sample model for a window the owner clicks in: as `model`, but on the Mac's monotonic clock, so a second
    /// click within the training actions' interval is ignored as in the real app. The pictures and the tests keep the
    /// scripted clock, which moves a second at each reading.
    @MainActor public static func interactiveModel(repositoryRoot: URL) throws -> AppModel {
        try build(repositoryRoot: repositoryRoot, usesRealClock: true).model
    }

    /// The sample model after an import of text that is not FMRTE rows: the squads are unchanged and
    /// `lastImport` says why the import failed.
    @MainActor public static func modelWithFailedImport(repositoryRoot: URL) throws -> AppModel {
        let (model, input) = try build(repositoryRoot: repositoryRoot)
        input.clipboard = "Oxford City 2 Banbury United 1"
        model.importSquad(.firstTeam)
        return model
    }

    /// The sample model after the first team is imported again from the capture of the same squad taken with
    /// FMRTE's `Id` column, so `lastImport` reports a second import: each player now keyed by his FMRTE id.
    @MainActor public static func modelAfterImport(repositoryRoot: URL) throws -> AppModel {
        let (model, input) = try build(repositoryRoot: repositoryRoot)
        input.clipboard = String(decoding: try fixture("captures/first-team-with-id.tsv", under: repositoryRoot), as: UTF8.self)
        input.config = .data(try fixture("captures/first-team-with-id.grids.json", under: repositoryRoot))
        model.importSquad(.firstTeam)
        if case .failed(_, let reason)? = model.lastImport {
            throw SampleDataError(description: "The sample first-team-with-id.tsv could not be imported: \(reason)")
        }
        return model
    }

    /// The sample model with its tactic saved without the in-possession striker, so the tactic has a problem:
    /// ten in-possession slots, and an out-of-possession striker nothing turns into.
    @MainActor public static func modelWithTacticProblem(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard var stored = model.tactics.first else {
            throw SampleDataError(description: "The sample model has no tactic.")
        }
        var draft = TacticDraft(stored.tactic)
        draft.toggle(.ST_C, in: .inPossession, catalog: model.catalog)
        stored.tactic = draft.tactic
        model.update(stored)
        return model
    }

    /// The sample model with an unsaved change to its tactic: the inside forward on the left made a winger.
    @MainActor public static func modelWithUnsavedTacticChange(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard let id = model.tactics.first?.id, var draft = model.draft(for: id) else {
            throw SampleDataError(description: "The sample model has no tactic.")
        }
        draft.setRole("Winger", at: .AM_L, in: .inPossession)
        model.setDraft(draft, for: id)
        return model
    }

    /// The sample model five days on, on 18 November, with a lineup confirmed for the first fixture (the starters of
    /// the last sample lineup) and none for the second, so one fixture before today is confirmed and one is not.
    @MainActor public static func modelWithPastFixtures(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard model.fixtures.count >= 2, let first = model.fixtures.first, var record = model.history.last else {
            throw SampleDataError(description: "The sample model has too few fixtures or no confirmed lineup.")
        }
        // The record holds the last sample lineup's starters, not the planned ones, so it is added to the history directly.
        record.lineup.fixture = first.id
        record.lineup.date = first.date
        model.history.append(record)
        model.save(.history)
        model.replan()
        var settings = model.settings
        settings.currentDate = Day(year: 2026, month: 11, day: 18)!
        model.update(settings)
        return model
    }

    /// The sample model with a lineup confirmed for the first fixture, as Match Selection's "Confirm this lineup"
    /// records it.
    @MainActor public static func modelAfterConfirmingFirst(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard let first = model.fixtures.first, model.canConfirm(first.id) else {
            throw SampleDataError(description: "The sample model's first fixture cannot be confirmed.")
        }
        model.confirm(first.id)
        return model
    }

    /// The sample model later in a season: seven more fixtures a week apart after the sample's five, and the first six
    /// confirmed in turn, so Match Selection's notes do not fit the window and the next match to play is the seventh.
    @MainActor public static func modelMidSeason(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard let last = model.fixtures.last else {
            throw SampleDataError(description: "The sample model has no fixtures.")
        }
        for (week, letter) in ["F", "G", "H", "I", "J", "K", "L"].enumerated() {
            model.addFixture(date: last.date.adding(days: 7 * (week + 1)), opponent: "Opponent \(letter)", importance: .medium)
        }
        for _ in 0..<6 {
            guard let next = model.fixtures.first(where: { model.canConfirm($0.id) }) else {
                throw SampleDataError(description: "The mid-season sample has no fixture that can be confirmed.")
            }
            model.confirm(next.id)
        }
        return model
    }

    /// The names of the three first-team players banned in `modelWithBans`.
    public static let bannedNames = ["Darnell Johnson", "Dejan Tetek", "Tyrone Marsh"]

    /// The sample model with three of its first eleven banned, as after a match in which each took the booking that
    /// brings a ban. With `notForTheFirstMatch`, the owner has said the bans are not for the first fixture.
    @MainActor public static func modelWithBans(repositoryRoot: URL, notForTheFirstMatch: Bool = false) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        edit(model) { player in
            if bannedNames.contains(player.name) { player.isBanned = true }
        }
        guard model.players.filter(\.isBanned).count == bannedNames.count, let first = model.fixtures.first else {
            throw SampleDataError(description: "The sample model lacks a fixture or one of the players to ban.")
        }
        if notForTheFirstMatch { model.setBansApply(false, in: first.id) }
        return model
    }

    /// The sample model with the owner's choices in the first fixture: the best available U21 player fixed at AM C,
    /// the injured goalkeeper fixed in goal (the owner's choice over the injury), a player out on loan fixed at left
    /// back (an override the engine cannot use) and the striker left out.
    @MainActor public static func modelWithChoices(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        let away = model.players.first { player in
            if case .loanedOut = model.squad.book.loanStatus(of: player, override: model.settings.clubOverride) { true } else { false }
        }
        guard let first = model.fixtures.first,
              let youth = model.candidates(for: .AM_C, in: first.id).first(where: { $0.squad == .u21 && $0.unavailable == nil }),
              let injured = model.players.first(where: { $0.name == "Jonny Maxted" && $0.isInjured }),
              let away,
              let striker = model.players.first(where: { $0.name == "Tyrone Marsh" }) else {
            throw SampleDataError(description: "The sample model lacks a fixture, a U21 player, its injured goalkeeper, "
                                  + "a player out on loan or its striker.")
        }
        model.setOverride(youth.player, at: .AM_C, in: first.id)
        model.setOverride(injured.id, at: .GK, in: first.id)
        model.setOverride(away.id, at: .D_L, in: first.id)
        model.reject(striker.id, in: first.id)
        return model
    }

    /// The sample model with an unconfirmed fixture on 12 November, the day before the squads were imported: a
    /// missed fixture.
    @MainActor public static func modelWithMissedFixture(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        model.addFixture(date: Day(year: 2026, month: 11, day: 12)!, opponent: "Opponent Z", importance: .medium)
        return model
    }

    /// The sample model two days on, on 15 November, with both squads imported again that day and the first fixture,
    /// on 14 November, never confirmed: a missed fixture with the eleven last planned for it remembered.
    @MainActor public static func modelWithMissedEleven(repositoryRoot: URL) throws -> AppModel {
        let (model, input) = try build(repositoryRoot: repositoryRoot)
        model.moveToday(by: 2)
        for (squad, paste, grids) in samplePastes {
            input.clipboard = String(decoding: try fixture("captures/\(paste)", under: repositoryRoot), as: UTF8.self)
            input.config = .data(try fixture("captures/\(grids)", under: repositoryRoot))
            model.importSquad(squad)
            if case .failed(_, let reason)? = model.lastImport {
                throw SampleDataError(description: "The sample \(paste) could not be imported: \(reason)")
            }
        }
        model.dismissImport()
        return model
    }

    /// The missed-eleven model with a second fixture on 17 November, so the plan stops while the missed fixture's eleven
    /// can still be confirmed.
    @MainActor public static func modelWithMissedElevenWhileThePlanIsStopped(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithMissedEleven(repositoryRoot: repositoryRoot)
        model.addFixture(date: Day(year: 2026, month: 11, day: 17)!, opponent: "Opponent F", importance: .low)
        return model
    }

    /// The sample model with a second fixture on 17 November, so the plan stops: a club plays one match a day.
    @MainActor public static func modelWithTwoMatchesOnOneDay(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        model.addFixture(date: Day(year: 2026, month: 11, day: 17)!, opponent: "Opponent F", importance: .low)
        return model
    }

    /// The sample model with its second fixture, a league match against a weaker side, made high importance, so the
    /// medium importance the advice suggests for it differs from the owner's choice. In the sample as it is, every
    /// fixture's suggestion agrees with its importance.
    @MainActor public static func modelWithDifferingSuggestion(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard model.fixtures.count >= 2 else {
            throw SampleDataError(description: "The sample model has too few fixtures.")
        }
        var second = model.fixtures[1]
        second.importance = .high
        model.update(second)
        return model
    }

    /// The sample model and a draft of its second fixture, a league match, after its opponent's squad was pasted: the
    /// capture of the same first team taken with FMRTE's `Id` column, which the sample, keyed by name, does not take for
    /// its own players. The draft has a reading and the strength it set.
    @MainActor public static func draftWithOpponentReading(repositoryRoot: URL) throws -> (model: AppModel, draft: FixtureDraft) {
        let (model, draft) = try draftAfterPaste(repositoryRoot: repositoryRoot, paste: "first-team-with-id.tsv",
                                                 grids: "first-team-with-id.grids.json")
        guard draft.opponentReading != nil else {
            throw SampleDataError(description: "The sample opponent squad was not read: \(draft.pasteProblem ?? "no reason given")")
        }
        return (model, draft)
    }

    /// The sample model and a draft of its second fixture after the owner's own first team was pasted as the opponent's,
    /// which is refused: the draft says why and has no reading.
    @MainActor public static func draftWithRefusedPaste(repositoryRoot: URL) throws -> (model: AppModel, draft: FixtureDraft) {
        let (model, draft) = try draftAfterPaste(repositoryRoot: repositoryRoot, paste: "first-team.tsv",
                                                 grids: "first-team.grids.json")
        guard draft.pasteProblem != nil else {
            throw SampleDataError(description: "Pasting the sample's own first team as the opponent's was not refused.")
        }
        return (model, draft)
    }

    /// The sample model and a draft of its second fixture after `paste`, with its grid layouts `grids`, was pasted as the
    /// opponent's squad.
    @MainActor private static func draftAfterPaste(repositoryRoot: URL, paste: String, grids: String) throws
        -> (model: AppModel, draft: FixtureDraft) {
        let (model, input) = try build(repositoryRoot: repositoryRoot)
        guard model.fixtures.count >= 2 else {
            throw SampleDataError(description: "The sample model has too few fixtures.")
        }
        input.clipboard = String(decoding: try fixture("captures/\(paste)", under: repositoryRoot), as: UTF8.self)
        input.config = .data(try fixture("captures/\(grids)", under: repositoryRoot))
        var draft = model.fixtureDraft(for: model.fixtures[1])
        model.pasteOpponentSquad(into: &draft)
        return (model, draft)
    }

    /// The sample model with two first-team players' jadedness raised in its copy of the squads, so the rest advice has
    /// every level: Alfie Potter, whose limit is lowered for his age and Stamina, far enough over it for a holiday, and
    /// Ludwig Francillette over the standard limit for rest.
    @MainActor public static func modelWithJadedPlayers(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        let raised = ["Alfie Potter": 520, "Ludwig Francillette": 460]
        guard Set(model.players.map(\.name)).isSuperset(of: raised.keys) else {
            throw SampleDataError(description: "The sample model lacks \(raised.keys.sorted().joined(separator: " or ")).")
        }
        edit(model) { player in
            if let jadedness = raised[player.name] { player.jadedness = jadedness }
        }
        return model
    }

    /// The sample model with every player fresh and fully fit and no confirmed lineups, so nobody needs rest.
    @MainActor public static func modelWithNobodyNeedingRest(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        model.history = []
        model.save(.history)
        edit(model) { player in
            player.jadedness = 0
            player.condition = 1
        }
        return model
    }

    /// The sample model before any retraining is accepted, so its recommendations show: the sample's accepted
    /// retraining fills the thin slot it was recommended for, which then gets no more recommendations.
    @MainActor public static func modelBeforeRetraining(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        for retraining in model.training.accepted {
            model.stopRetraining(TrainingState.choice(retraining))
        }
        return model
    }

    /// The sample model with its accepted retraining six weeks under way, accepted on 2 October and read at an import
    /// every two weeks since, his familiarity rising a point each time (short of solid) and the squad's copy showing the
    /// latest; the second recommendation made before it was accepted, turned down; and a second retraining, of the
    /// player with the longest name, accepted, and another position of his turned down, before he left the squads.
    @MainActor public static func modelWithRetrainingUnderWay(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard let accepted = model.training.accepted.first,
              let start = model.training.observations[TrainingState.choice(accepted)]?.first?.familiarity else {
            throw SampleDataError(description: "The sample model has no accepted retraining with a first observation.")
        }
        let choice = TrainingState.choice(accepted)
        model.stopRetraining(choice)
        guard case .ready(let open) = model.adviceState, open.training.recommendations.count >= 2,
              open.training.recommendations[0].choice == choice else {
            throw SampleDataError(description: "The sample's advice does not recommend its retraining and another.")
        }
        model.reject(open.training.recommendations[1].choice)
        model.accept(choice)

        let leastFamiliarFirst = { (player: Player) in
            Position.allCases.sorted { (player.familiarity[$0] ?? 0, Position.allCases.firstIndex(of: $0) ?? 0)
                < (player.familiarity[$1] ?? 0, Position.allCases.firstIndex(of: $1) ?? 0) }
        }
        guard let leaver = model.players.filter({ $0.id != accepted.player }).max(by: { $0.name.count < $1.name.count }) else {
            throw SampleDataError(description: "The sample model has no second player to retrain.")
        }
        let positions = leastFamiliarFirst(leaver)
        model.accept(RetrainingChoice(player: leaver.id, position: positions[0]))
        model.reject(RetrainingChoice(player: leaver.id, position: positions[1]))

        let solid = model.planParameters.depthSolidFamiliarity.value
        let readings = (0..<4).map { step in
            FamiliarityObservation(day: date.adding(days: 14 * step - 42), familiarity: min(start + step, solid - 1))
        }
        model.changeTraining(replanning: false) { state in
            state.accepted = state.accepted.map { retraining in
                retraining.player == accepted.player
                    ? Retraining(player: retraining.player, position: retraining.position, acceptedOn: date.adding(days: -42))
                    : retraining
            }
            state.observations[choice] = readings
        }
        for squad in Squad.allCases {
            guard var players = model.squad.book.current[squad] else { continue }
            players.removeAll { $0.id == leaver.id }
            for index in players.indices where players[index].id == accepted.player {
                players[index].familiarity[accepted.position] = readings.last?.familiarity
            }
            _ = model.squad.book.apply(ImportResult(grid: "sample", players: players, warnings: [],
                                                    money: model.squad.book.moneyStyle), to: squad)
        }
        model.save(.squad)
        model.replan()
        return model
    }

    /// The sample model with its accepted retraining twenty-one weeks under way and two points gained, well behind its
    /// estimate, with the squad's copy showing the latest; and a second player learning right back, where cover is
    /// not thin, so no slot needs him to.
    @MainActor public static func modelWithRetrainingBehind(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard let accepted = model.training.accepted.first,
              let start = model.training.observations[TrainingState.choice(accepted)]?.first?.familiarity else {
            throw SampleDataError(description: "The sample model has no accepted retraining with a first observation.")
        }
        guard let spare = model.players.first(where: {
            $0.squad == .firstTeam && $0.id != accepted.player && ($0.familiarity[.defenderRight] ?? 20) < 10
                && LoanStatus.of($0, ownClub: model.ownClub) == .own
        }) else {
            throw SampleDataError(description: "The sample model has no second player to learn right back.")
        }
        model.accept(RetrainingChoice(player: spare.id, position: .defenderRight))

        let readings = [(-147, 0), (-98, 1), (-49, 1), (0, 2)].map { days, gained in
            FamiliarityObservation(day: date.adding(days: days), familiarity: start + gained)
        }
        model.changeTraining(replanning: false) { state in
            state.accepted = state.accepted.map { retraining in
                retraining.player == accepted.player
                    ? Retraining(player: retraining.player, position: retraining.position, acceptedOn: date.adding(days: -147))
                    : retraining
            }
            state.observations[TrainingState.choice(accepted)] = readings
        }
        for squad in Squad.allCases {
            guard var players = model.squad.book.current[squad] else { continue }
            for index in players.indices where players[index].id == accepted.player {
                players[index].familiarity[accepted.position] = readings.last?.familiarity
            }
            _ = model.squad.book.apply(ImportResult(grid: "sample", players: players, warnings: [],
                                                    money: model.squad.book.moneyStyle), to: squad)
        }
        model.save(.squad)
        model.replan()
        return model
    }

    /// The sample model with nothing for the Training screen to list: its retraining stopped, and every player natural
    /// in every position, so no slot is thin.
    @MainActor public static func modelWithNothingToRetrain(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        for retraining in model.training.accepted {
            model.stopRetraining(TrainingState.choice(retraining))
        }
        edit(model) { player in
            for position in Position.allCases { player.familiarity[position] = 20 }
        }
        return model
    }

    /// The player `modelWithLoanee` puts on loan here: the longest name in the sample.
    public static let loaneeName = "Kauan Bitencourt de Oliveira"

    /// The sample model with one U21 player given a parent club in its copy of the squads, so the engine reads him as on
    /// loan to the club and the Player Removal screen reviews his loan.
    @MainActor public static func modelWithLoanee(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard model.players.contains(where: { $0.name == loaneeName }) else {
            throw SampleDataError(description: "The sample model lacks \(loaneeName).")
        }
        edit(model) { player in
            if player.name == loaneeName { player.club = "Banbury United" }
        }
        return model
    }

    /// The U21 player `modelWithYoungPlayers` makes a 16-year-old on a youth contract worth developing.
    static let youngToDevelopName = "Brayden Daniel"
    /// The U21 player `modelWithYoungPlayers` makes a 16-year-old on a youth contract markedly below the squad.
    static let youngToReleaseName = "Kauan Bitencourt de Oliveira"
    /// The U21 player of 19 `modelWithYoungPlayers` gives two years left on his contract and a potential worth
    /// developing.
    static let youngToLoanName = "Tyrae Njogu"

    /// The sample model with three U21 players changed in its copy of the squads, as an import of the changed squads
    /// would change them, and four more matches confirmed before the import, so each young player's starts are counted:
    /// a 16-year-old on a youth contract worth developing, kept to develop; a 16-year-old on a youth contract markedly
    /// below the squad (ability 20, potential 30, and every attribute but his personality halved), released; and a
    /// 19-year-old with two years left who has not started, loaned for matches: his potential is raised from 48 to 85,
    /// so his reach could pass the first choice at his best slot, since a player whose reach is markedly lower than the
    /// squad's is not worth developing. The first team's first choices are kept to play.
    @MainActor public static func modelWithYoungPlayers(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        let changed = [youngToDevelopName, youngToReleaseName, youngToLoanName]
        guard Set(model.players.map(\.name)).isSuperset(of: changed), model.history.count == 2 else {
            throw SampleDataError(description: "The sample model lacks \(changed.joined(separator: ", ")) or its two "
                                  + "confirmed lineups.")
        }
        // The sample's two lineups again, alternately, three and four days apart before them: six confirmed in all.
        let earlier = [Day(year: 2026, month: 10, day: 24)!, Day(year: 2026, month: 10, day: 27)!,
                       Day(year: 2026, month: 10, day: 31)!, Day(year: 2026, month: 11, day: 3)!]
        let copies = earlier.enumerated().map { index, day in
            var record = model.history[index % 2]
            record.lineup.fixture = FixtureID("\(day.iso)-played")
            record.lineup.date = day
            return record
        }
        model.history = copies + model.history
        model.save(.history)
        edit(model) { player in
            switch player.name {
            case youngToDevelopName:
                player.age = 16
                player.contractType = .youth
                player.monthsLeft = 24
            case youngToReleaseName:
                player.age = 16
                player.contractType = .youth
                player.monthsLeft = 24
                player.currentAbility = 20
                player.potentialAbility = 30
                for attribute in Attribute.allCases where ![.professionalism, .ambition, .determination].contains(attribute) {
                    if let value = player.attributes[attribute] { player.attributes[attribute] = max(1, value / 2) }
                }
            case youngToLoanName:
                player.monthsLeft = 24
                player.potentialAbility = 85
            default: break
            }
        }
        return model
    }

    /// The sample model with the first team's hierarchy entered, as the owner enters it: the three oldest first-team
    /// players of the club's own raised, the oldest to Team Leader, the next to Highly Influential and the third to
    /// Influential, all three in the core social group, and the two youngest in secondary group A; nobody else has an
    /// entry. The U21s have none, so their advice asks for their hierarchy.
    @MainActor public static func modelWithHierarchy(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        try enterHierarchy(in: model)
        return model
    }

    /// The hierarchy sample with the hierarchy entered five weeks before the game's current date, so it is stale.
    @MainActor public static func modelWithStaleHierarchy(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        model.moveToday(by: -35)
        try enterHierarchy(in: model)
        model.moveToday(by: 35)
        return model
    }

    /// Enters the first team's hierarchy as `modelWithHierarchy` describes, dated the game's current date.
    @MainActor private static func enterHierarchy(in model: AppModel) throws {
        let own = (model.squad.book.current[.firstTeam] ?? []).filter { LoanStatus.of($0, ownClub: model.ownClub) == .own }
        let oldest = own.sorted { ($1.age, $0.name) < ($0.age, $1.name) }
        let youngest = own.sorted { ($0.age, $0.name) < ($1.age, $1.name) }
        guard own.count >= 5 else {
            throw SampleDataError(description: "The sample first team has too few players of the club's own.")
        }
        var entries: [PlayerID: PlayerDynamics] = [:]
        for (player, standing) in zip(oldest, [Standing.teamLeader, .highlyInfluential, .influential]) {
            entries[player.id] = PlayerDynamics(standing: standing, socialGroup: .core)
        }
        for player in youngest.prefix(2) {
            entries[player.id] = PlayerDynamics(standing: .others, socialGroup: .secondary("A"))
        }
        model.setDynamics(entries, for: .firstTeam)
    }

    /// The hierarchy sample with the advice's first suggested first-team group recorded five weeks before the game's
    /// current date, and an import today in which the player its first arrow points to has risen one in
    /// Professionalism.
    @MainActor public static func modelWithMentoringGroup(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithHierarchy(repositoryRoot: repositoryRoot)
        try recordGroupWithARise(in: model)
        return model
    }

    /// As `modelWithMentoringGroup`, with the group's Team Leader given, before the group was recorded, an Ambition one
    /// below that of the first junior his arrow points to (counting no higher than where Ambition stops counting), so
    /// his guessed arrow into that junior is harmful. His Ambition is the same at both readings, so the group is not
    /// doing harm.
    @MainActor public static func modelWithMentoringWarning(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithHierarchy(repositoryRoot: repositoryRoot)
        let group = try firstSuggestion(model)
        let ceiling = model.planParameters.mentoringCeilings.value[.ambition] ?? 20
        let players = model.squad.book.current[.firstTeam] ?? []
        let levels = model.mentoring.dynamics(for: .firstTeam)
        guard let arrow = group.arrows.first(where: { levels[$0.arrow.from]?.standing == .teamLeader })?.arrow,
              let junior = players.first(where: { $0.id == arrow.to })?.attributes[.ambition].map({ min($0, ceiling) }),
              junior > 1 else {
            throw SampleDataError(description: "The sample's first suggested group has no arrow from its Team Leader into "
                                  + "a junior with an Ambition above 1.")
        }
        edit(model) { player in
            if player.id == arrow.from { player.attributes[.ambition] = junior - 1 }
        }
        try recordGroupWithARise(in: model, group: group)
        return model
    }

    /// The hierarchy sample with the advice's first suggested first-team group recorded fourteen weeks before the game's
    /// current date, its members' readings then and today the same, so it has stopped working.
    @MainActor public static func modelWithStoppedGroup(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithHierarchy(repositoryRoot: repositoryRoot)
        record(try firstSuggestion(model), in: model, weeksAgo: 14)
        return model
    }

    /// The hierarchy sample with the advice's first suggested first-team group recorded five weeks before the game's
    /// current date, an import today in which the player its first arrow points to has fallen one in Professionalism,
    /// and the group ended today, as End group does. It was doing harm when it ended, so the same three are not
    /// suggested again, and the suggestion that puts him with another of them says what fell.
    @MainActor public static func modelWithEndedGroup(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithHierarchy(repositoryRoot: repositoryRoot)
        let group = try firstSuggestion(model)
        let ceiling = model.planParameters.mentoringCeilings.value[.professionalism] ?? 20
        guard let mentee = group.arrows.first?.arrow.to,
              let value = (model.squad.book.current[.firstTeam] ?? []).first(where: { $0.id == mentee })?
                .attributes[.professionalism], value > 1, value <= ceiling else {
            throw SampleDataError(description: "The sample's first suggested group has no member who can fall in Professionalism.")
        }
        record(group, in: model, weeksAgo: 5)
        edit(model) { if $0.id == mentee { $0.attributes[.professionalism] = value - 1 } }
        model.recordPersonality(after: .firstTeam, on: model.settings.currentDate)
        let today = model.settings.currentDate
        model.changeMentoring { state in
            for index in state.groups.indices where state.groups[index].isLive { state.groups[index].endedOn = today }
        }
        let fell = { (caution: MemberCaution) in if case .fell(mentee, _, _) = caution { true } else { false } }
        guard case .ready(let report) = model.mentoringAdvice(for: .firstTeam),
              !report.suggestions.contains(where: { $0.id == group.id }),
              report.suggestions.contains(where: { $0.cautions.contains(where: fell) }) else {
            throw SampleDataError(description: "The sample's ended group is suggested again, or no suggestion says who fell in it.")
        }
        return model
    }

    /// The hierarchy sample with the six arrows of the advice's first suggested first-team group read today, each at
    /// the strength the tool guessed, as the owner records them in the arrows sheet, so that group rests on readings;
    /// the other suggestions still rest on guesses.
    @MainActor public static func modelWithArrowsRead(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithHierarchy(repositoryRoot: repositoryRoot)
        let group = try firstSuggestion(model)
        var draft = model.arrowsDraft(for: .firstTeam, members: group.members.map(\.player))
        for pair in draft.pairs {
            draft.strengths[pair] = group.arrows.first { $0.arrow.from == pair.from && $0.arrow.to == pair.to }?
                .arrow.strength ?? ArrowStrength.none
        }
        try saveArrows(draft, in: model)
        return model
    }

    /// The warning sample with its Team Leader's harmful arrow, in Ambition, read today as Significant in the arrows
    /// sheet; the group's other arrows are still guesses. His Ambition is the same at both readings, so the group is
    /// not doing harm.
    @MainActor public static func modelWithHarmfulArrow(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithMentoringWarning(repositoryRoot: repositoryRoot)
        guard case .ready(let report) = model.mentoringAdvice(for: .firstTeam), let review = report.groups.first,
              let (from, to) = review.warnings.lazy.compactMap({ warning -> (PlayerID, PlayerID)? in
                  guard case .harmfulArrow(let from, let to, _, _, .ambition, _, _) = warning else { return nil }
                  return (from, to)
              }).first else {
            throw SampleDataError(description: "The warning sample's group has no harmful arrow in Ambition.")
        }
        var draft = model.arrowsDraft(for: .firstTeam, members: review.group.current.map(\.player))
        draft.strengths[ArrowsDraft.Pair(from: from, to: to)] = .significant
        try saveArrows(draft, in: model)
        return model
    }

    /// The group sample with its group's six arrows read today as None in the arrows sheet, so it shows no influence.
    @MainActor public static func modelWithNoInfluence(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithMentoringGroup(repositoryRoot: repositoryRoot)
        guard let group = model.mentoring.groups.first(where: \.isLive) else {
            throw SampleDataError(description: "The group sample has no group.")
        }
        var draft = model.arrowsDraft(for: .firstTeam, members: group.current.map(\.player))
        for pair in draft.pairs { draft.strengths[pair] = ArrowStrength.none }
        try saveArrows(draft, in: model)
        return model
    }

    /// The hierarchy sample with its three seniors recorded by hand as a group today. Nobody is expected to influence a
    /// player of their age, so the group is expected to give nobody anything; and the juniors, left with no senior
    /// free, would gain from one, so the advice has a regrouping.
    @MainActor public static func modelWithRegrouping(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithHierarchy(repositoryRoot: repositoryRoot)
        try recordSeniors(in: model)
        return model
    }

    /// As `modelWithRegrouping`, with the other two seniors given the Team Leader's values where they count before
    /// the group was recorded, and its six arrows read today in the arrows sheet: Light from the Team Leader into each
    /// of the other two and None for the rest. The arrows are the game's, and give nobody anything.
    @MainActor public static func modelWithSpentGroup(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithHierarchy(repositoryRoot: repositoryRoot)
        let levels = model.mentoring.dynamics(for: .firstTeam)
        let players = model.squad.book.current[.firstTeam] ?? []
        guard let leader = players.first(where: { levels[$0.id]?.standing == .teamLeader }) else {
            throw SampleDataError(description: "The hierarchy sample has no Team Leader.")
        }
        let counted = Mentoring.counted(model.planParameters)
        edit(model) { player in
            guard let standing = levels[player.id]?.standing, standing > .others, player.id != leader.id else { return }
            for attribute in counted { player.attributes[attribute] = leader.attributes[attribute] }
        }
        let members = try recordSeniors(in: model)
        var draft = model.arrowsDraft(for: .firstTeam, members: members)
        for pair in draft.pairs { draft.strengths[pair] = pair.from == leader.id ? .light : ArrowStrength.none }
        try saveArrows(draft, in: model)
        return model
    }

    /// Records the first team's players with a level above Others as a group, as the group editor's Save does, and
    /// returns them; or says why the sample could not, or that the advice then has no regrouping.
    @MainActor @discardableResult private static func recordSeniors(in model: AppModel) throws -> [PlayerID] {
        let levels = model.mentoring.dynamics(for: .firstTeam)
        let seniors = (model.squad.book.current[.firstTeam] ?? []).map(\.id).filter {
            (levels[$0]?.standing ?? .others) > .others
        }
        let draft = MentoringGroupDraft(squad: .firstTeam, members: seniors)
        if let problem = model.mentoringProblem(of: draft) {
            throw SampleDataError(description: "The sample's seniors could not be recorded as a group: \(problem)")
        }
        model.saveGroup(draft)
        guard case .ready(let report) = model.mentoringAdvice(for: .firstTeam), report.regrouping != nil else {
            throw SampleDataError(description: "The sample's mentoring advice has no regrouping for its seniors' group.")
        }
        return seniors
    }

    /// Saves the arrows as the sheet's Save does, or says why the sample could not.
    @MainActor private static func saveArrows(_ draft: ArrowsDraft, in model: AppModel) throws {
        if let problem = model.arrowsProblem(of: draft) {
            throw SampleDataError(description: "The sample's arrows could not be saved: \(problem)")
        }
        model.saveArrows(draft)
    }

    /// The group sample with the first first-team player of the club's own given no Pressure value in its copy of the
    /// squads, so the first team's mentoring advice stops; the U21s' and the other advice do not.
    @MainActor public static func modelWithMentoringFailure(repositoryRoot: URL) throws -> AppModel {
        let model = try modelWithMentoringGroup(repositoryRoot: repositoryRoot)
        guard let player = (model.squad.book.current[.firstTeam] ?? [])
            .first(where: { LoanStatus.of($0, ownClub: model.ownClub) == .own }) else {
            throw SampleDataError(description: "The sample first team has no player of the club's own.")
        }
        edit(model) { if $0.id == player.id { $0.attributes[.pressure] = nil } }
        return model
    }

    /// The first group the mentoring advice suggests for the first team.
    @MainActor private static func firstSuggestion(_ model: AppModel) throws -> SuggestedGroup {
        guard case .ready(let report) = model.mentoringAdvice(for: .firstTeam), let group = report.suggestions.first else {
            throw SampleDataError(description: "The sample's mentoring advice suggests no first-team group.")
        }
        return group
    }

    /// Records `group` (the first suggested, if not given) five weeks back, then takes today's reading again with the
    /// player its first arrow points to one higher in Professionalism.
    @MainActor private static func recordGroupWithARise(in model: AppModel, group given: SuggestedGroup? = nil) throws {
        let group = try given ?? firstSuggestion(model)
        let ceiling = model.planParameters.mentoringCeilings.value[.professionalism] ?? 20
        guard let mentee = group.arrows.first?.arrow.to,
              let value = (model.squad.book.current[.firstTeam] ?? []).first(where: { $0.id == mentee })?
                .attributes[.professionalism], value < ceiling else {
            throw SampleDataError(description: "The sample's first suggested group has no member who can rise in Professionalism.")
        }
        record(group, in: model, weeksAgo: 5)
        edit(model) { if $0.id == mentee { $0.attributes[.professionalism] = value + 1 } }
        model.recordPersonality(after: .firstTeam, on: model.settings.currentDate)
    }

    /// Records the suggested first-team group as the owner would have `weeks` weeks before the game's current date: the
    /// date moved back, the first team read as an import that day reads it, the group recorded and its notice dismissed,
    /// and the date moved on again.
    @MainActor private static func record(_ group: SuggestedGroup, in model: AppModel, weeksAgo weeks: Int) {
        model.moveToday(by: -7 * weeks)
        model.recordPersonality(after: .firstTeam, on: model.settings.currentDate)
        model.recordGroup(group, in: .firstTeam)
        for notice in model.notices where notice.id == model.trainingNotice { model.dismiss(notice) }
        model.moveToday(by: 7 * weeks)
    }

    /// Changes every player in the model's copy of the squads as `change` says, as an import of the changed squads
    /// would, saves the squads and works the plan and advice out again.
    @MainActor private static func edit(_ model: AppModel, _ change: (inout Player) -> Void) {
        for squad in Squad.allCases {
            guard var players = model.squad.book.current[squad] else { continue }
            for index in players.indices { change(&players[index]) }
            _ = model.squad.book.apply(ImportResult(grid: "sample", players: players, warnings: [],
                                                    money: model.squad.book.moneyStyle), to: squad)
        }
        model.save(.squad)
        model.replan()
    }

    /// The sample squads' pastes and grid layouts, in the order they are imported.
    private static let samplePastes = [(Squad.firstTeam, "first-team.tsv", "first-team.grids.json"),
                                       (Squad.u21, "u21.tsv", "u21.grids.json")]

    /// A model with nothing in it, on a new temporary directory, whose clipboard is empty.
    @MainActor public static func emptyModel() -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lineup-empty-\(UUID().uuidString)")
        return AppModel(store: Store(directory: directory), environment: ScriptedInput(today: date).environment)
    }

    /// The engine's test fixture at `path` under `repositoryRoot`.
    private static func fixture(_ path: String, under repositoryRoot: URL) throws -> Data {
        let url = repositoryRoot.appendingPathComponent("LineupEngine/Tests/LineupEngineTests/Fixtures").appendingPathComponent(path)
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw SampleDataError(description: "The sample file \(url.path) could not be read.")
        }
        return data
    }

    /// A sample built and saved, with what the clipboard and FMRTE's settings file held at the end.
    private struct Built {
        let directory: URL
        let clipboard: String?
        let config: ScriptedInput.Config
    }

    /// The sample built from each repository root. Building plans the fixtures after every step, so it is done once
    /// and its files are copied for each model asked for.
    @MainActor private static var built: [URL: Built] = [:]

    /// A model on a new temporary directory holding a copy of the sample's files, with the clipboard and FMRTE's
    /// settings file as the sample's last import left them.
    @MainActor private static func build(repositoryRoot: URL, usesRealClock: Bool = false) throws
        -> (model: AppModel, input: ScriptedInput) {
        let sample = try built[repositoryRoot] ?? buildOnce(repositoryRoot: repositoryRoot)
        built[repositoryRoot] = sample
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lineup-sample-\(UUID().uuidString)")
        do {
            try FileManager.default.copyItem(at: sample.directory, to: directory)
        } catch {
            throw SampleDataError(description: "The sample data could not be copied to \(directory.path): \(error.localizedDescription)")
        }
        let input = ScriptedInput(today: date, clipboard: sample.clipboard, config: sample.config,
                                  usesRealClock: usesRealClock)
        return (AppModel(store: Store(directory: directory), environment: input.environment), input)
    }

    /// Builds the sample on a temporary directory of its own, which `build` copies.
    @MainActor private static func buildOnce(repositoryRoot: URL) throws -> Built {
        func data(_ path: String) throws -> Data { try fixture(path, under: repositoryRoot) }
        func decode<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
            do {
                return try JSONDecoder().decode(type, from: data(path))
            } catch let error as DecodingError {
                throw SampleDataError(description: "The sample file \(path) is not valid: \(ErrorDescriptions.describe(error))")
            }
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lineup-sample-\(UUID().uuidString)")
        let store = Store(directory: directory)
        let input = ScriptedInput(today: date)
        let model = AppModel(store: store, environment: input.environment)

        for (squad, paste, grids) in samplePastes {
            input.clipboard = String(decoding: try data("captures/\(paste)"), as: UTF8.self)
            input.config = .data(try data("captures/\(grids)"))
            model.importSquad(squad)
            if case .failed(_, let reason)? = model.lastImport {
                throw SampleDataError(description: "The sample \(paste) could not be imported: \(reason)")
            }
        }
        if model.ownClub == nil {
            var settings = model.settings
            settings.clubName = clubName
            model.update(settings)
        }

        // The fixtures come before the tactic, so the fixtures are planned only once there is a tactic to plan them with.
        for fixture in try decode([SampleFixture].self, "plans/sample-fixtures-with-competitions.json") {
            let id = model.addFixture(date: fixture.date, opponent: fixture.opponent, importance: fixture.importance)
            guard var stored = model.fixtures.first(where: { $0.id == id }) else {
                throw SampleDataError(description: "The sample fixture against \(fixture.opponent) was not saved.")
            }
            stored.competition = fixture.competition
            stored.opponentStrength = fixture.opponentStrength
            model.update(stored)
        }
        let tactic = try decode(Tactic.self, "tactics/sample-4231.json")
        let tacticID = model.addTactic(named: tactic.name)
        model.update(StoredTactic(id: tacticID, tactic: tactic))

        // One retraining accepted, so the Training screen has one under way.
        guard case .ready(let advice) = model.adviceState, let recommended = advice.training.recommendations.first else {
            throw SampleDataError(description: "The sample's advice recommends no retraining to accept: \(model.adviceState)")
        }
        model.accept(recommended.choice)
        // The notice saying what was accepted is not a problem with the sample; notices are not saved in any case.
        for notice in model.notices where notice.id == model.trainingNotice { model.dismiss(notice) }

        // These matches have no saved fixture, so they cannot be confirmed: the history is saved directly, and the
        // models made from these files load it.
        let names = Dictionary(model.players.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let history = try decode([ConfirmedLineup].self, "plans/sample-history.json").map { lineup in
            ConfirmedRecord(
                lineup: lineup,
                names: names.filter { id, _ in lineup.starters.values.contains(id) },
                tacticName: tactic.name)
        }
        try store.save(history, to: .history)
        if let notice = model.notices.first {
            throw SampleDataError(description: "The sample data could not be built: \(notice.text)")
        }
        return Built(directory: directory, clipboard: input.clipboard, config: input.config)
    }
}
