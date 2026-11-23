import Foundation
import LineupEngine

/// One of a club's figures in a player's "To a club" row: its label, with the period on a wage figure, and what is
/// entered for the club named, as plain digits (blank when nothing is).
public struct OfferFieldRow: Equatable, Sendable {
    public var field: ClubField
    /// "Can spend on transfers", "Wage budget, a month".
    public var label: String
    public var text: String
}

/// A suggestion as the screen shows it: the engine's lines, the advice first, and the terms its "Record…" button opens
/// the sheet filled with.
public struct OfferSuggestionBlock: Equatable, Sendable {
    /// The engine's, first the advice.
    public var lines: [String]
    /// What "Record…" opens filled with: the terms of a proposal or a counter; nil when the advice proposes nothing.
    public var terms: OfferTerms?
}

/// One round of a deal, in the engine's words, and what can be pressed under it.
public struct OfferRoundRow: Equatable, Sendable {
    public var line: String
    /// "Accepted", "Refused" and "No reply": on the last round of an open deal of a marked player, when it is the
    /// owner's with no answer yet.
    public var offersAnswers: Bool
    /// "I accepted": on the last round of an open deal of a marked player, when it is the club's.
    public var offersAccept: Bool
}

/// One deal with one club: its heading, its rounds and, while it is open, the next step.
public struct OfferDealCard: Identifiable, Equatable, Sendable {
    public var id: UUID
    /// "Barnet · open", "Barnet · agreed", "Barnet · ended"; under "Earlier offers" the player's name first,
    /// "Sam Reed · Barnet · ended", since the card no longer stands under him.
    public var heading: String
    public var rounds: [OfferRoundRow]
    /// The suggestion for the next round; nil unless the deal is open and its player marked with its kind, with a value.
    public var next: OfferSuggestionBlock?
    /// The engine's sentence when the next step needs a figure that is not entered.
    public var problem: String?
    /// The deal is open and its player is marked with its kind, so "Record my proposal", "Record their bid" and "End"
    /// are offered; false for every card under "Earlier offers", where only the deletion is.
    public var isOpen: Bool
}

/// One ask to clubs in general, in the engine's words.
public struct OfferAskRow: Identifiable, Equatable, Sendable {
    public var id: UUID
    /// Under "Earlier offers", the player's name first: "Sam Reed · Sat 21 Nov: offered to clubs at £40,000."
    public var line: String
    /// "No bid came": on his latest ask while it has none, and never under "Earlier offers".
    public var offersNoBid: Bool
}

/// One marked player, as his part of the screen shows him.
public struct OfferPlayerBlock: Identifiable, Equatable, Sendable {
    public var id: PlayerID
    public var name: String
    /// "Age 27 · D C · £1,950 a month · 14 months left", leaving out what is not known.
    public var details: String
    public var kind: OfferKind
    /// His value as plain digits; blank with none.
    public var valueText: String
    /// "entered Sat 21 Nov"; nil with no value.
    public var valueNote: String?
    /// What his loan is for; nil for a sale.
    public var purpose: LoanPurpose?
    /// The engine's sentence that stands in place of every suggestion of his: his value is not entered, or the engine's
    /// parameters cannot be used. Nil when there are suggestions.
    public var needsValue: String?
    /// The terms to ask of clubs in general.
    public var general: OfferSuggestionBlock?
    /// His asks of his kind, latest last.
    public var asks: [OfferAskRow]
    /// The club typed in his "To a club" row, as typed; blank with none.
    public var clubName: String
    /// The four figures, in `ClubField`'s order, filled from what is entered for the club named.
    public var clubFields: [OfferFieldRow]
    /// "entered Sat 21 Nov": when the club's figures were last entered; nil with none.
    public var clubNote: String?
    /// The terms to propose to the club named; nil with no club, with a problem, or with an open deal there.
    public var clubBlock: OfferSuggestionBlock?
    /// The engine's sentence naming the figure the proposal needs.
    public var clubProblem: String?
    /// The engine's sentence that his open deal with the club named is below, in place of a second proposal.
    public var clubHasOpenDeal: String?
    /// His deals of his kind: open ones first, then by the day of their last round, latest first.
    public var deals: [OfferDealCard]
}

/// The deals and asks of players no longer marked with their kind, under a line saying how many.
public struct EarlierOffers: Equatable, Sendable {
    /// "3 deals and 1 ask for players no longer marked".
    public var line: String
    public var deals: [OfferDealCard]
    public var asks: [OfferAskRow]
}

/// Everything the Offers screen shows, worked out from the marks, the squads and the record of offers.
public struct OffersSheet: Equatable, Sendable {
    public var intro: String
    /// The engine's line when nobody held in the squads is marked; nil otherwise.
    public var nobodyMarked: String?
    public var valueHint: String
    public var valueCaution: String
    /// In the squad book's order.
    public var toSell: [OfferPlayerBlock]
    public var toLoanOut: [OfferPlayerBlock]
    /// What the offers have shown: the engine's lines for sales, for loans and for the counter step; empty and nil
    /// while nothing is recorded.
    public var sales: [String]
    public var loans: [String]
    public var counterStep: String?
    /// The engine's line for the whole part while no deal and no ask is recorded.
    public var nothingRecorded: String?
    /// "Measured from Tue 17 Nov." once a day to measure from is set.
    public var measuredFrom: String?
    /// "Measure again from today" is offered once anything is recorded.
    public var offersMeasureAgain: Bool
    /// Nil when every deal and ask is for a player marked with its kind.
    public var earlier: EarlierOffers?
    public var evidenceNote: [String]
}

/// A round being recorded in the sheet, or an ask: its fields as typed, plain digits only.
public struct OfferRoundDraft: Equatable, Sendable, Identifiable {
    /// What is being recorded: an ask of clubs in general, the owner's proposal to a club, or the club's bid or offer.
    public enum Purpose: Sendable { case ask, mine, theirs }

    /// A new one for each opening of the sheet.
    public let id: UUID
    public var player: PlayerID
    public var kind: OfferKind
    /// Blank for an ask.
    public var club: String
    public var purpose: Purpose
    /// What the loan is for; nil for a sale.
    public var loanPurpose: LoanPurpose?
    /// A sale's money now and later and the share of his next fee.
    public var now, later, nextFee: String
    /// A loan's share of the wage, fee a month and fee to buy him (blank: none).
    public var wagePercent, feePerMonth, futureFee: String
    public var playingTime: PlayingTime?
    public var recall: Bool

    /// Opened filled with `terms` when they are of `kind`, each figure as plain digits ("0" for none of it), else blank.
    /// The playing time: the club's own offer for a development loan starts at less than a starting place, since clubs
    /// are reported to open there, and for a loan to move his wage at none, whatever the sheet is opened with; the
    /// owner's own round or ask takes the terms' playing time, or with no terms what the loan is for asks (a starting
    /// place for his development, none to move his wage). With no terms the recall starts kept, as every suggested loan
    /// keeps it. `loanPurpose` is nil for a sale (`AppModel.offerDraft` fills it in from the player).
    public init(player: PlayerID, kind: OfferKind, club: String, purpose: Purpose, loanPurpose: LoanPurpose?,
                filledWith terms: OfferTerms?) {
        id = UUID()
        self.player = player; self.kind = kind; self.club = club; self.purpose = purpose
        self.loanPurpose = kind == .loan ? loanPurpose : nil
        (now, later, nextFee) = ("", "", "")
        (wagePercent, feePerMonth, futureFee) = ("", "", "")
        playingTime = nil
        recall = true
        var filledTime: PlayingTime?? = .none
        switch (kind, terms) {
        case (.sale, .sale(let t)?):
            (now, later, nextFee) = (String(t.now), String(t.later), String(t.nextFeePercent))
        case (.loan, .loan(let t)?):
            (wagePercent, feePerMonth) = (String(t.wagePercent), String(t.feePerMonth))
            futureFee = t.futureFee.map(String.init) ?? ""
            recall = t.recall
            filledTime = .some(t.playingTime)
        case (.sale, .loan?), (.loan, .sale?), (.sale, nil), (.loan, nil):
            break
        }
        guard kind == .loan else { return }
        switch (purpose, self.loanPurpose) {
        case (.theirs, .development?): playingTime = .less
        case (.theirs, .wage?): playingTime = nil
        case (.theirs, nil): playingTime = filledTime.flatMap { $0 }.map { _ in .less }
        case (.ask, let loan), (.mine, let loan):
            if case .some(let time) = filledTime {
                playingTime = time
            } else {
                switch loan {
                case .development?: playingTime = .startingPlace
                case .wage?, nil: playingTime = nil
                }
            }
        }
    }

    /// Sets a field of this kind from what was typed, keeping its digits only; a field of the other kind, or one the
    /// sheet does not hold, is left as it is.
    public mutating func set(_ field: OfferField, text: String) {
        let digits = String(text.filter { $0.isASCII && $0.isNumber })
        switch (field, kind) {
        case (.feeNow, .sale): now = digits
        case (.feeLater, .sale): later = digits
        case (.nextFeePercent, .sale): nextFee = digits
        case (.wagePercent, .loan): wagePercent = digits
        case (.feePerMonth, .loan): feePerMonth = digits
        case (.futureFee, .loan): futureFee = digits
        case (.feeNow, .loan), (.feeLater, .loan), (.nextFeePercent, .loan), (.wagePercent, .sale), (.feePerMonth, .sale),
             (.futureFee, .sale), (.value, _), (.wage, _), (.transferBudget, _), (.wageBudget, _), (.wagesSpent, _),
             (.highestWage, _):
            break
        }
    }

    /// The terms typed. Throws `OfferError.missing` naming the first blank field the kind needs: a sale's money now,
    /// money later and share of the next fee; a loan's share of the wage and fee a month. A blank future fee is none.
    public func terms() throws -> OfferTerms {
        switch kind {
        case .sale:
            return .sale(SaleTerms(now: try Self.number(now, .feeNow), later: try Self.number(later, .feeLater),
                                   nextFeePercent: try Self.number(nextFee, .nextFeePercent)))
        case .loan:
            return .loan(LoanTerms(wagePercent: try Self.number(wagePercent, .wagePercent),
                                   feePerMonth: try Self.number(feePerMonth, .feePerMonth), playingTime: playingTime,
                                   recall: recall, futureFee: Self.digits(futureFee)))
        }
    }

    /// "Record this ask", "Record my proposal", "Record their bid".
    public var title: String {
        switch purpose {
        case .ask: OffersPresentation.recordAskTitle
        case .mine: OffersPresentation.recordMineTitle
        case .theirs: OffersPresentation.recordTheirsTitle
        }
    }

    /// The number in a field: its digits, or nil with none (or too many to hold).
    private static func digits(_ text: String) -> Int? {
        let digits = text.filter { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    private static func number(_ text: String, _ field: OfferField) throws -> Int {
        guard let number = digits(text) else { throw OfferError.missing(field, club: nil) }
        return number
    }
}

/// What became of a sheet sent to be recorded: recorded (the sheet closes), refused with the engine's sentence, or
/// ignored with nothing to say (the sheet stays open as it is).
public enum OfferRecordResult: Equatable, Sendable {
    case recorded
    case refused(String)
    case ignored
}

/// The Offers screen's plain labels and headings; every word about advice is the engine's.
public enum OffersPresentation {
    public static let toSellHeading = "To sell"
    public static let toLoanOutHeading = "To loan out"
    public static let valueLabel = "His value"
    public static let generalHeading = "To clubs in general"
    public static let clubLabel = "To a club"
    public static let recordAskTitle = "Record this ask"
    public static let recordMineTitle = "Record my proposal"
    public static let recordTheirsTitle = "Record their bid"
    public static let noBidTitle = "No bid came"
    public static let acceptedTitle = "Accepted"
    public static let refusedTitle = "Refused"
    public static let noReplyTitle = "No reply"
    public static let iAcceptedTitle = "I accepted"
    public static let endTitle = "End"
    public static let deleteTitle = "Delete"
    public static let saveTitle = "Save"
    public static let cancelTitle = "Cancel"
    public static let shownHeading = "What your offers have shown"
    public static let measureAgainTitle = "Measure again from today"
    public static let earlierHeading = "Earlier offers"
    /// Asked before a deal or an ask is deleted.
    public static let deleteDealQuestion = "Delete this deal and its rounds from the record?"
    public static let deleteAskQuestion = "Delete this ask from the record?"

    /// The state of a deal after its club in a card's heading.
    static func stateWord(_ state: DealState) -> String {
        switch state {
        case .open: "open"
        case .agreed: "agreed"
        case .ended: "ended"
        }
    }

    /// A club figure's label: a wage figure carries the period FMRTE shows wages by, "Wage budget, a month".
    public static func label(_ field: ClubField, period: WagePeriod) -> String {
        let per = switch period {
        case .weekly: "a week"
        case .monthly: "a month"
        case .yearly: "a year"
        }
        return switch field {
        case .transferBudget: "Can spend on transfers"
        case .wageBudget: "Wage budget, \(per)"
        case .wagesSpent: "Wages spent, \(per)"
        case .highestWage: "Highest wage it can offer, \(per)"
        }
    }

    /// A club figure as entered, in plain digits: the transfer budget in whole units, a wage figure in FMRTE's period
    /// rounded to a whole unit; blank when it is not entered.
    static func text(_ field: ClubField, _ figures: ClubFigures?, period: WagePeriod) -> String {
        func wage(_ perWeek: Double?) -> String {
            perWeek.map { String(Int(period.amount(perWeek: $0).rounded())) } ?? ""
        }
        return switch field {
        case .transferBudget: figures?.transferBudget.map(String.init) ?? ""
        case .wageBudget: wage(figures?.wageBudgetPerWeek)
        case .wagesSpent: wage(figures?.wagesSpentPerWeek)
        case .highestWage: wage(figures?.highestWagePerWeek)
        }
    }

    /// A goalkeeper is a player whose positions are goalkeeper only (the design's rule): his pasted positions are "GK"
    /// and nothing else, without regard to case. One solid in goal who also plays elsewhere is not.
    static func isGoalkeeper(_ player: Player) -> Bool {
        player.positionsText.trimmingCharacters(in: .whitespaces)
            .caseInsensitiveCompare(Position.goalkeeper.rawValue) == .orderedSame
    }

    /// "14 months left", "1 month left".
    static func monthsLeftText(_ months: Int) -> String { "\(months) \(months == 1 ? "month" : "months") left" }

    /// "Age 27 · D C · £1,950 a month · 14 months left": his age, positions, wage in FMRTE's period and the months left
    /// on his contract, leaving out the positions and the months when they are not known.
    static func details(of player: Player, money: MoneyStyle) -> String {
        let positions = player.positionsText.isEmpty ? nil : player.positionsText
        return ([ScoutingPresentation.ageText(player.age), positions, Display.wage(perWeek: player.wagePerWeek, money),
                 player.monthsLeft.map(monthsLeftText)] as [String?]).compactMap { $0 }.joined(separator: " · ")
    }

    /// "3 deals and 1 ask for players no longer marked", leaving out the part with none; nil with neither.
    static func earlierLine(deals: Int, asks: Int) -> String? {
        func count(_ n: Int, _ noun: String) -> String? { n == 0 ? nil : "\(n) \(noun)\(n == 1 ? "" : "s")" }
        let parts = [count(deals, "deal"), count(asks, "ask")].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " and ") + " for players no longer marked"
    }

    /// The terms a "Record…" button opens the sheet with: those of a proposal or a counter, else none.
    static func terms(of advice: OfferAdvice) -> OfferTerms? {
        switch advice {
        case .propose(let terms, _), .counter(let terms): terms
        case .accept, .agreed, .acceptOrLeave, .awaitAnswer, .nothingLower: nil
        }
    }
}

extension AppModel {
    /// The Offers screen's sheet, with the club typed in each player's "To a club" row. Building it changes nothing and
    /// saves nothing.
    public func offersSheet(clubs: [PlayerID: String]) -> OffersSheet {
        offersSheet(clubs: clubs, parameters: planParameters)
    }

    /// The sheet worked out with `parameters`: the measures once, handed to every suggestion in it, and, when the
    /// parameters cannot be used, their sentence once in place of every suggestion.
    func offersSheet(clubs: [PlayerID: String], parameters: EngineParameters) -> OffersSheet {
        let problems = FitnessModel.problems(in: parameters)
        let context = OffersContext(
            parameters: parameters, money: squad.book.moneyStyle,
            measures: Offers.measures(asks: offers.asks, deals: offers.deals, from: offers.measureFrom,
                                      parameters: parameters),
            unusable: problems.isEmpty ? nil : ErrorDescriptions.describe(PlanError.badParameters(problems)))

        var toSell: [OfferPlayerBlock] = []
        var toLoanOut: [OfferPlayerBlock] = []
        var marked: [PlayerID: OfferKind] = [:]
        for player in squad.book.allPlayers {
            guard marked[player.id] == nil, let kind = offerKind(for: player.id) else { continue }
            marked[player.id] = kind
            let block = offerBlock(player, kind: kind, club: clubs[player.id] ?? "", context: context)
            switch kind {
            case .sale: toSell.append(block)
            case .loan: toLoanOut.append(block)
            }
        }

        let earlierDeals = Self.dealOrder(offers.deals.filter { marked[$0.player] != $0.kind }).map {
            dealCard($0, subject: nil, live: false, context: context)
        }
        let earlierAsks = offers.asks.filter { marked[$0.player] != $0.kind }.map {
            OfferAskRow(id: $0.id, line: "\($0.playerName) · " + AdvisorText.askLine($0, money: context.money),
                        offersNoBid: false)
        }
        let earlier = OffersPresentation.earlierLine(deals: earlierDeals.count, asks: earlierAsks.count).map {
            EarlierOffers(line: $0, deals: earlierDeals, asks: earlierAsks)
        }

        let recorded = !offers.deals.isEmpty || !offers.asks.isEmpty
        let rules = context.rules
        return OffersSheet(
            intro: AdvisorText.offersIntro,
            nobodyMarked: marked.isEmpty ? AdvisorText.offersNobodyMarked : nil,
            valueHint: AdvisorText.valueHint, valueCaution: AdvisorText.valueCaution,
            toSell: toSell, toLoanOut: toLoanOut,
            sales: recorded ? AdvisorText.offerMeasureLines(context.measures, kind: .sale, rules: rules) : [],
            loans: recorded ? AdvisorText.offerMeasureLines(context.measures, kind: .loan, rules: rules) : [],
            counterStep: recorded ? AdvisorText.counterStepLine(context.measures, rules: rules) : nil,
            nothingRecorded: recorded ? nil : AdvisorText.nothingRecorded,
            measuredFrom: offers.measureFrom.map(AdvisorText.offersMeasuredFrom),
            offersMeasureAgain: recorded,
            earlier: earlier,
            evidenceNote: AdvisorText.offersEvidenceNote(rules))
    }

    /// A sheet to record a round or an ask for the player, of the kind his mark gives and, for a loan, for what his loan
    /// is for (`loanPurpose(for:)`), opened filled with `terms`; nil when he has no mark.
    public func offerDraft(for player: PlayerID, club: String, purpose: OfferRoundDraft.Purpose,
                           filledWith terms: OfferTerms?) -> OfferRoundDraft? {
        guard let kind = offerKind(for: player) else { return nil }
        return OfferRoundDraft(player: player, kind: kind, club: club, purpose: purpose,
                               loanPurpose: kind == .loan ? loanPurpose(for: player) : nil, filledWith: terms)
    }

    /// Records the sheet: an ask, or a round of the owner's or the club's. Refused with the engine's sentence, a blank
    /// field the kind needs first, and nothing saved then; ignored, with nothing saved and nothing to say, as
    /// `recordAsk` and `recordRound` ignore it (a second click within `offersActionInterval`, a blank club, a player with
    /// no mark or not in the squads), so the sheet stays open.
    @discardableResult public func record(_ draft: OfferRoundDraft) -> OfferRecordResult {
        let terms: OfferTerms
        do {
            terms = try draft.terms()
        } catch {
            return .refused(ErrorDescriptions.describe(error))
        }
        let before = offers
        let refusal: String?
        switch draft.purpose {
        case .ask: refusal = recordAsk(for: draft.player, terms: terms)
        case .mine: refusal = recordRound(for: draft.player, club: draft.club, by: .owner, terms: terms)
        case .theirs: refusal = recordRound(for: draft.player, club: draft.club, by: .club, terms: terms)
        }
        if let refusal { return .refused(refusal) }
        return offers == before ? .ignored : .recorded
    }

    // MARK: Working it out

    /// What every suggestion in one sheet is worked out and written with.
    private struct OffersContext {
        let parameters: EngineParameters
        let money: MoneyStyle
        let measures: OfferMeasures
        /// The sentence that the engine's parameters cannot be used; nil when they can.
        let unusable: String?
        var rules: OfferRules { parameters.offerRules.value }
    }

    private func offerBlock(_ player: Player, kind: OfferKind, club typed: String,
                            context: OffersContext) -> OfferPlayerBlock {
        let entry = offers.players[player.id]
        let purpose = loanPurpose(for: player.id)
        let subject = entry?.value.map {
            OfferSubject(value: $0, wagePerWeek: player.wagePerWeek,
                         isGoalkeeper: OffersPresentation.isGoalkeeper(player),
                         purpose: purpose)
        }
        // Nothing is worked out without his value or with parameters that cannot be used: one sentence says why.
        let needs = context.unusable ?? (subject == nil ? ErrorDescriptions.describe(OfferError.missing(.value, club: nil)) : nil)
        let usable = needs == nil ? subject : nil

        var needsValue = needs
        var general: OfferSuggestionBlock?
        let asks = offers.asks.filter { $0.player == player.id && $0.kind == kind }
        if let usable {
            do {
                let suggestion = try Offers.ask(usable, kind: kind, earlier: asks, measures: context.measures,
                                                parameters: context.parameters)
                general = suggestionBlock(suggestion, kind: kind, subject: usable, club: nil, context: context)
            } catch {
                needsValue = ErrorDescriptions.describe(error)
            }
        }
        let askRows = asks.enumerated().map { index, ask in
            OfferAskRow(id: ask.id, line: AdvisorText.askLine(ask, money: context.money),
                        offersNoBid: index == asks.count - 1 && !ask.noBidCame)
        }

        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let entered = name.isEmpty ? nil : clubEntry(named: name)
        let period = context.money.period
        var clubBlock: OfferSuggestionBlock?
        var clubProblem: String?
        var clubHasOpenDeal: String?
        if !name.isEmpty {
            if let open = openDeal(for: player.id, club: name) {
                clubHasOpenDeal = AdvisorText.openDealBelow(club: open.club)
            } else if let usable, needsValue == nil {
                var figures = entered?.figures ?? Self.figures(named: name)
                figures.name = name
                do {
                    let suggestion = try Offers.proposal(usable, kind: kind, club: figures, rounds: [],
                                                         measures: context.measures, parameters: context.parameters)
                    clubBlock = suggestionBlock(suggestion, kind: kind, subject: usable, club: name, context: context)
                } catch {
                    clubProblem = ErrorDescriptions.describe(error)
                }
            }
        }

        let deals = Self.dealOrder(offers.deals.filter { $0.player == player.id && $0.kind == kind }).map {
            dealCard($0, subject: needsValue == nil ? usable : nil, live: true, context: context)
        }
        return OfferPlayerBlock(
            id: player.id, name: player.name, details: OffersPresentation.details(of: player, money: context.money),
            kind: kind, valueText: entry?.value.map(String.init) ?? "",
            valueNote: entry?.value == nil ? nil : entry?.valueDay.map(AdvisorText.enteredOn),
            purpose: kind == .loan ? purpose : nil, needsValue: needsValue, general: general, asks: askRows,
            clubName: typed,
            clubFields: ClubField.allCases.map {
                OfferFieldRow(field: $0, label: OffersPresentation.label($0, period: period),
                              text: OffersPresentation.text($0, entered?.figures, period: period))
            },
            clubNote: entered.map { AdvisorText.enteredOn($0.enteredOn) },
            clubBlock: clubBlock, clubProblem: clubProblem, clubHasOpenDeal: clubHasOpenDeal, deals: deals)
    }

    /// A deal's card. `live` for a deal of a marked player of its kind: its last round offers what can be pressed, and,
    /// while open and with a `subject`, the next step is worked out from its rounds with the club's figures as entered
    /// now, else the deal's own, else the name alone. Under "Earlier offers" the heading names the player.
    private func dealCard(_ deal: OfferDeal, subject: OfferSubject?, live: Bool, context: OffersContext) -> OfferDealCard {
        let state = deal.state
        let open = live && state == .open
        let rounds = deal.rounds.enumerated().map { index, round in
            let last = open && index == deal.rounds.count - 1
            return OfferRoundRow(line: AdvisorText.roundLine(round, club: deal.club, money: context.money),
                                 offersAnswers: last && round.by == .owner && round.answer == nil,
                                 offersAccept: last && round.by == .club && round.answer == nil)
        }
        var next: OfferSuggestionBlock?
        var problem: String?
        if open, let subject {
            let entered = clubEntry(named: deal.club)?.figures
            var figures = (entered?.hasAnyFigure == true ? entered : nil) ?? deal.figures ?? Self.figures(named: deal.club)
            figures.name = deal.club
            do {
                let suggestion = try Offers.proposal(subject, kind: deal.kind, club: figures, rounds: deal.rounds,
                                                     measures: context.measures, parameters: context.parameters)
                next = suggestionBlock(suggestion, kind: deal.kind, subject: subject, club: deal.club, context: context)
            } catch {
                problem = ErrorDescriptions.describe(error)
            }
        }
        let heading = ((live ? [] : [deal.playerName]) + [deal.club, OffersPresentation.stateWord(state)])
            .joined(separator: " · ")
        return OfferDealCard(id: deal.id, heading: heading, rounds: rounds, next: next, problem: problem, isOpen: open)
    }

    private func suggestionBlock(_ suggestion: OfferSuggestion, kind: OfferKind, subject: OfferSubject, club: String?,
                                 context: OffersContext) -> OfferSuggestionBlock {
        OfferSuggestionBlock(
            lines: AdvisorText.offerLines(suggestion, kind: kind, subject: subject, club: club, money: context.money,
                                          rules: context.rules),
            terms: OffersPresentation.terms(of: suggestion.advice))
    }

    /// A club with nothing entered but its name.
    private static func figures(named name: String) -> ClubFigures {
        ClubFigures(name: name, transferBudget: nil, wageBudgetPerWeek: nil, wagesSpentPerWeek: nil, highestWagePerWeek: nil)
    }

    /// Open deals first, then by the day of the last round, latest first; of two on one day, the one opened later first.
    private static func dealOrder(_ deals: [OfferDeal]) -> [OfferDeal] {
        deals.enumerated().sorted { a, b in
            let openA = a.element.state == .open, openB = b.element.state == .open
            if openA != openB { return openA }
            let dayA = a.element.rounds.last?.day, dayB = b.element.rounds.last?.day
            if dayA != dayB {
                guard let dayA else { return false }
                guard let dayB else { return true }
                return dayA > dayB
            }
            return a.offset > b.offset
        }.map(\.element)
    }
}
