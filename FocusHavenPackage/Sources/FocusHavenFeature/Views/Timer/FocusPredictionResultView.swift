import SwiftUI

struct FocusPredictionResultView: View {
    let predictedLevel: Int
    let actualLevel: Int
    let duration: Int
    let distractionCount: Int
    let wasCompleted: Bool
    let onDone: () -> Void

    @State private var showContent = false
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    private var comparisonType: ComparisonType {
        if actualLevel > predictedLevel { return .underestimated }
        else if actualLevel == predictedLevel { return .spotOn }
        else { return .overestimated }
    }

    private var message: String {
        switch comparisonType {
        case .underestimated: return ["You underestimate yourself!", "Better than you thought!", "Plot twist: you crushed it"].randomElement()!
        case .spotOn: return ["Nailed it! You know yourself well", "Prediction master!", "Exactly as planned"].randomElement()!
        case .overestimated: return ["Tough one - awareness is growth", "You showed up. That counts", "Tomorrow's a new chance"].randomElement()!
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Focus score
                VStack(spacing: 12) {
                    Text("YOUR FOCUS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(2)

                    // Flames
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { level in
                            Image(systemName: "flame.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(level <= actualLevel ? comparisonType.color : .white.opacity(0.15))
                                .shadow(color: level <= actualLevel ? comparisonType.color.opacity(0.5) : .clear, radius: 6)
                        }
                    }
                    .opacity(showContent ? 1 : 0)

                    // Big number
                    Text("\(actualLevel)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(comparisonType.color)
                        .opacity(showContent ? 1 : 0)
                }

                // Comparison
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("Predicted")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("\(predictedLevel)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.white.opacity(0.3))

                    VStack(spacing: 4) {
                        Text("Actual")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("\(actualLevel)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(comparisonType.color)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.05)))
                .opacity(showContent ? 1 : 0)

                // Message
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: comparisonType.icon)
                        Text(comparisonType.title)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(comparisonType.color)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .opacity(showContent ? 1 : 0)

                // Stats
                HStack(spacing: 12) {
                    StatPill(icon: "clock", text: "\(duration / 60)m", color: .green)
                    StatPill(icon: distractionCount == 0 ? "checkmark.shield" : "exclamationmark.triangle",
                             text: distractionCount == 0 ? "Focused" : "\(distractionCount) breaks",
                             color: distractionCount == 0 ? .green : .orange)
                    StatPill(icon: wasCompleted ? "flag.checkered" : "stop.circle",
                             text: wasCompleted ? "Done" : "Early",
                             color: wasCompleted ? .green : .red)
                }
                .opacity(showContent ? 1 : 0)

                Spacer()

                // Button
                Button {
                    soundService.lightImpact(settings: settings)
                    onDone()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.focusGradient)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                showContent = true
            }
            soundService.successHaptic(settings: settings)
        }
    }
}

private struct StatPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.15)))
    }
}

private enum ComparisonType {
    case underestimated, spotOn, overestimated

    var title: String {
        switch self {
        case .underestimated: return "Better than expected!"
        case .spotOn: return "Spot on!"
        case .overestimated: return "Room to grow"
        }
    }

    var icon: String {
        switch self {
        case .underestimated: return "arrow.up.circle.fill"
        case .spotOn: return "target"
        case .overestimated: return "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .underestimated: return .green
        case .spotOn: return Color(red: 0.4, green: 0.8, blue: 0.6)
        case .overestimated: return .orange
        }
    }
}

#Preview {
    FocusPredictionResultView(
        predictedLevel: 3,
        actualLevel: 4,
        duration: 25 * 60,
        distractionCount: 1,
        wasCompleted: true,
        onDone: {}
    )
    .environment(SoundService())
    .environment(UserSettings())
}
