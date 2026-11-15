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
    /// Every arrow the owner has read, of any squad. Only this squad's, between two of its players not out on loan,
    /// are used.
    public var arrows: [ArrowReading]
    /// Names for members no longer imported.
    public var names: [PlayerID: String]
    /// Player Removal's `advisedToLeave`, or empty when that advice has not been worked out.
    public var leaving: Set<PlayerID>
    /// The game's current date.
    public var asOf: Day

    public init(squad: Squad, players: [Player], ownClub: String?, dynamics: [PlayerID: PlayerDynamics],
                dynamicsUpdatedOn: Day?, groups: [MentoringGroup], readings: [PlayerID: [PersonalityReading]],
                arrows: [ArrowReading], names: [PlayerID: String], leaving: Set<PlayerID>, asOf: Day) {
        self.squad = squad
        self.players = players
        self.ownClub = ownClub
        self.dynamics = dynamics
        self.dynamicsUpdatedOn = dynamicsUpdatedOn
        self.groups = groups
        self.readings = readings
        self.arrows = arrows
        self.names = names
        self.leaving = leaving
        self.asOf = asOf
    }
}

/// One counted attribute in which a player's worth differs from another's: his value and the other's, which he is
/// pulled towards. On a suggested group's arrow a pull only ever goes upward, because no arrow there is harmful; in a
/// recorded group it may go either way.
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


/// An arrow of a group, with what its target would gain.
public struct GroupArrow: Equatable, Sendable {
    public let arrow: Arrow
    public let fromName: String
    public let toName: String
    /// The counted attributes in which the target is worth less than the source, in `Mentoring.counted` order; empty:
    /// nothing to gain.
    public let pulls: [Pull]
}

/// Why a suggested group may not last: a member whose arrow it rests on will go.
public enum MemberCaution: Equatable, Sendable {
    case onLoanHere(PlayerID)
    case advisedToLeave(PlayerID)
}

public struct SuggestedMember: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let age: Int
}

public struct SuggestedGroup: Identifiable, Equatable, Sendable {
    public var id: String { members.map(\.player.key).joined(separator: "|") }
    /// Three, by key.
    public let members: [SuggestedMember]
    /// Those above None: greatest gain first, then by the source's key, then by the target's.
    public let arrows: [GroupArrow]
    /// Every arrow the group rests on was read; false when any of them is a guess.
    public let isRead: Bool
    /// On loan here first, then advised to leave; within each by key.
    public let cautions: [MemberCaution]
    public let basis: Evidence
}

/// Why a candidate has no suggested group: the first of these that applies.
public enum NotPlacedReason: Equatable, Sendable {
    /// He takes nothing, by his readings.
    case takesNothing
    /// No arrow into him, read or guessed, is above None.
    case noInfluence
    /// No arrow into him above None has anything to give him.
    case nothingToGain
    /// A player free to be grouped has an arrow into him with something to give, but fewer than three players, himself
    /// included, are free to be grouped at all.
    case tooFewFree
    /// A player free to be grouped has an arrow into him with something to give, and groups of three free players can
    /// be formed with him and such a player, but every one that would give it holds a harmful arrow.
    case wouldHarm
    /// A free player with something to give him is still in no suggested group, and groups that would help him can be
    /// formed among the free players, but none of them is left unused with a third player who would harm nobody.
    case noThirdFree
    /// Every free player with something to give him is in a suggested group; any others are in recorded groups.
    case influencersTaken
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
    /// No player of the squad who is not out on loan has a level above `.others`: every guess is then None.
    public let needsHierarchy: Bool
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
    /// Suggests groups of three from the arrows between the squad's players, read or guessed, and says why any
    /// candidate is in none. Throws `PlanError.badParameters` for `problems(in:)`, before anything else, and
    /// `RatingError.missingAttribute` for the first player of the squad, by key, not out on loan, with no value for a
    /// counted attribute (in `counted` order).
    ///
    /// The groups are found greedily: of every valid group among the free players not yet used, the one of greatest
    /// value is formed, then the same again among the players left, until none is valid. Ties go to the group with
    /// fewer members above Others, then to the one with more of its six arrows read, then to the lowest keys. This does
    /// not prove that no other set of groups has a greater total. Injury, bans and fitness are not looked at.
    public static func report(_ request: MentoringRequest, parameters: EngineParameters) throws -> MentoringReport {
        let problems = problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let counted = Mentoring.counted(parameters)

        // Sorting by key makes every list, every tie and the first error independent of input order; an index into
        // `people` is then in key order too.
        let recorded = Set(request.groups.filter(\.isLive).flatMap(\.current).map(\.player))
        var people: [Person] = []
        for player in request.players.filter({ $0.squad == request.squad }).sorted(by: { $0.id.key < $1.id.key }) {
            let isLoanedIn: Bool
            switch LoanStatus.of(player, ownClub: request.ownClub) {
            case .loanedOut: continue
            case .loanedIn: isLoanedIn = true
            case .own: isLoanedIn = false
            }
            var values: [Attribute: Int] = [:]
            for attribute in counted {
                guard let value = player.attributes[attribute] else {
                    throw RatingError.missingAttribute(player: player.name, attribute: attribute)
                }
                values[attribute] = value
            }
            people.append(Person(
                player: player, standing: request.dynamics[player.id]?.standing ?? .others,
                isOwn: !isLoanedIn, isLeaving: request.leaving.contains(player.id),
                inRecordedGroup: recorded.contains(player.id), values: values,
                worth: Dictionary(uniqueKeysWithValues: values.map { attribute, value in
                    (attribute, Mentoring.worth(attribute, value, parameters: parameters))
                })))
        }

        // A reading counts only between two players of this squad not out on loan. Sorted so that, of two readings of
        // one pair on one day, the same one counts whatever the input order.
        let ids = Set(people.map(\.player.id))
        let readings = request.arrows
            .filter { $0.squad == request.squad && ids.contains($0.from) && ids.contains($0.to) }
            .sorted { a, b in
                (a.from.key, a.to.key, a.readOn, a.strength) < (b.from.key, b.to.key, b.readOn, b.strength)
            }
        let judge = Judge(people: people, squad: request.squad, readings: readings, counted: counted,
                          parameters: parameters)

        let pool = people.indices.filter { !people[$0].inRecordedGroup }
        let candidates = pool.filter { judge.isCandidate[$0] }

        var used: Set<Int> = []
        var formed: [Option] = []
        while let best = judge.bestOption(among: pool.filter { !used.contains($0) }) {
            formed.append(best)
            used.formUnion(best.members)
        }

        let suggestions = formed.map { judge.suggestion($0) }
        let notPlaced = candidates.filter { !used.contains($0) }.map { index in
            let person = people[index]
            return NotPlaced(player: person.player.id, name: person.player.name, age: person.player.age,
                             reason: judge.reason(for: index, pool: pool, used: used))
        }

        let groups = request.groups.filter { $0.isLive && $0.squad == request.squad }.sorted {
            $0.startedOn != $1.startedOn ? $0.startedOn < $1.startedOn : $0.id.uuidString < $1.id.uuidString
        }.map { review($0, request: request, parameters: parameters) }

        let isStale = request.dynamicsUpdatedOn.map {
            $0.days(to: request.asOf) > parameters.mentoringDynamicsStaleAfterDays.value
        } ?? false
        return MentoringReport(
            squad: request.squad, needsHierarchy: !people.contains { $0.standing > .others },
            isStale: isStale, suggestions: suggestions, notPlaced: notPlaced, groups: groups, basis: judge.basis)
    }

    // MARK: Working

    /// A player of the squad who is not out on loan, with what the rules read.
    private struct Person {
        let player: Player
        let standing: Standing
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

    /// One valid group of three.
    private struct Option {
        /// Ascending, so in key order.
        let members: [Int]
        /// The sum over its candidates of the greatest gain of any one arrow into him.
        let value: Int
        /// Members with a level above Others.
        let seniors: Int
        /// Of its six arrows, those read.
        let read: Int
        /// For each candidate with a gain, the source and target of the arrow that gives it.
        let restsOn: [(from: Int, to: Int)]

        /// Greater value first; then fewer seniors; then more arrows read; then the lowest keys.
        func isBetter(than other: Option) -> Bool {
            if value != other.value { return value > other.value }
            if seniors != other.seniors { return seniors < other.seniors }
            if read != other.read { return read > other.read }
            return members.lexicographicallyPrecedes(other.members)
        }
    }

    /// The rules, with every arrow between the squad's players worked out once.
    private struct Judge {
        let people: [Person]
        let counted: [Attribute]
        /// `arrows[from][to]`, read or guessed; the diagonal is never used.
        let arrows: [[Arrow]]
        /// The strength's weight times the sum over the counted attributes of the source's worth less the target's.
        let gains: [[Int]]
        /// Above None, and the source is worth less than the target in a counted attribute.
        let harmful: [[Bool]]
        let takesNothing: [Bool]
        /// Belongs to the club, not advised to leave, and below the ceiling in a counted attribute. Only players in no
        /// recorded group are ever asked about.
        let isCandidate: [Bool]
        /// The weakest evidence of every parameter a suggestion rests on.
        let basis: Evidence

        init(people: [Person], squad: Squad, readings: [ArrowReading], counted: [Attribute],
             parameters: EngineParameters) {
            self.people = people
            self.counted = counted
            let standings = Dictionary(uniqueKeysWithValues: people.map { ($0.player.id, $0.standing) })
            let parties = people.map { Party(id: $0.player.id, standing: $0.standing, age: $0.player.age) }
            // `problems(in:)` has made sure every strength has a weight.
            let weights = parameters.mentoringStrengthWeights.value
            var arrows: [[Arrow]] = [], gains: [[Int]] = [], harmful: [[Bool]] = []
            for (i, source) in people.enumerated() {
                var arrowRow: [Arrow] = [], gainRow: [Int] = [], harmRow: [Bool] = []
                for (j, target) in people.enumerated() {
                    let arrow = Mentoring.arrow(from: parties[i], to: parties[j], in: squad, readings: readings,
                                                standings: standings, parameters: parameters)
                    let difference = counted.reduce(0) { $0 + source.worth[$1]! - target.worth[$1]! }
                    arrowRow.append(arrow)
                    gainRow.append(i == j ? 0 : weights[arrow.strength]! * difference)
                    harmRow.append(i != j && arrow.strength > .none
                                   && counted.contains { source.worth[$0]! < target.worth[$0]! })
                }
                arrows.append(arrowRow)
                gains.append(gainRow)
                harmful.append(harmRow)
            }
            self.arrows = arrows
            self.gains = gains
            self.harmful = harmful
            takesNothing = people.map {
                Mentoring.takesNothing($0.player.id, in: squad, readings: readings, standings: standings,
                                       parameters: parameters)
            }
            let ceilings = parameters.mentoringCeilings.value
            isCandidate = people.map { person in
                person.isOwn && !person.isLeaving && counted.contains { attribute in
                    // `problems(in:)` has made sure every counted attribute has a ceiling.
                    person.values[attribute]! < ceilings[attribute]!
                }
            }
            // The guess reads `mentoringMenteeMaxAge` as its age line.
            basis = Evidence.weakest([parameters.mentoringWeights.evidence, parameters.mentoringCeilings.evidence,
                                      parameters.mentoringStrengthWeights.evidence, parameters.mentoringGuess.evidence,
                                      parameters.mentoringMenteeMaxAge.evidence,
                                      parameters.mentoringTakesNothingAfter.evidence])!
        }

        /// The group of three as an option; nil when it is not valid: an arrow among its six is harmful, or no
        /// candidate in it has an arrow into him with a gain above 0.
        func option(_ members: [Int]) -> Option? {
            for from in members {
                for to in members where to != from && harmful[from][to] { return nil }
            }
            var value = 0
            var restsOn: [(from: Int, to: Int)] = []
            for target in members where isCandidate[target] {
                // Greatest gain; of two the same, a read arrow before a guess, then the lower source key.
                let best = members.filter { $0 != target && gains[$0][target] > 0 }.min { a, b in
                    if gains[a][target] != gains[b][target] { return gains[a][target] > gains[b][target] }
                    if arrows[a][target].isRead != arrows[b][target].isRead { return arrows[a][target].isRead }
                    return a < b
                }
                if let best {
                    value += gains[best][target]
                    restsOn.append((best, target))
                }
            }
            guard value > 0 else { return nil }
            var read = 0
            for from in members {
                for to in members where to != from && arrows[from][to].isRead { read += 1 }
            }
            let seniors = members.filter { people[$0].standing > .others }.count
            return Option(members: members, value: value, seniors: seniors, read: read, restsOn: restsOn)
        }

        /// Every group of three among `free`, ascending, in order.
        func trios(_ free: [Int]) -> [[Int]] {
            var found: [[Int]] = []
            for (i, a) in free.enumerated() {
                for (j, b) in free.enumerated() where j > i {
                    for c in free[(j + 1)...] { found.append([a, b, c]) }
                }
            }
            return found
        }

        /// The best valid group among `free`; nil when there is none.
        func bestOption(among free: [Int]) -> Option? {
            var best: Option?
            for trio in trios(free) {
                guard let option = option(trio) else { continue }
                if best.map({ option.isBetter(than: $0) }) ?? true { best = option }
            }
            return best
        }

        func suggestion(_ option: Option) -> SuggestedGroup {
            let members = option.members
            var listed: [(arrow: GroupArrow, gain: Int)] = []
            for from in members {
                for to in members where to != from && arrows[from][to].strength > .none {
                    let source = people[from], target = people[to]
                    listed.append((GroupArrow(
                        arrow: arrows[from][to], fromName: source.player.name, toName: target.player.name,
                        pulls: counted.filter { target.worth[$0]! < source.worth[$0]! }.map {
                            Pull(attribute: $0, value: target.values[$0]!, towards: source.values[$0]!)
                        }), gains[from][to]))
                }
            }
            listed.sort { a, b in
                if a.gain != b.gain { return a.gain > b.gain }
                let x = a.arrow.arrow, y = b.arrow.arrow
                return (x.from.key, x.to.key) < (y.from.key, y.to.key)
            }
            let sources = Set(option.restsOn.map(\.from)).sorted()
            let cautions = sources.filter { !people[$0].isOwn }.map { MemberCaution.onLoanHere(people[$0].player.id) }
                + sources.filter { people[$0].isLeaving }.map { MemberCaution.advisedToLeave(people[$0].player.id) }
            return SuggestedGroup(
                members: members.map { SuggestedMember(player: people[$0].player.id, name: people[$0].player.name,
                                                        age: people[$0].player.age) },
                arrows: listed.map(\.arrow),
                isRead: option.restsOn.allSatisfy { arrows[$0.from][$0.to].isRead },
                cautions: cautions, basis: basis)
        }

        /// The first reason that applies, judged against every squad player not out on loan, members of recorded
        /// groups included; `used` are the members of the suggested groups. It never changes which groups are formed.
        func reason(for index: Int, pool: [Int], used: Set<Int>) -> NotPlacedReason {
            if takesNothing[index] { return .takesNothing }
            let others = people.indices.filter { $0 != index }
            let influencing = others.filter { arrows[$0][index].strength > .none }
            if influencing.isEmpty { return .noInfluence }
            if !influencing.contains(where: { gains[$0][index] > 0 }) { return .nothingToGain }
            let free = pool.filter { $0 != index }
            if free.contains(where: { gains[$0][index] > 0 }) {
                // "Free" is the pool, himself included: no group of three can be formed from fewer.
                if pool.count < Mentoring.groupSize { return .tooFewFree }
                let helped = free.indices.contains { i in
                    free[(i + 1)...].contains { other in
                        option([index, free[i], other].sorted())?.restsOn.contains { $0.to == index } == true
                    }
                }
                if !helped { return .wouldHarm }
                if free.contains(where: { gains[$0][index] > 0 && !used.contains($0) }) { return .noThirdFree }
            }
            return .influencersTaken
        }
    }
}
