import LineupAppCore
import LineupEngine
import SwiftUI

/// The wall, the aluminium frame and the white board inside it, with `content` written on the board.
struct BoardFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.top, Theme.Board.topInset)
            .padding(.horizontal, Theme.Board.sideInset)
            .padding(.bottom, Theme.Board.bottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.Colour.board)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Board.cornerRadius - Theme.Board.frameWidth))
            .padding(Theme.Board.frameWidth)
            .background(Theme.Colour.frame, in: RoundedRectangle(cornerRadius: Theme.Board.cornerRadius))
            .padding(.horizontal, Theme.Board.wallMargin)
            .padding(.bottom, Theme.Board.wallMargin)
            .padding(.top, Theme.Board.titleBarClearance)
            .background(Theme.Colour.wall)
            .ignoresSafeArea(edges: .top)
            .foregroundStyle(Theme.Colour.ink)
            .font(Theme.Typeface.text())
    }
}

/// Across the top of the board: the club's name underlined in marker, the screens as pills, and the date in the
/// game on a yellow note. When they do not fit on one row, the pills go on a row of their own and wrap.
struct TopRow: View {
    let model: AppModel
    @Bindable var navigation: Navigation

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Theme.Board.topRowGap) {
                ClubTitle(text: model.boardTitle)
                pills(FlowLayout()).fixedSize()
                Spacer(minLength: 0)
                TodayNote(model: model)
            }
            .frame(minHeight: Theme.Board.topRowHeight)
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .center, spacing: Theme.Spacing.l) {
                    ClubTitle(text: model.boardTitle)
                    Spacer(minLength: 0)
                    TodayNote(model: model)
                }
                pills(FlowLayout())
            }
        }
    }

    private func pills(_ layout: FlowLayout) -> some View {
        layout {
            ForEach(Screen.allCases) { screen in
                ScreenPill(title: screen.pillTitle, isCurrent: navigation.screen == screen) { navigation.screen = screen }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Screens")
    }
}

/// The club's name in marker blue with a hand-drawn underline its own width.
struct ClubTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typeface.display(Theme.TypeSize.boardTitle))
            .foregroundStyle(Theme.Colour.markerBlue)
            .lineLimit(1)
            .fixedSize()
            .padding(.bottom, Theme.Underline.gap + Theme.Underline.thickness)
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: Theme.Underline.cornerRadius)
                    .fill(Theme.Colour.markerBlue)
                    .frame(height: Theme.Underline.thickness)
                    .rotationEffect(.degrees(Theme.Underline.tilt))
                    .accessibilityHidden(true)
            }
            .accessibilityAddTraits(.isHeader)
    }
}

/// One screen's pill: filled with ink when it is the screen shown, else outlined faintly.
struct ScreenPill: View {
    let title: String
    let isCurrent: Bool
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Pill.height / 2, style: .circular)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .bold))
                .foregroundStyle(isCurrent ? Theme.Colour.onMarker : Theme.Colour.ink)
                .padding(.horizontal, Theme.Pill.horizontalPadding)
                .frame(height: Theme.Pill.height)
                .background(isCurrent ? Theme.Colour.ink : Color.clear, in: shape)
                .overlay {
                    shape.strokeBorder(isCurrent ? Theme.Colour.ink : Theme.Colour.pillOutline,
                                       lineWidth: Theme.Pill.lineWidth)
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// The date in the game on a yellow note, with the day before, the day after and a calendar to choose another.
struct TodayNote: View {
    let model: AppModel
    @State private var choosing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            // The date on the same line as what it is, so the note is two lines high and the board keeps its height.
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Text("Today in the game")
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                Text(DayText.shortWithYear(model.settings.currentDate))
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading))
            }
            HStack(spacing: Theme.Spacing.m) {
                Button("Day before") { model.moveToday(by: -1) }
                Button("Day after") { model.moveToday(by: 1) }
                Button("Choose a day") { choosing = true }
                    .popover(isPresented: $choosing, arrowEdge: .bottom) {
                        DayPicker("Today in the game", day: today, graphical: true)
                            .labelsHidden()
                            .padding(Theme.Spacing.m)
                            .background(Theme.Colour.board)
                            .environment(\.colorScheme, .light)
                    }
            }
            .buttonStyle(.onNote)
        }
        .fixedSize()
        .padding(.horizontal, Theme.Sticky.horizontalPadding)
        .padding(.vertical, Theme.Sticky.verticalPadding)
        .stickyNote(Theme.Note.today, tilt: Theme.Sticky.todayTilt)
        .help("Fixtures before this day count as played. Each import is dated with it.")
    }

    private var today: Binding<Day> {
        Binding(get: { model.settings.currentDate }, set: { day in
            var settings = model.settings
            settings.currentDate = day
            model.update(settings)
        })
    }
}

/// The model's notices, each on a pink note with a button that dismisses it.
struct NoticeNotes: View {
    let model: AppModel

    var body: some View {
        if !model.notices.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ForEach(Array(model.notices.enumerated()), id: \.element.id) { index, notice in
                    WarningNote(tilt: NoteTilt.degrees(at: index)) {
                        HStack(alignment: .center, spacing: Theme.Spacing.m) {
                            Text(notice.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: Theme.Spacing.m)
                            Button("Dismiss") { model.dismiss(notice) }
                                .buttonStyle(.onNote)
                        }
                    }
                    .frame(maxWidth: Theme.Sticky.noticeMaximumWidth, alignment: .leading)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }
}
