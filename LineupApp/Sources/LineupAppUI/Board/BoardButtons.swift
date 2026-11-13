import SwiftUI

/// The board's buttons: primary filled with ink, secondary an ink outline, the one main action on a screen filled with
/// marker blue, and a small button written on a sticky note in the note's ink.
struct BoardButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, main, onNote }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        BoardButtonLabel(kind: kind, label: configuration.label, isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BoardButtonStyle {
    static var primary: BoardButtonStyle { BoardButtonStyle(kind: .primary) }
    static var secondary: BoardButtonStyle { BoardButtonStyle(kind: .secondary) }
    static var main: BoardButtonStyle { BoardButtonStyle(kind: .main) }
    static var onNote: BoardButtonStyle { BoardButtonStyle(kind: .onNote) }
}

private struct BoardButtonLabel<Label: View>: View {
    let kind: BoardButtonStyle.Kind
    let label: Label
    let isPressed: Bool
    @Environment(\.isEnabled) private var isEnabled

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Button.cornerRadius) }

    var body: some View {
        styled
            .opacity(isEnabled ? (isPressed ? Theme.Button.pressedOpacity : 1) : Theme.Button.disabledOpacity)
            .contentShape(shape)
    }

    @ViewBuilder private var styled: some View {
        switch kind {
        case .primary:
            label
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                .foregroundStyle(Theme.Colour.onMarker)
                .padding(.horizontal, Theme.Button.horizontalPadding)
                .frame(minHeight: Theme.Button.height)
                .background(Theme.Colour.ink, in: shape)
        case .secondary:
            label
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                .foregroundStyle(Theme.Colour.ink)
                .padding(.horizontal, Theme.Button.horizontalPadding)
                .frame(minHeight: Theme.Button.height)
                .overlay { shape.strokeBorder(Theme.Colour.ink, lineWidth: Theme.Button.lineWidth) }
        case .main:
            label
                .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .extraBold))
                .foregroundStyle(Theme.Colour.onMarker)
                .padding(.horizontal, Theme.Button.mainHorizontalPadding)
                .frame(minHeight: Theme.Button.mainHeight)
                .background(Theme.Colour.markerBlue, in: shape)
        case .onNote:
            label
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
                .underline()
        }
    }
}

/// A text field written on the board: white, with an ink outline, in the text face.
struct BoardFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(Theme.Typeface.text())
            .foregroundStyle(Theme.Colour.ink)
            .padding(.horizontal, Theme.Field.horizontalPadding)
            .frame(height: Theme.Field.height)
            .background(Theme.Colour.field, in: RoundedRectangle(cornerRadius: Theme.Field.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Field.cornerRadius)
                    .strokeBorder(Theme.Colour.ink, lineWidth: Theme.Field.lineWidth)
            }
    }
}

extension View {
    func boardField() -> some View { modifier(BoardFieldModifier()) }
}

/// Choices written on the board as tabs, the chosen one underlined in marker blue. Each is a button, chosen with a
/// click or with the keyboard, and says to assistive technology which is chosen.
struct BoardTabs<Value: Hashable>: View {
    let choices: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: Theme.Tab.gap) {
            ForEach(choices, id: \.value) { choice in
                let isChosen = choice.value == selection
                Button { selection = choice.value } label: {
                    Text(choice.title)
                        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                        .foregroundStyle(isChosen ? Theme.Colour.ink : Theme.Colour.mutedInk)
                        .padding(.horizontal, Theme.Tab.horizontalPadding)
                        .frame(height: Theme.Tab.height)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isChosen ? Theme.Colour.markerBlue : Color.clear)
                                .frame(height: Theme.Tab.underline)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isChosen ? .isSelected : [])
            }
        }
        .fixedSize()
    }
}
