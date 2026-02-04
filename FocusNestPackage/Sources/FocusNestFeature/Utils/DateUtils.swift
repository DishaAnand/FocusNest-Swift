import Foundation

/// Date utilities matching React Native `src/utils/date.ts`
public enum DateUtils {

    // MARK: - Date Formatting

    /// Returns date as "YYYY-MM-DD" string using local calendar
    /// Matches RN: `toISODate(d)`
    public static func toISODate(_ date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    // MARK: - Day Boundaries

    /// Returns date at start of day (00:00:00)
    /// Matches RN: `startOfDay(d)`
    public static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Returns date at end of day (23:59:59.999)
    /// Matches RN: `endOfDay(d)`
    public static func endOfDay(_ date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    // MARK: - Week Boundaries (Sunday-based)

    /// Returns the Sunday of the week containing the date
    /// Matches RN: `startOfWeekSun(d)`
    public static func startOfWeekSun(_ date: Date) -> Date {
        let calendar = Calendar.current
        let start = startOfDay(date)
        let weekday = calendar.component(.weekday, from: start) // 1 = Sunday
        let daysToSubtract = weekday - 1
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: start) ?? start
    }

    /// Returns the Saturday 23:59:59 of the week containing the date
    /// Matches RN: `endOfWeekSun(d)`
    public static func endOfWeekSun(_ date: Date) -> Date {
        let weekStart = startOfWeekSun(date)
        let calendar = Calendar.current
        let saturday = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return endOfDay(saturday)
    }

    // MARK: - Month Boundaries

    /// Returns the 1st of the month at 00:00:00
    /// Matches RN: `startOfMonth(d)`
    public static func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Returns the last day of the month at 23:59:59
    /// Matches RN: `endOfMonth(d)`
    public static func endOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth(date)) ?? date
        let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? date
        return endOfDay(lastDay)
    }

    // MARK: - Date Arithmetic

    /// Add n days to date
    /// Matches RN: `addDays(d, n)`
    public static func addDays(_ date: Date, _ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Add n months to date
    /// Matches RN: `addMonths(d, n)`
    public static func addMonths(_ date: Date, _ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: date) ?? date
    }

    // MARK: - Labels

    /// Short weekday names starting from Sunday
    /// Matches RN: `weekdayShort`
    public static let weekdayShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Returns full month name (e.g., "January")
    /// Matches RN: `monthName(d)`
    public static func monthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
}
