import LineupEngine

/// What the owner has typed for one player: his value with the day it was typed, what his loan is for when he has
/// switched it, and whether he chose sale or loan terms against his mark. Kept under his key, so it stays when his mark
/// is taken off and is found again when he is marked again.
public struct PlayerOffer: Equatable, Codable, Sendable {
    /// Nil when none is typed; 0 is a value.
    public var value: Int?
    /// The day in the game the value was last changed; nil with no value.
    public var valueDay: Day?
    /// Nil until the owner switches it; until then it follows his age (`AppModel.loanPurpose(for:)`).
    public var purpose: LoanPurpose?
    /// The terms his block works out when the owner chose the kind his mark does not give; nil to follow the mark
    /// (`AppModel.offerKind(for:)`). Absent in a file saved before the choice existed, which reads as nil.
    public var kind: OfferKind?

    public init(value: Int? = nil, valueDay: Day? = nil, purpose: LoanPurpose? = nil, kind: OfferKind? = nil) {
        self.value = value; self.valueDay = valueDay; self.purpose = purpose; self.kind = kind
    }
}

/// A club's figures as the owner last typed them, and the day in the game they were typed.
public struct ClubEntry: Equatable, Codable, Sendable {
    public var figures: ClubFigures
    public var enteredOn: Day

    public init(figures: ClubFigures, enteredOn: Day) {
        self.figures = figures; self.enteredOn = enteredOn
    }
}

/// The values, the clubs' figures and the record of offers. Kept in a file of its own, and nothing in it is dropped
/// when a mark is taken off or a player leaves: the record is what measures what clubs pay.
public struct OffersState: Equatable, Codable, Sendable {
    public var players: [PlayerID: PlayerOffer] = [:]
    /// Keyed by `PlayerID.normalise` of the club's name.
    public var clubs: [String: ClubEntry] = [:]
    /// In the order recorded.
    public var asks: [OfferAsk] = []
    /// In the order opened.
    public var deals: [OfferDeal] = []
    /// The day the measures are read from; nil to read the whole record.
    public var measureFrom: Day?

    public init() {}
}

/// A club figure the owner types.
public enum ClubField: String, CaseIterable, Sendable { case transferBudget, wageBudget, wagesSpent, highestWage }
