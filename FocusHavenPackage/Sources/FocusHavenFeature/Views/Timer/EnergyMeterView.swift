import SwiftUI

struct EnergyMeterView: View {
    let onStart: (Int) -> Void
    let onSkip: () -> Void

    @State private var selectedLevel: Int = 3
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    private let levelLabels = [
        "Expecting distractions",
        "Might struggle a bit",
        "Moderately focused",
        "Pretty locked in",
        "Full laser mode"
    ]

    private var meterGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.7),
                Color.orange,
                Color(red: 1.0, green: 0.4, blue: 0.1),
                Color(red: 1.0, green: 0.25, blue: 0.1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var currentColor: Color {
        switch selectedLevel {
        case 1: return .orange.opacity(0.7)
        case 2: return .orange
        case 3: return Color(red: 1.0, green: 0.5, blue: 0.0)
        case 4: return Color(red: 1.0, green: 0.3, blue: 0.0)
        case 5: return Color(red: 1.0, green: 0.2, blue: 0.0)
        default: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with Skip button
            HStack {
                Text("How focused will you be?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Text("Optional · helps track self-awareness")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)

            // Horizontal Energy Meter with sliding
            VStack(spacing: 16) {
                GeometryReader { geometry in
                    let meterWidth = geometry.size.width
                    let segmentWidth = meterWidth / 5

                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.textTertiary.opacity(0.15))

                        // Filled portion with gradient
                        RoundedRectangle(cornerRadius: 12)
                            .fill(meterGradient)
                            .frame(width: segmentWidth * CGFloat(selectedLevel))
                            .shadow(color: currentColor.opacity(0.5), radius: 8, x: 0, y: 2)

                        // Divider lines
                        HStack(spacing: 0) {
                            ForEach(1...4, id: \.self) { _ in
                                Spacer()
                                Rectangle()
                                    .fill(Color.white.opacity(0.25))
                                    .frame(width: 1.5, height: 32)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: 48)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newLevel = max(1, min(5, Int(ceil(value.location.x / segmentWidth))))
                                if newLevel != selectedLevel {
                                    selectedLevel = newLevel
                                    soundService.selectionChanged(settings: settings)
                                }
                            }
                    )
                    .onTapGesture { location in
                        let newLevel = max(1, min(5, Int(ceil(location.x / segmentWidth))))
                        withAnimation(.spring(response: 0.2)) {
                            selectedLevel = newLevel
                        }
                        soundService.selectionChanged(settings: settings)
                    }
                }
                .frame(height: 48)
                .padding(.horizontal, 24)

                // Level indicators below meter
                HStack(spacing: 0) {
                    ForEach(1...5, id: \.self) { level in
                        Text("\(level)")
                            .font(.system(size: 13, weight: level == selectedLevel ? .bold : .medium))
                            .foregroundStyle(level <= selectedLevel ? currentColor : Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 32)
            }

            // Selected level display
            VStack(spacing: 4) {
                Text("\(selectedLevel)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(currentColor)
                    .contentTransition(.numericText())

                Text(levelLabels[selectedLevel - 1])
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 8)

            Spacer(minLength: 16)

            // Start button
            Button {
                soundService.mediumImpact(settings: settings)
                onStart(selectedLevel)
            } label: {
                Text("Start Focus Session")
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
        .background(Theme.backgroundPrimary)
    }
}

#Preview {
    EnergyMeterView(
        onStart: { level in print("Starting with level \(level)") },
        onSkip: { print("Skipped") }
    )
    .environment(SoundService())
    .environment(UserSettings())
}
