import Testing
import Foundation
@testable import FocusNestFeature

@Suite("TimerService Tests")
@MainActor
struct TimerServiceTests {
    @Test("Timer service initializes with correct defaults")
    func timerServiceInitializesCorrectly() async throws {
        let settings = UserSettings()
        settings.focusDuration = 25 * 60
        let service = TimerService(settings: settings)
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
        let service = TimerService(settings: settings)
        #expect(service.formattedTime == "25:00")
    }

    @Test("Timer service identifies break mode correctly")
    func timerServiceIdentifiesBreakMode() async throws {
        let settings = UserSettings()
        let service = TimerService(settings: settings)
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
        let service = TimerService(settings: settings)
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
        let service = TimerService(settings: settings)
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
        let service = TimerService(settings: settings)
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
        let service = TimerService(settings: settings)
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
        let service = TimerService(settings: settings)
        service.setMode(.focus)
        service.skip()
        #expect(service.mode == .shortBreak)
        service.skip()
        #expect(service.mode == .focus)
    }
}
