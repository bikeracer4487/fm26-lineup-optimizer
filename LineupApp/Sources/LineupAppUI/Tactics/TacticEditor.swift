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
                    ForEach(problems, id: \.self) { CautionLine($0) }
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
        WrappingRow(alignment: .center) {
            Text("Name")
                .foregroundStyle(Theme.Colour.mutedInk)
            TextField("Name", text: Binding(get: { draft.tactic.name }, set: { name in change { $0.tactic.name = name } }))
                .labelsHidden()
                .boardField()
                .frame(width: Theme.Layout.nameFieldWidth)
        } trailing: {
            if hasChanges {
                Text("Unsaved changes")
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .foregroundStyle(Theme.Colour.amberText)
            }
            Button("Revert") { model.revertDraft(stored.id) }
                .buttonStyle(.secondary)
                .disabled(!hasChanges)
            Button("Save changes") { model.saveDraft(stored.id) }
                .buttonStyle(.primary)
                .disabled(!hasChanges || !problems.isEmpty)
        }
    }

    // MARK: The selected slot

    @ViewBuilder private var inspector: some View {
        if let selected, draft.role(at: selected.slot, in: selected.phase) != nil {
            WrappingRow(spacing: Theme.Spacing.l, pushesTrailing: false) {
                Text(TacticDraft.inspectorTitle(selected))
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading))
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
                .buttonStyle(.secondary)
            }
        } else {
            Text(TacticDraft.inspectorHint)
                .foregroundStyle(Theme.Colour.mutedInk)
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
                BoardHeading(phase.title)
                Spacer(minLength: Theme.Spacing.s)
                Text(draft.filledText(in: phase))
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
            PitchGrid(aspectRatio: Theme.Pitch.editorAspectRatio) { slot in
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

/// A slot on the editor's pitch: when filled, a magnet in its line's colour with the slot's code on it and the role
/// beneath on the board's white; when empty, a dashed circle with its code. The selected slot has an ink ring, and the
/// slots it turns into or from a marker-blue one.
struct SlotToken: View {
    enum Look { case plain, selected, linked }

    let slot: SlotID
    let role: String?
    let look: Look
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let role {
                    filled(role)
                } else {
                    EmptyMagnet(letters: slot.displayName, diameter: Theme.Pitch.emptySlotDiameter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(TacticDraft.slotHelp(slot, role: role))
        .accessibilityAddTraits(look == .selected ? .isSelected : [])
    }

    private func filled(_ role: String) -> some View {
        let colours = Theme.Colour.magnet(PitchLine(slot))
        return VStack(spacing: Theme.Spacing.xxs) {
            Magnet(fill: colours.fill, text: colours.text, letters: slot.displayName,
                   diameter: Theme.Pitch.editorMagnetDiameter, font: Theme.Typeface.display(Theme.Pitch.slotCodeSize))
                .overlay {
                    if look != .plain {
                        Circle()
                            .strokeBorder(look == .selected ? Theme.Colour.ink : Theme.Colour.markerBlue,
                                          lineWidth: Theme.Magnet.ringWidth)
                            .padding(-(Theme.Magnet.ringWidth + Theme.Magnet.ringGap))
                    }
                }
                .padding(.top, Theme.Magnet.ringWidth)
            Text(role)
                .font(Theme.Typeface.text(Theme.Pitch.roleSize, weight: .semibold))
                .foregroundStyle(Theme.Colour.ink)
                .multilineTextAlignment(.center)
                .lineLimit(Theme.Pitch.roleNameLines)
                .minimumScaleFactor(Theme.Pitch.labelMinimumScale)
                .padding(.horizontal, Theme.Pitch.labelPadding)
                .background(Theme.Colour.board)
        }
    }
}
