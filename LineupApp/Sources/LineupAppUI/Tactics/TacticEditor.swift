import LineupAppCore
import LineupEngine
import SwiftUI

/// One tactic being changed: its name, the two shapes on pitches side by side, the selected slot's role and what it
/// turns into, and the problems that stop it being saved. Changes are the model's unsaved draft of the tactic,
/// kept until saved or reverted, whichever tactic or screen is shown meanwhile.
struct TacticEditor: View {
    let model: AppModel
    let stored: StoredTactic
    /// Filling: the pitches side by side fill the height left. Scrolling: side by side, sized by width. Stacked: one
    /// above the other.
    let layout: PageLayout
    @State private var selected: TacticSlot?

    /// - Parameter selected: the slot selected when the editor opens.
    init(model: AppModel, stored: StoredTactic, layout: PageLayout, selected: TacticSlot? = nil) {
        self.model = model
        self.stored = stored
        self.layout = layout
        _selected = State(initialValue: selected)
    }

    private var draft: TacticDraft {
        model.draft(for: stored.id) ?? TacticDraft(stored.tactic)
    }

    /// Applies `edit` to the model's draft of the tactic.
    private func change(_ edit: (inout TacticDraft) -> Void) {
        var changed = draft
        edit(&changed)
        model.setDraft(changed, for: stored.id)
    }

    private var hasChanges: Bool { model.hasUnsavedChanges(stored.id) }

    private var problems: [String] {
        model.problems(saving: StoredTactic(id: stored.id, tactic: draft.tactic))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            header
            inspector
                .frame(minHeight: Theme.Layout.controlRowHeight)
            pitches
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

    @ViewBuilder private var pitches: some View {
        switch layout {
        case .filling, .scrolling:
            HStack(alignment: .top, spacing: Theme.Spacing.l) {
                pitch(.inPossession)
                pitch(.outOfPossession)
            }
        case .stacked:
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                pitch(.inPossession)
                pitch(.outOfPossession)
            }
            .frame(maxWidth: Theme.Pitch.scrollingMaximumWidth)
        }
    }

    // MARK: Name and saving

    private var header: some View {
        WrappingRow(alignment: .firstTextBaseline) {
            Text("Name")
                .font(Theme.Typeface.text())
            TextField("Name", text: Binding(get: { draft.tactic.name }, set: { name in change { $0.tactic.name = name } }))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .frame(width: Theme.Layout.nameFieldWidth)
        } trailing: {
            if hasChanges {
                Text("Unsaved changes")
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
            }
            Button("Revert") { model.revertDraft(stored.id) }
                .disabled(!hasChanges)
            Button("Save changes") { model.saveDraft(stored.id) }
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges || !problems.isEmpty)
        }
    }

    // MARK: The selected slot

    @ViewBuilder private var inspector: some View {
        if let selected, draft.role(at: selected.slot, in: selected.phase) != nil {
            WrappingRow(spacing: Theme.Spacing.l, pushesTrailing: false) {
                Text(TacticDraft.inspectorTitle(selected))
                    .font(Theme.Typeface.text(weight: .semibold))
                Picker("Role", selection: roleBinding(selected)) {
                    ForEach(draft.roleChoices(at: selected, catalog: model.catalog), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .fixedSize()
            } trailing: {
                if selected.phase == .inPossession {
                    Picker("Becomes, out of possession", selection: targetBinding(selected.slot)) {
                        if draft.tactic.mapping[selected.slot] == nil {
                            Text(TacticDraft.noTargetYet).tag(SlotID?.none)
                        }
                        ForEach(draft.targetChoices(for: selected.slot), id: \.self) { target in
                            Text(draft.targetName(target)).tag(SlotID?.some(target))
                        }
                    }
                    .fixedSize()
                }
                Button("Remove") {
                    change { $0.toggle(selected.slot, in: selected.phase, catalog: model.catalog) }
                    self.selected = nil
                }
            }
        } else {
            Text(TacticDraft.inspectorHint)
                .font(Theme.Typeface.text())
                .foregroundStyle(.secondary)
        }
    }

    private func roleBinding(_ selected: TacticSlot) -> Binding<String> {
        Binding(
            get: { draft.role(at: selected.slot, in: selected.phase) ?? "" },
            set: { role in change { $0.setRole(role, at: selected.slot, in: selected.phase) } })
    }

    private func targetBinding(_ slot: SlotID) -> Binding<SlotID?> {
        Binding(
            get: { draft.tactic.mapping[slot] },
            set: { target in
                if let target { change { $0.map(slot, to: target) } }
            })
    }

    // MARK: Pitches

    private func pitch(_ phase: Phase) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(phase.title)
                    .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                Spacer(minLength: Theme.Spacing.s)
                Text(draft.filledText(in: phase))
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
            change { $0.toggle(place.slot, in: place.phase, catalog: model.catalog) }
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
        .help(TacticDraft.slotHelp(slot, role: role))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Pitch.tokenCornerRadius)
    }

    private func filled(_ role: String) -> some View {
        VStack(spacing: 0) {
            Text(slot.displayName)
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
        Text(slot.displayName)
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
