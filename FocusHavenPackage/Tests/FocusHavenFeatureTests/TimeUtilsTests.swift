import Testing
import Foundation
@testable import FocusHavenFeature

@Suite("TimeUtils Tests - Matching RN time.ts")
struct TimeUtilsTests {

    // MARK: - secsToWholeMinutes Tests

    @Test("secsToWholeMinutes converts correctly")
    func secsToWholeMinutesBasic() {
        #expect(TimeUtils.secsToWholeMinutes(60) == 1)
        #expect(TimeUtils.secsToWholeMinutes(120) == 2)
        #expect(TimeUtils.secsToWholeMinutes(1500) == 25)
    }

    @Test("secsToWholeMinutes floors partial minutes")
    func secsToWholeMinutesFloors() {
        #expect(TimeUtils.secsToWholeMinutes(59) == 0)
        #expect(TimeUtils.secsToWholeMinutes(90) == 1)
        #expect(TimeUtils.secsToWholeMinutes(119) == 1)
    }

    @Test("secsToWholeMinutes handles nil")
    func secsToWholeMinutesNil() {
        #expect(TimeUtils.secsToWholeMinutes(nil) == 0)
    }

    @Test("secsToWholeMinutes handles zero and negative")
    func secsToWholeMinutesZeroNegative() {
        #expect(TimeUtils.secsToWholeMinutes(0) == 0)
        #expect(TimeUtils.secsToWholeMinutes(-60) == 0)
    }

    // MARK: - fmtHMsec Tests (matching RN exactly)

    @Test("fmtHMsec formats hours and minutes")
    func fmtHMsecHoursMinutes() {
        // RN: >= 3600 returns "Xh Ym" or "Xh"
        #expect(TimeUtils.fmtHMsec(3661) == "1h 1m")   // 1 hour, 1 minute, 1 second
        #expect(TimeUtils.fmtHMsec(3660) == "1h 1m")   // 1 hour, 1 minute
        #expect(TimeUtils.fmtHMsec(3600) == "1h")      // exactly 1 hour
        #expect(TimeUtils.fmtHMsec(7200) == "2h")      // exactly 2 hours
        #expect(TimeUtils.fmtHMsec(5400) == "1h 30m")  // 1.5 hours
    }

    @Test("fmtHMsec formats minutes and seconds")
    func fmtHMsecMinutesSeconds() {
        // RN: < 3600 returns "Xm Ys" or "Xm"
        #expect(TimeUtils.fmtHMsec(90) == "1m 30s")    // 1 minute 30 seconds
        #expect(TimeUtils.fmtHMsec(60) == "1m")        // exactly 1 minute
        #expect(TimeUtils.fmtHMsec(1500) == "25m")     // 25 minutes (standard focus)
        #expect(TimeUtils.fmtHMsec(300) == "5m")       // 5 minutes (standard break)
    }

    @Test("fmtHMsec handles edge cases")
    func fmtHMsecEdgeCases() {
        #expect(TimeUtils.fmtHMsec(0) == "0m")
        #expect(TimeUtils.fmtHMsec(30) == "0m 30s")
        #expect(TimeUtils.fmtHMsec(59) == "0m 59s")
    }

    @Test("fmtHMsec matches RN output exactly")
    func fmtHMsecMatchesRN() {
        // Test cases from RN behavior:
        // s >= 3600: shows hours
        // s < 3600: shows minutes and seconds

        // Hour cases - only show remaining minutes if > 0
        #expect(TimeUtils.fmtHMsec(3600) == "1h")
        #expect(TimeUtils.fmtHMsec(3601) == "1h")    // 1 second doesn't add minute
        #expect(TimeUtils.fmtHMsec(3660) == "1h 1m")

        // Minute cases - only show remaining seconds if > 0
        #expect(TimeUtils.fmtHMsec(60) == "1m")
        #expect(TimeUtils.fmtHMsec(61) == "1m 1s")
    }

    // MARK: - formatTimerDisplay Tests

    @Test("formatTimerDisplay shows MM:SS format")
    func formatTimerDisplayBasic() {
        #expect(TimeUtils.formatTimerDisplay(1500) == "25:00")
        #expect(TimeUtils.formatTimerDisplay(300) == "05:00")
        #expect(TimeUtils.formatTimerDisplay(0) == "00:00")
    }

    @Test("formatTimerDisplay pads correctly")
    func formatTimerDisplayPadding() {
        #expect(TimeUtils.formatTimerDisplay(65) == "01:05")
        #expect(TimeUtils.formatTimerDisplay(9) == "00:09")
        #expect(TimeUtils.formatTimerDisplay(599) == "09:59")
    }

    @Test("formatTimerDisplay handles over 60 minutes")
    func formatTimerDisplayOverHour() {
        #expect(TimeUtils.formatTimerDisplay(3600) == "60:00")
        #expect(TimeUtils.formatTimerDisplay(3661) == "61:01")
    }
}
