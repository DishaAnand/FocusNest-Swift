import SwiftUI

@MainActor
public struct SettingsView: View {
    @Environment(UserSettings.self) private var settings
    @Environment(NotificationService.self) private var notificationService
    @State private var showingResetAlert = false

    public init() {}

    public var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            List {
                Section("Timer") {
                    durationPicker(title: "Focus Duration", value: $settings.focusDurationMinutes, range: 1...120)
                    durationPicker(title: "Short Break", value: $settings.breakDurationMinutes, range: 1...30)
                    durationPicker(title: "Long Break", value: $settings.longBreakDurationMinutes, range: 1...60)
                    Stepper("Sessions before long break: \(settings.sessionsBeforeLongBreak)", value: $settings.sessionsBeforeLongBreak, in: 2...8)
                }
                Section("Automation") {
                    Toggle("Auto-start Breaks", isOn: $settings.autoStartBreaks)
                    Toggle("Auto-start Focus", isOn: $settings.autoStartFocus)
                }
                Section("Feedback") {
                    Toggle("Sound", isOn: $settings.soundEnabled)
                    Toggle("Vibration", isOn: $settings.vibrationEnabled)
                }
                Section("Notifications") {
                    Toggle("Notifications", isOn: $settings.notificationsEnabled)
                    if !notificationService.isAuthorized {
                        Button("Enable Notifications") { Task { _ = await notificationService.requestAuthorization() } }.foregroundStyle(Theme.focusColor)
                    }
                }
                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
                Section("About") {
                    HStack { Text("Version"); Spacer(); Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0").foregroundStyle(Theme.textSecondary) }
                    Button("Reset All Settings") { showingResetAlert = true }.foregroundStyle(Theme.errorColor)
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Settings?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    settings.focusDuration = 25 * 60; settings.breakDuration = 5 * 60; settings.longBreakDuration = 15 * 60
                    settings.sessionsBeforeLongBreak = 4; settings.soundEnabled = true; settings.vibrationEnabled = true
                    settings.autoStartBreaks = false; settings.autoStartFocus = false; settings.theme = .system; settings.notificationsEnabled = true
                }
            } message: { Text("This will reset all settings to their default values.") }
        }
    }

    private func durationPicker(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack { Text(title); Spacer(); Picker(title, selection: value) { ForEach(Array(range), id: \.self) { Text("\($0) min").tag($0) } }.pickerStyle(.menu).labelsHidden() }
    }
}
