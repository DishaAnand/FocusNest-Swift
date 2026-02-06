import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@MainActor
struct RecordVoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WakeUpVoiceService.self) private var voiceService

    @State private var recordingState: RecordingState = .idle
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var recordedURL: URL?
    @State private var voiceName: String = ""
    @State private var showingFilePicker = false

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
            .navigationTitle("Add Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        voiceService.cancelRecording()
                        dismiss()
                    }
                }
            }
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
                handleFileImport(result)
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundStyle(Theme.focusColor.opacity(0.6))
            Text("Record or import a voice")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 20) {
                Button { startRecording() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.circle.fill").font(.system(size: 48))
                        Text("Record").font(Theme.bodyFont)
                    }
                    .foregroundStyle(Theme.focusColor)
                    .frame(width: 120, height: 100)
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(16)
                }
                Button { showingFilePicker = true } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.circle.fill").font(.system(size: 48))
                        Text("Import").font(Theme.bodyFont)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 120, height: 100)
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(16)
                }
            }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 24) {
            Circle().fill(Color.red).frame(width: 16, height: 16)
            Text(formatDuration(recordingDuration))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
            Text("Max 30 seconds").font(Theme.captionFont).foregroundStyle(Theme.textTertiary)
            Button { stopRecording() } label: {
                Image(systemName: "stop.circle.fill").font(.system(size: 72)).foregroundStyle(.red)
            }
        }
    }

    private var recordedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(.green)
            Text(formatDuration(recordingDuration)).font(.system(size: 32, weight: .light)).foregroundStyle(Theme.textSecondary)
            Button {
                if let url = recordedURL { voiceService.playAudio(from: url) }
            } label: {
                HStack { Image(systemName: "play.fill"); Text("Preview") }
                    .font(Theme.bodyFont).foregroundStyle(Theme.focusColor)
            }
            TextField("Name this recording", text: $voiceName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)
            Button { saveRecording() } label: {
                Text("Save")
                    .font(Theme.bodyFont.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(voiceName.isEmpty ? Theme.textTertiary : Theme.focusColor)
                    .cornerRadius(12)
            }
            .disabled(voiceName.isEmpty)
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
                        if recordingDuration >= 30 { stopRecording() }
                    }
                }
            }
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        if let result = voiceService.stopRecording() {
            recordedURL = result.url
            recordingDuration = result.duration
            recordingState = .recorded
        }
    }

    private func saveRecording() {
        guard let url = recordedURL else { return }
        _ = voiceService.saveRecording(url: url, name: voiceName, duration: recordingDuration)
        dismiss()
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let fileName = "\(UUID().uuidString).m4a"
            let destURL = voiceService.getFileURL(for: WakeUpVoice(name: "", fileName: fileName, duration: 0))
            do {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                try FileManager.default.copyItem(at: url, to: destURL)
                let asset = AVURLAsset(url: destURL)
                Task {
                    let duration = try await asset.load(.duration)
                    let seconds = CMTimeGetSeconds(duration)
                    await MainActor.run {
                        recordedURL = destURL
                        recordingDuration = min(seconds, 30)
                        recordingState = .recorded
                        voiceName = url.deletingPathExtension().lastPathComponent
                    }
                }
            } catch { print("Failed to import: \(error)") }
        case .failure(let error): print("Import failed: \(error)")
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        let tenths = Int((duration - Double(seconds)) * 10)
        return String(format: "%02d.%d", seconds, tenths)
    }
}
