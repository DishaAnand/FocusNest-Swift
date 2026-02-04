import SwiftUI

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
