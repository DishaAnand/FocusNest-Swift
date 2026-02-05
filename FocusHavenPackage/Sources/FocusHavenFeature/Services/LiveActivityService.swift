import ActivityKit
import Foundation

/// Service to manage Live Activities for the focus timer
@MainActor
@Observable
public final class LiveActivityService {
    private var currentActivity: Activity<FocusTimerAttributes>?

    public init() {}

    /// Check if Live Activities are supported and enabled
    public var isSupported: Bool {
        let supported = ActivityAuthorizationInfo().areActivitiesEnabled
        print("📱 Live Activities supported: \(supported)")
        return supported
    }

    /// Start a new Live Activity for the timer
    public func startActivity(
        remainingSeconds: Int,
        totalSeconds: Int,
        mode: String,
        taskName: String?
    ) {
        print("📱 startActivity called - remaining: \(remainingSeconds)s, mode: \(mode), task: \(taskName ?? "none")")

        guard isSupported else {
            print("📱 Live Activities not supported or disabled - check Settings > FocusHaven > Live Activities")
            return
        }

        // End any existing activity first
        Task {
            await endActivity()

            // Start new activity after ending old one
            await MainActor.run {
                let attributes = FocusTimerAttributes(taskName: taskName)
                let endTime = Date().addingTimeInterval(TimeInterval(remainingSeconds))
                let state = FocusTimerAttributes.ContentState(
                    endTime: endTime,
                    totalSeconds: totalSeconds,
                    mode: mode,
                    isPaused: false
                )

                do {
                    let activity = try Activity.request(
                        attributes: attributes,
                        content: .init(state: state, staleDate: nil),
                        pushType: nil
                    )
                    self.currentActivity = activity
                    print("📱 Live Activity started successfully! ID: \(activity.id)")
                } catch {
                    print("📱 Failed to start Live Activity: \(error.localizedDescription)")
                    print("📱 Error details: \(error)")
                }
            }
        }
    }

    /// Update the Live Activity (e.g., when paused/resumed)
    public func updateActivity(
        remainingSeconds: Int,
        totalSeconds: Int,
        mode: String,
        isPaused: Bool
    ) async {
        guard let activity = currentActivity else { return }

        let endTime = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let state = FocusTimerAttributes.ContentState(
            endTime: endTime,
            totalSeconds: totalSeconds,
            mode: mode,
            isPaused: isPaused
        )

        await activity.update(.init(state: state, staleDate: nil))
        print("📱 Live Activity updated - paused: \(isPaused), remaining: \(remainingSeconds)s")
    }

    /// End the Live Activity
    public func endActivity() async {
        guard let activity = currentActivity else { return }

        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
        print("📱 Live Activity ended")
    }

    /// End all Live Activities (cleanup)
    public func endAllActivities() async {
        for activity in Activity<FocusTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        print("📱 All Live Activities ended")
    }
}
