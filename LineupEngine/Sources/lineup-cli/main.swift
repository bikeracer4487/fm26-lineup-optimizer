import Foundation
import LineupEngine

// Reads the files named on the command line, runs the engine, prints the explained lineup or plan.
// Formatting lives in Report.swift; the engine does no file access.

let usage = """
usage: lineup-cli select --grids <fmrte config or grids snapshot> --tactic <tactic.json>
                         [--first-team <paste.tsv>] [--u21 <paste.tsv>] [--u18 <paste.tsv>]
                         [--importance high|medium|low|sharpness] [--own-club <name>]
                         [--profile fm27|carried-over|both]
       lineup-cli plan   --grids <fmrte config or grids snapshot> --tactic <tactic.json>
                         --fixtures <fixtures.json> --as-of <YYYY-MM-DD>
                         [--first-team <paste.tsv>] [--u21 <paste.tsv>] [--u18 <paste.tsv>] [--own-club <name>]
                         [--history <confirmed.json>] [--intensity low|medium|high] [--stability <0...1>]
                         [--saving <0...10>] [--horizon <n>] [--profile fm27|carried-over]
       lineup-cli advise --grids <fmrte config or grids snapshot> --tactic <tactic.json> --as-of <YYYY-MM-DD>
                         [--first-team <paste.tsv>] [--u21 <paste.tsv>] [--u18 <paste.tsv>] [--own-club <name>]
                         [--history <confirmed.json>] [--fixtures <fixtures.json>] [--intensity low|medium|high]
                         [--profile fm27|carried-over]
       At least one of --first-team, --u21, --u18 is required.
       --profile picks the rating profile: fm27 (FM27 engine tests, the default), carried-over (carried over from FM26),
       or, for select only, both, which prints the FM27 lineup, then the carried-over one, and compares them.

       select chooses the lineup for the next fixture.
       plan chooses the lineups for the next fixtures in date order, every one with the --tactic tactic, projecting
       fitness from the day the squads were exported (--as-of) and printing a table of who starts where.
       advise prints the advisors' reports for the --tactic tactic as of --as-of: the first and second elevens, depth
       at each slot, who needs rest, who could retrain to cover thin slots, who to sell, loan out or release, and the
       loan review; with --fixtures, a suggested importance beside each fixture's own.
       --fixtures is a JSON array of {"id", "date", "opponent", "importance", "overrides"?: {"<slot>": "<player key>"},
       "rejected"?: ["<player key>"], "competition"?: "league|cup|minorCup|friendly",
       "opponentStrength"?: "muchStronger|stronger|similar|weaker|muchWeaker"}. plan ignores competition and
       opponentStrength. --history is a JSON array of confirmed lineups:
       {"fixture", "date", "starters": {"<slot>": "<player key>"}}. Dates are YYYY-MM-DD. A player's key is "fmrte:<Id>"
       when the paste has FMRTE's Id column, otherwise his name in lower case.
       Unless given, training intensity is medium, stability 0.5, saving players 1 (0 turns it off) and horizon 5.
"""

enum Command: String { case select, plan, advise }

/// The rating profiles `--profile` can name, by the ids `RatingProfile` gives them, in the order they print.
let profileChoices: [String: [String]] = [
    "fm27": ["fm27-engine-tests"],
    "carried-over": ["carried-over"],
    "both": ["fm27-engine-tests", "carried-over"],
]

struct Options {
    var command: Command
    var grids: String?
    var tactic: String?
    var pastes: [(squad: Squad, path: String)] = []
    var importance = Importance.high
    var ownClub: String?
    var profileIDs = profileChoices["fm27"]!
    var fixtures: String?
    var history: String?
    var asOf: Day?
    var settings = PlanSettings.standard
}

struct UsageError: Error { let reason: String }

func parse(_ arguments: [String]) throws -> Options {
    var args = arguments[...]
    let command: Command
    switch args.popFirst() {
    case "select": command = .select
    case "plan": command = .plan
    case "advise": command = .advise
    default: throw UsageError(reason: "the commands are 'select', 'plan' and 'advise'")
    }
    var options = Options(command: command)
    let squads: [String: Squad] = ["--first-team": .firstTeam, "--u21": .u21, "--u18": .u18]
    let shared = ["--grids", "--tactic", "--own-club", "--profile"]
    let allowed = switch command {
    case .select: shared + ["--importance"]
    case .plan: shared + ["--fixtures", "--history", "--as-of", "--intensity", "--stability", "--saving", "--horizon"]
    case .advise: shared + ["--fixtures", "--history", "--as-of", "--intensity"]
    }
    let name = command.rawValue
    while let flag = args.popFirst() {
        guard allowed.contains(flag) || squads[flag] != nil else { throw UsageError(reason: "unknown option \(flag) for \(name)") }
        guard let value = args.popFirst() else { throw UsageError(reason: "\(flag) needs a value") }
        func number(_ text: String) throws -> Double {
            guard let x = Double(text) else { throw UsageError(reason: "\(flag) needs a number, not '\(text)'") }
            return x
        }
        switch flag {
        case "--grids": options.grids = value
        case "--tactic": options.tactic = value
        case "--own-club": options.ownClub = value
        case "--importance":
            guard let importance = Importance(rawValue: value) else {
                throw UsageError(reason: "unknown importance '\(value)' (use high, medium, low or sharpness)")
            }
            options.importance = importance
        case "--profile":
            guard let ids = profileChoices[value], command == .select || ids.count == 1 else {
                throw UsageError(reason: "unknown profile '\(value)' (use fm27\(command == .select ? ", carried-over or both" : " or carried-over"))")
            }
            options.profileIDs = ids
        case "--fixtures": options.fixtures = value
        case "--history": options.history = value
        case "--as-of":
            guard let day = Day(iso: value) else { throw UsageError(reason: "--as-of needs a date in the form YYYY-MM-DD, not '\(value)'") }
            options.asOf = day
        case "--intensity":
            guard let intensity = TrainingIntensity(rawValue: value) else {
                throw UsageError(reason: "unknown intensity '\(value)' (use low, medium or high)")
            }
            options.settings.trainingIntensity = intensity
        case "--stability": options.settings.stability = try number(value)
        case "--saving": options.settings.savingPlayers = try number(value)
        case "--horizon":
            guard let horizon = Int(value) else { throw UsageError(reason: "--horizon needs a whole number, not '\(value)'") }
            options.settings.horizon = horizon
        default: options.pastes.append((squads[flag]!, value))
        }
    }
    guard options.grids != nil else { throw UsageError(reason: "--grids is required") }
    guard options.tactic != nil else { throw UsageError(reason: "--tactic is required") }
    guard !options.pastes.isEmpty else { throw UsageError(reason: "give at least one of --first-team, --u21, --u18") }
    switch command {
    case .select: break
    case .plan:
        guard options.fixtures != nil else { throw UsageError(reason: "--fixtures is required") }
        guard options.asOf != nil else { throw UsageError(reason: "--as-of is required") }
    case .advise:
        guard options.asOf != nil else { throw UsageError(reason: "--as-of is required") }
    }
    return options
}

func fail(_ message: String, showUsage: Bool = false) -> Never {
    FileHandle.standardError.write(Data((message + "\n" + (showUsage ? usage + "\n" : "")).utf8))
    exit(1)
}

func read(_ path: String) -> Data {
    guard let data = FileManager.default.contents(atPath: path) else { fail("cannot read \(path)", showUsage: true) }
    return data
}

func readText(_ path: String) -> String {
    guard let text = String(data: read(path), encoding: .utf8) else { fail("\(path) is not UTF-8 text", showUsage: true) }
    return text
}

/// Decodes a JSON file the user wrote; a bad file is a usage error that names the file and the field.
func decode<T: Decodable>(_ type: T.Type, _ data: Data, file path: String, what: String) -> T {
    do { return try JSONDecoder().decode(type, from: data) } catch {
        fail("The \(what) file \(path) is not valid: \(ErrorDescriptions.describe(error))", showUsage: true)
    }
}

/// One entry of the fixtures file. Every fixture is played with the `--tactic` tactic.
struct FixtureEntry: Decodable {
    let id: FixtureID
    let date: Day
    let opponent: String
    let importance: Importance
    let overrides: [SlotID: PlayerID]?
    let rejected: [PlayerID]?
    let competition: Competition?
    let opponentStrength: OpponentStrength?
}

/// The entries of the fixtures file at `path` as fixtures with `tactic`. A key the squads do not have is a mistake in
/// the file, not a player to leave out quietly.
func resolveFixtures(_ entries: [FixtureEntry], file path: String, tactic: Tactic, book: SquadBook) -> [Fixture] {
    let known = Set(book.allPlayers.map(\.id))
    for (index, entry) in entries.enumerated() {
        let named = (entry.overrides ?? [:]).sorted { $0.key.rawValue < $1.key.rawValue }
            .map { (field: "overrides.\($0.key.rawValue)", id: $0.value) }
            + (entry.rejected ?? []).map { (field: "rejected", id: $0) }
        if let unknown = named.first(where: { !known.contains($0.id) }) {
            fail("The fixtures file \(path) is not valid: fixture \(index + 1) (\(entry.id.raw)), field "
                 + "'\(unknown.field)', names '\(unknown.id.key)', who is not in the imported squads", showUsage: true)
        }
    }
    return entries.map {
        Fixture(id: $0.id, date: $0.date, opponent: $0.opponent, importance: $0.importance, tactic: tactic,
                overrides: $0.overrides ?? [:], rejected: Set($0.rejected ?? []),
                competition: $0.competition, opponentStrength: $0.opponentStrength)
    }
}

let options: Options
do { options = try parse(Array(CommandLine.arguments.dropFirst())) } catch let error as UsageError {
    fail(error.reason, showUsage: true)
}

let grids = read(options.grids!)
let tacticData = read(options.tactic!)
let pastes = options.pastes.map { (squad: $0.squad, path: $0.path, text: readText($0.path)) }
let fixtureEntries = options.fixtures.map { path in decode([FixtureEntry].self, read(path), file: path, what: "fixtures") }
let history = options.history.map { path in decode([ConfirmedLineup].self, read(path), file: path, what: "history") } ?? []

var output = ""
do {
    var book = SquadBook()
    var imports: [(squad: Squad, result: ImportResult)] = []
    var moves: [(name: String, from: Squad, to: Squad)] = []
    for paste in pastes {
        let result = try Importer.importPlayers(clipboard: paste.text, fmrteConfig: grids, squad: paste.squad)
        let squadBefore = Dictionary(book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })
        let change = book.apply(result, to: paste.squad)
        for id in change.movedIn {
            let name = book.current[paste.squad]?.first { $0.id == id }?.name ?? id.key
            if let from = squadBefore[id] { moves.append((name, from, paste.squad)) }
        }
        imports.append((paste.squad, result))
    }
    let tactic: Tactic
    do { tactic = try JSONDecoder().decode(Tactic.self, from: tacticData) } catch {
        fail("The tactic file \(options.tactic!) is not valid: \(ErrorDescriptions.describe(error))")
    }
    let ownClub = book.ownClub(override: options.ownClub)
    let catalog = try RoleCatalog.fm27()
    let available = try RatingProfile.all()
    let profiles = options.profileIDs.map { id in
        guard let profile = available.first(where: { $0.id == id }) else { fail("no rating profile has the id \(id)") }
        return profile
    }
    let header = Report.Header(imports: imports, moves: moves, book: book, ownClub: ownClub, override: options.ownClub, tactic: tactic)

    switch options.command {
    case .select:
        let request = SelectionRequest(tactic: tactic, players: book.allPlayers, ownClub: ownClub, importance: options.importance,
                                       isNextFixture: true, overrides: [:], rejected: [])
        let results = try profiles.map { profile in
            (profile: profile, lineup: try LineupSelector(catalog: catalog, profile: profile, parameters: .fm27).select(request))
        }
        output = Report.render(header, importance: options.importance, results: results, parameters: .fm27)

    case .plan:
        let fixtures = resolveFixtures(fixtureEntries ?? [], file: options.fixtures!, tactic: tactic, book: book)
        let profile = profiles[0]
        let parameters = EngineParameters.fm27
        let plan = try Planner(catalog: catalog, profile: profile, parameters: parameters).plan(PlanRequest(
            fixtures: fixtures, players: book.allPlayers, ownClub: ownClub, asOf: options.asOf!, confirmed: history,
            retraining: [], settings: options.settings))
        output = Report.render(header, plan: plan, fixtures: fixtures, history: history, asOf: options.asOf!,
                               profile: profile, parameters: parameters, settings: options.settings)

    case .advise:
        let fixtures = fixtureEntries.map { resolveFixtures($0, file: options.fixtures!, tactic: tactic, book: book) }
        let profile = profiles[0]
        let parameters = EngineParameters.fm27
        let players = book.allPlayers
        let advisors = try Advisors.report(AdvisorsRequest(
            primary: tactic, tactics: [tactic], players: players, ownClub: ownClub, history: StartHistory(history),
            asOf: options.asOf!, intensity: options.settings.trainingIntensity, accepted: [], rejected: []),
            catalog: catalog, profile: profile, parameters: parameters)
        var suggestions: [(fixture: Fixture, suggestion: ImportanceSuggestion)]?
        if let fixtures {
            // The planner's tiers: injured players left out, as they cannot play.
            let tiers = try SquadTiers.compute(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                               profile: profile, parameters: parameters)
            suggestions = try fixtures.sorted { ($0.date, $0.id.raw) < ($1.date, $1.id.raw) }.map { fixture in
                (fixture, try ImportanceAdvisor.suggest(for: fixture, among: fixtures, confirmed: history, players: players,
                                                        tiers: tiers, parameters: parameters))
            }
        }
        output = Report.render(header, advice: Report.Advice(
            asOf: options.asOf!, profile: profile, intensity: options.settings.trainingIntensity, history: history,
            elevens: advisors.elevens, depth: advisors.depth, rest: advisors.rest, training: advisors.training,
            removal: advisors.removal, suggestions: suggestions),
            parameters: parameters)
    }
} catch {
    // The library describes FMRTE's configuration without knowing where it was read from.
    let isConfigError = switch error as? ImportError {
    case .configUnreadable?, .noPlayerGrids?: true
    case .emptyClipboard?, .notAnFMRTEGrid?, .raggedRows?, .noGridFits?, .ambiguousGrid?, .missingColumns?,
         .invalidValue?, .unexpectedScale?, .duplicateID?, nil: false
    }
    fail(ErrorDescriptions.describe(error) + (isConfigError ? " (read from \(options.grids!))" : ""))
}
print(output, terminator: "")
