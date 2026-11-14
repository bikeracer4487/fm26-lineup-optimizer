import Foundation
import LineupEngine

/// What the advisor screens show around the advice itself.
public enum AdvicePresentation {
    /// What an advisor screen shows in place of the advice, as Match Selection shows it in place of a plan; nil when
    /// the advice is ready.
    public static func notReady(_ state: AdviceState) -> NotReady? {
        switch state {
        case .ready:
            return nil
        case .needsSquad:
            return NotReady(message: "No squad yet. Import your first team on the Squad screen to get advice.",
                            problems: [], isFailure: false, action: MatchPresentation.goTo(.squad), screen: .squad)
        case .needsTactic(let problems) where problems.isEmpty:
            return NotReady(message: "No tactic yet. Add one on the Tactics screen to get advice.",
                            problems: [], isFailure: false, action: MatchPresentation.goTo(.tactics), screen: .tactics)
        case .needsTactic(let problems) where problems == [AppModel.noPrimaryTactic]:
            return NotReady(message: "No tactic is the primary one, so there is no advice.",
                            problems: [], isFailure: false, action: MatchPresentation.goTo(.tactics), screen: .tactics)
        case .needsTactic(let problems):
            return NotReady(message: "The primary tactic cannot be used, so there is no advice.",
                            problems: problems, isFailure: false, action: MatchPresentation.goTo(.tactics),
                            screen: .tactics)
        case .failed(let failures, let screen):
            return NotReady(message: "The advice could not be worked out.", problems: failures, isFailure: true,
                            action: MatchPresentation.goTo(screen), screen: screen)
        }
    }

    /// The report while the advice is ready; nil otherwise.
    public static func report(_ state: AdviceState) -> AdvisorsReport? {
        if case .ready(let report) = state { report } else { nil }
    }

    /// "From the squad as imported on Fri 13 Nov.": the day the advice's figures were imported.
    public static func importLine(_ day: Day) -> String {
        "From the squad as imported on \(DayText.short(day))."
    }
}
