import SwiftUI

@MainActor
struct AmbientSoundPicker: View {
    @Environment(AmbientSoundService.self) private var soundService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Volume slider
                VStack(spacing: Theme.spacingS) {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(Theme.textSecondary)
                        Slider(value: Binding(
                            get: { Double(soundService.volume) },
                            set: { soundService.volume = Float($0) }
                        ), in: 0...1)
                        .tint(Theme.focusColor)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, Theme.spacingM)
                    .padding(.vertical, Theme.spacingS)
                }
                .background(Theme.backgroundSecondary)

                // Sound options
                ScrollView {
                    LazyVStack(spacing: Theme.spacingS) {
                        ForEach(AmbientSound.allCases) { sound in
                            SoundOptionRow(
                                sound: sound,
                                isSelected: soundService.selectedSound == sound
                            ) {
                                soundService.changeSound(to: sound)
                            }
                        }
                    }
                    .padding(Theme.spacingM)
                }
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("Ambient Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

@MainActor
private struct SoundOptionRow: View {
    let sound: AmbientSound
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.spacingM) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.focusColor : Theme.backgroundSecondary)
                        .frame(width: 44, height: 44)

                    Image(systemName: sound.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? .white : Theme.textSecondary)
                }

                // Name
                Text(sound.displayName)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.focusColor)
                }
            }
            .padding(Theme.spacingM)
            .background(isSelected ? Theme.focusColor.opacity(0.1) : Theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AmbientSoundPicker()
        .environment(AmbientSoundService())
}
