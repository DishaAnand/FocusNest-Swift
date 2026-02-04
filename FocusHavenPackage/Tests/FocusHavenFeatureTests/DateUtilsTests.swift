import Testing
import Foundation
@testable import FocusHavenFeature

@Suite("DateUtils Tests - Matching RN date.ts")
struct DateUtilsTests {

    // MARK: - toISODate Tests

    @Test("toISODate returns YYYY-MM-DD format")
    func toISODateFormat() {
        let date = makeDate(year: 2026, month: 2, day: 4)
        let result = DateUtils.toISODate(date)
        #expect(result == "2026-02-04")
    }

    @Test("toISODate pads single digit month and day")
    func toISODatePadding() {
        let date = makeDate(year: 2026, month: 1, day: 5)
        let result = DateUtils.toISODate(date)
        #expect(result == "2026-01-05")
    }

    @Test("toISODate handles December correctly")
    func toISODateDecember() {
        let date = makeDate(year: 2025, month: 12, day: 31)
        let result = DateUtils.toISODate(date)
        #expect(result == "2025-12-31")
    }

    // MARK: - startOfDay Tests

    @Test("startOfDay returns midnight")
    func startOfDayMidnight() {
        let date = makeDateWithTime(year: 2026, month: 2, day: 4, hour: 15, minute: 30, second: 45)
        let result = DateUtils.startOfDay(date)

        let calendar = Calendar.current
        #expect(calendar.component(.hour, from: result) == 0)
        #expect(calendar.component(.minute, from: result) == 0)
        #expect(calendar.component(.second, from: result) == 0)
        #expect(calendar.component(.day, from: result) == 4)
    }

    // MARK: - endOfDay Tests

    @Test("endOfDay returns 23:59:59")
    func endOfDayTime() {
        let date = makeDate(year: 2026, month: 2, day: 4)
        let result = DateUtils.endOfDay(date)

        let calendar = Calendar.current
        #expect(calendar.component(.hour, from: result) == 23)
        #expect(calendar.component(.minute, from: result) == 59)
        #expect(calendar.component(.second, from: result) == 59)
        #expect(calendar.component(.day, from: result) == 4)
    }

    // MARK: - startOfWeekSun Tests

    @Test("startOfWeekSun returns Sunday for a Wednesday")
    func startOfWeekSunFromWednesday() {
        // Feb 5, 2026 is a Thursday
        let thursday = makeDate(year: 2026, month: 2, day: 5)
        let result = DateUtils.startOfWeekSun(thursday)

        let calendar = Calendar.current
        #expect(calendar.component(.weekday, from: result) == 1) // Sunday
        #expect(calendar.component(.day, from: result) == 1) // Feb 1, 2026
    }

    @Test("startOfWeekSun returns same day for Sunday")
    func startOfWeekSunFromSunday() {
        // Feb 1, 2026 is a Sunday
        let sunday = makeDate(year: 2026, month: 2, day: 1)
        let result = DateUtils.startOfWeekSun(sunday)

        let calendar = Calendar.current
        #expect(calendar.component(.weekday, from: result) == 1) // Sunday
        #expect(calendar.component(.day, from: result) == 1)
    }

    // MARK: - endOfWeekSun Tests

    @Test("endOfWeekSun returns Saturday 23:59:59")
    func endOfWeekSunFromWednesday() {
        // Feb 5, 2026 is a Thursday
        let thursday = makeDate(year: 2026, month: 2, day: 5)
        let result = DateUtils.endOfWeekSun(thursday)

        let calendar = Calendar.current
        #expect(calendar.component(.weekday, from: result) == 7) // Saturday
        #expect(calendar.component(.day, from: result) == 7) // Feb 7, 2026
        #expect(calendar.component(.hour, from: result) == 23)
        #expect(calendar.component(.minute, from: result) == 59)
    }

    // MARK: - startOfMonth Tests

    @Test("startOfMonth returns first of month")
    func startOfMonthFirstDay() {
        let date = makeDate(year: 2026, month: 2, day: 15)
        let result = DateUtils.startOfMonth(date)

        let calendar = Calendar.current
        #expect(calendar.component(.day, from: result) == 1)
        #expect(calendar.component(.month, from: result) == 2)
        #expect(calendar.component(.hour, from: result) == 0)
    }

    // MARK: - endOfMonth Tests

    @Test("endOfMonth returns last day of February")
    func endOfMonthFebruary() {
        let date = makeDate(year: 2026, month: 2, day: 10)
        let result = DateUtils.endOfMonth(date)

        let calendar = Calendar.current
        #expect(calendar.component(.day, from: result) == 28) // 2026 is not leap year
        #expect(calendar.component(.hour, from: result) == 23)
    }

    @Test("endOfMonth returns 31 for January")
    func endOfMonthJanuary() {
        let date = makeDate(year: 2026, month: 1, day: 15)
        let result = DateUtils.endOfMonth(date)

        let calendar = Calendar.current
        #expect(calendar.component(.day, from: result) == 31)
    }

    // MARK: - addDays Tests

    @Test("addDays adds positive days")
    func addDaysPositive() {
        let date = makeDate(year: 2026, month: 2, day: 1)
        let result = DateUtils.addDays(date, 5)

        let calendar = Calendar.current
        #expect(calendar.component(.day, from: result) == 6)
    }

    @Test("addDays subtracts with negative")
    func addDaysNegative() {
        let date = makeDate(year: 2026, month: 2, day: 10)
        let result = DateUtils.addDays(date, -5)

        let calendar = Calendar.current
        #expect(calendar.component(.day, from: result) == 5)
    }

    @Test("addDays crosses month boundary")
    func addDaysCrossesMonth() {
        let date = makeDate(year: 2026, month: 1, day: 30)
        let result = DateUtils.addDays(date, 5)

        let calendar = Calendar.current
        #expect(calendar.component(.month, from: result) == 2)
        #expect(calendar.component(.day, from: result) == 4)
    }

    // MARK: - addMonths Tests

    @Test("addMonths adds positive months")
    func addMonthsPositive() {
        let date = makeDate(year: 2026, month: 1, day: 15)
        let result = DateUtils.addMonths(date, 2)

        let calendar = Calendar.current
        #expect(calendar.component(.month, from: result) == 3)
    }

    @Test("addMonths subtracts with negative")
    func addMonthsNegative() {
        let date = makeDate(year: 2026, month: 3, day: 15)
        let result = DateUtils.addMonths(date, -2)

        let calendar = Calendar.current
        #expect(calendar.component(.month, from: result) == 1)
    }

    // MARK: - weekdayShort Tests

    @Test("weekdayShort has correct values")
    func weekdayShortValues() {
        #expect(DateUtils.weekdayShort.count == 7)
        #expect(DateUtils.weekdayShort[0] == "Sun")
        #expect(DateUtils.weekdayShort[1] == "Mon")
        #expect(DateUtils.weekdayShort[6] == "Sat")
    }

    // MARK: - monthName Tests

    @Test("monthName returns full month name")
    func monthNameFull() {
        let january = makeDate(year: 2026, month: 1, day: 1)
        #expect(DateUtils.monthName(january) == "January")

        let december = makeDate(year: 2026, month: 12, day: 1)
        #expect(DateUtils.monthName(december) == "December")
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    private func makeDateWithTime(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return Calendar.current.date(from: components)!
    }
}
