import SwiftUI
import AVFoundation

@MainActor
struct RecordVoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WakeUpVoiceService.self) private var voiceService

    @State private var recordingState: RecordingState = .idle
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var recordedURL: URL?
    @State private var voiceName: String = ""
    @State private var isSaving = false

    private let maxDuration: TimeInterval = 30

    private enum RecordingState {
        case idle, recording, recorded
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                switch recordingState {
                case .idle: idleView
                case .recording: recordingView
                case .recorded: recordedView
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Record Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        voiceService.cancelRecording()
                        dismiss()
                    }
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.5)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(voiceService.conversionProgress ?? "Saving...")
                                .font(Theme.bodyFont)
                                .foregroundStyle(.white)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    .ignoresSafeArea()
                }
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundStyle(Theme.focusColor.opacity(0.6))
            Text("Record a wake-up message")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
            Text("Max 30 seconds")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textTertiary)
            Button { startRecording() } label: {
                VStack(spacing: 8) {
                    Image(systemName: "mic.circle.fill").font(.system(size: 64))
                    Text("Tap to Record").font(Theme.bodyFont)
                }
                .foregroundStyle(Theme.focusColor)
            }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(Color.red)
                .frame(width: 16, height: 16)
            Text(formatDuration(recordingDuration))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
            Text("\(Int(maxDuration - recordingDuration)) seconds remaining")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textTertiary)
            Button { stopRecording() } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red)
            }
        }
    }

    private var recordedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text(formatDuration(recordingDuration))
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.textSecondary)
            Button {
                if let url = recordedURL {
                    if voiceService.isPlaying {
                        voiceService.stopPlayback()
                    } else {
                        voiceService.playAudio(from: url)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: voiceService.isPlaying ? "stop.fill" : "play.fill")
                    Text(voiceService.isPlaying ? "Stop" : "Preview")
                }
                .font(Theme.bodyFont.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.focusColor.opacity(0.8))
                .clipShape(Capsule())
            }

            // Name input section
            VStack(alignment: .leading, spacing: 8) {
                Text("Give it a name")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                HStack {
                    Image(systemName: "text.cursor")
                        .foregroundStyle(Theme.textTertiary)
                    TextField("e.g. Morning motivation", text: $voiceName)
                        .font(Theme.bodyFont)
                }
                .padding()
                .background(Theme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Button { saveRecording() } label: {
                Text("Save Recording")
                    .font(Theme.bodyFont.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(voiceName.isEmpty ? Theme.textTertiary : Theme.focusColor)
                    .cornerRadius(12)
            }
            .disabled(voiceName.isEmpty || isSaving)
            .padding(.horizontal, 32)
        }
    }

    private func startRecording() {
        Task {
            let started = await voiceService.startRecording()
            if started {
                recordingState = .recording
                recordingDuration = 0
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    Task { @MainActor in
                        recordingDuration += 0.1
                        if recordingDuration >= maxDuration { stopRecording() }
                    }
                }
            }
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        Task {
            if let result = await voiceService.stopRecording() {
                recordedURL = result.url
                recordingDuration = result.duration
                recordingState = .recorded
            }
        }
    }

    private func saveRecording() {
        guard let url = recordedURL else { return }
        isSaving = true
        Task {
            _ = await voiceService.saveRecording(sourceURL: url, name: voiceName, duration: recordingDuration)
            isSaving = false
            dismiss()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        let tenths = Int((duration - Double(seconds)) * 10)
        return String(format: "%02d.%d", seconds, tenths)
    }
}
