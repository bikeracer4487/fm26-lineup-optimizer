import LineupAppCore
import SwiftUI

/// The first and second elevens for a tactic, and the cover for every slot.
public struct ElevensScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        AdviceGate(screen: .elevens, state: model.adviceState) { _ in
            AdviceReadyLine(model: model)
        }
    }
}
