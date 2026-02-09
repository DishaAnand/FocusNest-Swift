import SwiftUI

@MainActor
struct AmbientSoundButton: View {
    let sound: AmbientSound
    let isPlaying: Bool
    let onTap: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "waveform" : sound.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.focusColor)
                    .scaleEffect(isPlaying && isAnimating ? 1.1 : 1.0)

                Text(sound.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                if isPlaying {
                    // Animated dots
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Theme.focusColor)
                                .frame(width: 5, height: 5)
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
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Theme.backgroundSecondary)
                    .overlay(
                        Capsule()
                            .stroke(
                                isPlaying ? Theme.focusColor : Theme.focusColor.opacity(0.4),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Theme.focusColor.opacity(isPlaying ? 0.25 : 0.12), radius: 10, x: 0, y: 4)
            )
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
