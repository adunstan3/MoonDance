import Foundation
import HealthKit
import Observation

/// Keeps Moondance on screen between climbs. watchOS normally drops back to the
/// clock a couple of minutes after the wrist goes down; while a workout session
/// runs, raising the wrist shows the app instead. Apple's guidance is to use a
/// workout session (not an extended runtime session) for strenuous activity.
///
/// The session runs without a workout builder, so nothing is saved to Health.
/// It ends when turned off in Settings, or by itself after `maxDuration`.
@Observable
final class ClimbingSession: NSObject {
    enum State: Equatable {
        case off
        case starting
        case running(since: Date)
        case failed(String)
    }

    /// A session left on ends by itself after this long.
    static let maxDuration: Duration = .seconds(3 * 60 * 60)

    private(set) var state: State = .off

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var sessionID = UUID()

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func toggle() {
        switch state {
        case .running, .starting: stop()
        case .off, .failed: Task { await start() }
        }
    }

    func start() async {
        guard session == nil else { return }
        guard isAvailable else {
            state = .failed("Health isn't available on this watch")
            return
        }
        state = .starting
        do {
            // Starting a workout session needs permission to write workouts,
            // even though this one never saves one.
            try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .climbing
            configuration.locationType = .indoor
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            session.delegate = self
            self.session = session
            let start = Date.now
            session.startActivity(with: start)
            state = .running(since: start)
            endAutomatically()
        } catch {
            session = nil
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        session?.end()
        session = nil
        sessionID = UUID()
        state = .off
    }

    private func endAutomatically() {
        let id = sessionID
        Task { [weak self] in
            try? await Task.sleep(for: Self.maxDuration)
            guard let self, self.sessionID == id, self.isRunning else { return }
            self.stop()
        }
    }
}

extension ClimbingSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState, date: Date) {
        guard toState == .ended || toState == .stopped else { return }
        Task { @MainActor [weak self] in
            guard let self, self.session === workoutSession else { return }
            self.session = nil
            self.state = .off
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, self.session === workoutSession else { return }
            self.session = nil
            self.state = .failed(message)
        }
    }
}
