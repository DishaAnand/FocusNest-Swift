import SwiftUI
import AVFoundation

@MainActor
struct WakeUpVoicesSettingsView: View {
    @Environment(WakeUpVoiceService.self) private var voiceService
    @State private var showingRecordSheet = false

    var body: some View {
        @Bindable var voiceService = voiceService

        List {
            Section {
                Toggle("Enable Wake-Up Voices", isOn: $voiceService.isEnabled)
            } footer: {
                Text("When enabled, a voice recording will play if you extend your break by more than 2 minutes.")
            }

            if voiceService.isEnabled {
                Section {
                    Toggle("Play in Silent Mode", isOn: $voiceService.playInSilentMode)
                    Toggle("Shuffle Recordings", isOn: $voiceService.shuffleEnabled)
                } footer: {
                    Text("Shuffle will randomly pick from your recordings each time.")
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
                            Text("Add your first wake-up voice")
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
                            Text("Add Recording")
                                .foregroundStyle(Theme.focusColor)
                        }
                    }
                } header: {
                    Text("Your Recordings")
                }
            }
        }
        .navigationTitle("Wake-Up Voices")
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
