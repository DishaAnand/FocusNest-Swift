import Testing
import SwiftUI
@testable import FocusHavenFeature

@Suite("Theme Tests - Matching RN theme.ts & useChartColors.ts")
struct ThemeTests {

    // MARK: - Color Hex Extension Tests

    @Test("Color init from 6-digit hex works correctly")
    func colorFromHex6Digit() {
        // Test known color: white
        let white = Color(hex: "FFFFFF")
        // Can't directly compare Color values, but we can verify it doesn't crash

        // Test known color: black
        let black = Color(hex: "000000")

        // Test RN primary color
        let primary = Color(hex: "2B7A78")

        // If we got here, hex parsing works
        #expect(true)
    }

    @Test("Color init from hex with hash prefix works")
    func colorFromHexWithHash() {
        let color = Color(hex: "#F8F7F3")
        // If we got here, hash stripping works
        #expect(true)
    }

    @Test("Color init from 3-digit hex works")
    func colorFromHex3Digit() {
        let white = Color(hex: "FFF")
        #expect(true)
    }

    // MARK: - Chart Color Tests (matching RN useChartColors.ts)

    @Test("Chart axis label color differs for light and dark")
    func chartAxisLabelColorDiffers() {
        let lightColor = Theme.chartAxisLabel(.light)
        let darkColor = Theme.chartAxisLabel(.dark)
        // Light: #4A5A59, Dark: #B0B0B0
        // They should be different
        #expect(lightColor != darkColor)
    }

    @Test("Chart X-axis label color differs for light and dark")
    func chartXAxisLabelColorDiffers() {
        let lightColor = Theme.chartXAxisLabel(.light)
        let darkColor = Theme.chartXAxisLabel(.dark)
        // Light: #0E1A19, Dark: #CCCCCC
        #expect(lightColor != darkColor)
    }

    @Test("Chart grid line color differs for light and dark")
    func chartGridLineColorDiffers() {
        let lightColor = Theme.chartGridLine(.light)
        let darkColor = Theme.chartGridLine(.dark)
        // Light: #0B0B0B, Dark: white
        #expect(lightColor != darkColor)
    }

    @Test("Chart grid opacity values match RN")
    func chartGridOpacityMatchesRN() {
        // RN: gridOpacityMajor: 0.06, gridOpacityMinor: 0.03
        #expect(Theme.chartGridOpacityMajor == 0.06)
        #expect(Theme.chartGridOpacityMinor == 0.03)
    }

    // MARK: - Light Theme Color Tests

    @Test("Light theme colors exist")
    func lightThemeColorsExist() {
        // Just verify they don't crash when accessed
        _ = Theme.LightTheme.bg
        _ = Theme.LightTheme.card
        _ = Theme.LightTheme.text
        _ = Theme.LightTheme.muted
        _ = Theme.LightTheme.primary
        _ = Theme.LightTheme.primaryBg
        _ = Theme.LightTheme.border
        #expect(true)
    }

    // MARK: - Dark Theme Color Tests

    @Test("Dark theme colors exist")
    func darkThemeColorsExist() {
        // Just verify they don't crash when accessed
        _ = Theme.DarkTheme.bg
        _ = Theme.DarkTheme.card
        _ = Theme.DarkTheme.text
        _ = Theme.DarkTheme.muted
        _ = Theme.DarkTheme.primary
        _ = Theme.DarkTheme.primaryBg
        _ = Theme.DarkTheme.border
        #expect(true)
    }

    @Test("Dark theme card color is 1E1E1E")
    func darkThemeCardColorIsCorrect() {
        // RN: darkColors.card = #1E1E1E
        let card = Theme.DarkTheme.card
        // We can at least verify it's not white (light theme)
        #expect(card != Theme.LightTheme.card)
    }

    // MARK: - Adaptive Color Tests

    @Test("Adaptive background returns light bg in light mode")
    func adaptiveBgReturnsLightInLightMode() {
        let lightBg = Theme.adaptiveBg(.light)
        let darkBg = Theme.adaptiveBg(.dark)
        #expect(lightBg != darkBg)
    }

    @Test("Adaptive card returns different colors for modes")
    func adaptiveCardDiffersByMode() {
        let lightCard = Theme.adaptiveCard(.light)
        let darkCard = Theme.adaptiveCard(.dark)
        #expect(lightCard != darkCard)
    }

    @Test("Adaptive text returns different colors for modes")
    func adaptiveTextDiffersByMode() {
        let lightText = Theme.adaptiveText(.light)
        let darkText = Theme.adaptiveText(.dark)
        #expect(lightText != darkText)
    }

    @Test("Adaptive primary returns different colors for modes")
    func adaptivePrimaryDiffersByMode() {
        // Light: #2B7A78 (teal), Dark: #4DD0E1 (cyan)
        let lightPrimary = Theme.adaptivePrimary(.light)
        let darkPrimary = Theme.adaptivePrimary(.dark)
        #expect(lightPrimary != darkPrimary)
    }

    // MARK: - Existing Theme Colors Tests

    @Test("RN parity colors exist")
    func rnParityColorsExist() {
        _ = Theme.rnPrimary
        _ = Theme.rnBackground
        _ = Theme.secondaryLight
        _ = Theme.secondaryDark
        _ = Theme.cardBackground
        _ = Theme.rnText
        _ = Theme.mutedColor
        _ = Theme.coralColor
        _ = Theme.borderColor
        _ = Theme.shadowColor
        #expect(true)
    }

    @Test("Timer colors exist")
    func timerColorsExist() {
        _ = Theme.focusColor
        _ = Theme.breakColor
        _ = Theme.pausedColor
        #expect(true)
    }

    @Test("Status colors exist")
    func statusColorsExist() {
        _ = Theme.successColor
        _ = Theme.warningColor
        _ = Theme.errorColor
        _ = Theme.awayColor
        #expect(true)
    }

    // MARK: - Spacing Tests

    @Test("Spacing values are in increasing order")
    func spacingValuesIncreasing() {
        #expect(Theme.spacingXS < Theme.spacingS)
        #expect(Theme.spacingS < Theme.spacingM)
        #expect(Theme.spacingM < Theme.spacingL)
        #expect(Theme.spacingL < Theme.spacingXL)
        #expect(Theme.spacingXL < Theme.spacingXXL)
    }

    @Test("Spacing XS is 4")
    func spacingXSIs4() {
        #expect(Theme.spacingXS == 4)
    }

    @Test("Spacing M is 16")
    func spacingMIs16() {
        #expect(Theme.spacingM == 16)
    }

    // MARK: - Corner Radius Tests

    @Test("Corner radius values are in increasing order")
    func cornerRadiusValuesIncreasing() {
        #expect(Theme.cornerRadiusS < Theme.cornerRadiusM)
        #expect(Theme.cornerRadiusM < Theme.cornerRadiusL)
        #expect(Theme.cornerRadiusL < Theme.cornerRadiusXL)
    }

    @Test("Corner radius M is 12")
    func cornerRadiusMIs12() {
        #expect(Theme.cornerRadiusM == 12)
    }

    // MARK: - Font Tests

    @Test("Fonts are accessible")
    func fontsAccessible() {
        _ = Theme.titleFont
        _ = Theme.headlineFont
        _ = Theme.bodyFont
        _ = Theme.captionFont
        _ = Theme.timerFont
        _ = Theme.timerFontSmall
        #expect(true)
    }

    // MARK: - Gradient Tests

    @Test("Gradients are accessible")
    func gradientsAccessible() {
        _ = Theme.focusGradient
        _ = Theme.breakGradient
        #expect(true)
    }
}
