import SwiftUI

/// Hold set, grades, Stay open (a climbing session), saved board with Forget
/// board, Bluetooth log, and Export logs. A ScrollView rather than a List so each segment and card is
/// its own tap target.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(BoardManager.self) private var board
    @Environment(Router.self) private var router
    @Environment(ClimbingSession.self) private var climbing

    @State private var confirmForget = false

    var body: some View {
        @Bindable var settings = settings
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Hold set")
                SegmentedControl(options: HoldSet.allCases, selection: $settings.holdSet) { $0.label }

                SectionLabel(text: "Grades").padding(.top, 6)
                SegmentedControl(options: GradeScale.allCases, selection: $settings.gradeScale) { $0.label }
                Caption(settings.gradeScale == .v ? "Grades like V5" : "Grades like 6C+")

                SectionLabel(text: "Your height").padding(.top, 6)
                CardButton(title: AppSettings.heightText(settings.climberHeight),
                           subtitle: "\(AppSettings.centimetres(settings.climberHeight)) cm · climber in hold pictures",
                           titleColor: Theme.blue) {
                    router.push(.heightPicker)
                }
                .accessibilityIdentifier("climberHeight")

                SectionLabel(text: "Stay open").padding(.top, 6)
                CardButton(title: climbingTitle, subtitle: climbingSubtitle,
                           titleColor: climbing.isRunning ? Theme.green : Theme.blue) {
                    climbing.toggle()
                }
                .accessibilityIdentifier("climbingSession")
                Caption("Keeps Moondance on screen between climbs, for up to 3 hours. Nothing is saved to Health.")

                SectionLabel(text: "Board").padding(.top, 6)
                if settings.hasSavedBoard {
                    CardButton(title: "Rocky Top board",
                               subtitle: "Box ID \(savedBoardID) · saved",
                               titleColor: Theme.white) {
                        router.push(.findBoard)
                    }
                    CardButton(title: "Forget board", subtitle: "Scan again next time", titleColor: Theme.red) {
                        confirmForget = true
                    }
                } else {
                    CardButton(title: "Find board", subtitle: "No board saved yet", titleColor: Theme.blue) {
                        router.push(.findBoard)
                    }
                }
                CardButton(title: "Bluetooth log", subtitle: "Every step and error", titleColor: Theme.blue) {
                    router.push(.bluetoothLog)
                }

                SectionLabel(text: "Your logs").padding(.top, 6)
                CardButton(title: "Export logs", subtitle: "CSV by Mail or Messages", titleColor: Theme.blue) {
                    router.push(.export)
                }
                Caption(lastExportText)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Forget this board?", isPresented: $confirmForget) {
            Button("Forget board", role: .destructive) {
                settings.forgetBoard()
                board.log.add("Forgot the saved board")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Moondance will scan for the LED box again next time.")
        }
    }

    private var climbingTitle: String {
        switch climbing.state {
        case .off, .failed: "Start climbing session"
        case .starting: "Starting…"
        case .running: "End climbing session"
        }
    }

    private var climbingSubtitle: String {
        switch climbing.state {
        case .off: "Off"
        case .starting: "Asking Health for permission"
        case .running(let since): "On since \(since.formatted(date: .omitted, time: .shortened))"
        case .failed(let message): "Couldn't start: \(message)"
        }
    }

    private var savedBoardID: String {
        BoardIdentity.displayID(name: settings.boardName, identifier: settings.boardID ?? "")
    }

    private var lastExportText: String {
        guard let date = settings.lastExport else { return "Not exported yet" }
        return "Last export: \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

/// A two-or-more option pill control, as in the Settings design.
struct SegmentedControl<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isSelected = option == selection
                Text(label(option))
                    .font(.footnote.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(isSelected ? Theme.blue : .clear, in: Capsule())
                    .foregroundStyle(isSelected ? .white : Theme.secondaryText)
                    .contentShape(Capsule())
                    .onTapGesture { selection = option }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityAction { selection = option }
            }
        }
        .padding(4)
        .background(Theme.card, in: Capsule())
    }
}

/// A full-width card with a colored title and gray subtitle.
struct CardButton: View {
    let title: String
    let subtitle: String
    let titleColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(titleColor)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct Caption: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.secondaryText)
    }
}
