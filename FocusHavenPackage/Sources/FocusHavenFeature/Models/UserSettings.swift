import Foundation
import SwiftUI

/// User preferences for the app
@Observable
public final class UserSettings: @unchecked Sendable {
    private static let focusDurationKey = "focusDuration"
    private static let breakDurationKey = "breakDuration"
    private static let longBreakDurationKey = "longBreakDuration"
    private static let sessionsBeforeLongBreakKey = "sessionsBeforeLongBreak"
    private static let soundEnabledKey = "soundEnabled"
    private static let vibrationEnabledKey = "vibrationEnabled"
    private static let autoStartBreaksKey = "autoStartBreaks"
    private static let autoStartFocusKey = "autoStartFocus"
    private static let themeKey = "theme"
    private static let notificationsEnabledKey = "notificationsEnabled"
    private static let soundKeyKey = "soundKey"
    private static let hasSeenNotificationOnboardingKey = "hasSeenNotificationOnboarding"

    public var focusDuration: Int { didSet { save() } }
    public var breakDuration: Int { didSet { save() } }
    public var longBreakDuration: Int { didSet { save() } }
    public var sessionsBeforeLongBreak: Int { didSet { save() } }
    public var soundEnabled: Bool { didSet { save() } }
    public var vibrationEnabled: Bool { didSet { save() } }
    public var autoStartBreaks: Bool { didSet { save() } }
    public var autoStartFocus: Bool { didSet { save() } }
    public var theme: AppTheme { didSet { save() } }
    public var notificationsEnabled: Bool { didSet { save() } }
    /// Selected notification sound (matches RN soundKey)
    public var soundKey: String { didSet { save() } }
    /// Whether user has seen the notification onboarding prompt
    public var hasSeenNotificationOnboarding: Bool { didSet { save() } }

    public init() {
        let defaults = UserDefaults.standard
        self.focusDuration = defaults.object(forKey: Self.focusDurationKey) as? Int ?? 25 * 60
        self.breakDuration = defaults.object(forKey: Self.breakDurationKey) as? Int ?? 5 * 60
        self.longBreakDuration = defaults.object(forKey: Self.longBreakDurationKey) as? Int ?? 15 * 60
        self.sessionsBeforeLongBreak = defaults.object(forKey: Self.sessionsBeforeLongBreakKey) as? Int ?? 4
        self.soundEnabled = defaults.object(forKey: Self.soundEnabledKey) as? Bool ?? true
        self.vibrationEnabled = defaults.object(forKey: Self.vibrationEnabledKey) as? Bool ?? true
        self.autoStartBreaks = defaults.object(forKey: Self.autoStartBreaksKey) as? Bool ?? true  // RN default is true
        self.autoStartFocus = defaults.object(forKey: Self.autoStartFocusKey) as? Bool ?? false
        self.notificationsEnabled = defaults.object(forKey: Self.notificationsEnabledKey) as? Bool ?? true
        self.soundKey = defaults.string(forKey: Self.soundKeyKey) ?? "chimes"  // RN default
        self.hasSeenNotificationOnboarding = defaults.bool(forKey: Self.hasSeenNotificationOnboardingKey)

        if let themeRaw = defaults.string(forKey: Self.themeKey),
           let savedTheme = AppTheme(rawValue: themeRaw) {
            self.theme = savedTheme
        } else {
            self.theme = .system
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(focusDuration, forKey: Self.focusDurationKey)
        defaults.set(breakDuration, forKey: Self.breakDurationKey)
        defaults.set(longBreakDuration, forKey: Self.longBreakDurationKey)
        defaults.set(sessionsBeforeLongBreak, forKey: Self.sessionsBeforeLongBreakKey)
        defaults.set(soundEnabled, forKey: Self.soundEnabledKey)
        defaults.set(vibrationEnabled, forKey: Self.vibrationEnabledKey)
        defaults.set(autoStartBreaks, forKey: Self.autoStartBreaksKey)
        defaults.set(autoStartFocus, forKey: Self.autoStartFocusKey)
        defaults.set(theme.rawValue, forKey: Self.themeKey)
        defaults.set(notificationsEnabled, forKey: Self.notificationsEnabledKey)
        defaults.set(soundKey, forKey: Self.soundKeyKey)
        defaults.set(hasSeenNotificationOnboarding, forKey: Self.hasSeenNotificationOnboardingKey)
    }

    public var focusDurationMinutes: Int {
        get { focusDuration / 60 }
        set { focusDuration = newValue * 60 }
    }

    public var breakDurationMinutes: Int {
        get { breakDuration / 60 }
        set { breakDuration = newValue * 60 }
    }

    public var longBreakDurationMinutes: Int {
        get { longBreakDuration / 60 }
        set { longBreakDuration = newValue * 60 }
    }
}

public enum AppTheme: String, CaseIterable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
