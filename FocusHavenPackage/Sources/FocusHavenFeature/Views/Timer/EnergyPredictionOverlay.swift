import SwiftUI

/// Floating overlay with vertical energy slider
struct EnergyPredictionOverlay: View {
    let onStart: (Int) -> Void
    let onDismiss: () -> Void

    @State private var selectedLevel: Int = 3
    @State private var isDragging = false
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    private let levelEmojis = ["😴", "😐", "🙂", "😊", "🔥"]
    private let levelLabels = [
        "Low energy",
        "Bit tired",
        "Okay",
        "Good",
        "Laser focus"
    ]

    private var currentColor: Color {
        switch selectedLevel {
        case 1: return Color.orange
        case 2: return Color(red: 1.0, green: 0.6, blue: 0.0)
        case 3: return Color(red: 0.9, green: 0.5, blue: 0.0)
        case 4: return Color(red: 1.0, green: 0.35, blue: 0.0)
        case 5: return Color(red: 1.0, green: 0.2, blue: 0.0)
        default: return .orange
        }
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Floating card
            VStack(spacing: 20) {
                // Header
                Text("How focused can you be?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 24)

                // Vertical slider area
                HStack(spacing: 24) {
                    // Labels on left
                    VStack(spacing: 0) {
                        ForEach((1...5).reversed(), id: \.self) { level in
                            Text(levelEmojis[level - 1])
                                .font(.system(size: 24))
                                .opacity(level == selectedLevel ? 1.0 : 0.4)
                                .frame(height: 52)
                        }
                    }

                    // Vertical slider
                    GeometryReader { geometry in
                        let sliderHeight = geometry.size.height
                        let segmentHeight = sliderHeight / 5

                        ZStack(alignment: .bottom) {
                            // Background track
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Theme.textTertiary.opacity(0.15))
                                .frame(width: 56)

                            // Filled portion
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [currentColor.opacity(0.7), currentColor],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: 56, height: segmentHeight * CGFloat(selectedLevel))
                                .shadow(color: currentColor.opacity(0.5), radius: 12, x: 0, y: -4)
                                .animation(.spring(response: 0.25), value: selectedLevel)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    // Invert because Y increases downward
                                    let invertedY = sliderHeight - value.location.y
                                    let newLevel = max(1, min(5, Int(ceil(invertedY / segmentHeight))))
                                    if newLevel != selectedLevel {
                                        selectedLevel = newLevel
                                        soundService.selectionChanged(settings: settings)
                                    }
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                    }
                    .frame(width: 56, height: 260)

                    // Current selection display
                    VStack(spacing: 8) {
                        Text("\(selectedLevel)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(currentColor)
                            .contentTransition(.numericText())

                        Text(levelLabels[selectedLevel - 1])
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(width: 100)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 8)

                // Start button
                Button {
                    soundService.mediumImpact(settings: settings)
                    onStart(selectedLevel)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text("Start Focus")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.focusGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(width: 300, height: 440)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Theme.textTertiary.opacity(0.15), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
        }
    }
}

/// Cute pill button with pink/purple gradient to trigger energy prediction
struct EnergyPredictionPill: View {
    let lastPrediction: Int?
    let onTap: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let last = lastPrediction {
                    Text("Predicted \(last)/5")
                        .font(.system(size: 14, weight: .medium))
                } else {
                    Text("Predict your focus")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Theme.backgroundSecondary.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.5), .pink.opacity(0.4), .orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .purple.opacity(0.15), radius: 8, x: 0, y: 2)
            )
            .scaleEffect(isAnimating ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        EnergyPredictionOverlay(
            onStart: { level in print("Starting with level \(level)") },
            onDismiss: { print("Dismissed") }
        )
        .environment(SoundService())
        .environment(UserSettings())
    }
}
