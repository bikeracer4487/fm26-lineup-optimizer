import Foundation

/// A change to one player's match-day value for one fixture, with the reason the manager is shown.
///
/// The selector applies it as `value × factor − cost`; it computes none itself. A factor below 1 or a
/// cost above 0 holds a player back; a factor above 1 or a negative cost (a bonus) favours him.
public struct Adjustment: Equatable, Sendable {
    /// Why the value changed. The case order is the order adjustments are applied, listed and named.
    public enum Kind: String, CaseIterable, Sendable {
        case loanedIn, consecutiveStarts, needsSharpness, development, retraining, stability, savedForLater
    }

    public let kind: Kind
    /// Multiplies the match-day value; 1 changes nothing.
    public let factor: Double
    /// Subtracted from the match-day value, in rating points; 0 changes nothing.
    public let cost: Double
    /// A full sentence fragment the pick shows as it is.
    public let reason: String

    /// - Precondition: `factor` is finite and not negative, and `cost` is finite. Anything else is a
    ///   fault in the caller's arithmetic, not data from the game, so it stops the program.
    public init(kind: Kind, factor: Double = 1, cost: Double = 0, reason: String) {
        precondition(factor.isFinite && factor >= 0, "Adjustment factor must be finite and not negative, got \(factor) (\(kind))")
        precondition(cost.isFinite, "Adjustment cost must be finite, got \(cost) (\(kind))")
        self.kind = kind; self.factor = factor; self.cost = cost; self.reason = reason
    }

    /// True when it lowers the value: a factor below 1 or a cost above 0.
    var holdsBack: Bool { factor < 1 || cost > 0 }
}
