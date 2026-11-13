import LineupAppCore
import LineupEngine
import SwiftUI

/// The saved tactics, and the editor for the one chosen: both shapes, a role for each slot, and what each
/// in-possession slot turns into out of possession.
public struct TacticsScreen: View {
    let model: AppModel
    let startingSlot: TacticSlot?
    @State private var chosen: UUID?
    @State private var deleting: StoredTactic?

    /// - Parameter startingSlot: the slot the editor opens with selected.
    public init(model: AppModel, startingSlot: TacticSlot? = nil) {
        self.model = model
        self.startingSlot = startingSlot
    }

    /// The chosen tactic, or the primary when none is chosen or the chosen one was deleted.
    private var shown: StoredTactic? {
        model.tactics.first { $0.id == chosen } ?? model.primaryTactic ?? model.tactics.first
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(Screen.tactics.title)
                .font(Theme.Typeface.title())
            if model.tactics.isEmpty {
                EmptyState("No tactics yet. Start from a 4-2-3-1 and change it to yours.",
                           action: "New tactic", perform: addTactic)
                Spacer(minLength: 0)
            } else {
                list
                if let shown {
                    TacticEditor(model: model, stored: shown, selected: startingSlot)
                        .id(shown.id)
                }
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert(deleting.map { "Delete \($0.tactic.name)?" } ?? "", isPresented: isDeleting, presenting: deleting) { tactic in
            Button("Delete", role: .destructive) {
                model.deleteTactic(tactic.id)
                chosen = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Fixtures that use it will use the primary tactic.")
        }
    }

    /// The saved tactics as a menu, the primary marked, with what can be done to them. A menu rather than a
    /// column, so the two pitches have the window's width.
    private var list: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            Picker("Tactic", selection: Binding(get: { shown?.id }, set: { chosen = $0 })) {
                ForEach(model.tactics) { stored in
                    Text(stored.id == model.settings.primaryTacticID ? "\(stored.tactic.name) (primary)" : stored.tactic.name)
                        .tag(UUID?.some(stored.id))
                }
            }
            .fixedSize()
            Spacer(minLength: Theme.Spacing.m)
            Button("New tactic", action: addTactic)
            Button("Duplicate") {
                if let shown, let copy = model.duplicateTactic(shown.id) { chosen = copy }
            }
            Button("Make primary") {
                if let shown { model.makePrimary(shown.id) }
            }
            .disabled(shown?.id == model.settings.primaryTacticID)
            .help("Fixtures use the primary tactic unless they name another.")
            Button("Delete") { deleting = shown }
        }
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func addTactic() {
        chosen = model.addTactic(named: model.unusedTacticName("New tactic"))
    }
}
