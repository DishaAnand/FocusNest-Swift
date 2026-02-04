import Testing
import Foundation
@testable import FocusHavenFeature

@Suite("FocusRecord Tests - Matching RN sessionStore.ts")
struct FocusRecordTests {

    // MARK: - Basic Model Tests

    @Test("FocusRecord initializes with correct defaults")
    func recordInitDefaults() {
        let record = FocusRecord(duration: 1500)
        #expect(record.duration == 1500)
        #expect(record.isBreak == false)
        #expect(record.taskId == nil)
        #expect(record.taskTitle == nil)
        #expect(record.wasCompleted == true)
        #expect(record.wasBuddySession == false)
    }

    @Test("FocusRecord durationMinutes calculates correctly")
    func recordDurationMinutes() {
        let record1 = FocusRecord(duration: 1500)  // 25 minutes
        #expect(record1.durationMinutes == 25)

        let record2 = FocusRecord(duration: 300)   // 5 minutes
        #expect(record2.durationMinutes == 5)

        let record3 = FocusRecord(duration: 90)    // 1.5 minutes -> floors to 1
        #expect(record3.durationMinutes == 1)
    }

    @Test("FocusRecord formattedDuration matches RN format")
    func recordFormattedDuration() {
        // RN: fmtHMsec function - "Xh Ym" or "Xm"
        let record1 = FocusRecord(duration: 3700)  // 1h 1m 40s
        #expect(record1.formattedDuration == "1h 1m")

        let record2 = FocusRecord(duration: 3600)  // exactly 1 hour
        #expect(record2.formattedDuration == "1h 0m")

        let record3 = FocusRecord(duration: 1500)  // 25 minutes
        #expect(record3.formattedDuration == "25m")

        let record4 = FocusRecord(duration: 300)   // 5 minutes
        #expect(record4.formattedDuration == "5m")
    }

    // MARK: - SessionStats Tests (matching RN getSessionStatsInRange)

    @Test("SessionStats initializes with correct defaults")
    func sessionStatsDefaults() {
        let stats = SessionStats()
        #expect(stats.sessionsCompleted == 0)
        #expect(stats.avgSession == 0)
        #expect(stats.longestSession == 0)
    }

    @Test("getStatsInRange returns empty stats for no records")
    func getStatsNoRecords() {
        let stats = FocusRecord.getStatsInRange(
            records: [],
            start: Date(),
            end: Date()
        )
        #expect(stats.sessionsCompleted == 0)
        #expect(stats.avgSession == 0)
        #expect(stats.longestSession == 0)
    }

    @Test("getStatsInRange filters by date range")
    func getStatsFiltersDateRange() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let records = [
            FocusRecord(date: twoDaysAgo, duration: 1500),
            FocusRecord(date: yesterday, duration: 1800),
            FocusRecord(date: today, duration: 2100)
        ]

        // Query only yesterday
        let stats = FocusRecord.getStatsInRange(
            records: records,
            start: yesterday,
            end: yesterday
        )
        #expect(stats.sessionsCompleted == 1)
        #expect(stats.longestSession == 1800)
        #expect(stats.avgSession == 1800)
    }

    @Test("getStatsInRange excludes break sessions")
    func getStatsExcludesBreaks() {
        // Matches RN: filter(!record.isBreak)
        let today = Date()
        let records = [
            FocusRecord(date: today, duration: 1500, isBreak: false),
            FocusRecord(date: today, duration: 300, isBreak: true),  // Break - excluded
            FocusRecord(date: today, duration: 1800, isBreak: false)
        ]

        let stats = FocusRecord.getStatsInRange(
            records: records,
            start: today,
            end: today
        )
        #expect(stats.sessionsCompleted == 2)  // Only focus sessions
        #expect(stats.longestSession == 1800)
        #expect(stats.avgSession == (1500 + 1800) / 2)  // 1650
    }

    @Test("getStatsInRange calculates correct statistics")
    func getStatsCalculatesCorrectly() {
        // Matches RN: sessionsCompleted, avgSession, longestSession
        let today = Date()
        let records = [
            FocusRecord(date: today, duration: 1200),  // 20 min
            FocusRecord(date: today, duration: 1500),  // 25 min
            FocusRecord(date: today, duration: 1800),  // 30 min
            FocusRecord(date: today, duration: 2100)   // 35 min
        ]

        let stats = FocusRecord.getStatsInRange(
            records: records,
            start: today,
            end: today
        )

        #expect(stats.sessionsCompleted == 4)
        #expect(stats.longestSession == 2100)
        // Total: 1200+1500+1800+2100 = 6600, Avg: 6600/4 = 1650
        #expect(stats.avgSession == 1650)
    }

    @Test("getStatsInRange includes records at range boundaries")
    func getStatsIncludesBoundaries() {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today)!

        let records = [
            FocusRecord(date: startOfToday, duration: 1500),            // Start of day
            FocusRecord(date: today, duration: 1800),                   // Middle of day
            FocusRecord(date: endOfToday, duration: 2100)               // End of day
        ]

        let stats = FocusRecord.getStatsInRange(
            records: records,
            start: today,
            end: today
        )
        #expect(stats.sessionsCompleted == 3)  // All included
    }

    @Test("getStatsInRange handles single record")
    func getStatsSingleRecord() {
        let today = Date()
        let records = [
            FocusRecord(date: today, duration: 1500)
        ]

        let stats = FocusRecord.getStatsInRange(
            records: records,
            start: today,
            end: today
        )

        #expect(stats.sessionsCompleted == 1)
        #expect(stats.longestSession == 1500)
        #expect(stats.avgSession == 1500)
    }

    // MARK: - Record Creation Tests

    @Test("FocusRecord creates focus session correctly")
    func createFocusSession() {
        let task = FocusTask(title: "Study")
        let record = FocusRecord(
            duration: 1500,
            isBreak: false,
            taskId: task.id,
            taskTitle: task.title
        )
        #expect(record.isBreak == false)
        #expect(record.taskTitle == "Study")
        #expect(record.duration == 1500)
    }

    @Test("FocusRecord creates break session correctly")
    func createBreakSession() {
        let record = FocusRecord(
            duration: 300,
            isBreak: true
        )
        #expect(record.isBreak == true)
        #expect(record.taskId == nil)
        #expect(record.duration == 300)
    }

    @Test("FocusRecord creates buddy session correctly")
    func createBuddySession() {
        let record = FocusRecord(
            duration: 1500,
            isBreak: false,
            wasBuddySession: true
        )
        #expect(record.wasBuddySession == true)
    }
}
