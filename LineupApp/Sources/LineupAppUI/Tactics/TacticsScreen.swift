import LineupAppCore
import LineupEngine
import SwiftUI

/// The saved tactics, and the editor for the one chosen: both shapes, a role for each slot, and what each
/// in-possession slot turns into out of possession.
public struct TacticsScreen: View {
    let model: AppModel
    let navigation: Navigation
    let startingSlot: TacticSlot?
    @State private var deleting: StoredTactic?
    @State private var layout = PageLayout(Theme.Layout.defaultWindow)

    /// - Parameter startingSlot: the slot the editor opens with selected.
    public init(model: AppModel, navigation: Navigation, startingSlot: TacticSlot? = nil) {
        self.model = model
        self.navigation = navigation
        self.startingSlot = startingSlot
    }

    /// The chosen tactic, or the primary when none is chosen or the chosen one was deleted.
    private var shown: StoredTactic? {
        model.tactics.first { $0.id == navigation.tacticID } ?? model.primaryTactic ?? model.tactics.first
    }

    private var chosen: UUID? {
        get { navigation.tacticID }
        nonmutating set { navigation.tacticID = newValue }
    }

    public var body: some View {
        Group {
            if layout.scrolls {
                ScrollView(.vertical) { page }
            } else {
                page
            }
        }
        .onGeometryChange(for: PageLayout.self) { PageLayout($0.size) } action: { layout = $0 }
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

    private var page: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if model.tactics.isEmpty {
                BoardHeading(Screen.tactics.title, size: Theme.TypeSize.title)
                EmptyState("No tactics yet. Start from a 4-2-3-1 and change it to yours.",
                           action: "New tactic", perform: addTactic)
                Spacer(minLength: 0)
            } else {
                list
                if let shown {
                    TacticEditor(model: model, stored: shown, layout: layout, selected: startingSlot)
                        .id(shown.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: layout.scrolls ? nil : .infinity, alignment: .topLeading)
    }

    /// The saved tactics as a menu, the primary and those with unsaved changes marked, with what can be done to
    /// them. A menu rather than a column, so the two pitches have the window's width.
    private var list: some View {
        WrappingRow(alignment: .center) {
            BoardHeading(Screen.tactics.title, size: Theme.TypeSize.title)
                .padding(.trailing, Theme.Spacing.m)
            Picker("Tactic", selection: Binding(get: { shown?.id }, set: { chosen = $0 })) {
                ForEach(model.tactics) { stored in
                    Text(model.menuTitle(of: stored.id))
                        .tag(UUID?.some(stored.id))
                }
            }
            .font(Theme.Typeface.text())
            .fixedSize()
        } trailing: {
            Button("New tactic", action: addTactic)
                .buttonStyle(.secondary)
            Button("Duplicate") {
                if let shown, let copy = model.duplicateTactic(shown.id) { chosen = copy }
            }
            .buttonStyle(.secondary)
            Button("Make primary") {
                if let shown { model.makePrimary(shown.id) }
            }
            .buttonStyle(.secondary)
            .disabled(shown?.id == model.settings.primaryTacticID)
            .help("Fixtures use the primary tactic unless they name another.")
            Button("Delete") { deleting = shown }
                .buttonStyle(.secondary)
        }
    }

    private var isDeleting: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func addTactic() {
        chosen = model.addTactic(named: model.unusedTacticName("New tactic"))
    }
}
