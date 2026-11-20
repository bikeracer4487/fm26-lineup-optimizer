import Foundation

/// The words about the league table: where the club stands, what a league match is worth because of it, and the
/// notes on the table's own limits. Every figure comes from the reading; nothing is worked out here but plurals.
extension AdvisorText {
    public static func name(_ kind: LeagueLineKind) -> String {
        switch kind {
        case .promotion: "promoted"
        case .bye: "bye"
        case .playOff: "play-offs"
        case .relegation: "relegated"
        }
    }

    /// "2nd and 3rd get a bye."; nil when no play-off place gets one.
    public static func byeLine(_ format: LeagueFormat) -> String? {
        guard format.byes > 0 else { return nil }
        let places = (1...format.byes).map { ordinal(format.promoted + $0) }
        if places.count == 1 { return "\(places[0]) gets a bye." }
        return places.dropLast().joined(separator: ", ") + " and " + places[places.count - 1] + " get a bye."
    }

    /// The reading in the order place, each line from promotion to relegation, the situation, the sides within the margin.
    public static func standingLines(_ reading: LeagueReading) -> [String] {
        if reading.seasonIsOver {
            return ["You are \(ordinal(reading.place)) on \(points(reading.points)).",
                    "The season in this table is over. Paste the new season's table when it starts."]
        }
        var out = ["You are \(ordinal(reading.place)) on \(points(reading.points)) with \(matches(reading.matchesLeft)) left."]
        out += reading.lines.map { lineSentence($0, mostReachable: reading.mostReachable) }
        if let situation = reading.situation { out.append(situationLine(situation, reading)) }
        if !reading.rivals.isEmpty {
            out.append("Within \(points(reading.margin)) of you: \(list(reading.rivals.map(\.name))).")
        }
        return out
    }

    /// The first reason of a suggestion when the table sets a league match's base, without the ": 100" that follows.
    public static func leagueBaseReason(_ reading: LeagueReading) -> String {
        guard let situation = reading.situation else { return "League match" }
        switch situation {
        case .midTable:
            guard let held = farLineHeld(reading) else { return "League match, nothing within reach" }
            return "League match, " + decidedText(held, reading, withMatchesWhenClose: false)
        case .nothingToPlayFor: return "League match, nothing left to settle"
        case .titleRaceOrRelegationFight, .inContention:
            guard let decided = reading.decidedBy else { return "League match" }
            return "League match, " + decidedText(decided, reading, withMatchesWhenClose: false)
        }
    }

    /// "Buxton are level on points with you (×1.2)".
    public static func battlingReason(_ rival: LeagueRival, factor: Double) -> String {
        let place: String
        if rival.pointsAhead == 0 {
            place = "level on points with you"
        } else if rival.pointsAhead > 0 {
            place = "\(points(rival.pointsAhead)) ahead of you"
        } else {
            place = "\(points(-rival.pointsAhead)) behind you"
        }
        return "\(rival.name) are \(place) (\u{00D7}\(String(format: "%.1f", factor)))"
    }

    /// "Table pasted on Sat 18 Apr."
    public static func tablePastedLine(on day: Day) -> String {
        let weekdays = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let sinceEpoch = Day(iso: "1970-01-01")!.days(to: day)
        let weekday = weekdays[((sinceEpoch % 7) + 7) % 7]
        let parts = day.iso.split(separator: "-").compactMap { Int($0) }
        return "Table pasted on \(weekday) \(parts[2]) \(months[parts[1] - 1])."
    }

    public static let tableOutOfDate = "A league match has been played since; paste the table again."

    public static func tableStopsLine(matchesLeft: Int, beyond: Int) -> String {
        let used = matchesLeft == 1 ? "your next league fixture" : "your next \(matchesLeft) league fixtures"
        let rest = beyond == 1 ? "the 1 after it is read without it" : "the \(beyond) after them are read without it"
        return "The table has \(matches(matchesLeft)) left, so it is used for \(used); \(rest)."
    }

    public static func handChoiceLine(byHand: LeagueSituation, table: LeagueSituation) -> String {
        "You have set league matches to \(name(byHand)); the table reads \(name(table)). Your choice is used."
    }

    /// Said under the three numbers while the saved format is in use and the fields show something else (a blank field,
    /// or numbers that were refused), in the words `LeagueFormatError.tooMany`'s sentence uses.
    public static func formatInUseLine(_ format: LeagueFormat) -> String {
        "The table is still read with \(format.promoted) promoted, \(format.playOffs) in the play-offs and "
            + "\(format.relegated) relegated."
    }

    /// The key to the mark beside a side within the margin: "Within 6 points of you" (3 with one match left).
    public static func withinMarginKey(_ reading: LeagueReading) -> String {
        "Within \(points(reading.margin)) of you"
    }

    public static func notInTheTable(_ opponent: String) -> String { "\(opponent) is not in the league table." }

    public static let orderWorkedOutLine = "The paste had no Position column, so the order of the table was worked out from "
        + "points, goal difference, goals scored and name, not taken from the game."

    public static let noFormatLine = "Enter how many teams are promoted, in the play-offs and relegated, to read where you stand."

    public static let noTableLines = [
        "No league table has been pasted.",
        "Copy the league's standings in FMRTE, then paste them here to read where you stand.",
    ]

    /// The menu's first entry: "From the table (In contention)", or just "From the table" with no situation.
    public static func fromTheTable(_ situation: LeagueSituation?) -> String {
        situation.map { "From the table (\(name($0)))" } ?? "From the table"
    }

    /// What the reading rests on. The margin is the owner's rule; which lines are within reach and the factor for a side
    /// within the margin are the tool's estimate (as `LeagueStandingRules`' own source in `EngineParameters` says).
    public static func leagueEvidenceNote(_ reading: LeagueReading, rules: LeagueStandingRules) -> String {
        switch reading.basis {
        case .derived:
            return "The places and points are the table's own. The margin of \(points(rules.marginPoints)) is your rule "
                + "(\(rules.marginPointsLastMatch) with one match left). Which lines are within reach or far, and the "
                + "\u{00D7}\(String(format: "%.1f", rules.battlingFactor)) for a side within the margin, are this tool's "
                + "estimate, with no test behind them."
        case .carriedOverFM26: return "The lines and the margin use FM26-era numbers."
        case .fm27Measured, .fm27Official, .fm27Observation:
            return "The lines and the margin rest on FM27 evidence."
        }
    }

    // MARK: private

    private static func ordinal(_ n: Int) -> String {
        let suffix: String
        if (11...13).contains(n % 100) {
            suffix = "th"
        } else {
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    /// "1 point", "6 points", "−10 points" (a true minus, U+2212).
    private static func points(_ n: Int) -> String { n == 1 ? "1 point" : "\(signedNumber(n)) points" }
    private static func matches(_ n: Int) -> String { n == 1 ? "1 match" : "\(n) matches" }

    private static func list(_ names: [String]) -> String {
        names.count <= 1 ? (names.first ?? "") : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }

    /// What the club has above the line ("your play-off place") and what it is short of below it ("a play-off place").
    private static func held(_ kind: LeagueLineKind) -> String {
        switch kind {
        case .promotion: "your promotion place"
        case .bye: "your bye"
        case .playOff: "your play-off place"
        case .relegation: "the drop"
        }
    }

    private static func wanted(_ kind: LeagueLineKind) -> String {
        switch kind {
        case .promotion: "automatic promotion"
        case .bye: "a bye"
        case .playOff: "a play-off place"
        case .relegation: "safety"
        }
    }

    private static func capitalised(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    private static func lineSentence(_ reading: LineReading, mostReachable: Int) -> String {
        let kind = reading.line.kind
        let other = reading.other?.name ?? ""
        let place = ordinal(reading.otherPlace ?? 0)
        let gap = reading.gap ?? 0
        if reading.isAbove {
            switch reading.state {
            case .safe, .outOfReach:
                switch kind {
                case .promotion: return "Promotion is certain."
                case .bye: return "Your bye is safe."
                case .playOff: return "Your play-off place is safe."
                case .relegation: return "You cannot be relegated."
                }
            case .close:
                let behind = gap == 0 ? "are level on points with you" : "are \(points(gap)) behind you"
                let lead = kind == .relegation ? "You can still be relegated" : "\(capitalised(held(kind))) is not safe"
                return "\(lead): \(other), in \(place), \(behind)."
            case .withinReach, .far:
                if kind == .relegation {
                    return "\(other), in \(place), are \(points(gap)) behind you, across the relegation line."
                }
                return "\(other), in \(place), are \(points(gap)) behind \(held(kind))."
            }
        }
        let missing = kind == .bye ? "A bye in the play-offs" : capitalised(wanted(kind))
        switch reading.state {
        case .outOfReach:
            return "\(missing) is out of reach: \(other) have \(points(reading.other?.points ?? 0)) and the most you can "
                + "reach is \(signedNumber(mostReachable))."
        case .safe, .close, .withinReach, .far:
            let away = gap == 0 ? "level on points" : "\(points(gap)) away"
            return "\(missing) is \(away): \(other), in \(place), have \(signedNumber(reading.other?.points ?? 0))."
        }
    }

    /// The line that decided a situation, as part of a sentence: "your play-off place is within 6 points", with the
    /// matches left when `withMatchesWhenClose`, and always for a line within reach.
    private static func decidedText(_ decided: LineReading, _ reading: LeagueReading, withMatchesWhenClose: Bool) -> String {
        let what = decided.isAbove ? held(decided.line.kind) : wanted(decided.line.kind)
        let left = matches(reading.matchesLeft)
        switch decided.state {
        case .close:
            return "\(what) is within \(points(reading.margin))" + (withMatchesWhenClose ? " with \(left) left" : "")
        case .withinReach, .far, .safe, .outOfReach:
            let gap = points(decided.gap ?? 0)
            return "\(what) is \(gap) \(decided.isAbove ? "clear" : "away") with \(left) left"
        }
    }

    /// The highest line a club in mid-table is far above (promotion first, relegation last), so the words say what he
    /// holds rather than that nothing is within reach; nil when he is far above none.
    private static func farLineHeld(_ reading: LeagueReading) -> LineReading? {
        reading.lines.first { $0.isAbove && $0.state == .far }
    }

    private static func situationLine(_ situation: LeagueSituation, _ reading: LeagueReading) -> String {
        let head = "League matches read as \(name(situation))"
        switch situation {
        case .nothingToPlayFor: return "\(head): nothing can change for you."
        case .midTable:
            guard let held = farLineHeld(reading) else { return "\(head): nothing is within reach (this tool's estimate)." }
            return "\(head): \(decidedText(held, reading, withMatchesWhenClose: true)), and nothing else is within reach "
                + "(this tool's estimate)."
        case .titleRaceOrRelegationFight, .inContention:
            guard let decided = reading.decidedBy else { return "\(head) (this tool's estimate)." }
            return "\(head): \(decidedText(decided, reading, withMatchesWhenClose: true)) (this tool's estimate)."
        }
    }
}
