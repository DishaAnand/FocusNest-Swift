import SwiftUI

/// Progress bar showing progress toward unlocking early exit from break
struct UnlockProgressBar: View {
    let progress: Double // 0-100

    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    private var normalizedProgress: Double {
        min(max(progress, 0), 100) / 100.0
    }

    private var isComplete: Bool {
        progress >= 100
    }

    private var barColor: Color {
        switch progress {
        case 0..<25:
            return Theme.breakColor
        case 25..<50:
            return Color(red: 0.2, green: 0.6, blue: 0.9) // Blue transitioning to cyan
        case 50..<75:
            return .cyan
        case 75..<100:
            return Color(red: 0.9, green: 0.4, blue: 0.6) // Transitioning to pink
        default:
            return .pink
        }
    }

    private var message: String {
        switch progress {
        case 0..<25:
            return "Get moving to unlock early exit"
        case 25..<50:
            return "You're warming up!"
        case 50..<75:
            return "Halfway to freedom!"
        case 75..<100:
            return "Almost there!"
        default:
            return "Break Complete! Tap to continue"
        }
    }

    private var lockIcon: String {
        isComplete ? "lock.open.fill" : "lock.fill"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 8)

                // Progress fill
                GeometryReader { geometry in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [barColor, barColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * normalizedProgress)
                        .shadow(color: barColor.opacity(glowOpacity), radius: 8, x: 0, y: 0)
                        .scaleEffect(x: 1, y: pulseScale, anchor: .center)
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity)

            // Lock icon and message
            HStack(spacing: 8) {
                Image(systemName: lockIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isComplete ? .pink : .white.opacity(0.7))
                    .scaleEffect(isComplete ? 1.2 : 1.0)

                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Text("\(Int(min(progress, 100)))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(barColor)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 24)
        .onAppear {
            startPulseAnimation()
        }
        .onChange(of: progress) { _, newValue in
            updatePulseAnimation(for: newValue)
        }
    }

    private func startPulseAnimation() {
        updatePulseAnimation(for: progress)
    }

    private func updatePulseAnimation(for value: Double) {
        // Different pulse speeds based on progress
        let duration: Double
        let scale: CGFloat

        switch value {
        case 0..<50:
            // No pulse for low progress
            withAnimation(.easeInOut(duration: 0.3)) {
                pulseScale = 1.0
                glowOpacity = 0.3
            }
            return
        case 50..<75:
            duration = 1.5
            scale = 1.1
        case 75..<100:
            duration = 0.8
            scale = 1.15
        default:
            // Complete - celebration pulse
            duration = 0.5
            scale = 1.2
        }

        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            pulseScale = scale
            glowOpacity = 0.6
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 40) {
            UnlockProgressBar(progress: 15)
            UnlockProgressBar(progress: 35)
            UnlockProgressBar(progress: 60)
            UnlockProgressBar(progress: 85)
            UnlockProgressBar(progress: 100)
        }
        .padding()
    }
}
