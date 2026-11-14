import LineupAppCore
import SwiftUI

/// Who needs a holiday, a rest or watching.
public struct RestScreen: View {
    let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        AdviceGate(screen: .rest, state: model.adviceState) { _ in
            AdviceReadyLine(model: model)
        }
    }
}
