import SwiftUI
import SwiftData
import FocusHavenFeature

@main
@MainActor
struct FocusHavenApp: App {
    @State private var settings = UserSettings()
    @State private var timerService: TimerService
    @State private var notificationService = NotificationService()
    @State private var soundService = SoundService()
    @State private var sessionService = SessionService()

    init() {
        let settings = UserSettings()
        self._settings = State(initialValue: settings)
        self._timerService = State(initialValue: TimerService(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(timerService)
                .environment(notificationService)
                .environment(soundService)
                .environment(sessionService)
                .preferredColorScheme(settings.theme.colorScheme)
                .task {
                    sessionService.configure()
                }
        }
        .modelContainer(for: [FocusTask.self, FocusRecord.self])
    }
}
