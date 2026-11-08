import SwiftData
import SwiftUI

/// Session is home; Projects, History and Settings are a swipe left. Pages swipe
/// sideways so the Digital Crown stays free for stepping through problems.
struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Environment(SessionModel.self) private var session

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            TabView(selection: $router.page) {
                SessionView()
                    .tag(Page.session)
                ProjectsView()
                    .tag(Page.projects)
                HistoryView()
                    .tag(Page.history)
                SettingsView()
                    .tag(Page.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
        }
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
        case .export: ExportView()
        }
    }

    /// DEBUG launch arguments for screenshots:
    /// `-openScreen list|grade|log|settings|find|export`, `-page projects|history|settings`,
    /// `-demoBoard lit|failed|connecting`, `-demoBanner attempt|sent`, `-demoLogs YES`.
    private func applyDebugLaunchArguments() {
        #if DEBUG
        if RuntimeEnvironment.debugValue("demoLogs") != nil {
            DemoData.addLogs(context: context, settings: settings)
            reload()
        }
        switch RuntimeEnvironment.debugValue("demoBoard") {
        case "lit":
            session.litProblemID = session.current?.problemId
            model.board.debugSetStatus(.lit)
        case "failed":
            session.litProblemID = session.current?.problemId
            model.board.debugSetStatus(.failed("The board didn't answer"))
        case "connecting":
            model.board.debugSetStatus(.connecting)
        default: break
        }
        switch RuntimeEnvironment.debugValue("demoBanner") {
        case "attempt": model.logAttempt()
        case "sent": model.markSent()
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
