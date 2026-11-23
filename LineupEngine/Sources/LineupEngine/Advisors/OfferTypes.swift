import Foundation

/// The numbers behind the terms suggested for a sale or a loan (`Offers`). Money is whole units, a wage is by the week,
/// a share is a whole percentage. Every one is an estimate (see `EngineParameters.offerRules`).
public struct OfferRules: Sendable, Equatable {
    /// The total asked for a sale, as a share of his value.
    public var saleLine: Double
    /// What a borrower bears a week for a loan, as a share of his value.
    public var loanLinePerWeek: Double
    /// How far a club's counter is taken to come up on its first bid.
    public var counterStep: Double
    /// The share of his next fee asked in a sale, a whole percentage.
    public var nextFeePercent: Int
    /// The appearances after which money asked later falls due.
    public var appearancesForLater: Int
    /// The share of money asked later that is paid in instalments.
    public var laterInInstalments: Double
    /// The months over which instalments run.
    public var instalmentMonths: Int
    /// The step a loan's wage share is moved by, a whole percentage that divides 100.
    public var wageStepPercent: Int
    /// The weeks to a month in the loan rule.
    public var weeksPerMonthInRule: Int
    /// The lowest share of his value that a bid from a club with no interest is taken to be.
    public var noInterestBidLow: Double
    /// The highest share of his value that such a bid is taken to be.
    public var noInterestBidHigh: Double
    /// The share by which an ask is stepped down after refusals.
    public var stepDown: Double
    /// The most steps down.
    public var stepsDownAtMost: Int
    /// The fewest deals each way (agreed, turned down) before a line is measured from them.
    public var fewestEachWay: Int
    /// The fewest deals with a counter before the counter step is measured.
    public var fewestCounterDeals: Int
    /// The significant figures an amount is rounded to.
    public var significantFigures: Int

    public init(saleLine: Double, loanLinePerWeek: Double, counterStep: Double, nextFeePercent: Int,
                appearancesForLater: Int, laterInInstalments: Double, instalmentMonths: Int, wageStepPercent: Int,
                weeksPerMonthInRule: Int, noInterestBidLow: Double, noInterestBidHigh: Double, stepDown: Double,
                stepsDownAtMost: Int, fewestEachWay: Int, fewestCounterDeals: Int, significantFigures: Int) {
        self.saleLine = saleLine; self.loanLinePerWeek = loanLinePerWeek; self.counterStep = counterStep
        self.nextFeePercent = nextFeePercent; self.appearancesForLater = appearancesForLater
        self.laterInInstalments = laterInInstalments; self.instalmentMonths = instalmentMonths
        self.wageStepPercent = wageStepPercent; self.weeksPerMonthInRule = weeksPerMonthInRule
        self.noInterestBidLow = noInterestBidLow; self.noInterestBidHigh = noInterestBidHigh
        self.stepDown = stepDown; self.stepsDownAtMost = stepsDownAtMost; self.fewestEachWay = fewestEachWay
        self.fewestCounterDeals = fewestCounterDeals; self.significantFigures = significantFigures
    }
}

/// Whether a deal is a sale or a loan out.
public enum OfferKind: String, Codable, CaseIterable, Sendable { case sale, loan }
/// Why a player is loaned out: for matches, or to take his wage off the club.
public enum LoanPurpose: String, Codable, CaseIterable, Sendable { case development, wage }
/// What a loan asks the borrower to promise about his playing time.
public enum PlayingTime: String, Codable, CaseIterable, Sendable { case startingPlace, less }

/// The terms of a sale: money now, money later, and a share of his next fee.
public struct SaleTerms: Equatable, Codable, Sendable {
    public var now: Int
    public var later: Int
    public var nextFeePercent: Int
    public var total: Int { now + later }

    public init(now: Int, later: Int, nextFeePercent: Int) {
        self.now = now; self.later = later; self.nextFeePercent = nextFeePercent
    }
}

/// The terms of a loan out. `playingTime` is nil when none is asked.
public struct LoanTerms: Equatable, Codable, Sendable {
    public var wagePercent: Int
    public var feePerMonth: Int
    public var playingTime: PlayingTime?
    public var recall: Bool
    public var futureFee: Int?

    public init(wagePercent: Int, feePerMonth: Int, playingTime: PlayingTime?, recall: Bool, futureFee: Int?) {
        self.wagePercent = wagePercent; self.feePerMonth = feePerMonth; self.playingTime = playingTime
        self.recall = recall; self.futureFee = futureFee
    }

    private enum CodingKeys: String, CodingKey { case wagePercent, feePerMonth, playingTime, recall, futureFee }

    /// Every key is required; an absent `playingTime` or `futureFee` is an error, a null is "none".
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wagePercent = try c.decode(Int.self, forKey: .wagePercent)
        feePerMonth = try c.decode(Int.self, forKey: .feePerMonth)
        playingTime = try c.decode(PlayingTime?.self, forKey: .playingTime)
        recall = try c.decode(Bool.self, forKey: .recall)
        futureFee = try c.decode(Int?.self, forKey: .futureFee)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(wagePercent, forKey: .wagePercent)
        try c.encode(feePerMonth, forKey: .feePerMonth)
        try c.encode(playingTime, forKey: .playingTime)
        try c.encode(recall, forKey: .recall)
        try c.encode(futureFee, forKey: .futureFee)
    }
}

/// The terms of either kind of deal.
public enum OfferTerms: Equatable, Codable, Sendable {
    case sale(SaleTerms)
    case loan(LoanTerms)

    public var kind: OfferKind {
        switch self {
        case .sale: .sale
        case .loan: .loan
        }
    }
}

/// Who made a round of a deal.
public enum RoundBy: String, Codable, Sendable { case owner, club }
/// How the club answered an owner's round.
public enum RoundAnswer: String, Codable, Sendable { case accepted, refused, noReply }

/// One round of a deal. An owner's round carries the club's answer; a club's round is `.accepted` once the owner
/// accepts it, else nil.
public struct OfferRound: Equatable, Codable, Sendable {
    public var day: Day
    public var by: RoundBy
    public var terms: OfferTerms
    /// His value as it stood when the round was made.
    public var value: Int
    /// His wage a week as it stood when the round was made.
    public var wagePerWeek: Double
    public var answer: RoundAnswer?

    public init(day: Day, by: RoundBy, terms: OfferTerms, value: Int, wagePerWeek: Double, answer: RoundAnswer?) {
        self.day = day; self.by = by; self.terms = terms; self.value = value
        self.wagePerWeek = wagePerWeek; self.answer = answer
    }

    private enum CodingKeys: String, CodingKey { case day, by, terms, value, wagePerWeek, answer }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(Day.self, forKey: .day)
        by = try c.decode(RoundBy.self, forKey: .by)
        terms = try c.decode(OfferTerms.self, forKey: .terms)
        value = try c.decode(Int.self, forKey: .value)
        wagePerWeek = try c.decode(Double.self, forKey: .wagePerWeek)
        answer = try c.decode(RoundAnswer?.self, forKey: .answer)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(day, forKey: .day)
        try c.encode(by, forKey: .by)
        try c.encode(terms, forKey: .terms)
        try c.encode(value, forKey: .value)
        try c.encode(wagePerWeek, forKey: .wagePerWeek)
        try c.encode(answer, forKey: .answer)
    }
}

/// What the owner has entered of a club's money. A figure not entered is nil.
public struct ClubFigures: Equatable, Codable, Sendable {
    public var name: String
    public var transferBudget: Int?
    public var wageBudgetPerWeek: Double?
    public var wagesSpentPerWeek: Double?
    public var highestWagePerWeek: Double?

    /// The wage budget less the wages spent, never below 0; nil when either is not entered.
    public var wageLeftPerWeek: Double? {
        guard let budget = wageBudgetPerWeek, let spent = wagesSpentPerWeek else { return nil }
        return max(0, budget - spent)
    }

    public init(name: String, transferBudget: Int?, wageBudgetPerWeek: Double?, wagesSpentPerWeek: Double?,
                highestWagePerWeek: Double?) {
        self.name = name; self.transferBudget = transferBudget; self.wageBudgetPerWeek = wageBudgetPerWeek
        self.wagesSpentPerWeek = wagesSpentPerWeek; self.highestWagePerWeek = highestWagePerWeek
    }

    private enum CodingKeys: String, CodingKey {
        case name, transferBudget, wageBudgetPerWeek, wagesSpentPerWeek, highestWagePerWeek
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        transferBudget = try c.decode(Int?.self, forKey: .transferBudget)
        wageBudgetPerWeek = try c.decode(Double?.self, forKey: .wageBudgetPerWeek)
        wagesSpentPerWeek = try c.decode(Double?.self, forKey: .wagesSpentPerWeek)
        highestWagePerWeek = try c.decode(Double?.self, forKey: .highestWagePerWeek)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(transferBudget, forKey: .transferBudget)
        try c.encode(wageBudgetPerWeek, forKey: .wageBudgetPerWeek)
        try c.encode(wagesSpentPerWeek, forKey: .wagesSpentPerWeek)
        try c.encode(highestWagePerWeek, forKey: .highestWagePerWeek)
    }
}

/// Where a deal stands.
public enum DealState: Sendable { case open, agreed, ended }

/// One negotiation with one club over one player: its rounds in order.
public struct OfferDeal: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var player: PlayerID
    public var playerName: String
    public var kind: OfferKind
    public var club: String
    public var figures: ClubFigures?
    public var rounds: [OfferRound]
    public var endedOn: Day?

    /// Agreed when any round's answer is accepted (that wins over ended), else ended when `endedOn` is set, else open.
    public var state: DealState {
        if rounds.contains(where: { $0.answer == .accepted }) { return .agreed }
        return endedOn != nil ? .ended : .open
    }

    public init(id: UUID, player: PlayerID, playerName: String, kind: OfferKind, club: String, figures: ClubFigures?,
                rounds: [OfferRound], endedOn: Day?) {
        self.id = id; self.player = player; self.playerName = playerName; self.kind = kind; self.club = club
        self.figures = figures; self.rounds = rounds; self.endedOn = endedOn
    }

    private enum CodingKeys: String, CodingKey { case id, player, playerName, kind, club, figures, rounds, endedOn }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        player = try c.decode(PlayerID.self, forKey: .player)
        playerName = try c.decode(String.self, forKey: .playerName)
        kind = try c.decode(OfferKind.self, forKey: .kind)
        club = try c.decode(String.self, forKey: .club)
        figures = try c.decode(ClubFigures?.self, forKey: .figures)
        rounds = try c.decode([OfferRound].self, forKey: .rounds)
        endedOn = try c.decode(Day?.self, forKey: .endedOn)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(player, forKey: .player)
        try c.encode(playerName, forKey: .playerName)
        try c.encode(kind, forKey: .kind)
        try c.encode(club, forKey: .club)
        try c.encode(figures, forKey: .figures)
        try c.encode(rounds, forKey: .rounds)
        try c.encode(endedOn, forKey: .endedOn)
    }
}

/// A price the owner put on a player to clubs in general, and whether no bid came.
public struct OfferAsk: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var player: PlayerID
    public var playerName: String
    public var kind: OfferKind
    public var day: Day
    public var terms: OfferTerms
    public var value: Int
    public var wagePerWeek: Double
    public var noBidCame: Bool

    public init(id: UUID, player: PlayerID, playerName: String, kind: OfferKind, day: Day, terms: OfferTerms,
                value: Int, wagePerWeek: Double, noBidCame: Bool) {
        self.id = id; self.player = player; self.playerName = playerName; self.kind = kind; self.day = day
        self.terms = terms; self.value = value; self.wagePerWeek = wagePerWeek; self.noBidCame = noBidCame
    }
}

/// What the terms are worked out for: his value, his wage a week, whether he is a goalkeeper, and why a loan is wanted.
public struct OfferSubject: Equatable, Sendable {
    public var value: Int
    public var wagePerWeek: Double
    public var isGoalkeeper: Bool
    public var purpose: LoanPurpose

    public init(value: Int, wagePerWeek: Double, isGoalkeeper: Bool, purpose: LoanPurpose) {
        self.value = value; self.wagePerWeek = wagePerWeek; self.isGoalkeeper = isGoalkeeper; self.purpose = purpose
    }
}

/// How money asked later is split: in instalments, and after appearances.
public struct SaleSplit: Equatable, Sendable {
    public var instalments: Int
    public var afterAppearances: Int

    public init(instalments: Int, afterAppearances: Int) {
        self.instalments = instalments; self.afterAppearances = afterAppearances
    }
}

/// Why there is nothing lower to propose.
public enum NothingLower: Sendable { case clubTurnedDownThree, noBidThree, clubDoesNotWantHim }

/// What to do next in a deal.
public enum OfferAdvice: Equatable, Sendable {
    /// An ask or a proposal; the split only for a sale with later money.
    case propose(OfferTerms, split: SaleSplit?)
    case counter(OfferTerms)
    case accept
    /// A round has been accepted: there is nothing left to answer.
    case agreed
    case acceptOrLeave
    case awaitAnswer
    case nothingLower(NothingLower)
}

/// The club's figure, a week, that limited a loan's wage share.
public enum ShareLimit: Equatable, Sendable { case all, value, wageLeft(Double), highestWage(Double) }

/// Something to say beside the terms. In every suggestion the notes come in one order: `valueIsZero`, `steppedDown`,
/// the kind's own, then `measuredLine` and `measuredCounterStep`.
public enum OfferNote: Equatable, Sendable {
    case valueIsZero
    case doNotList, noInterestBids, clubsOpenLow
    case nothingToSpendNow, restAskedLater(now: Int)
    case wageLeftUnderHisWage(left: Double), highestWageUnderHisWage(highest: Double)
    case shareLimitedBy(ShareLimit), recallWithFee, optionalFutureFee(Int)
    case steppedDown
    /// The line was measured from recorded deals; carries the figure used.
    case measuredLine(Double)
    /// The counter step was measured from recorded deals; carries the figure used.
    case measuredCounterStep(Double)
}

/// The advice, its notes and the weakest evidence behind it.
public struct OfferSuggestion: Equatable, Sendable {
    public var advice: OfferAdvice
    public var notes: [OfferNote]
    public var basis: Evidence

    public init(advice: OfferAdvice, notes: [OfferNote], basis: Evidence) {
        self.advice = advice; self.notes = notes; self.basis = basis
    }
}

/// What recorded deals of one kind show of the line clubs pay or turn down.
public struct OfferLineReading: Equatable, Sendable {
    public var deals: Int
    public var agreed: Int
    public var paid: Int
    public var turnedDown: Int
    public var medianPaid: Double?
    public var medianTurnedDown: Double?
    public var line: Double?
    public var since: Day?

    public init(deals: Int, agreed: Int, paid: Int, turnedDown: Int, medianPaid: Double?, medianTurnedDown: Double?,
                line: Double?, since: Day?) {
        self.deals = deals; self.agreed = agreed; self.paid = paid; self.turnedDown = turnedDown
        self.medianPaid = medianPaid; self.medianTurnedDown = medianTurnedDown; self.line = line; self.since = since
    }
}

/// What the recorded deals show, for each kind and for clubs' counters.
public struct OfferMeasures: Equatable, Sendable {
    public var sale: OfferLineReading
    public var loan: OfferLineReading
    public var counterDeals: Int
    public var counterStep: Double?
    public var measuredFrom: Day?

    /// Nothing recorded: every count 0, every figure nil.
    public static let none = OfferMeasures(
        sale: OfferLineReading(deals: 0, agreed: 0, paid: 0, turnedDown: 0, medianPaid: nil, medianTurnedDown: nil,
                               line: nil, since: nil),
        loan: OfferLineReading(deals: 0, agreed: 0, paid: 0, turnedDown: 0, medianPaid: nil, medianTurnedDown: nil,
                               line: nil, since: nil),
        counterDeals: 0, counterStep: nil, measuredFrom: nil)

    public init(sale: OfferLineReading, loan: OfferLineReading, counterDeals: Int, counterStep: Double?, measuredFrom: Day?) {
        self.sale = sale; self.loan = loan; self.counterDeals = counterDeals
        self.counterStep = counterStep; self.measuredFrom = measuredFrom
    }
}

/// A field of an offer a sentence can name.
public enum OfferField: String, Sendable, CaseIterable {
    case value, wage, transferBudget, wageBudget, wagesSpent, highestWage, wagePercent, feeNow, feeLater, nextFeePercent, feePerMonth, futureFee
}

/// Why terms cannot be worked out or recorded.
public enum OfferError: Error, Equatable {
    case missing(OfferField, club: String?)
    case negative(OfferField)
    case over100(OfferField)
    case wrongKind
}
