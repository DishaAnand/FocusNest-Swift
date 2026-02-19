import SwiftUI
import SwiftData
import StoreKit
import UIKit

// MARK: - Settings Hero Header

struct SettingsHeroHeader: View {
    let isPro: Bool
    let onUpgrade: () -> Void

    @State private var appeared = false

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Night owl mode"
        }
    }

    var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "☀️"
        case 12..<17: return "🌤️"
        case 17..<21: return "🌙"
        default: return "🦉"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Greeting
            Text("\(greeting) \(greetingEmoji)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)
                .padding(.top, 12)

            // Pro banner (if not pro)
            if !isPro {
                Button(action: onUpgrade) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(.yellow.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.yellow)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Pro")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Unlock all features")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.75))
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Theme.focusColor,
                                Theme.focusColor.opacity(0.85),
                                .cyan.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Theme.focusColor.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, 16)
                .opacity(appeared ? 1 : 0)
            }
        }
        .padding(.bottom, 16)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Clean List Row

struct CleanSettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var value: String? = nil
    var showChevron: Bool = true
    var showLock: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            if let value {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }

            if showLock {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Toggle Row

struct CleanToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.focusColor)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Picker Row

struct CleanPickerRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Menu {
                ForEach(Array(range), id: \.self) { num in
                    Button("\(num) \(unit)") {
                        withAnimation(.spring(response: 0.3)) {
                            value = num
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(value)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.focusColor)
                    Text(unit)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Stepper Row

struct CleanStepperRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if value > range.lowerBound {
                        withAnimation(.spring(response: 0.25)) {
                            value -= 1
                        }
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(value > range.lowerBound ? Theme.focusColor : Theme.textTertiary)
                }
                .disabled(value <= range.lowerBound)

                Text("\(value)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 30)

                Button {
                    if value < range.upperBound {
                        withAnimation(.spring(response: 0.25)) {
                            value += 1
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(value < range.upperBound ? Theme.focusColor : Theme.textTertiary)
                }
                .disabled(value >= range.upperBound)
            }
        }
        .padding(.vertical, 6)
    }
}


// MARK: - Main Settings View

@MainActor
public struct SettingsView: View {
    @Environment(UserSettings.self) private var settings
    @Environment(NotificationService.self) private var notificationService
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(SoundService.self) private var soundService

    @State private var showingResetAlert = false
    @State private var showPaywall = false
    @State private var showWakeUpVoice = false
    @State private var showRatingSheet = false
    @State private var sectionsAppeared = false



    public init() {}

    public var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header
                    SettingsHeroHeader(
                        isPro: subscriptionService.isPro,
                        onUpgrade: {
                            showPaywall = true
                        }
                    )

                    // List sections with staggered animations
                    VStack(spacing: 24) {


                        // MARK: - Timer Settings
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TIMER")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                // Break Duration
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Theme.breakColor.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.breakColor)
                                    }

                                    Text("Break Duration")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.textPrimary)

                                    Spacer()

                                    Picker("", selection: $settings.breakDurationMinutes) {
                                        ForEach([5, 10, 15], id: \.self) { minutes in
                                            Text("\(minutes) min").tag(minutes)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.breakColor)
                                }
                                .padding(.vertical, 6)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Theme.backgroundSecondary)
                                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
                            )
                            .padding(.horizontal, 16)
                        }
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)

                        // MARK: - Sounds & Feedback
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SOUNDS & FEEDBACK")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                CleanToggleRow(
                                    icon: "speaker.wave.2.fill",
                                    iconColor: .blue,
                                    title: "Sounds & Haptics",
                                    isOn: $settings.soundEnabled
                                )
                                Divider().padding(.leading, 60)

                                // Recharge detection mode picker (always shown - recharge mode is mandatory)
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Theme.breakColor.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Theme.breakColor)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Recharge Detection")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text(settings.rechargeDetectionMode.description)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.textSecondary)
                                    }

                                    Spacer()

                                    Picker("", selection: $settings.rechargeDetectionMode) {
                                        ForEach(RechargeDetectionMode.allCases, id: \.self) { mode in
                                            Text(mode.displayName).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.breakColor)
                                }
                                .padding(.vertical, 6)

                                Divider().padding(.leading, 60)

                                Button {
                                    showWakeUpVoice = true
                                } label: {
                                    CleanSettingsRow(
                                        icon: "waveform",
                                        iconColor: Theme.focusColor,
                                        title: "Wake-Up Voice"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Theme.backgroundSecondary)
                                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
                            )
                            .padding(.horizontal, 16)
                        }
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)

                        // MARK: - Notifications (only if disabled)
                        if !notificationService.isAuthorized {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NOTIFICATIONS")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.textTertiary)
                                    .padding(.horizontal, 20)

                                VStack(spacing: 12) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.orange.opacity(0.15))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "bell.slash.fill")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.orange)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Notifications Off")
                                                .font(.system(size: 16))
                                                .foregroundStyle(Theme.textPrimary)
                                            Text("You won't hear timer alerts")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Theme.textSecondary)
                                        }

                                        Spacer()
                                    }

                                    Button {
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        Text("Enable Notifications")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(Theme.focusColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Theme.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 16)
                            }
                        }

                        // MARK: - Appearance
                        VStack(alignment: .leading, spacing: 8) {
                            Text("APPEARANCE")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.indigo.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "circle.lefthalf.filled")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.indigo)
                                    }

                                    Text("Theme")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.textPrimary)

                                    Spacer()

                                    Picker("", selection: $settings.theme) {
                                        ForEach(AppTheme.allCases, id: \.self) {
                                            Text($0.displayName).tag($0)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(Theme.focusColor)
                                }
                                .padding(.vertical, 6)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Theme.backgroundSecondary)
                                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
                            )
                            .padding(.horizontal, 16)
                        }
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)

                        // MARK: - Support
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SUPPORT")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                Button {
                                    Task {
                                        try? await subscriptionService.restorePurchases()
                                    }
                                } label: {
                                    CleanSettingsRow(
                                        icon: "arrow.clockwise.circle.fill",
                                        iconColor: .green,
                                        title: "Restore Purchases"
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 60)

                                Button {
                                    if let url = URL(string: "mailto:infiniarc123@gmail.com?subject=FocusHaven%20Feedback") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    CleanSettingsRow(
                                        icon: "envelope.fill",
                                        iconColor: .blue,
                                        title: "Send Feedback"
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 60)

                                Button {
                                    showRatingSheet = true
                                } label: {
                                    CleanSettingsRow(
                                        icon: "star.fill",
                                        iconColor: .orange,
                                        title: "Rate FocusHaven"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Theme.backgroundSecondary)
                                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
                            )
                            .padding(.horizontal, 16)
                        }
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)

                        // MARK: - About
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ABOUT")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                CleanSettingsRow(
                                    icon: "info.circle.fill",
                                    iconColor: .gray,
                                    title: "Version",
                                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                                    showChevron: false
                                )

                                Divider().padding(.leading, 60)

                                CleanSettingsRow(
                                    icon: "icloud.fill",
                                    iconColor: FileManager.default.ubiquityIdentityToken != nil ? .green : .gray,
                                    title: "iCloud Sync",
                                    value: FileManager.default.ubiquityIdentityToken != nil ? "Active" : "Unavailable",
                                    showChevron: false
                                )

                                Divider().padding(.leading, 60)

                                Button {
                                    if let url = URL(string: "https://dishaanand.github.io/FocusNest-Swift/privacy/") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    CleanSettingsRow(
                                        icon: "hand.raised.fill",
                                        iconColor: .indigo,
                                        title: "Privacy Policy"
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 60)

                                Button {
                                    if let url = URL(string: "https://dishaanand.github.io/FocusNest-Swift/terms/") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    CleanSettingsRow(
                                        icon: "doc.text.fill",
                                        iconColor: .gray,
                                        title: "Terms of Service"
                                    )
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 60)

                                Button {
                                    showingResetAlert = true
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.red.opacity(0.15))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.red)
                                        }

                                        Text("Reset All Settings")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.red)

                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Theme.backgroundSecondary)
                                    .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
                            )
                            .padding(.horizontal, 16)
                        }
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 20)

                        // Made with love footer
                        Text("Made with 💚 for focused minds")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .opacity(sectionsAppeared ? 1 : 0)

                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 8)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                            sectionsAppeared = true
                        }
                    }
                }
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Reset Settings?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    withAnimation(.spring(response: 0.4)) {
                        settings.focusDuration = 25 * 60
                        settings.breakDuration = 5 * 60
                        settings.soundEnabled = true
                        settings.theme = .system
                        settings.notificationsEnabled = true
                    }
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showWakeUpVoice) {
                NavigationStack {
                    WakeUpVoicesSettingsView()
                }
            }
            .sheet(isPresented: $showRatingSheet) {
                RateAppSheet()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Rate App Sheet

private struct RateAppSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @State private var rating: Int = 0
    @State private var submitted = false

    var body: some View {
        VStack(spacing: 24) {
            if submitted {
                VStack(spacing: 16) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.pink)

                    Text("Thank you!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    Text(rating >= 4
                        ? "We're glad you enjoy FocusHaven!"
                        : "We'll work on improving your experience.")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    if rating >= 4 {
                        requestReview()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("Enjoying FocusHaven?")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Tap the stars to rate your experience")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }

                StarRatingView(rating: $rating, size: 40)
                    .padding(.vertical, 8)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        submitted = true
                    }
                } label: {
                    Text("Submit")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(rating > 0 ? Theme.focusColor : Theme.textTertiary.opacity(0.3))
                        )
                }
                .disabled(rating == 0)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.backgroundPrimary)
    }
}

#Preview {
    SettingsView()
        .environment(UserSettings())
        .environment(NotificationService())
        .environment(SubscriptionService())
        .environment(SoundService())
}
