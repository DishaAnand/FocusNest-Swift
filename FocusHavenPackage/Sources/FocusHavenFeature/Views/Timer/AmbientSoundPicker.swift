import SwiftUI

@MainActor
struct AmbientSoundPicker: View {
    @Environment(AmbientSoundService.self) private var soundService
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var showUpgradePrompt = false

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
                            let isLocked = !sound.isFree && !subscriptionService.canAccessAllSounds
                            SoundOptionRow(
                                sound: sound,
                                isSelected: soundService.selectedSound == sound,
                                isLocked: isLocked
                            ) {
                                if isLocked {
                                    showUpgradePrompt = true
                                } else {
                                    soundService.changeSound(to: sound)
                                }
                            }
                        }
                    }
                    .padding(Theme.spacingM)
                    .frame(maxWidth: 500)  // iPad: constrain content width
                    .frame(maxWidth: .infinity)  // Center on larger screens
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
            .sheet(isPresented: $showUpgradePrompt) {
                UpgradePromptSheet {
                    UpgradePromptView.soundsLocked()
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// Helper to present UpgradePromptView in a sheet
private struct UpgradePromptSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
                .onTapGesture { dismiss() }
            content()
        }
        .presentationBackground(.clear)
    }
}

@MainActor
private struct SoundOptionRow: View {
    let sound: AmbientSound
    let isSelected: Bool
    let isLocked: Bool
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
                    .foregroundStyle(isLocked ? Theme.textSecondary : Theme.textPrimary)

                Spacer()

                // Lock or Checkmark
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textTertiary)
                } else if isSelected {
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
