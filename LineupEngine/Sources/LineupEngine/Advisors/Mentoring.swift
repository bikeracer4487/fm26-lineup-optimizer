import Foundation

/// Everything the mentoring advice needs for one squad.
public struct MentoringRequest: Sendable {
    public var squad: Squad
    /// Every imported player; the squad's are picked out.
    public var players: [Player]
    public var ownClub: String?
    /// A player with no entry is `.others` with no social group.
    public var dynamics: [PlayerID: PlayerDynamics]
    /// When the owner last entered standings and social groups for this squad; nil if never.
    public var dynamicsUpdatedOn: Day?
    /// Every recorded group, of any squad.
    public var groups: [MentoringGroup]
    public var readings: [PlayerID: [PersonalityReading]]
    /// Names for members no longer imported.
    public var names: [PlayerID: String]
    /// Player Removal's `advisedToLeave`, or empty when that advice has not been worked out.
    public var leaving: Set<PlayerID>
    /// The game's current date.
    public var asOf: Day

    public init(squad: Squad, players: [Player], ownClub: String?, dynamics: [PlayerID: PlayerDynamics],
                dynamicsUpdatedOn: Day?, groups: [MentoringGroup], readings: [PlayerID: [PersonalityReading]],
                names: [PlayerID: String], leaving: Set<PlayerID>, asOf: Day) {
        self.squad = squad
        self.players = players
        self.ownClub = ownClub
        self.dynamics = dynamics
        self.dynamicsUpdatedOn = dynamicsUpdatedOn
        self.groups = groups
        self.readings = readings
        self.names = names
        self.leaving = leaving
        self.asOf = asOf
    }
}

/// One counted attribute in which a member's worth differs from the lead's: the member's value and the lead's, which he
/// is pulled towards. In a suggested group a pull only ever goes upward, because no member is worth more than the lead
/// in a counted attribute; in a recorded group it may go either way.
public struct Pull: Equatable, Sendable {
    public let attribute: Attribute
    public let value: Int
    public let towards: Int

    public init(attribute: Attribute, value: Int, towards: Int) {
        self.attribute = attribute
        self.value = value
        self.towards = towards
    }
}

/// Why a suggested group may not last: it ends when the lead goes.
public enum LeadCaution: Equatable, Sendable { case onLoanHere, advisedToLeave }

public struct SuggestedMember: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let age: Int
    /// The third player who makes up a group of a lead and one mentee.
    public let isMakingUp: Bool
    /// In `Mentoring.counted` order; empty for one making up with nothing to gain.
    public let pulls: [Pull]
    /// Known to be in a different social group from the lead's, or either is in `.others`.
    public let inDifferentSocialGroup: Bool
}

public struct SuggestedGroup: Equatable, Sendable {
    public let lead: PlayerID
    public let leadName: String
    public let leadAge: Int
    public let leadStanding: Standing
    /// Two: the mentees first, most to gain first, then any player making up the group.
    public let members: [SuggestedMember]
    /// On loan here first, then advised to leave.
    public let cautions: [LeadCaution]
    public let basis: Evidence
}

/// Why a young player has no suggested group: the first of these that applies.
public enum NotPlacedReason: Equatable, Sendable {
    /// Nobody in the squad stands above him.
    case nobodyAbove
    /// Nobody who stands above him is better where it counts.
    case nobodyBetter
    /// Those better where it counts would pull him down in this attribute: the first counted one in which the one he
    /// would gain most from is worth less.
    case wouldHarm(Attribute)
    /// Every lead who suits him is in a suggested group with others who gain more, or in a recorded group.
    case leadsTaken
    /// No third player could be found to make up a group with him and his lead.
    case noThird
}

public struct NotPlaced: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let age: Int
    public let reason: NotPlacedReason
}

/// Mentoring advice for one squad.
public struct MentoringReport: Equatable, Sendable {
    public let squad: Squad
    /// No player of the squad who is not out on loan has a standing above `.others`: who stands above whom then rests
    /// on age alone.
    public let byAgeAlone: Bool
    /// The standings were entered more than `mentoringDynamicsStaleAfterDays` before `asOf`; false if never entered.
    public let isStale: Bool
    /// In the order they were formed.
    public let suggestions: [SuggestedGroup]
    /// By player key.
    public let notPlaced: [NotPlaced]
    /// The squad's live recorded groups: oldest first, then by id.
    public let groups: [GroupReview]
    public let basis: Evidence
}

extension Mentoring {
    /// Suggests groups of three for the squad's young players and says why any of them has none. Throws
    /// `PlanError.badParameters` for `problems(in:)`, before anything else, and `RatingError.missingAttribute` for the
    /// first player of the squad, by key, not out on loan, with no value for a counted attribute (in `counted` order).
    ///
    /// The groups are found greedily: of every valid group among the players not yet used, the one with the greatest
    /// gain is formed, then the same again among the players left, until none is valid. Ties go to a group of a lead and
    /// two mentees before one made up with a third player, then to the lowest lead key, then to the lowest member keys.
    /// This gives the pair with most to gain first call on a lead; it does not prove that no other set of groups has a
    /// greater total. Injury, bans and fitness are not looked at.
    public static func report(_ request: MentoringRequest, parameters: EngineParameters) throws -> MentoringReport {
        let problems = problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let judge = Judge(parameters: parameters)

        // Sorting by key makes every list, every tie and the first error independent of input order; an index into
        // `present` is then in key order too.
        let recorded = Set(request.groups.filter(\.isLive).flatMap(\.current).map(\.player))
        var present: [Person] = []
        for player in request.players.filter({ $0.squad == request.squad }).sorted(by: { $0.id.key < $1.id.key }) {
            let status = LoanStatus.of(player, ownClub: request.ownClub)
            let isLoanedIn: Bool
            switch status {
            case .loanedOut: continue
            case .loanedIn: isLoanedIn = true
            case .own: isLoanedIn = false
            }
            var values: [Attribute: Int] = [:]
            for attribute in judge.counted {
                guard let value = player.attributes[attribute] else {
                    throw RatingError.missingAttribute(player: player.name, attribute: attribute)
                }
                values[attribute] = value
            }
            let dynamics = request.dynamics[player.id] ?? PlayerDynamics()
            present.append(Person(
                player: player, standing: dynamics.standing, socialGroup: dynamics.socialGroup,
                isOwn: !isLoanedIn, isLeaving: request.leaving.contains(player.id),
                inRecordedGroup: recorded.contains(player.id), values: values,
                worth: Dictionary(uniqueKeysWithValues: values.map { attribute, value in
                    (attribute, Mentoring.worth(attribute, value, parameters: parameters))
                })))
        }

        let pool = present.indices.filter { !present[$0].inRecordedGroup }
        let candidates = pool.filter { judge.isCandidate(present[$0]) }

        var used: Set<Int> = []
        var formed: [Option] = []
        while let best = judge.bestOption(present, pool: pool, candidates: candidates, used: used) {
            formed.append(best)
            used.formUnion([best.lead] + best.memberIndices)
        }

        let suggestions = formed.map { judge.suggestion($0, present) }
        let notPlaced = candidates.filter { !used.contains($0) }.map { index in
            let person = present[index]
            return NotPlaced(player: person.player.id, name: person.player.name, age: person.player.age,
                             reason: judge.reason(for: index, present, used: used))
        }

        let groups = request.groups.filter { $0.isLive && $0.squad == request.squad }.sorted {
            $0.startedOn != $1.startedOn ? $0.startedOn < $1.startedOn : $0.id.uuidString < $1.id.uuidString
        }.map { review($0, request: request, parameters: parameters) }

        let isStale = request.dynamicsUpdatedOn.map {
            $0.days(to: request.asOf) > parameters.mentoringDynamicsStaleAfterDays.value
        } ?? false
        return MentoringReport(
            squad: request.squad,
            byAgeAlone: !present.contains { $0.standing > .others },
            isStale: isStale, suggestions: suggestions, notPlaced: notPlaced, groups: groups,
            basis: Evidence.weakest(judge.evidence + [parameters.mentoringDynamicsStaleAfterDays.evidence])!)
    }

    // MARK: Working

    /// A player of the squad who is not out on loan, with what the rules read.
    private struct Person {
        let player: Player
        let standing: Standing
        let socialGroup: SocialGroup?
        /// Belongs to the club: not on loan here.
        let isOwn: Bool
        let isLeaving: Bool
        /// A current member of a live recorded group, of any squad.
        let inRecordedGroup: Bool
        /// The counted attributes' values.
        let values: [Attribute: Int]
        /// The counted attributes' worth.
        let worth: [Attribute: Int]
    }

    /// One valid group: a lead, one or two mentees, and the third player when there is one mentee.
    private struct Option {
        let lead: Int
        /// Most to gain first, then by key.
        let mentees: [Int]
        let third: Int?
        let gain: Double

        var isFull: Bool { third == nil }
        /// The two members' indices, ascending.
        var memberIndices: [Int] { (mentees + (third.map { [$0] } ?? [])).sorted() }

        /// Greater gain first; then a full group; then the lowest lead key; then the lowest member keys.
        func isBetter(than other: Option) -> Bool {
            if gain != other.gain { return gain > other.gain }
            if isFull != other.isFull { return isFull }
            if lead != other.lead { return lead < other.lead }
            return memberIndices.lexicographicallyPrecedes(other.memberIndices)
        }
    }

    /// The rules, with the parameters they read.
    private struct Judge {
        let parameters: EngineParameters
        let counted: [Attribute]
        /// The evidence of every parameter a suggestion rests on.
        let evidence: [Evidence]

        init(parameters: EngineParameters) {
            self.parameters = parameters
            counted = Mentoring.counted(parameters)
            evidence = [parameters.mentoringWeights.evidence, parameters.mentoringCeilings.evidence,
                        parameters.mentoringMenteeMaxAge.evidence, parameters.mentoringSeniorityYears.evidence,
                        parameters.mentoringOtherSocialGroupShare.evidence]
        }

        /// Belongs to the club, young enough, not advised to leave, and below the ceiling in a counted attribute.
        /// The caller has left out players in recorded groups.
        func isCandidate(_ person: Person) -> Bool {
            let ceilings = parameters.mentoringCeilings.value
            return person.isOwn && !person.isLeaving && person.player.age <= parameters.mentoringMenteeMaxAge.value
                && counted.contains { attribute in
                    // `problems(in:)` has made sure every counted attribute has a ceiling.
                    person.values[attribute]! < ceilings[attribute]!
                }
        }

        func standsAbove(_ a: Person, _ b: Person) -> Bool {
            Mentoring.standsAbove((a.standing, a.player.age), (b.standing, b.player.age), parameters: parameters)
        }

        /// The first counted attribute in which `above` is worth less than `below`; nil when he is worth no less in any.
        func harm(from above: Person, to below: Person) -> Attribute? {
            counted.first { above.worth[$0]! < below.worth[$0]! }
        }

        /// Rule 1 between two members: whichever stands above the other is worth no less in any counted attribute.
        func noHarmBetween(_ a: Person, _ b: Person) -> Bool {
            if standsAbove(a, b) { return harm(from: a, to: b) == nil }
            if standsAbove(b, a) { return harm(from: b, to: a) == nil }
            return true
        }

        func inDifferentSocialGroup(_ lead: Person, _ member: Person) -> Bool {
            Mentoring.sameSocialGroup(lead.socialGroup, member.socialGroup) == false
        }

        /// The sum over the counted attributes of the lead's worth less the mentee's, kept at
        /// `mentoringOtherSocialGroupShare` when they are known to be in different social groups.
        func gain(from lead: Person, to mentee: Person) -> Double {
            let total = Double(counted.reduce(0) { $0 + lead.worth[$1]! - mentee.worth[$1]! })
            return inDifferentSocialGroup(lead, mentee) ? total * parameters.mentoringOtherSocialGroupShare.value : total
        }

        /// Stands above him, gives him a gain above 0, and is worth no less in any counted attribute. Whether the lead
        /// is free to lead is the caller's question.
        func suits(_ lead: Person, _ mentee: Person) -> Bool {
            standsAbove(lead, mentee) && gain(from: lead, to: mentee) > 0 && harm(from: lead, to: mentee) == nil
        }

        /// The best valid group among the pool players not yet used; nil when there is none.
        func bestOption(_ present: [Person], pool: [Int], candidates: [Int], used: Set<Int>) -> Option? {
            var best: Option?
            func consider(_ option: Option) {
                if best.map({ option.isBetter(than: $0) }) ?? true { best = option }
            }
            for lead in pool where !used.contains(lead) {
                let suited = candidates.filter { $0 != lead && !used.contains($0) && suits(present[lead], present[$0]) }
                let gains = Dictionary(uniqueKeysWithValues: suited.map { ($0, gain(from: present[lead], to: present[$0])) })
                for (i, first) in suited.enumerated() {
                    for second in suited[(i + 1)...] where noHarmBetween(present[first], present[second]) {
                        let pair = [first, second].sorted { gains[$0]! != gains[$1]! ? gains[$0]! > gains[$1]! : $0 < $1 }
                        consider(Option(lead: lead, mentees: pair, third: nil, gain: gains[first]! + gains[second]!))
                    }
                    if let third = third(present, lead: lead, mentee: first, pool: pool, suited: suited, used: used) {
                        consider(Option(lead: lead, mentees: [first], third: third, gain: gains[first]!))
                    }
                }
            }
            return best
        }

        /// The youngest, then lowest-key, pool player not yet used who belongs to the club, is not advised to leave, is
        /// not a candidate the lead suits, is one the lead stands above, and meets rule 1 with both.
        private func third(_ present: [Person], lead: Int, mentee: Int, pool: [Int], suited: [Int],
                           used: Set<Int>) -> Int? {
            let leader = present[lead], mentored = present[mentee]
            return pool.filter { index in
                let person = present[index]
                return index != lead && index != mentee && !used.contains(index) && !suited.contains(index)
                    && person.isOwn && !person.isLeaving && standsAbove(leader, person)
                    && noHarmBetween(leader, person) && noHarmBetween(mentored, person)
            }.min { a, b in
                present[a].player.age != present[b].player.age ? present[a].player.age < present[b].player.age : a < b
            }
        }

        func suggestion(_ option: Option, _ present: [Person]) -> SuggestedGroup {
            let lead = present[option.lead]
            func member(_ index: Int, isMakingUp: Bool) -> SuggestedMember {
                let person = present[index]
                return SuggestedMember(
                    player: person.player.id, name: person.player.name, age: person.player.age, isMakingUp: isMakingUp,
                    pulls: counted.filter { person.worth[$0]! != lead.worth[$0]! }.map {
                        Pull(attribute: $0, value: person.values[$0]!, towards: lead.values[$0]!)
                    },
                    inDifferentSocialGroup: inDifferentSocialGroup(lead, person))
            }
            var cautions: [LeadCaution] = []
            if !lead.isOwn { cautions.append(.onLoanHere) }
            if lead.isLeaving { cautions.append(.advisedToLeave) }
            return SuggestedGroup(
                lead: lead.player.id, leadName: lead.player.name, leadAge: lead.player.age, leadStanding: lead.standing,
                members: option.mentees.map { member($0, isMakingUp: false) }
                    + (option.third.map { [member($0, isMakingUp: true)] } ?? []),
                cautions: cautions, basis: Evidence.weakest(evidence)!)
        }

        /// The first reason that applies, judged against every squad player not out on loan, members of recorded
        /// groups included. It never changes which groups are formed.
        func reason(for index: Int, _ present: [Person], used: Set<Int>) -> NotPlacedReason {
            let mentee = present[index]
            let above = present.indices.filter { $0 != index && standsAbove(present[$0], mentee) }
            if above.isEmpty { return .nobodyAbove }
            let better = above.filter { gain(from: present[$0], to: mentee) > 0 }
            if better.isEmpty { return .nobodyBetter }
            let suiting = better.filter { harm(from: present[$0], to: mentee) == nil }
            if suiting.isEmpty {
                // Greatest gain first, then lowest key; every one of them does harm somewhere.
                let most = better.min { a, b in
                    let ga = gain(from: present[a], to: mentee), gb = gain(from: present[b], to: mentee)
                    return ga != gb ? ga > gb : a < b
                }!
                return .wouldHarm(harm(from: present[most], to: mentee)!)
            }
            if suiting.allSatisfy({ used.contains($0) || present[$0].inRecordedGroup }) { return .leadsTaken }
            return .noThird
        }
    }
}
