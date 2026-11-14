import LineupAppCore
import SwiftUI

/// Who to retrain for the thin slots, and how the retrainings under way are going.
public struct TrainingScreen: View {
    let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        AdviceGate(screen: .training, state: model.adviceState) { _ in
            AdviceReadyLine(model: model)
        }
    }
}
