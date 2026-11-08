import Observation
import SwiftUI

/// Screens pushed on the navigation stack.
enum Route: Hashable {
    case problemList
    case gradePicker
    case settings
    case bluetoothLog
    case findBoard
    case export
}

/// The swipeable pages. Session is home; Projects and History are a swipe left.
enum Page: Hashable {
    case session
    case projects
    case history
    case settings
}

/// One navigation state for the whole app, so taps, deep links and debug
/// launch arguments can all push screens.
@Observable
final class Router {
    var path = NavigationPath()
    var page: Page = .session

    func push(_ route: Route) { path.append(route) }

    func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    func popToRoot() { path = NavigationPath() }

    /// Back to the Session page with nothing pushed.
    func showSession() {
        popToRoot()
        page = .session
    }
}
