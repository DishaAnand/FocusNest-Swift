import SwiftUI

@MainActor
struct AmbientSoundButton: View {
    let sound: AmbientSound
    let isPlaying: Bool
    let onTap: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "waveform" : sound.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isPlaying && isAnimating ? 1.1 : 1.0)

                Text(sound.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                if isPlaying {
                    // Small animated dots
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 4, height: 4)
                                .scaleEffect(isAnimating ? [1.0, 1.4, 0.8][i] : [0.8, 1.0, 1.2][i])
                                .animation(
                                    .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                    value: isAnimating
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Theme.backgroundSecondary.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                LinearGradient(
                                    colors: isPlaying
                                        ? [.cyan.opacity(0.6), .blue.opacity(0.5), .purple.opacity(0.3)]
                                        : [.cyan.opacity(0.4), .blue.opacity(0.3), .teal.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .cyan.opacity(isPlaying ? 0.25 : 0.12), radius: 8, x: 0, y: 2)
            )
            .scaleEffect(isAnimating && !isPlaying ? 1.02 : 1.0)
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
    VStack(spacing: 20) {
        AmbientSoundButton(sound: .silence, isPlaying: false) {}
        AmbientSoundButton(sound: .rain, isPlaying: false) {}
        AmbientSoundButton(sound: .rain, isPlaying: true) {}
        AmbientSoundButton(sound: .oceanWaves, isPlaying: true) {}
    }
    .padding()
    .background(Theme.backgroundPrimary)
}
