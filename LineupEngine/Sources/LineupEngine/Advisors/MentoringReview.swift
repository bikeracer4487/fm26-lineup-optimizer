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
    public let isLead: Bool
    /// Against the lead, in `Mentoring.counted` order, either direction; empty for the lead, with nobody leading, and
    /// for a member not present or without a value for every counted attribute.
    public let pulls: [Pull]
    /// One for each counted attribute, in `Mentoring.counted` order, from his readings whether or not he is present.
    public let changes: [AttributeChange]
}

public enum GroupWarning: Equatable, Sendable {
    /// No present member stands above every other.
    case nobodyLeads
    /// `above` stands above `below` and is worth less in this counted attribute.
    case mayBeDraggedDown(above: PlayerID, below: PlayerID, attribute: Attribute, aboveValue: Int, belowValue: Int)
    /// Known to be in a different social group from the lead's, or either is in `.others`.
    case differentSocialGroup(PlayerID)
    /// Left, or moved to another squad.
    case notInSquad(PlayerID)
    case outOnLoan(PlayerID, club: String)
    case advisedToLeave(PlayerID)
}

public struct GroupReview: Identifiable, Equatable, Sendable {
    public var id: UUID { group.id }
    public let group: MentoringGroup
    public let lead: PlayerID?
    /// The current members: the lead first, then by player key.
    public let members: [MemberReview]
    /// In the order of `GroupWarning`'s cases; within a case by player key (for `mayBeDraggedDown`, by the key of the
    /// one above, then of the one below, then in `Mentoring.counted` order).
    public let warnings: [GroupWarning]
    /// A member, the lead included, is worth less in a counted attribute at his latest reading than at his start.
    public let isDoingHarm: Bool
    /// No change in worth among the members other than the lead for `mentoringStoppedAfterWeeks`, up to the latest
    /// reading; never when the group is doing harm.
    public let hasStoppedWorking: Bool
    public let basis: Evidence
}

extension Mentoring {
    /// Reads one recorded group as the request's players and readings now stand. Only current members are read.
    ///
    /// A member is present when he is among the request's players in the group's squad and not out on loan. The lead,
    /// the pulls, the dragged-down warning and the social-group caution are worked out among present members only.
    /// Never throws for a member who has left or lacks a value: he has no pulls, and his changes come from his readings.
    /// The name of a member no longer imported is taken from `names`, or failing that his key.
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
                            standing: request.dynamics[member.player]?.standing ?? .others,
                            socialGroup: request.dynamics[member.player]?.socialGroup,
                            values: isPresent && values.count == counted.count ? values : nil,
                            readings: (request.readings[member.player] ?? []).sorted { $0.day < $1.day })
        }

        let present = reviewed.filter(\.isPresent)
        func standsAbove(_ a: Reviewed, _ b: Reviewed) -> Bool {
            guard let ageA = a.imported?.age, let ageB = b.imported?.age else { return false }
            return Mentoring.standsAbove((a.standing, ageA), (b.standing, ageB), parameters: parameters)
        }
        let lead = present.first { candidate in
            present.allSatisfy { $0.member.player == candidate.member.player || standsAbove(candidate, $0) }
        }
        func worth(_ attribute: Attribute, _ value: Int) -> Int {
            Mentoring.worth(attribute, value, parameters: parameters)
        }

        var memberReviews: [MemberReview] = []
        var changesByPlayer: [PlayerID: [AttributeChange]] = [:]
        for person in reviewed {
            let isLead = person.member.player == lead?.member.player
            var pulls: [Pull] = []
            if !isLead, let mine = person.values, let theirs = lead?.values {
                pulls = counted.filter { worth($0, mine[$0]!) != worth($0, theirs[$0]!) }.map {
                    Pull(attribute: $0, value: mine[$0]!, towards: theirs[$0]!)
                }
            }
            let changes = Self.changes(of: person, counted: counted, parameters: parameters)
            changesByPlayer[person.member.player] = changes
            let review = MemberReview(
                player: person.member.player,
                name: person.imported?.name ?? request.names[person.member.player] ?? person.member.player.key,
                age: person.imported?.age, isLead: isLead, pulls: pulls, changes: changes)
            if isLead { memberReviews.insert(review, at: 0) } else { memberReviews.append(review) }
        }

        var warnings: [GroupWarning] = []
        if lead == nil { warnings.append(.nobodyLeads) }
        for above in present {
            for below in present where above.member.player != below.member.player && standsAbove(above, below) {
                guard let high = above.values, let low = below.values else { continue }
                for attribute in counted where worth(attribute, high[attribute]!) < worth(attribute, low[attribute]!) {
                    warnings.append(.mayBeDraggedDown(above: above.member.player, below: below.member.player,
                                                      attribute: attribute, aboveValue: high[attribute]!,
                                                      belowValue: low[attribute]!))
                }
            }
        }
        if let lead {
            for person in present where person.member.player != lead.member.player
                && Mentoring.sameSocialGroup(lead.socialGroup, person.socialGroup) == false {
                warnings.append(.differentSocialGroup(person.member.player))
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

        let isDoingHarm = changesByPlayer.values.contains { $0.contains { $0.change == .worse } }
        let watched = reviewed.filter { $0.member.player != lead?.member.player }
        let hasStoppedWorking = !isDoingHarm && Self.hasStopped(
            group, members: members, watched: watched, counted: counted, parameters: parameters)

        return GroupReview(
            group: group, lead: lead?.member.player, members: memberReviews, warnings: warnings,
            isDoingHarm: isDoingHarm, hasStoppedWorking: hasStoppedWorking,
            basis: Evidence.weakest([parameters.mentoringWeights.evidence, parameters.mentoringCeilings.evidence,
                                     parameters.mentoringSeniorityYears.evidence,
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
        let standing: Standing
        let socialGroup: SocialGroup?
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
