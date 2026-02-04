import SwiftUI

// MARK: - Color Extension for Hex

extension Color {
    /// Initialize Color from hex string (e.g., "F8F7F3" or "#F8F7F3")
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public enum Theme {
    // MARK: - Primary Colors
    public static let primary = Color("Primary", bundle: .module)
    public static let secondary = Color("Secondary", bundle: .module)
    public static let accent = Color.accentColor

    // MARK: - Timer Colors
    public static let focusColor = Color(red: 0.38, green: 0.73, blue: 0.60)
    public static let breakColor = Color(red: 0.45, green: 0.68, blue: 0.82)
    public static let pausedColor = Color(red: 0.85, green: 0.65, blue: 0.35)

    // MARK: - Status Colors
    public static let successColor = Color.green
    public static let warningColor = Color.orange
    public static let errorColor = Color.red
    public static let awayColor = Color(red: 0.85, green: 0.55, blue: 0.55)

    // MARK: - React Native Parity Colors (from colors.ts)
    /// RN: COLORS.primary = #2A7F7F (teal)
    public static let rnPrimary = Color(red: 0.165, green: 0.498, blue: 0.498)
    /// RN: COLORS.background = #FBF9F4 (off-white)
    public static let rnBackground = Color(red: 0.984, green: 0.976, blue: 0.957)
    /// RN: COLORS.secondaryLight = #E0F0F0
    public static let secondaryLight = Color(red: 0.878, green: 0.941, blue: 0.941)
    /// RN: COLORS.secondaryDark = #4D7070
    public static let secondaryDark = Color(red: 0.302, green: 0.439, blue: 0.439)
    /// RN: COLORS.card = #FFFFFF
    public static let cardBackground = Color.white
    /// RN: COLORS.text = #0F172A (near-black)
    public static let rnText = Color(red: 0.059, green: 0.090, blue: 0.165)
    /// RN: COLORS.muted = #2F6F6A (teal for headings)
    public static let mutedColor = Color(red: 0.184, green: 0.435, blue: 0.416)
    /// RN: COLORS.primary2 = #FF7A73 (coral - for Start/Cancel buttons)
    public static let coralColor = Color(red: 1.0, green: 0.478, blue: 0.451)
    /// RN: COLORS.border = rgba(0,0,0,0.06)
    public static let borderColor = Color.black.opacity(0.06)
    /// RN: COLORS.shadow = rgba(0,0,0,0.08)
    public static let shadowColor = Color.black.opacity(0.08)

    // MARK: - Chart Colors (matching RN useChartColors.ts)

    /// Y-axis label color - adapts to color scheme
    public static func chartAxisLabel(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(hex: "B0B0B0")
            : Color(hex: "4A5A59")
    }

    /// X-axis label color - adapts to color scheme
    public static func chartXAxisLabel(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(hex: "CCCCCC")
            : Color(hex: "0E1A19")
    }

    /// Grid line color - adapts to color scheme
    public static func chartGridLine(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white
            : Color(hex: "0B0B0B")
    }

    /// Grid opacity for major lines
    public static let chartGridOpacityMajor: Double = 0.06
    /// Grid opacity for minor lines
    public static let chartGridOpacityMinor: Double = 0.03

    // MARK: - Light/Dark Theme Colors (matching RN theme.ts)

    /// Light theme colors - matches RN lightColors
    public enum LightTheme {
        public static let bg = Color(hex: "F8F7F3")
        public static let card = Color.white
        public static let text = Color(hex: "111111")
        public static let muted = Color(hex: "6B7280")
        public static let primary = Color(hex: "2B7A78")
        public static let primaryBg = Color(hex: "E0F2F1")
        public static let border = Color(hex: "E5E7EB")
    }

    /// Dark theme colors - matches RN darkColors
    public enum DarkTheme {
        public static let bg = Color(hex: "121212")
        public static let card = Color(hex: "1E1E1E")
        public static let text = Color.white
        public static let muted = Color(hex: "AAAAAA")
        public static let primary = Color(hex: "4DD0E1")
        public static let primaryBg = Color(hex: "1A2A2A")
        public static let border = Color(hex: "333333")
    }

    /// Get theme color that adapts to color scheme
    public static func themeColor(_ colorScheme: ColorScheme, light: Color, dark: Color) -> Color {
        colorScheme == .dark ? dark : light
    }

    /// Adaptive background color
    public static func adaptiveBg(_ colorScheme: ColorScheme) -> Color {
        themeColor(colorScheme, light: LightTheme.bg, dark: DarkTheme.bg)
    }

    /// Adaptive card color
    public static func adaptiveCard(_ colorScheme: ColorScheme) -> Color {
        themeColor(colorScheme, light: LightTheme.card, dark: DarkTheme.card)
    }

    /// Adaptive text color
    public static func adaptiveText(_ colorScheme: ColorScheme) -> Color {
        themeColor(colorScheme, light: LightTheme.text, dark: DarkTheme.text)
    }

    /// Adaptive muted color
    public static func adaptiveMuted(_ colorScheme: ColorScheme) -> Color {
        themeColor(colorScheme, light: LightTheme.muted, dark: DarkTheme.muted)
    }

    /// Adaptive primary color
    public static func adaptivePrimary(_ colorScheme: ColorScheme) -> Color {
        themeColor(colorScheme, light: LightTheme.primary, dark: DarkTheme.primary)
    }

    /// Adaptive primary background color
    public static func adaptivePrimaryBg(_ colorScheme: ColorScheme) -> Color {
        themeColor(colorScheme, light: LightTheme.primaryBg, dark: DarkTheme.primaryBg)
    }

    /// Adaptive border color
    public static func adaptiveBorder(_ colorScheme: ColorScheme) -> Color {
        themeColor(colorScheme, light: LightTheme.border, dark: DarkTheme.border)
    }

    // MARK: - Background Colors
    public static let backgroundPrimary = Color(uiColor: .systemBackground)
    public static let backgroundSecondary = Color(uiColor: .secondarySystemBackground)
    public static let backgroundTertiary = Color(uiColor: .tertiarySystemBackground)

    // MARK: - Text Colors
    public static let textPrimary = Color(uiColor: .label)
    public static let textSecondary = Color(uiColor: .secondaryLabel)
    public static let textTertiary = Color(uiColor: .tertiaryLabel)

    // MARK: - Gradients
    public static let focusGradient = LinearGradient(
        colors: [Color(red: 0.38, green: 0.73, blue: 0.60), Color(red: 0.30, green: 0.60, blue: 0.50)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let breakGradient = LinearGradient(
        colors: [Color(red: 0.45, green: 0.68, blue: 0.82), Color(red: 0.35, green: 0.55, blue: 0.70)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Spacing
    public static let spacingXS: CGFloat = 4
    public static let spacingS: CGFloat = 8
    public static let spacingM: CGFloat = 16
    public static let spacingL: CGFloat = 24
    public static let spacingXL: CGFloat = 32
    public static let spacingXXL: CGFloat = 48

    // MARK: - Corner Radius
    public static let cornerRadiusS: CGFloat = 8
    public static let cornerRadiusM: CGFloat = 12
    public static let cornerRadiusL: CGFloat = 16
    public static let cornerRadiusXL: CGFloat = 24

    // MARK: - Typography
    public static let titleFont = Font.system(.title, design: .rounded, weight: .bold)
    public static let headlineFont = Font.system(.headline, design: .rounded, weight: .semibold)
    public static let bodyFont = Font.system(.body, design: .rounded)
    public static let captionFont = Font.system(.caption, design: .rounded)
    public static let timerFont = Font.system(size: 72, weight: .light, design: .rounded)
    public static let timerFontSmall = Font.system(size: 48, weight: .light, design: .rounded)
}

extension View {
    public func cardStyle() -> some View {
        self
            .background(Theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    public func primaryButtonStyle() -> some View {
        self
            .font(Theme.headlineFont)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacingM)
            .background(Theme.focusGradient)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
    }

    public func secondaryButtonStyle() -> some View {
        self
            .font(Theme.headlineFont)
            .foregroundStyle(Theme.focusColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacingM)
            .background(Theme.focusColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
    }
}
