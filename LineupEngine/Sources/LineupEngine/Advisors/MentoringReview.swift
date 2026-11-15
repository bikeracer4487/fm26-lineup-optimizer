import Foundation

/// How a member's value in one attribute has moved since he joined his group, judged by worth.
public enum ValueChange: Equatable, Sendable { case noReading, improved, noChange, worse }

public struct AttributeChange: Equatable, Sendable {
    public let attribute: Attribute
    /// Nil with no reading, or when the reading lacks the attribute.
    public let start: Int?
    public let latest: Int?
    /// From the later of the day he joined and his starting reading's day, to his latest reading's day; 0 with
    /// `noReading`.
    public let weeks: Double
    /// `noReading` with fewer than two readings to compare, or either value missing.
    public let change: ValueChange
}

public struct MemberReview: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    /// Nil when he is no longer imported.
    public let age: Int?
    /// One for each counted attribute, in `Mentoring.counted` order, from his readings whether or not he is present.
    public let changes: [AttributeChange]
}

public enum GroupWarning: Equatable, Sendable {
    /// An arrow above None whose source is worth less than its target in this counted attribute.
    case harmfulArrow(from: PlayerID, to: PlayerID, strength: ArrowStrength, isRead: Bool,
                      attribute: Attribute, fromValue: Int, toValue: Int)
    /// Left, or moved to another squad.
    case notInSquad(PlayerID)
    case outOnLoan(PlayerID, club: String)
    case advisedToLeave(PlayerID)
}

public struct GroupReview: Identifiable, Equatable, Sendable {
    public var id: UUID { group.id }
    public let group: MentoringGroup
    /// The current members, by player key.
    public let members: [MemberReview]
    /// The arrows above None between present members: strongest first, then by the source's key, then by the target's.
    public let arrows: [GroupArrow]
    /// Of the arrows between present members, None included, how many are guesses.
    public let unreadArrows: Int
    /// The group's three current members are all present, and all six arrows between them were read as None.
    public let hasNoInfluence: Bool
    /// In the order of `GroupWarning`'s cases. `harmfulArrow` by the source's key, then the target's, then in
    /// `Mentoring.counted` order; the others by player key.
    public let warnings: [GroupWarning]
    /// A current member is worth less in a counted attribute at his latest reading than at his start.
    public let isDoingHarm: Bool
    /// No change in worth for `mentoringStoppedAfterWeeks`, up to the latest reading, among the watched members: the
    /// present members with an arrow above None into them, read or guessed. Never with nobody watched, and never when
    /// the group is doing harm or has no influence.
    public let hasStoppedWorking: Bool
    public let basis: Evidence
}

extension Mentoring {
    /// Reads one recorded group as the request's players, readings and arrows now stand. Only current members are read.
    ///
    /// A member is present when he is among the request's players in the group's squad and not out on loan. The arrows
    /// are worked out between present members only, from the readings of the group's squad between its players not
    /// out on loan, and the guess where a pair has none; the harm and the pulls are judged as for a suggestion. Never
    /// throws for a member who has left or lacks a value: he has arrows only while present, a member without a value
    /// for every counted attribute has no pulls and no harm judged, and his changes come from his readings. The name
    /// of a member no longer imported is taken from `names`, or failing that his key.
    static func review(_ group: MentoringGroup, request: MentoringRequest, parameters: EngineParameters) -> GroupReview {
        let counted = Mentoring.counted(parameters)
        let members = group.current
        let reviewed = members.map { member -> Reviewed in
            let imported = request.players.first { $0.id == member.player && $0.squad == group.squad }
                ?? request.players.first { $0.id == member.player }
            let status = imported.map { LoanStatus.of($0, ownClub: request.ownClub) }
            let isPresent: Bool
            var loanedTo: String?
            switch status {
            case .none: isPresent = false
            case .loanedOut(let club):
                isPresent = false
                loanedTo = club
            case .loanedIn, .own: isPresent = imported?.squad == group.squad
            }
            let values = Dictionary(uniqueKeysWithValues: counted.compactMap { attribute in
                imported?.attributes[attribute].map { (attribute, $0) }
            })
            return Reviewed(member: member, imported: imported, isPresent: isPresent, loanedTo: loanedTo,
                            values: isPresent && values.count == counted.count ? values : nil,
                            readings: (request.readings[member.player] ?? []).sorted { $0.day < $1.day })
        }

        // The squad's players not out on loan, as the suggestions take them: whose levels count towards taking
        // nothing, and between whom readings are used.
        var standings: [PlayerID: Standing] = [:]
        for player in request.players where player.squad == group.squad {
            if case .loanedOut = LoanStatus.of(player, ownClub: request.ownClub) { continue }
            standings[player.id] = request.dynamics[player.id]?.standing ?? .others
        }
        let readings = readingsUsed(request.arrows, in: group.squad, among: Set(standings.keys))

        // Every ordered pair of present members, by the source's key, then the target's.
        let present = reviewed.filter(\.isPresent)
        let parties = present.map {
            Party(id: $0.member.player, standing: standings[$0.member.player] ?? .others, age: $0.imported!.age)
        }
        var pairs: [(arrow: Arrow, from: Reviewed, to: Reviewed)] = []
        for (i, source) in present.enumerated() {
            for (j, target) in present.enumerated() where i != j {
                pairs.append((Mentoring.arrow(from: parties[i], to: parties[j], in: group.squad, readings: readings,
                                              standings: standings, parameters: parameters), source, target))
            }
        }
        let influencing = pairs.filter { $0.arrow.strength > .none }

        let arrows = influencing.sorted { a, b in
            if a.arrow.strength != b.arrow.strength { return a.arrow.strength > b.arrow.strength }
            return (a.arrow.from.key, a.arrow.to.key) < (b.arrow.from.key, b.arrow.to.key)
        }.map { pair in
            var pulls: [Pull] = []
            if let source = pair.from.values, let target = pair.to.values {
                pulls = Mentoring.pulls(from: source, to: target, counted: counted, parameters: parameters)
            }
            return GroupArrow(arrow: pair.arrow, fromName: pair.from.imported!.name, toName: pair.to.imported!.name,
                              pulls: pulls)
        }
        let hasNoInfluence = members.count == Mentoring.groupSize && present.count == members.count
            && pairs.allSatisfy { $0.arrow.isRead && $0.arrow.strength == .none }

        var warnings: [GroupWarning] = []
        for pair in influencing {
            guard let source = pair.from.values, let target = pair.to.values else { continue }
            for attribute in Mentoring.harms(pair.arrow.strength, from: source, to: target, counted: counted,
                                             parameters: parameters) {
                warnings.append(.harmfulArrow(from: pair.arrow.from, to: pair.arrow.to, strength: pair.arrow.strength,
                                              isRead: pair.arrow.isRead, attribute: attribute,
                                              fromValue: source[attribute]!, toValue: target[attribute]!))
            }
        }
        for person in reviewed where !person.isPresent && person.loanedTo == nil {
            warnings.append(.notInSquad(person.member.player))
        }
        for person in reviewed {
            if let club = person.loanedTo { warnings.append(.outOnLoan(person.member.player, club: club)) }
        }
        for person in reviewed where request.leaving.contains(person.member.player) {
            warnings.append(.advisedToLeave(person.member.player))
        }

        let memberReviews = reviewed.map { person in
            MemberReview(
                player: person.member.player,
                name: person.imported?.name ?? request.names[person.member.player] ?? person.member.player.key,
                age: person.imported?.age,
                changes: Self.changes(of: person, counted: counted, parameters: parameters))
        }
        let isDoingHarm = memberReviews.contains { $0.changes.contains { $0.change == .worse } }
        let targets = Set(influencing.map(\.arrow.to))
        let watched = reviewed.filter { targets.contains($0.member.player) }
        let hasStoppedWorking = !isDoingHarm && !hasNoInfluence && !watched.isEmpty && Self.hasStopped(
            group, members: members, watched: watched, counted: counted, parameters: parameters)

        return GroupReview(
            group: group, members: memberReviews, arrows: arrows, unreadArrows: pairs.filter { !$0.arrow.isRead }.count,
            hasNoInfluence: hasNoInfluence, warnings: warnings, isDoingHarm: isDoingHarm,
            hasStoppedWorking: hasStoppedWorking,
            basis: Evidence.weakest([parameters.mentoringWeights.evidence, parameters.mentoringCeilings.evidence,
                                     parameters.mentoringStrengthWeights.evidence, parameters.mentoringGuess.evidence,
                                     parameters.mentoringStoppedAfterWeeks.evidence])!)
    }

    /// A current member of a recorded group, with what the review reads.
    private struct Reviewed {
        let member: MentoringMember
        /// Among the request's players: in the group's squad if he is there, otherwise in any.
        let imported: Player?
        let isPresent: Bool
        /// The club he is out on loan to.
        let loanedTo: String?
        /// The counted attributes' values; nil when he is not present or lacks one.
        let values: [Attribute: Int]?
        /// By day.
        let readings: [PersonalityReading]
    }

    /// His starting reading is the last on or before the day he joined, or with none the first after; his latest is
    /// the last.
    private static func changes(of person: Reviewed, counted: [Attribute],
                                parameters: EngineParameters) -> [AttributeChange] {
        let readings = person.readings
        let joined = person.member.joinedOn
        let startIndex = readings.lastIndex { $0.day <= joined } ?? readings.indices.first
        let starting = startIndex.map { readings[$0] }, latest = readings.last
        let compared = startIndex.map { $0 != readings.count - 1 } ?? false
        let weeks: Double = if compared, let starting, let latest {
            Double(max(joined, starting.day).days(to: latest.day)) / 7
        } else { 0 }
        return counted.map { attribute in
            let start = starting?.values[attribute], end = latest?.values[attribute]
            var change = ValueChange.noReading
            if compared, let start, let end {
                let before = worth(attribute, start, parameters: parameters)
                let after = worth(attribute, end, parameters: parameters)
                change = after > before ? .improved : after < before ? .worse : .noChange
            }
            return AttributeChange(attribute: attribute, start: start, latest: end,
                                   weeks: change == .noReading ? 0 : weeks, change: change)
        }
    }

    /// The clock starts at the latest of the group's start, the latest day a member joined, and the last reading in
    /// which a watched member's worth in a counted attribute differed from his reading before; it is read against the
    /// latest reading of a watched member, not today's date.
    private static func hasStopped(_ group: MentoringGroup, members: [MentoringMember], watched: [Reviewed],
                                   counted: [Attribute], parameters: EngineParameters) -> Bool {
        guard let lastReading = watched.compactMap({ $0.readings.last?.day }).max() else { return false }
        var clock = ([group.startedOn] + members.map(\.joinedOn)).max()!
        for person in watched {
            for (before, after) in zip(person.readings, person.readings.dropFirst()) {
                let differs = counted.contains { attribute in
                    guard let a = before.values[attribute], let b = after.values[attribute] else { return false }
                    return worth(attribute, a, parameters: parameters) != worth(attribute, b, parameters: parameters)
                }
                if differs { clock = max(clock, after.day) }
            }
        }
        return clock.days(to: lastReading) >= parameters.mentoringStoppedAfterWeeks.value * 7
    }
}
