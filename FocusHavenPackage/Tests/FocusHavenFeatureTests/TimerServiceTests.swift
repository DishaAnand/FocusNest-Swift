import Testing
import Foundation
@testable import FocusHavenFeature

@Suite("TimerService Tests")
@MainActor
struct TimerServiceTests {
    @Test("Timer service initializes with correct defaults")
    func timerServiceInitializesCorrectly() async throws {
        let settings = UserSettings()
        settings.focusDuration = 25 * 60
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())
        #expect(service.state == .idle)
        #expect(service.mode == .focus)
        #expect(service.remainingTime == 25 * 60)
        #expect(service.totalDuration == 25 * 60)
        #expect(service.completedSessions == 0)
        #expect(service.selectedTask == nil)
    }

    @Test("Timer service formats time correctly")
    func timerServiceFormatsTime() async throws {
        let settings = UserSettings()
        settings.focusDuration = 25 * 60
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())
        #expect(service.formattedTime == "25:00")
    }

    @Test("Timer service identifies break mode correctly")
    func timerServiceIdentifiesBreakMode() async throws {
        let settings = UserSettings()
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())
        service.setMode(.focus)
        #expect(service.isBreak == false)
        service.setMode(.shortBreak)
        #expect(service.isBreak == true)
        service.setMode(.longBreak)
        #expect(service.isBreak == true)
    }

    @Test("Timer service can set mode")
    func timerServiceCanSetMode() async throws {
        let settings = UserSettings()
        settings.focusDuration = 25 * 60
        settings.breakDuration = 5 * 60
        settings.longBreakDuration = 15 * 60
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())
        service.setMode(.focus)
        #expect(service.mode == .focus)
        #expect(service.remainingTime == 25 * 60)
        service.setMode(.shortBreak)
        #expect(service.mode == .shortBreak)
        #expect(service.remainingTime == 5 * 60)
        service.setMode(.longBreak)
        #expect(service.mode == .longBreak)
        #expect(service.remainingTime == 15 * 60)
    }

    @Test("Timer service state transitions work correctly")
    func timerServiceStateTransitions() async throws {
        let settings = UserSettings()
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())
        #expect(service.state == .idle)
        #expect(service.isRunning == false)
        #expect(service.isPaused == false)
        service.start()
        #expect(service.state == .running)
        #expect(service.isRunning == true)
        service.pause()
        #expect(service.state == .paused)
        #expect(service.isPaused == true)
        service.resume()
        #expect(service.state == .running)
        service.stop()
        #expect(service.state == .idle)
    }

    @Test("Timer service toggle play pause works correctly")
    func timerServiceTogglePlayPause() async throws {
        let settings = UserSettings()
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())
        #expect(service.state == .idle)
        service.togglePlayPause()
        #expect(service.state == .running)
        service.togglePlayPause()
        #expect(service.state == .paused)
        service.togglePlayPause()
        #expect(service.state == .running)
    }

    @Test("Timer service reset works correctly")
    func timerServiceResetWorksCorrectly() async throws {
        let settings = UserSettings()
        settings.focusDuration = 25 * 60
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())
        service.setMode(.shortBreak)
        service.start()
        service.reset()
        #expect(service.state == .idle)
        #expect(service.mode == .focus)
        #expect(service.remainingTime == 25 * 60)
        #expect(service.completedSessions == 0)
    }

    @Test("Timer service skip advances to next mode")
    func timerServiceSkipAdvancesToNextMode() async throws {
        let settings = UserSettings()
        settings.sessionsBeforeLongBreak = 4
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())
        service.setMode(.focus)
        service.skip()
        #expect(service.mode == .shortBreak)
        service.skip()
        #expect(service.mode == .focus)
    }

    @Test("Timer service progress calculation works correctly")
    func timerServiceProgressCalculation() async throws {
        let settings = UserSettings()
        settings.focusDuration = 100
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())

        // At start, progress should be 0
        #expect(service.progress == 0.0)

        // After starting and simulating time passing via setMode with custom duration
        // We can test by directly checking the formula
        // progress = 1.0 - (remainingTime / totalDuration)
        // When remainingTime = totalDuration, progress = 0
        // When remainingTime = 0, progress = 1

        // Test edge case: totalDuration is 0
        service.setMode(.focus, duration: 0)
        #expect(service.progress == 0.0)

        // Reset to valid duration and verify initial progress
        service.setMode(.focus, duration: 100)
        #expect(service.totalDuration == 100)
        #expect(service.remainingTime == 100)
        #expect(service.progress == 0.0)
    }

    @Test("Timer service time formatting handles edge cases")
    func timerServiceTimeFormattingEdgeCases() async throws {
        let settings = UserSettings()

        // Test single digit seconds (should be zero-padded)
        settings.focusDuration = 65  // 1:05
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())
        #expect(service.formattedTime == "01:05")

        // Test zero time
        service.setMode(.focus, duration: 0)
        #expect(service.formattedTime == "00:00")

        // Test larger time
        service.setMode(.focus, duration: 90 * 60)  // 90 minutes
        #expect(service.formattedTime == "90:00")
    }

    @Test("Timer service setMode accepts custom duration")
    func timerServiceSetModeWithCustomDuration() async throws {
        let settings = UserSettings()
        settings.focusDuration = 25 * 60
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())

        // Set focus mode with custom duration
        service.setMode(.focus, duration: 10 * 60)
        #expect(service.mode == .focus)
        #expect(service.totalDuration == 10 * 60)
        #expect(service.remainingTime == 10 * 60)
        #expect(service.state == .idle)

        // Set short break with custom duration
        service.setMode(.shortBreak, duration: 3 * 60)
        #expect(service.mode == .shortBreak)
        #expect(service.totalDuration == 3 * 60)

        // Set long break with custom duration
        service.setMode(.longBreak, duration: 20 * 60)
        #expect(service.mode == .longBreak)
        #expect(service.totalDuration == 20 * 60)
    }

    @Test("Timer service stop resets to current mode duration")
    func timerServiceStopResetsToCurrentModeDuration() async throws {
        let settings = UserSettings()
        settings.focusDuration = 25 * 60
        settings.breakDuration = 5 * 60
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())

        // Start and then stop should reset remaining time
        service.start()
        service.stop()
        #expect(service.state == .idle)
        #expect(service.remainingTime == 25 * 60)

        // Switch to break, start, and stop
        service.setMode(.shortBreak)
        service.start()
        service.stop()
        #expect(service.state == .idle)
        #expect(service.remainingTime == 5 * 60)
    }

    @Test("Timer service start from idle resets remaining time")
    func timerServiceStartFromIdleResetsTime() async throws {
        let settings = UserSettings()
        settings.focusDuration = 25 * 60
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())

        // Modify remaining time via setMode with different duration
        service.setMode(.focus, duration: 10 * 60)
        #expect(service.remainingTime == 10 * 60)

        // When starting from idle, it should use totalDuration
        service.start()
        #expect(service.remainingTime == 10 * 60)
        #expect(service.state == .running)
    }

    @Test("Timer service guards against invalid state transitions")
    func timerServiceGuardsInvalidTransitions() async throws {
        let settings = UserSettings()
        let service = TimerService(settings: settings, liveActivityService: LiveActivityService(), notificationService: NotificationService())

        // Calling pause when idle should do nothing
        service.pause()
        #expect(service.state == .idle)

        // Calling resume when idle should do nothing
        service.resume()
        #expect(service.state == .idle)

        // Start the timer
        service.start()
        #expect(service.state == .running)

        // Calling start again when running should do nothing
        service.start()
        #expect(service.state == .running)

        // Pause and try to resume
        service.pause()
        #expect(service.state == .paused)

        // Calling pause when paused should do nothing
        service.pause()
        #expect(service.state == .paused)

        // Resume works from paused
        service.resume()
        #expect(service.state == .running)
    }

    @Test("TimerMode has correct display names")
    func timerModeDisplayNames() async throws {
        #expect(TimerMode.focus.displayName == "Focus")
        #expect(TimerMode.shortBreak.displayName == "Short Break")
        #expect(TimerMode.longBreak.displayName == "Long Break")
    }

    @Test("TimerMode raw values are correct")
    func timerModeRawValues() async throws {
        #expect(TimerMode.focus.rawValue == "focus")
        #expect(TimerMode.shortBreak.rawValue == "shortBreak")
        #expect(TimerMode.longBreak.rawValue == "longBreak")
    }

    @Test("TimerState equality works correctly")
    func timerStateEquality() async throws {
        #expect(TimerState.idle == TimerState.idle)
        #expect(TimerState.running == TimerState.running)
        #expect(TimerState.paused == TimerState.paused)
        #expect(TimerState.idle != TimerState.running)
        #expect(TimerState.running != TimerState.paused)
    }
}
