import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct WakeUpVoicesSettingsView: View {
    @Environment(WakeUpVoiceService.self) private var voiceService
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(NotificationService.self) private var notificationService
    @State private var showingRecordSheet = false
    @State private var showingFileImporter = false
    @State private var showingNamePrompt = false
    @State private var importedFileURL: URL?
    @State private var importName = ""
    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var showUpgradePrompt = false

    private var canAddMoreVoices: Bool {
        subscriptionService.canAddWakeUpVoice(currentCount: voiceService.voices.count)
    }

    var body: some View {
        @Bindable var voiceService = voiceService

        List {
            if !notificationService.isAuthorized {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notifications Disabled")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Wake-up voices need notifications to alert you when your break ends. Enable them in Settings.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("Open Settings")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

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
                        if canAddMoreVoices {
                            showingRecordSheet = true
                        } else {
                            showUpgradePrompt = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "mic.circle.fill")
                                .foregroundStyle(Theme.focusColor)
                            Text("Record New Voice")
                                .foregroundStyle(Theme.focusColor)
                            if !canAddMoreVoices {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }

                    Button {
                        if canAddMoreVoices {
                            showingFileImporter = true
                        } else {
                            showUpgradePrompt = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundStyle(.orange)
                            Text("Import Audio File")
                                .foregroundStyle(.orange)
                            if !canAddMoreVoices {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                } header: {
                    Text("Your Recordings")
                } footer: {
                    Text("⏱ Maximum 30 seconds. Longer files will be rejected.")
                        .foregroundStyle(.orange)
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
        .task {
            await notificationService.checkAuthorizationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await notificationService.checkAuthorizationStatus() }
        }
        .sheet(isPresented: $showingRecordSheet) {
            RecordVoiceView()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importedFileURL = url
                    importName = url.deletingPathExtension().lastPathComponent
                    showingNamePrompt = true
                }
            case .failure(let error):
                importError = error.localizedDescription
                showingImportError = true
            }
        }
        .sheet(isPresented: $showingNamePrompt) {
            ImportNamePromptView(
                fileName: importedFileURL?.lastPathComponent ?? "audio",
                name: $importName,
                isImporting: isImporting,
                progress: voiceService.conversionProgress,
                onCancel: {
                    importedFileURL = nil
                    importName = ""
                    showingNamePrompt = false
                },
                onImport: {
                    guard let url = importedFileURL else { return }
                    isImporting = true
                    Task {
                        let result = await voiceService.importAudioFile(from: url, name: importName)
                        isImporting = false
                        switch result {
                        case .success:
                            importedFileURL = nil
                            importName = ""
                            showingNamePrompt = false
                        case .tooLong(let duration):
                            importError = "Audio is \(Int(duration)) seconds. Maximum allowed is 30 seconds."
                            showingNamePrompt = false
                            showingImportError = true
                        case .failed(let error):
                            importError = error.localizedDescription
                            showingNamePrompt = false
                            showingImportError = true
                        }
                    }
                }
            )
            .presentationDetents([.height(280)])
            .interactiveDismissDisabled(isImporting)
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK") {
                importError = nil
            }
        } message: {
            Text(importError ?? "Unknown error")
        }
        .sheet(isPresented: $showUpgradePrompt) {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { showUpgradePrompt = false }
                UpgradePromptView.wakeUpVoiceLimit()
            }
            .presentationBackground(.clear)
        }
    }
}

// MARK: - Import Name Prompt

private struct ImportNamePromptView: View {
    let fileName: String
    @Binding var name: String
    let isImporting: Bool
    let progress: String?
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // File info
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Importing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(fileName)
                            .font(.body)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Give it a name")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Morning alarm", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isImporting)
                }

                Spacer()

                // Import button
                Button {
                    onImport()
                } label: {
                    if isImporting {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                            Text(progress ?? "Importing...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("Import")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(name.isEmpty ? Color.gray : Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .disabled(name.isEmpty || isImporting)
            }
            .padding()
            .navigationTitle("Import Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isImporting)
                }
            }
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

            if !voiceService.shuffleEnabled {
                Button {
                    voiceService.setDefault(voice)
                } label: {
                    Image(systemName: voice.isDefault ? "star.fill" : "star")
                        .foregroundStyle(voice.isDefault ? .yellow : Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
