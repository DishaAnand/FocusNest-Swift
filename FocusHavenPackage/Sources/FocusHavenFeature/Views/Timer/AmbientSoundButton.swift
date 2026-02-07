import SwiftUI

@MainActor
struct AmbientSoundButton: View {
    let sound: AmbientSound
    let isPlaying: Bool
    let onTap: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Animated icon container
                ZStack {
                    // Pulse ring when playing
                    if isPlaying {
                        Circle()
                            .stroke(Theme.focusColor.opacity(0.3), lineWidth: 2)
                            .frame(width: 32, height: 32)
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                            .opacity(isPulsing ? 0 : 0.6)
                    }

                    // Icon background
                    Circle()
                        .fill(isPlaying ? Theme.focusColor : Theme.textTertiary.opacity(0.3))
                        .frame(width: 28, height: 28)

                    // Icon
                    Image(systemName: sound.iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isPlaying ? .white : Theme.textSecondary)
                }
                .frame(width: 32, height: 32)

                // Sound name
                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)

                    if isPlaying {
                        Text("Playing")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.focusColor)
                    } else {
                        Text("Tap to change")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isPlaying ? Theme.focusColor.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onChange(of: isPlaying) { _, playing in
            if playing {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
        .onAppear {
            if isPlaying {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
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
