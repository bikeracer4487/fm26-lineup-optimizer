import Foundation

/// The engine's own errors, and the importer's warnings, in plain words for the manager. Every known error type is described
/// by an exhaustive switch; only a type the engine does not define falls through to a generic line.
public enum ErrorDescriptions {
    public static func describe(_ error: Error) -> String {
        switch error {
        case let e as ImportError: describe(e)
        case let e as CatalogError: describe(e)
        case let e as TacticError: describe(e)
        case let e as RatingError: describe(e)
        case let e as DecodingError: describe(e)
        case let e as DuplicatePlayerError: describe(e)
        case let e as PlanError: describe(e)
        case let e as OpponentReadingError: describe(e)
        case let e as LeagueTableError: describe(e)
        case let e as LeagueFormatError: describe(e)
        default: "Unexpected error: \(error.localizedDescription)"
        }
    }

    public static func describe(_ error: ImportError) -> String {
        switch error {
        case .configUnreadable(let reason): "FMRTE's configuration cannot be read: \(reason)"
        case .noPlayerGrids: "FMRTE's configuration has no player grids"
        case .emptyClipboard: "The paste is empty"
        case .notAnFMRTEGrid(let reason): "The paste is not an FMRTE grid: \(reason)"
        case .raggedRows(let expected, let row, let found):
            "Row \(row) of the paste has \(found) cells where \(expected) were expected"
        case .noGridFits(let count, let violations) where violations.isEmpty:
            "No saved FMRTE grid has \(count) columns, as the paste has; FMRTE may not have saved its current layout yet"
        case .noGridFits(let count, let violations):
            "No grid fits the paste's \(count) columns (misfit cells per grid: "
                + violations.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ") + ")"
        case .ambiguousGrid(let keys): "More than one grid fits the paste: \(keys.sorted().joined(separator: ", "))"
        case .missingColumns(let grid, let columns): "Grid \(grid) lacks the columns: \(columns.joined(separator: ", "))"
        case .invalidValue(let player, let column, let value): "\(player): the value '\(value)' in column \(column) is not valid"
        case .unexpectedScale(let column): "Column \(column) looks like percentages; FMRTE's 0 to 10000 scale is expected"
        case .duplicateID(let id, let players):
            "Two rows have the same FMRTE Id \(id): \(players.joined(separator: " and "))"
        case .unknownWagePeriod(let found):
            "FMRTE is set to show wages by a period this tool does not know (“\(found)”). Set it to Weekly, Monthly or "
                + "Yearly in FMRTE's settings, then import again."
        case .mixedCurrency(let player, let symbol, let expected):
            "\(player)'s wage is in \(symbol) where the rest of the paste is in \(expected). Check FMRTE's currency "
                + "setting, then copy the rows again."
        }
    }

    /// An import warning in plain words; the caller says which squad it came from.
    public static func describe(_ warning: ImportWarning) -> String {
        switch warning {
        case .duplicateName(let name):
            "more than one player is called \(name); they were told apart by potential ability, then nationality"
        case .indistinguishable(let name):
            "players called \(name) also share potential ability and nationality, so they were told apart by their order "
                + "in the paste; re-sorting the grid in FMRTE can swap them"
        case .outOfContract(let name): "\(name) is out of contract"
        case .identifiedByName:
            "This grid has no Id column, so players are identified by name. Add the Id column in FMRTE for exact identity."
        }
    }

    /// A warning about the squads taken together, as a whole sentence.
    public static func describe(_ warning: SquadWarning) -> String {
        switch warning {
        case .ownClubUnknown:
            "Your club cannot be told from the squads pasted, so every player with a club under 'loaned to' is treated "
                + "as out on loan. Set your club's name."
        case .sharedName(let name):
            "More than one player is called \(name); they are kept as separate players, told apart by potential "
                + "ability, then nationality."
        case .mixedCurrencies(let symbols):
            currenciesSentence(symbols) + " Wages in different currencies cannot be compared: import every squad with the "
                + "same currency set in FMRTE."
        }
    }

    public static func describe(_ error: CatalogError) -> String {
        switch error {
        case .malformed(let reason): "The role or rating data is damaged: \(reason)"
        case .unknownAttribute(let role, let name): "\(role) uses an attribute the engine does not know: \(name)"
        case .unknownRole(let name, let phase, let position):
            "\(name) is not an \(phaseName(phase)) role for \(PositionText.plain(position))"
        }
    }

    public static func describe(_ error: TacticError) -> String {
        "The tactic cannot be used:\n" + error.problems.map { "  - " + describe($0) }.joined(separator: "\n")
    }

    public static func describe(_ problem: TacticProblem) -> String {
        switch problem {
        case .wrongSlotCount(let phase, let n): "The \(phaseName(phase)) side has \(n) slots, not 11"
        case .missingGoalkeeper(let phase): "The \(phaseName(phase)) side has no goalkeeper"
        case .unmapped(let slot): "\(capitalised(slot)) has no out-of-possession slot to turn into"
        case .mappingTargetInactive(let from, let to):
            "\(capitalised(from)) turns into \(PositionText.plain(to)), which has no out-of-possession role"
        case .duplicateMappingTarget(let slot): "More than one slot turns into \(PositionText.plain(slot))"
        case .unknownRole(let phase, let slot, let role):
            "\(role) is not an \(phaseName(phase)) role for \(PositionText.plain(slot))"
        case .goalkeeperMappedToOutfield(let slot):
            "\(capitalised(.GK)) turns into \(PositionText.plain(slot)) out of possession; the goalkeeper must stay in goal"
        }
    }

    public static func describe(_ error: RatingError) -> String {
        switch error {
        case .missingAttribute(let player, let attribute): "\(player) has no value for the attribute \(attribute.rawValue)"
        case .missingFamiliarity(let player, let position): "\(player) has no familiarity for the position \(PositionText.plain(position))"
        }
    }

    public static func describe(_ error: DuplicatePlayerError) -> String {
        "Two players share the identity \(error.id.key): \(error.names.joined(separator: " and ")). "
            + "Import the squad again so each player has his own identity."
    }

    public static func describe(_ error: OpponentReadingError) -> String {
        switch error {
        case .noOwnSquad: "Import your own squad first, so there is something to compare theirs with."
        case .ownSquadPasted: "The rows pasted are your own players. Open the opponent's squad in FMRTE and copy that."
        case .noClubName:
            "Say who the match is against before pasting, so that a player on loan there can be told from one away on loan."
        case .tooFewPlayers(.theirs(let club), let found):
            "\(club) has only \(found) fit players among the rows pasted who are not away on loan; eleven are needed."
        case .tooFewPlayers(.own, let found):
            "Your own squads have only \(found) fit players who are not away on loan; eleven are needed."
        }
    }

    public static func describe(_ error: LeagueTableError) -> String {
        switch error {
        case .noStandingsGrid: "FMRTE's settings file has no league table layout."
        case .noGridFits(let count):
            "The pasted rows fit none of FMRTE's league table layouts: they have \(count) columns."
        case .ambiguousGrid(let keys):
            "More than one of FMRTE's league table layouts fits the paste: \(keys.sorted().joined(separator: ", "))."
        case .missingColumns(let grid, let columns):
            "FMRTE's league table layout \(grid) lacks: \(columns.map(columnName).joined(separator: ", "))."
        case .invalidValue(let team, _, _) where team.isEmpty: "A row of the table has no team name."
        case .invalidValue(let team, let column, let value):
            "\(team)'s \(columnName(column)) is '\(value)', not a whole number."
        case .tooFewTeams(let found):
            "The paste has only \(found) team\(found == 1 ? "" : "s"); a league table needs at least two."
        case .duplicateTeam(let name): "\(name) is in the table twice."
        case .placesNotInOrder: "The places pasted are not 1 to the number of teams, each once."
        case .resultsDoNotAddUp(let team, let played, let won, let drawn, let lost):
            "\(team)'s \(won) wins, \(drawn) draws and \(lost) losses do not add up to \(played) matches played."
        case .playedTooMany(let team, let played, let season):
            "\(team) have played \(played) matches, but a season of this league holds \(season)."
        case .noClubKnown: "The club is not known yet. Import a squad first."
        case .clubNotInTable(let club, let teams):
            "\(club) is not among the \(teams) teams pasted. Paste your own league's table, or correct the club's name in Settings."
        }
    }

    public static func describe(_ error: LeagueFormatError) -> String {
        switch error {
        case .negative(let field, let value):
            let name = switch field {
            case .promoted: "promoted places"
            case .playOffs: "play-offs"
            case .relegated: "relegated places"
            }
            let shown = value < 0 ? "\u{2212}\(-value)" : "\(value)"
            return "The \(name) cannot have \(shown) teams."
        case .tooMany(let format, let teams):
            let total = format.promoted + format.playOffs + format.relegated
            return "\(format.promoted) promoted, \(format.playOffs) in the play-offs and \(format.relegated) relegated make "
                + "\(total), more than the \(teams) teams in the table."
        }
    }

    public static func describe(_ warning: LeagueTableWarning) -> String {
        switch warning {
        case .pointsDoNotFit(let team, let points, let fromResults):
            "\(team) have \(AdvisorText.signedNumber(points)) points where their results give "
                + "\(AdvisorText.signedNumber(fromResults)); the table's points are used."
        }
    }

    /// FMRTE's column path said in words: "GoalsAllowed" as "Goals allowed".
    private static func columnName(_ path: String) -> String {
        var words: [String] = []
        for character in path {
            if character.isUppercase || words.isEmpty { words.append(String(character)) } else { words[words.count - 1].append(character) }
        }
        return words.enumerated().map { $0.offset == 0 ? $0.element : $0.element.lowercased() }.joined(separator: " ")
    }

    public static func describe(_ error: PlanError) -> String {
        switch error {
        case .fixtureBeforeSnapshot(let fixture, let date, let asOf):
            "The fixture \(fixture.raw) on \(date.iso) is before the squad was imported on \(asOf.iso). "
                + "Confirm its lineup if it has been played, or correct its date."
        case .fixturesOnTheSameDay(let first, let second, let day):
            "The fixtures \(first.raw) and \(second.raw) are both on \(day.iso). A club plays one match a day: correct one of the dates."
        case .duplicateFixtureID(let fixture):
            "More than one fixture, confirmed lineup or played match has the id \(fixture.raw). Each fixture needs its own id."
        case .badSettings(let problems): "The plan settings cannot be used: \(problems.joined(separator: "; "))."
        case .badParameters(let problems): "The engine's parameters cannot be used: \(problems.joined(separator: "; "))."
        }
    }

    /// Why the player cannot play, as a phrase: "injured", "condition 78% is below the 85% floor". With `projected`, a
    /// fitness figure is called projected, for a fixture whose fitness is projected from the import rather than read
    /// from the game.
    public static func describe(_ exclusion: Exclusion, parameters: EngineParameters, projected: Bool = false) -> String {
        let figure = projected ? "projected " : ""
        return switch exclusion {
        case .injured: "injured"
        case .outOnLoan(let club): "on loan at \(club)"
        case .banned: "banned"
        case .belowConditionFloor(let condition):
            "\(figure)condition \(Display.percent(condition)) is below the \(Display.percent(parameters.conditionFloor.value)) floor"
        case .jaded(let jadedness): "\(figure)jadedness \(jadedness) is above \(parameters.jadedThreshold.value)"
        case .rejected: "rejected for this fixture"
        }
    }

    /// Why the manager's choice for a slot was not used, as a phrase that follows the player's name and slot.
    public static func describe(_ problem: OverrideProblem, parameters: EngineParameters, projected: Bool = false) -> String {
        switch problem {
        case .notInSquad: "who is not in the imported squads"
        case .notAllowed(let exclusion): describe(exclusion, parameters: parameters, projected: projected) + ", which cannot be overruled"
        case .usedTwice: "because he is fixed in another slot too"
        case .slotNotInTactic: "because the tactic has no such slot"
        }
    }

    /// A caution about a pick, as a whole sentence: out of position in a phase, with his familiarity and the threshold
    /// below which a player is out of position; or chosen by the manager although a rule would leave him out, with the
    /// rule's phrase. With `projected`, a fitness figure in that rule is called projected.
    public static func describe(_ warning: PickWarning, parameters: EngineParameters, projected: Bool = false) -> String {
        switch warning {
        case .outOfPosition(let phase, let familiarity):
            "Out of position \(phase == .inPossession ? "in possession" : "out of possession"): familiarity \(familiarity), "
                + "below \(parameters.outOfPositionBelow.value)."
        case .overridesRule(let exclusion):
            "Chosen by you over a rule: \(describe(exclusion, parameters: parameters, projected: projected))."
        }
    }

    public static func describe(_ error: DecodingError) -> String {
        func path(_ codingPath: [CodingKey], adding key: CodingKey? = nil) -> String {
            let parts = (codingPath + (key.map { [$0] } ?? [])).map(\.stringValue)
            return parts.isEmpty ? "the top level" : "'" + parts.joined(separator: ".") + "'"
        }
        switch error {
        case .keyNotFound(let key, let context): return "missing the field \(path(context.codingPath, adding: key))"
        case .valueNotFound(_, let context): return "the field \(path(context.codingPath)) has no value"
        case .typeMismatch(_, let context): return "the field \(path(context.codingPath)) has the wrong kind of value: \(context.debugDescription)"
        case .dataCorrupted(let context): return "the data at \(path(context.codingPath)) is not valid: \(context.debugDescription)"
        @unknown default: return "the file could not be decoded: \(error.localizedDescription)"
        }
    }

    /// "The first team's wages are in $ and the U21s' are in £.": every squad given, first team first.
    private static func currenciesSentence(_ symbols: [Squad: String]) -> String {
        let held = Squad.allCases.compactMap { squad in symbols[squad].map { (squad: squad, symbol: $0) } }
        var parts = held.map { "\(AdvisorText.possessive($0.squad)) are in \($0.symbol)" }
        // The first part starts the sentence and says what is in each currency.
        if let first = held.first {
            let owner = AdvisorText.possessive(first.squad)
            parts[0] = owner.prefix(1).uppercased() + owner.dropFirst() + " wages are in \(first.symbol)"
        }
        guard let last = parts.popLast() else { return "" }
        return (parts.isEmpty ? last : parts.joined(separator: ", ") + " and " + last) + "."
    }

    private static func phaseName(_ phase: Phase) -> String { phase == .inPossession ? "in-possession" : "out-of-possession" }

    /// The slot in words with a capital first letter, to start a sentence: "Left back".
    private static func capitalised(_ slot: SlotID) -> String {
        let words = PositionText.plain(slot)
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
