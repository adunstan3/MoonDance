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
    /// Full-screen hold pictures for a problem (by problem id).
    case problemPreview(String)
    /// Hold pictures with Show beta on (the Beta mark on Session).
    case problemBeta(String)
    /// Writing one hold's beta (from its callout in the hold pictures).
    case holdBeta(problemID: String, holdSet: String, position: String)
    /// Edit one problem's attempts and sends on one day (from History).
    case logEditor(problemID: String, holdSet: String, day: Date)
}

/// The swipeable pages. Session is home; History and Settings are a swipe left.
enum Page: Hashable {
    case session
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
