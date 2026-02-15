import Testing
import SwiftUI
@testable import FocusHavenFeature

@Suite("UserSettings Tests - Matching RN settings.ts")
@MainActor
struct UserSettingsTests {

    // MARK: - Default Initialization Tests

    @Test("Settings initialize with expected default values matching RN")
    func settingsInitializeWithExpectedDefaults() async throws {
        // Clear any stored values to test defaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "focusDuration")
        defaults.removeObject(forKey: "breakDuration")
        defaults.removeObject(forKey: "soundEnabled")
        defaults.removeObject(forKey: "theme")
        defaults.removeObject(forKey: "notificationsEnabled")
        defaults.removeObject(forKey: "soundKey")

        let settings = UserSettings()

        // Duration defaults (in seconds) - RN stores in minutes, we store in seconds
        // RN: focusMin = 25, breakMin = 5
        #expect(settings.focusDuration == 25 * 60)  // 25 minutes
        #expect(settings.breakDuration == 5 * 60)   // 5 minutes

        // Boolean defaults
        #expect(settings.soundEnabled == true)
        #expect(settings.soundEnabled == true)
        #expect(settings.notificationsEnabled == true)

        // Theme default - RN: appearance = 'system'
        #expect(settings.theme == .system)

        // Sound key default - RN: soundKey = 'chimes'
        #expect(settings.soundKey == "chimes")
    }

    // MARK: - Duration Minutes Computed Property Tests

    @Test("Focus duration minutes getter returns correct value")
    func focusDurationMinutesGetterReturnsCorrectValue() async throws {
        let settings = UserSettings()

        settings.focusDuration = 25 * 60  // 25 minutes in seconds
        #expect(settings.focusDurationMinutes == 25)

        settings.focusDuration = 45 * 60  // 45 minutes in seconds
        #expect(settings.focusDurationMinutes == 45)

        settings.focusDuration = 60 * 60  // 60 minutes in seconds
        #expect(settings.focusDurationMinutes == 60)
    }

    @Test("Focus duration minutes setter updates seconds correctly")
    func focusDurationMinutesSetterUpdatesSecondsCorrectly() async throws {
        let settings = UserSettings()

        settings.focusDurationMinutes = 30
        #expect(settings.focusDuration == 30 * 60)

        settings.focusDurationMinutes = 50
        #expect(settings.focusDuration == 50 * 60)

        settings.focusDurationMinutes = 1
        #expect(settings.focusDuration == 60)
    }

    @Test("Break duration minutes getter returns correct value")
    func breakDurationMinutesGetterReturnsCorrectValue() async throws {
        let settings = UserSettings()

        settings.breakDuration = 5 * 60  // 5 minutes in seconds
        #expect(settings.breakDurationMinutes == 5)

        settings.breakDuration = 10 * 60  // 10 minutes in seconds
        #expect(settings.breakDurationMinutes == 10)
    }

    @Test("Break duration minutes setter updates seconds correctly")
    func breakDurationMinutesSetterUpdatesSecondsCorrectly() async throws {
        let settings = UserSettings()

        settings.breakDurationMinutes = 7
        #expect(settings.breakDuration == 7 * 60)

        settings.breakDurationMinutes = 15
        #expect(settings.breakDuration == 15 * 60)
    }

    @Test("Duration minutes handles edge cases")
    func durationMinutesHandlesEdgeCases() async throws {
        let settings = UserSettings()

        // Zero minutes
        settings.focusDurationMinutes = 0
        #expect(settings.focusDuration == 0)
        #expect(settings.focusDurationMinutes == 0)

        // Large value
        settings.focusDurationMinutes = 120  // 2 hours
        #expect(settings.focusDuration == 7200)
        #expect(settings.focusDurationMinutes == 120)
    }

    // MARK: - AppTheme Color Scheme Tests

    @Test("System theme returns nil color scheme")
    func systemThemeReturnsNilColorScheme() async throws {
        let theme = AppTheme.system
        #expect(theme.colorScheme == nil)
    }

    @Test("Light theme returns light color scheme")
    func lightThemeReturnsLightColorScheme() async throws {
        let theme = AppTheme.light
        #expect(theme.colorScheme == .light)
    }

    @Test("Dark theme returns dark color scheme")
    func darkThemeReturnsDarkColorScheme() async throws {
        let theme = AppTheme.dark
        #expect(theme.colorScheme == .dark)
    }

    @Test("All themes have correct display names")
    func allThemesHaveCorrectDisplayNames() async throws {
        #expect(AppTheme.system.displayName == "System")
        #expect(AppTheme.light.displayName == "Light")
        #expect(AppTheme.dark.displayName == "Dark")
    }

    @Test("AppTheme raw values are correct")
    func appThemeRawValuesAreCorrect() async throws {
        #expect(AppTheme.system.rawValue == "system")
        #expect(AppTheme.light.rawValue == "light")
        #expect(AppTheme.dark.rawValue == "dark")
    }

    @Test("AppTheme can be initialized from raw value")
    func appThemeCanBeInitializedFromRawValue() async throws {
        #expect(AppTheme(rawValue: "system") == .system)
        #expect(AppTheme(rawValue: "light") == .light)
        #expect(AppTheme(rawValue: "dark") == .dark)
        #expect(AppTheme(rawValue: "invalid") == nil)
    }

    @Test("AppTheme CaseIterable contains all cases")
    func appThemeCaseIterableContainsAllCases() async throws {
        let allCases = AppTheme.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.system))
        #expect(allCases.contains(.light))
        #expect(allCases.contains(.dark))
    }

    // MARK: - Sound Key Tests (matching RN soundKey setting)

    @Test("Sound key default matches RN")
    func soundKeyDefaultMatchesRN() async throws {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "soundKey")

        let settings = UserSettings()
        // RN: soundKey default = 'chimes'
        #expect(settings.soundKey == "chimes")
    }

    @Test("Sound key can be changed and persists")
    func soundKeyCanBeChangedAndPersists() async throws {
        let settings = UserSettings()
        settings.soundKey = "bell"

        let loadedSettings = UserSettings()
        #expect(loadedSettings.soundKey == "bell")

        // Test another value
        settings.soundKey = "notification"
        let reloadedSettings = UserSettings()
        #expect(reloadedSettings.soundKey == "notification")

        // Reset to default
        settings.soundKey = "chimes"
    }

    // MARK: - UserDefaults Persistence Tests

    @Test("Settings persist to UserDefaults")
    func settingsPersistToUserDefaults() async throws {
        let settings = UserSettings()

        // Set custom values
        settings.focusDuration = 35 * 60
        settings.breakDuration = 8 * 60
        settings.soundEnabled = false
        settings.soundEnabled = false
        settings.theme = .dark
        settings.notificationsEnabled = false
        settings.soundKey = "bell"

        // Create new instance to verify persistence
        let loadedSettings = UserSettings()

        #expect(loadedSettings.focusDuration == 35 * 60)
        #expect(loadedSettings.breakDuration == 8 * 60)
        #expect(loadedSettings.soundEnabled == false)
        #expect(loadedSettings.soundEnabled == false)
        #expect(loadedSettings.theme == .dark)
        #expect(loadedSettings.notificationsEnabled == false)
        #expect(loadedSettings.soundKey == "bell")
    }

    @Test("Theme persists correctly to UserDefaults")
    func themePersistsCorrectlyToUserDefaults() async throws {
        let settings = UserSettings()

        // Test each theme option persists
        settings.theme = .light
        var loadedSettings = UserSettings()
        #expect(loadedSettings.theme == .light)

        settings.theme = .dark
        loadedSettings = UserSettings()
        #expect(loadedSettings.theme == .dark)

        settings.theme = .system
        loadedSettings = UserSettings()
        #expect(loadedSettings.theme == .system)
    }
}
