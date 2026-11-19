import LineupAppCore
import SwiftUI

/// The Scouting screen: for now its title behind the advisor screens' gate, and nothing else; its two tabs come next.
public struct ScoutingScreen: View {
    let model: AppModel
    let navigation: Navigation

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        AdviceGate(screen: .scouting, state: model.adviceState, importLine: model.adviceImportLine) { _ in
            EmptyView()
        }
    }
}
