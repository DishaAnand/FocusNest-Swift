import Foundation
import SwiftUI

/// User preferences for the app
@Observable
public final class UserSettings: @unchecked Sendable {
    private static let focusDurationKey = "focusDuration"
    private static let breakDurationKey = "breakDuration"
    private static let soundEnabledKey = "soundEnabled"
    private static let themeKey = "theme"
    private static let notificationsEnabledKey = "notificationsEnabled"
    private static let soundKeyKey = "soundKey"
    private static let hasSeenNotificationOnboardingKey = "hasSeenNotificationOnboarding"
    private static let hasSeenWakeUpVoiceOnboardingKey = "hasSeenWakeUpVoiceOnboarding"
    private static let rechargeDetectionModeKey = "rechargeDetectionMode"
    private static let isPremiumKey = "isPremium"

    public var focusDuration: Int { didSet { save() } }
    public var breakDuration: Int { didSet { save() } }
    public var soundEnabled: Bool { didSet { save() } }
    public var theme: AppTheme { didSet { save() } }
    public var notificationsEnabled: Bool { didSet { save() } }
    /// Selected notification sound (matches RN soundKey)
    public var soundKey: String { didSet { save() } }
    /// Whether user has seen the notification onboarding prompt
    public var hasSeenNotificationOnboarding: Bool { didSet { save() } }
    /// Whether user has seen the wake-up voice onboarding prompt
    public var hasSeenWakeUpVoiceOnboarding: Bool { didSet { save() } }
    /// Detection mode for recharge (any movement vs walking only)
    public var rechargeDetectionMode: RechargeDetectionMode { didSet { save() } }
    /// Whether user has premium access (unlocks Universe and other features)
    public var isPremium: Bool { didSet { save() } }

    public init() {
        let defaults = UserDefaults.standard
        self.focusDuration = defaults.object(forKey: Self.focusDurationKey) as? Int ?? 25 * 60
        self.breakDuration = defaults.object(forKey: Self.breakDurationKey) as? Int ?? 5 * 60
        self.soundEnabled = defaults.object(forKey: Self.soundEnabledKey) as? Bool ?? true
        self.notificationsEnabled = defaults.object(forKey: Self.notificationsEnabledKey) as? Bool ?? true
        self.soundKey = defaults.string(forKey: Self.soundKeyKey) ?? "chimes"  // RN default
        self.hasSeenNotificationOnboarding = defaults.bool(forKey: Self.hasSeenNotificationOnboardingKey)
        self.hasSeenWakeUpVoiceOnboarding = defaults.bool(forKey: Self.hasSeenWakeUpVoiceOnboardingKey)
        self.isPremium = defaults.bool(forKey: Self.isPremiumKey)

        if let modeRaw = defaults.string(forKey: Self.rechargeDetectionModeKey),
           let savedMode = RechargeDetectionMode(rawValue: modeRaw) {
            self.rechargeDetectionMode = savedMode
        } else {
            self.rechargeDetectionMode = .anyMovement
        }

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
        defaults.set(soundEnabled, forKey: Self.soundEnabledKey)
        defaults.set(theme.rawValue, forKey: Self.themeKey)
        defaults.set(notificationsEnabled, forKey: Self.notificationsEnabledKey)
        defaults.set(soundKey, forKey: Self.soundKeyKey)
        defaults.set(hasSeenNotificationOnboarding, forKey: Self.hasSeenNotificationOnboardingKey)
        defaults.set(hasSeenWakeUpVoiceOnboarding, forKey: Self.hasSeenWakeUpVoiceOnboardingKey)
        defaults.set(rechargeDetectionMode.rawValue, forKey: Self.rechargeDetectionModeKey)
        defaults.set(isPremium, forKey: Self.isPremiumKey)
    }

    public var focusDurationMinutes: Int {
        get { focusDuration / 60 }
        set { focusDuration = newValue * 60 }
    }

    public var breakDurationMinutes: Int {
        get { breakDuration / 60 }
        set { breakDuration = newValue * 60 }
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
