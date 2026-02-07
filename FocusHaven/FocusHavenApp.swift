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
    @State private var liveActivityService = LiveActivityService()
    @State private var wakeUpVoiceService: WakeUpVoiceService
    @State private var ambientSoundService = AmbientSoundService()

    init() {
        let settings = UserSettings()
        let liveActivityService = LiveActivityService()
        let notificationService = NotificationService()
        let wakeUpVoiceService = WakeUpVoiceService()
        let ambientSoundService = AmbientSoundService()
        self._settings = State(initialValue: settings)
        self._liveActivityService = State(initialValue: liveActivityService)
        self._notificationService = State(initialValue: notificationService)
        self._wakeUpVoiceService = State(initialValue: wakeUpVoiceService)
        self._ambientSoundService = State(initialValue: ambientSoundService)
        self._timerService = State(initialValue: TimerService(settings: settings, liveActivityService: liveActivityService, notificationService: notificationService, wakeUpVoiceService: wakeUpVoiceService))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(timerService)
                .environment(notificationService)
                .environment(soundService)
                .environment(sessionService)
                .environment(wakeUpVoiceService)
                .environment(ambientSoundService)
                .preferredColorScheme(settings.theme.colorScheme)
                .task {
                    sessionService.configure()
                    // Request notification permission on launch
                    _ = await notificationService.requestAuthorization()
                }
        }
        .modelContainer(for: [FocusTask.self, FocusRecord.self])
    }
}
