import Foundation

/// Time utilities matching React Native `src/utils/time.ts`
public enum TimeUtils {

    /// Convert seconds to whole minutes (floor division)
    /// Matches RN: `secsToWholeMinutes(secs)`
    /// - Parameter seconds: Number of seconds (handles nil/negative as 0)
    /// - Returns: Whole minutes (floored)
    public static func secsToWholeMinutes(_ seconds: Int?) -> Int {
        guard let secs = seconds, secs > 0 else { return 0 }
        return secs / 60
    }

    /// Format seconds as human-readable duration
    /// Matches RN: `fmtHMsec(s)`
    ///
    /// Examples:
    /// - 3661 → "1h 1m"
    /// - 3600 → "1h"
    /// - 90 → "1m 30s"
    /// - 60 → "1m"
    /// - 30 → "0m 30s"
    ///
    /// - Parameter seconds: Total seconds
    /// - Returns: Formatted string like "1h 30m" or "25m 30s"
    public static func fmtHMsec(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes)m \(remainingSeconds)s"
            } else {
                return "\(minutes)m"
            }
        }
    }

    /// Format seconds as MM:SS for timer display
    /// - Parameter seconds: Total seconds
    /// - Returns: Formatted string like "25:00" or "05:30"
    public static func formatTimerDisplay(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
