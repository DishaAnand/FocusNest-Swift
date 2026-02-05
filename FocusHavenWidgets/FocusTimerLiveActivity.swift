import ActivityKit
import SwiftUI
import WidgetKit

struct FocusTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerAttributes.self) { context in
            // Lock Screen / StandBy view
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Theme Colors

private struct ThemeColors {
    static let focusGradient = LinearGradient(
        colors: [Color(hex: "22C55E"), Color(hex: "16A34A")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let breakGradient = LinearGradient(
        colors: [Color(hex: "3B82F6"), Color(hex: "6366F1")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let focusColor = Color(hex: "22C55E")
    static let breakColor = Color(hex: "6366F1")
    static let pausedColor = Color(hex: "F59E0B")
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    private var accentColor: Color {
        context.state.isPaused ? ThemeColors.pausedColor :
            (context.state.isBreak ? ThemeColors.breakColor : ThemeColors.focusColor)
    }

    private var modeEmoji: String {
        if context.state.isPaused { return "⏸️" }
        return context.state.isBreak ? "☕" : "🎯"
    }

    private var gradient: LinearGradient {
        context.state.isBreak ? ThemeColors.breakGradient : ThemeColors.focusGradient
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Icon badge with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .blur(radius: 8)

                // Main circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                // Emoji
                Text(modeEmoji)
                    .font(.system(size: 22))
            }

            // Center: Timer and info
            VStack(alignment: .leading, spacing: 4) {
                // Big timer
                if context.state.isPaused {
                    Text("PAUSED")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeColors.pausedColor)
                } else {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                // Mode + task
                HStack(spacing: 8) {
                    Text(context.state.modeDisplayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)

                    if let taskName = context.attributes.taskName, !taskName.isEmpty {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        Text(taskName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            // Right: App branding
            VStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .activityBackgroundTint(Color.black.opacity(0.9))
    }
}

// MARK: - Dynamic Island Compact Views

private struct CompactLeadingView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    private var accentColor: Color {
        context.state.isPaused ? ThemeColors.pausedColor :
            (context.state.isBreak ? ThemeColors.breakColor : ThemeColors.focusColor)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(accentColor)
                .frame(width: 24, height: 24)

            if context.state.isPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text(context.state.isBreak ? "☕" : "🎯")
                    .font(.system(size: 12))
            }
        }
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    private var accentColor: Color {
        context.state.isPaused ? ThemeColors.pausedColor :
            (context.state.isBreak ? ThemeColors.breakColor : ThemeColors.focusColor)
    }

    var body: some View {
        if context.state.isPaused {
            Image(systemName: "pause.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ThemeColors.pausedColor)
        } else {
            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(accentColor)
                .monospacedDigit()
        }
    }
}

private struct MinimalView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    private var accentColor: Color {
        context.state.isPaused ? ThemeColors.pausedColor :
            (context.state.isBreak ? ThemeColors.breakColor : ThemeColors.focusColor)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(accentColor)

            if context.state.isPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text(context.state.isBreak ? "☕" : "🎯")
                    .font(.system(size: 10))
            }
        }
    }
}

// MARK: - Dynamic Island Expanded Views

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    private var accentColor: Color {
        context.state.isPaused ? ThemeColors.pausedColor :
            (context.state.isBreak ? ThemeColors.breakColor : ThemeColors.focusColor)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 36, height: 36)

                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text(context.state.isBreak ? "☕" : "🎯")
                        .font(.system(size: 16))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.isPaused ? "Paused" : context.state.modeDisplayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                if let taskName = context.attributes.taskName, !taskName.isEmpty {
                    Text(taskName)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    private var accentColor: Color {
        context.state.isPaused ? ThemeColors.pausedColor :
            (context.state.isBreak ? ThemeColors.breakColor : ThemeColors.focusColor)
    }

    var body: some View {
        if context.state.isPaused {
            VStack(spacing: 2) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ThemeColors.pausedColor)
                Text("Paused")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ThemeColors.pausedColor.opacity(0.8))
            }
        } else {
            VStack(spacing: 2) {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("remaining")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    private var accentColor: Color {
        context.state.isPaused ? ThemeColors.pausedColor :
            (context.state.isBreak ? ThemeColors.breakColor : ThemeColors.focusColor)
    }

    var body: some View {
        HStack {
            Text(encouragementText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            // Total duration badge
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text("\(context.state.totalSeconds / 60) min")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.top, 6)
    }

    private var encouragementText: String {
        if context.state.isPaused {
            return "⏸️ Tap to resume"
        }
        if context.state.isBreak {
            return "☕ Enjoy your break"
        }
        return "🎯 Stay focused"
    }
}

// MARK: - Attributes (copied here for widget target)

struct FocusTimerAttributes: ActivityAttributes {
    let taskName: String?

    struct ContentState: Codable, Hashable {
        let endTime: Date
        let totalSeconds: Int
        let mode: String
        let isPaused: Bool

        var modeDisplayName: String {
            switch mode {
            case "focus": return "Focus"
            case "shortBreak": return "Short Break"
            case "longBreak": return "Long Break"
            default: return "Focus"
            }
        }

        var isBreak: Bool {
            mode == "shortBreak" || mode == "longBreak"
        }
    }
}
