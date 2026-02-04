import Foundation
import AVFoundation
import UIKit

@MainActor
@Observable
public final class SoundService: @unchecked Sendable {
    public init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    public func playTimerComplete(settings: UserSettings) {
        guard settings.soundEnabled else { return }
        AudioServicesPlaySystemSound(1007)
    }

    public func playSuccess(settings: UserSettings) {
        guard settings.soundEnabled else { return }
        AudioServicesPlaySystemSound(1057)
    }

    public func playNotification(settings: UserSettings) {
        guard settings.soundEnabled else { return }
        AudioServicesPlaySystemSound(1315)
    }

    public func playTap(settings: UserSettings) {
        guard settings.soundEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }

    public func lightImpact(settings: UserSettings) {
        guard settings.vibrationEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public func mediumImpact(settings: UserSettings) {
        guard settings.vibrationEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    public func heavyImpact(settings: UserSettings) {
        guard settings.vibrationEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    public func successHaptic(settings: UserSettings) {
        guard settings.vibrationEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public func warningHaptic(settings: UserSettings) {
        guard settings.vibrationEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    public func errorHaptic(settings: UserSettings) {
        guard settings.vibrationEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    public func selectionChanged(settings: UserSettings) {
        guard settings.vibrationEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
