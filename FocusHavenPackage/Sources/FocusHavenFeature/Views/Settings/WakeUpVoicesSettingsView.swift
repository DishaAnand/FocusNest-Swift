import SwiftUI

@MainActor
struct WakeUpVoicesSettingsView: View {
    @Environment(WakeUpVoiceService.self) private var voiceService
    @State private var showingRecordSheet = false

    var body: some View {
        @Bindable var voiceService = voiceService

        List {
            Section {
                Toggle("Enable Wake-Up Voice", isOn: $voiceService.isEnabled)
            } footer: {
                Text("When enabled, your recorded voice will play as the notification sound when your break ends.")
            }

            if voiceService.isEnabled {
                Section {
                    Toggle("Shuffle Recordings", isOn: $voiceService.shuffleEnabled)
                } footer: {
                    Text("Randomly pick from your recordings each time.")
                }

                Section {
                    if voiceService.voices.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.textTertiary)
                            Text("No recordings yet")
                                .font(Theme.bodyFont)
                                .foregroundStyle(Theme.textSecondary)
                            Text("Record a short message (max 30 sec)")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(voiceService.voices) { voice in
                            VoiceRow(voice: voice)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                voiceService.deleteVoice(voiceService.voices[index])
                            }
                        }
                    }

                    Button {
                        showingRecordSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Theme.focusColor)
                            Text("Record New Voice")
                                .foregroundStyle(Theme.focusColor)
                        }
                    }
                } header: {
                    Text("Your Recordings")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How it works", systemImage: "info.circle")
                            .font(Theme.bodyFont.weight(.medium))
                        Text("Your voice will play as the notification sound when your break timer ends. This works even when you're using other apps.")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Wake-Up Voice")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRecordSheet) {
            RecordVoiceView()
        }
    }
}

// MARK: - Voice Row

private struct VoiceRow: View {
    let voice: WakeUpVoice
    @Environment(WakeUpVoiceService.self) private var voiceService

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if voiceService.isPlaying {
                    voiceService.stopPlayback()
                } else {
                    voiceService.playVoice(voice)
                }
            } label: {
                Image(systemName: voiceService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.focusColor)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(voice.name)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textPrimary)
                Text(voice.formattedDuration)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            Button {
                voiceService.setDefault(voice)
            } label: {
                Image(systemName: voice.isDefault ? "star.fill" : "star")
                    .foregroundStyle(voice.isDefault ? .yellow : Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
