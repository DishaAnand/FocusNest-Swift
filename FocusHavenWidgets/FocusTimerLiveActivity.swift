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
                // Expanded view (when long-pressed)
                DynamicIslandExpandedRegion(.center) {
                    ExpandedView(context: context)
                }
            } compactLeading: {
                // Compact leading - colored dot
                Circle()
                    .fill(context.state.isBreak ? Color.cyan : Color.green)
                    .frame(width: 8, height: 8)
            } compactTrailing: {
                // Compact trailing - timer
                if context.state.isPaused {
                    Text("||")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                } else {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(context.state.isBreak ? Color.cyan : Color.green)
                        .monospacedDigit()
                }
            } minimal: {
                // Minimal view (when another activity is shown)
                Circle()
                    .fill(context.state.isBreak ? Color.cyan : Color.green)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    private var modeColor: Color {
        context.state.isBreak ? .cyan : .green
    }

    var body: some View {
        VStack(spacing: 12) {
            // Timer - hero element
            if context.state.isPaused {
                Text("PAUSED")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            } else {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            // Mode label
            Text(context.state.modeDisplayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(modeColor)
                .textCase(.uppercase)
                .tracking(1.5)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)

                    // Progress
                    if !context.state.isPaused {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(modeColor)
                            .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    }
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 40)

            // Task name
            if let taskName = context.attributes.taskName {
                Text(taskName)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .activityBackgroundTint(Color.black.opacity(0.8))
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let elapsed = context.state.totalSeconds - Int(context.state.endTime.timeIntervalSinceNow)
        let progress = min(max(Double(elapsed) / Double(context.state.totalSeconds), 0), 1)
        return totalWidth * progress
    }
}

// MARK: - Dynamic Island Expanded View

private struct ExpandedView: View {
    let context: ActivityViewContext<FocusTimerAttributes>

    private var modeColor: Color {
        context.state.isBreak ? .cyan : .green
    }

    var body: some View {
        VStack(spacing: 10) {
            // Top row: dot + timer + mode
            HStack(spacing: 8) {
                Circle()
                    .fill(modeColor)
                    .frame(width: 10, height: 10)

                if context.state.isPaused {
                    Text("PAUSED")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                } else {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                Text(context.state.modeDisplayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(modeColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.2))
                        .frame(height: 3)

                    if !context.state.isPaused {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(modeColor)
                            .frame(width: progressWidth(in: geometry.size.width), height: 3)
                    }
                }
            }
            .frame(height: 3)

            // Task name
            if let taskName = context.attributes.taskName {
                Text(taskName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            } else {
                Text("Stay focused!")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let elapsed = context.state.totalSeconds - Int(context.state.endTime.timeIntervalSinceNow)
        let progress = min(max(Double(elapsed) / Double(context.state.totalSeconds), 0), 1)
        return totalWidth * progress
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
