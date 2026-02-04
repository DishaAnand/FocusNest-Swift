import SwiftUI
import SwiftData

@MainActor
public struct FocusProgressView: View {
    @Query(sort: \FocusRecord.date, order: .reverse) private var records: [FocusRecord]
    @State private var selectedTab: ProgressTab = .daily
    @State private var anchorDate: Date = Date()

    public init() {}

    // MARK: - Period Calculations

    private var calendar: Calendar { Calendar.current }

    private var periodStart: Date {
        switch selectedTab {
        case .daily:
            return calendar.startOfDay(for: anchorDate)
        case .weekly:
            return startOfWeekMonday(anchorDate)
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: anchorDate)) ?? anchorDate
        }
    }

    private var periodEnd: Date {
        switch selectedTab {
        case .daily:
            return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: anchorDate) ?? anchorDate
        case .weekly:
            return calendar.date(byAdding: .day, value: 6, to: startOfWeekMonday(anchorDate)) ?? anchorDate
        case .monthly:
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: periodStart),
                  let lastDay = calendar.date(byAdding: .day, value: -1, to: nextMonth) else { return anchorDate }
            return lastDay
        }
    }

    private func startOfWeekMonday(_ date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7 // Monday = 0
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: date)) ?? date
    }

    // MARK: - Title

    private var periodTitle: String {
        let today = calendar.startOfDay(for: Date())
        let anchorDay = calendar.startOfDay(for: anchorDate)

        switch selectedTab {
        case .daily:
            if calendar.isDate(anchorDay, inSameDayAs: today) {
                return "Today"
            }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               calendar.isDate(anchorDay, inSameDayAs: yesterday) {
                return "Yesterday"
            }
            return anchorDate.formatted(.dateTime.day().month(.abbreviated).year())
        case .weekly:
            let start = startOfWeekMonday(anchorDate)
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
        case .monthly:
            return anchorDate.formatted(.dateTime.month(.wide).year())
        }
    }

    // MARK: - Navigation

    private var canGoNext: Bool {
        let today = calendar.startOfDay(for: Date())
        switch selectedTab {
        case .daily:
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: anchorDate) else { return false }
            return calendar.startOfDay(for: nextDay) <= today
        case .weekly:
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: startOfWeekMonday(anchorDate)) ?? anchorDate
            guard let nextWeekStart = calendar.date(byAdding: .day, value: 1, to: weekEnd) else { return false }
            return nextWeekStart <= today
        case .monthly:
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: periodStart) else { return false }
            return nextMonth <= today
        }
    }

    private func goPrevious() {
        switch selectedTab {
        case .daily:
            anchorDate = calendar.date(byAdding: .day, value: -1, to: anchorDate) ?? anchorDate
        case .weekly:
            anchorDate = calendar.date(byAdding: .day, value: -7, to: anchorDate) ?? anchorDate
        case .monthly:
            anchorDate = calendar.date(byAdding: .month, value: -1, to: anchorDate) ?? anchorDate
        }
    }

    private func goNext() {
        guard canGoNext else { return }
        switch selectedTab {
        case .daily:
            anchorDate = calendar.date(byAdding: .day, value: 1, to: anchorDate) ?? anchorDate
        case .weekly:
            anchorDate = calendar.date(byAdding: .day, value: 7, to: anchorDate) ?? anchorDate
        case .monthly:
            anchorDate = calendar.date(byAdding: .month, value: 1, to: anchorDate) ?? anchorDate
        }
    }

    // MARK: - Period Stats

    private var periodStats: SessionStats {
        FocusRecord.getStatsInRange(records: records, start: periodStart, end: periodEnd)
    }

    private var periodFocusMinutes: Int {
        records.filter { record in
            !record.isBreak &&
            record.date >= periodStart &&
            record.date <= periodEnd
        }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var periodBreakMinutes: Int {
        records.filter { record in
            record.isBreak &&
            record.date >= periodStart &&
            record.date <= periodEnd
        }.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - All-time Stats (for streak)

    private var currentStreak: Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while true {
            let hasSession = records.contains { record in
                !record.isBreak && calendar.isDate(record.date, inSameDayAs: checkDate)
            }

            if hasSession {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    // Period navigation header
                    HStack {
                        Button { goPrevious() } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.focusColor)
                        }

                        Spacer()

                        Text(periodTitle)
                            .font(Theme.headlineFont)
                            .foregroundStyle(Theme.textPrimary)

                        Spacer()

                        Button { goNext() } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(canGoNext ? Theme.focusColor : Theme.textTertiary)
                        }
                        .disabled(!canGoNext)
                    }
                    .padding(.horizontal, Theme.spacingM)

                    // Stats grid - period-specific
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacingM) {
                        StatCard(title: "Focus Time", value: formatHoursMinutes(periodFocusMinutes), icon: "clock.fill", color: Theme.focusColor)
                        StatCard(title: "Sessions", value: "\(periodStats.sessionsCompleted)", icon: "checkmark.circle.fill", color: Theme.successColor)
                        StatCard(title: "Avg Session", value: formatDuration(periodStats.avgSession), icon: "chart.bar.fill", color: Theme.warningColor)
                        StatCard(title: "Longest", value: formatDuration(periodStats.longestSession), icon: "trophy.fill", color: Theme.errorColor)
                    }

                    // Streak card (all-time)
                    HStack {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(currentStreak) day streak")
                                .font(Theme.headlineFont)
                                .foregroundStyle(Theme.textPrimary)
                            Text("Keep it going!")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(Theme.spacingM)
                    .cardStyle()

                    // Tab selector
                    SegmentedTabView(selection: $selectedTab)
                        .padding(.horizontal, Theme.spacingM)
                        .onChange(of: selectedTab) { _, _ in
                            // Reset to today when switching tabs
                            anchorDate = Date()
                        }

                    // Charts
                    switch selectedTab {
                    case .daily: DailyChartView(records: records)
                    case .weekly: WeeklyChartView(records: records)
                    case .monthly: MonthlyChartView(records: records)
                    }
                }
                .padding(Theme.spacingM)
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("Progress")
        }
    }

    // MARK: - Formatting

    private func formatHoursMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0m" }
        let minutes = seconds / 60
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

@MainActor
private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(Theme.titleFont)
                .foregroundStyle(Theme.textPrimary)
            Text(title)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.spacingM)
        .cardStyle()
    }
}
