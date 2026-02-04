import SwiftUI
import SwiftData

@MainActor
public struct FocusProgressView: View {
    @Query(sort: \FocusRecord.date, order: .reverse) private var records: [FocusRecord]
    @State private var selectedTab: ProgressTab = .daily

    public init() {}

    private var totalFocusMinutes: Int { records.filter { !$0.isBreak }.reduce(0) { $0 + $1.durationMinutes } }
    private var totalSessions: Int { records.filter { !$0.isBreak && $0.wasCompleted }.count }
    private var todayFocusMinutes: Int {
        let calendar = Calendar.current
        return records.filter { !$0.isBreak && calendar.isDate($0.date, inSameDayAs: Date()) }.reduce(0) { $0 + $1.durationMinutes }
    }
    private var currentStreak: Int {
        let calendar = Calendar.current
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

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacingM) {
                        StatCard(title: "Total Focus", value: formatHoursMinutes(totalFocusMinutes), icon: "clock.fill", color: Theme.focusColor)
                        StatCard(title: "Sessions", value: "\(totalSessions)", icon: "checkmark.circle.fill", color: Theme.successColor)
                        StatCard(title: "Today", value: "\(todayFocusMinutes)m", icon: "sun.max.fill", color: Theme.warningColor)
                        StatCard(title: "Streak", value: "\(currentStreak) days", icon: "flame.fill", color: Theme.errorColor)
                    }
                    SegmentedTabView(selection: $selectedTab).padding(.horizontal, Theme.spacingM)
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

    private func formatHoursMinutes(_ minutes: Int) -> String {
        let h = minutes / 60; let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

@MainActor
private struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            HStack { Image(systemName: icon).foregroundStyle(color); Spacer() }
            Text(value).font(Theme.titleFont).foregroundStyle(Theme.textPrimary)
            Text(title).font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.spacingM).cardStyle()
    }
}
