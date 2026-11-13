import Foundation
import LineupEngine

// Reads the files named on the command line, runs the engine, prints the explained lineup.
// Formatting lives in Report.swift; the engine does no file access.

let usage = """
usage: lineup-cli select --grids <fmrte config or grids snapshot> --tactic <tactic.json>
                         [--first-team <paste.tsv>] [--u21 <paste.tsv>] [--u18 <paste.tsv>]
                         [--importance high|medium|low|sharpness] [--own-club <name>]
       At least one of --first-team, --u21, --u18 is required.
"""

struct Options {
    var grids: String?
    var tactic: String?
    var pastes: [(squad: Squad, path: String)] = []
    var importance = Importance.high
    var ownClub: String?
}

struct UsageError: Error { let reason: String }

func parse(_ arguments: [String]) throws -> Options {
    var args = arguments[...]
    guard args.popFirst() == "select" else { throw UsageError(reason: "the only command is 'select'") }
    var options = Options()
    while let flag = args.popFirst() {
        let squads: [String: Squad] = ["--first-team": .firstTeam, "--u21": .u21, "--u18": .u18]
        guard ["--grids", "--tactic", "--importance", "--own-club"].contains(flag) || squads[flag] != nil else {
            throw UsageError(reason: "unknown option \(flag)")
        }
        guard let value = args.popFirst() else { throw UsageError(reason: "\(flag) needs a value") }
        switch flag {
        case "--grids": options.grids = value
        case "--tactic": options.tactic = value
        case "--own-club": options.ownClub = value
        case "--importance":
            guard let importance = Importance(rawValue: value) else {
                throw UsageError(reason: "unknown importance '\(value)' (use high, medium, low or sharpness)")
            }
            options.importance = importance
        default: options.pastes.append((squads[flag]!, value))
        }
    }
    guard options.grids != nil else { throw UsageError(reason: "--grids is required") }
    guard options.tactic != nil else { throw UsageError(reason: "--tactic is required") }
    guard !options.pastes.isEmpty else { throw UsageError(reason: "give at least one of --first-team, --u21, --u18") }
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

let options: Options
do { options = try parse(Array(CommandLine.arguments.dropFirst())) } catch let error as UsageError {
    fail(error.reason, showUsage: true)
}

let grids = read(options.grids!)
let tacticData = read(options.tactic!)
let pastes = options.pastes.map { (squad: $0.squad, path: $0.path, text: readText($0.path)) }

var output = ""
do {
    var book = SquadBook()
    var imports: [(squad: Squad, result: ImportResult)] = []
    for paste in pastes {
        let result = try Importer.importPlayers(clipboard: paste.text, fmrteConfig: grids, squad: paste.squad)
        book.apply(result, to: paste.squad)
        imports.append((paste.squad, result))
    }
    let tactic: Tactic
    do { tactic = try JSONDecoder().decode(Tactic.self, from: tacticData) } catch {
        fail("The tactic file \(options.tactic!) is not valid: \(ErrorDescriptions.describe(error))")
    }
    let ownClub = book.ownClub(override: options.ownClub)
    let selector = LineupSelector(catalog: try .fm27(), tables: try .bundled(), parameters: .fm27)
    let lineup = try selector.select(.init(tactic: tactic, players: book.allPlayers, ownClub: ownClub,
                                           importance: options.importance, isNextFixture: true,
                                           overrides: [:], rejected: []))
    output = Report.render(imports: imports, book: book, ownClub: ownClub, override: options.ownClub,
                           tactic: tactic, importance: options.importance, lineup: lineup)
} catch {
    fail(ErrorDescriptions.describe(error))
}
print(output, terminator: "")
