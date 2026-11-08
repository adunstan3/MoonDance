import SwiftData
import SwiftUI

/// Session is home; the other pages are a swipe left. Pages swipe sideways so
/// the Digital Crown stays free for stepping through problems.
struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(BoardManager.self) private var board
    @State private var router = Router()
    @State private var session = SessionModel()

    var body: some View {
        NavigationStack(path: $router.path) {
            TabView(selection: $router.page) {
                SessionView()
                    .tag(Page.session)
                SettingsView()
                    .tag(Page.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
        }
        .environment(router)
        .environment(session)
        .onAppear {
            session.reload(context: context, settings: settings)
            offerFindBoardOnFirstLaunch()
            applyDebugLaunchArguments()
        }
        .onChange(of: settings.holdSet) { reload() }
        .onChange(of: settings.lastGrade) { reload() }
        .onChange(of: settings.benchmarksOnly) { reload() }
    }

    /// First launch with no saved box: open Find board once (it has a Not now button).
    private func offerFindBoardOnFirstLaunch() {
        let key = "offeredFindBoard"
        guard !settings.hasSavedBoard, !settings.defaults.bool(forKey: key) else { return }
        settings.defaults.set(true, forKey: key)
        router.push(.findBoard)
    }

    private func reload() {
        session.reload(context: context, settings: settings)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .problemList: ProblemListView()
        case .gradePicker: GradePickerView()
        case .bluetoothLog: BluetoothLogView()
        case .settings: SettingsView()
        case .findBoard: FindBoardView()
        case .export: Text("Export comes in milestone 6")
        }
    }

    /// `-openScreen list|grade|log` and `-page projects` jump straight to a screen (DEBUG only).
    private func applyDebugLaunchArguments() {
        #if DEBUG
        switch RuntimeEnvironment.debugValue("demoBoard") {
        case "lit":
            session.litProblemID = session.current?.problemId
            board.debugSetStatus(.lit)
        case "failed":
            session.litProblemID = session.current?.problemId
            board.debugSetStatus(.failed("The board didn't answer"))
        case "connecting":
            board.debugSetStatus(.connecting)
        default: break
        }
        #endif
        switch RuntimeEnvironment.debugValue("page") {
        case "projects": router.page = .projects
        case "history": router.page = .history
        case "settings": router.page = .settings
        default: break
        }
        switch RuntimeEnvironment.debugValue("openScreen") {
        case "list": router.push(.problemList)
        case "grade": router.push(.gradePicker)
        case "log": router.push(.bluetoothLog)
        case "settings": router.push(.settings)
        case "find": router.push(.findBoard)
        case "export": router.push(.export)
        default: break
        }
    }
}
