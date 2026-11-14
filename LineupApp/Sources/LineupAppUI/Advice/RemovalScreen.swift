import LineupAppCore
import SwiftUI

/// Who to sell, loan out or release, and the loans to the club.
public struct RemovalScreen: View {
    let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        AdviceGate(screen: .removal, state: model.adviceState) { _ in
            AdviceReadyLine(model: model)
        }
    }
}
