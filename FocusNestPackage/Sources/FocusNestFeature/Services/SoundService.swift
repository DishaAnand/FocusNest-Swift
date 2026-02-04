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

    public func playTimerComplete() { AudioServicesPlaySystemSound(1007) }
    public func playSuccess() { AudioServicesPlaySystemSound(1057) }
    public func playNotification() { AudioServicesPlaySystemSound(1315) }
    public func playTap() { AudioServicesPlaySystemSound(1104) }

    public func lightImpact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    public func mediumImpact() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    public func heavyImpact() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    public func successHaptic() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    public func warningHaptic() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    public func errorHaptic() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    public func selectionChanged() { UISelectionFeedbackGenerator().selectionChanged() }
}
