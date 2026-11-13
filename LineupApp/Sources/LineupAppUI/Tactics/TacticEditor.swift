import LineupAppCore
import LineupEngine
import SwiftUI

/// One tactic being changed: its name, the two shapes on pitches side by side, the selected slot's role and what it
/// turns into, and the problems that stop it being saved. Changes are kept in a draft until saved; leaving the
/// tactic discards them.
struct TacticEditor: View {
    let model: AppModel
    let stored: StoredTactic
    @State private var draft: TacticDraft
    @State private var selected: TacticSlot?

    /// - Parameter selected: the slot selected when the editor opens.
    init(model: AppModel, stored: StoredTactic, selected: TacticSlot? = nil) {
        self.model = model
        self.stored = stored
        _draft = State(initialValue: TacticDraft(stored.tactic))
        _selected = State(initialValue: selected)
    }

    private var hasChanges: Bool { draft.tactic != stored.tactic }

    private var problems: [String] {
        model.problems(saving: StoredTactic(id: stored.id, tactic: draft.tactic))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            header
            inspector
                .frame(minHeight: Theme.Layout.controlRowHeight)
            HStack(alignment: .top, spacing: Theme.Spacing.l) {
                pitch(.inPossession)
                pitch(.outOfPossession)
            }
            if !problems.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(problems, id: \.self) { problem in
                        MarkedText(problem, colour: Theme.Colour.amber)
                    }
                }
                .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
            }
        }
    }

    // MARK: Name and saving

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Text("Name")
                .font(Theme.Typeface.text())
            TextField("Name", text: $draft.tactic.name)
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(width: Theme.Layout.nameFieldWidth)
            Spacer(minLength: Theme.Spacing.m)
            if hasChanges {
                Text("Unsaved changes")
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
            }
            Button("Revert") {
                draft = TacticDraft(stored.tactic)
            }
            .disabled(!hasChanges)
            Button("Save changes", action: save)
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges || !problems.isEmpty)
        }
    }

    private func save() {
        var tactic = draft.tactic
        tactic.name = tactic.name.trimmingCharacters(in: .whitespacesAndNewlines)
        model.update(StoredTactic(id: stored.id, tactic: tactic))
        draft = TacticDraft(tactic)
    }

    // MARK: The selected slot

    @ViewBuilder private var inspector: some View {
        if let selected, let role = draft.role(at: selected.slot, in: selected.phase) {
            HStack(alignment: .center, spacing: Theme.Spacing.l) {
                Text("\(PitchLayout.label(of: selected.slot)), \(phaseName(selected.phase))")
                    .font(Theme.Typeface.text(weight: .semibold))
                Picker("Role", selection: roleBinding(selected)) {
                    ForEach(roleNames(selected, current: role), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .fixedSize()
                if selected.phase == .inPossession {
                    Picker("Becomes, out of possession", selection: targetBinding(selected.slot)) {
                        if draft.tactic.mapping[selected.slot] == nil {
                            Text("Nothing yet").tag(SlotID?.none)
                        }
                        ForEach(draft.targetChoices(for: selected.slot), id: \.self) { target in
                            Text(targetName(target)).tag(SlotID?.some(target))
                        }
                    }
                    .fixedSize()
                }
                Button("Remove") {
                    draft.toggle(selected.slot, in: selected.phase, catalog: model.catalog)
                    self.selected = nil
                }
                Spacer(minLength: 0)
            }
        } else {
            Text("Click a place on either pitch to add a slot there, or a filled slot to change its role.")
                .font(Theme.Typeface.text())
                .foregroundStyle(.secondary)
        }
    }

    /// The roles the catalogue allows at the slot, with the current one added if the catalogue does not list it
    /// there, so the menu can show it.
    private func roleNames(_ selected: TacticSlot, current: String) -> [String] {
        let allowed = model.catalog.roles(phase: selected.phase, at: selected.slot.position).map(\.name)
        return allowed.contains(current) ? allowed : [current] + allowed
    }

    private func roleBinding(_ selected: TacticSlot) -> Binding<String> {
        Binding(
            get: { draft.role(at: selected.slot, in: selected.phase) ?? "" },
            set: { draft.setRole($0, at: selected.slot, in: selected.phase) })
    }

    private func targetName(_ target: SlotID) -> String {
        let label = PitchLayout.label(of: target)
        if draft.role(at: target, in: .outOfPossession) == nil {
            return "\(label) (empty)"
        }
        return draft.unmappedTargets.contains(target) ? "\(label) (nothing turns into it yet)" : label
    }

    private func targetBinding(_ slot: SlotID) -> Binding<SlotID?> {
        Binding(
            get: { draft.tactic.mapping[slot] },
            set: { target in
                if let target { draft.map(slot, to: target) }
            })
    }

    private func phaseName(_ phase: Phase) -> String {
        switch phase {
        case .inPossession: "in possession"
        case .outOfPossession: "out of possession"
        }
    }

    // MARK: Pitches

    private func pitch(_ phase: Phase) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(phase == .inPossession ? "In possession" : "Out of possession")
                    .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                Spacer(minLength: Theme.Spacing.s)
                Text("\(draft.filled(in: phase)) of 11 slots filled")
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
            }
            PitchGrid { slot in
                SlotToken(slot: slot, role: draft.role(at: slot, in: phase), look: look(of: TacticSlot(slot, in: phase))) {
                    click(TacticSlot(slot, in: phase))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Clicking an empty slot adds it; either way the slot is then selected.
    private func click(_ place: TacticSlot) {
        if draft.role(at: place.slot, in: place.phase) == nil {
            draft.toggle(place.slot, in: place.phase, catalog: model.catalog)
        }
        selected = place
    }

    /// Selected; or linked to the selected slot, as what it turns into or what turns into it; or neither.
    private func look(of place: TacticSlot) -> SlotToken.Look {
        guard let selected else { return .plain }
        if place == selected { return .selected }
        return draft.linked(to: selected).contains(place) ? .linked : .plain
    }
}

/// A slot on the editor's pitch: its code and role when filled, a dashed outline with its code when empty.
struct SlotToken: View {
    enum Look { case plain, selected, linked }

    let slot: SlotID
    let role: String?
    let look: Look
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if let role {
                filled(role)
            } else {
                empty
            }
        }
        .buttonStyle(.plain)
        .help(role.map { "\(PitchLayout.label(of: slot)): \($0)" } ?? "Add a slot at \(PitchLayout.label(of: slot))")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Pitch.tokenCornerRadius)
    }

    private func filled(_ role: String) -> some View {
        VStack(spacing: 0) {
            Text(PitchLayout.label(of: slot))
                .font(Theme.Typeface.number(Theme.TypeSize.step1))
            Text(role)
                .font(Theme.Typeface.text())
                .multilineTextAlignment(.center)
                .lineLimit(Theme.Pitch.roleNameLines)
                .minimumScaleFactor(Theme.Pitch.roleNameMinimumScale)
        }
        .foregroundStyle(look == .selected ? Theme.Colour.turf : Theme.Colour.chalk)
        .padding(Theme.Pitch.tokenPadding)
        // Every filled token takes its whole cell, so the codes along a row line up.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            // Turf first, so the pitch's markings do not show through the token.
            shape.fill(Theme.Colour.turf)
            shape.fill(look == .selected ? Theme.Colour.chalk : Theme.Colour.chalk.opacity(Theme.Pitch.tokenFillOpacity))
        }
        .overlay {
            if look == .linked {
                shape.strokeBorder(Theme.Colour.chalk, lineWidth: Theme.Pitch.linkedLineWidth)
            }
        }
        .contentShape(shape)
    }

    private var empty: some View {
        Text(PitchLayout.label(of: slot))
            .font(Theme.Typeface.number(Theme.TypeSize.base))
            .foregroundStyle(Theme.Colour.chalk.opacity(Theme.Pitch.emptyTokenOpacity))
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Pitch.emptyTokenHeight)
            .background(shape.fill(Theme.Colour.turf))
            .overlay {
                shape.strokeBorder(Theme.Colour.chalk.opacity(Theme.Pitch.emptyTokenOpacity),
                                   style: StrokeStyle(lineWidth: Theme.Pitch.emptyTokenLineWidth,
                                                      dash: Theme.Pitch.emptyTokenDash))
            }
            .contentShape(shape)
    }
}
