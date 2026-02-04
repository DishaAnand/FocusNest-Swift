import SwiftUI
import Charts

public struct WeeklyChartView: View {
    let records: [FocusRecord]

    public init(records: [FocusRecord]) { self.records = records }

    private var weeklyData: [WeeklyFocusData] {
        let calendar = Calendar.current
        let today = Date()
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let monthStart = calendar.date(from: components) else { return [] }
        var weeks: [WeeklyFocusData] = []
        var weekStart = monthStart
        while calendar.component(.month, from: weekStart) == calendar.component(.month, from: today) {
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let weekRecords = records.filter { $0.date >= weekStart && $0.date <= weekEnd }
            weeks.append(WeeklyFocusData(weekNumber: weeks.count + 1, weekLabel: "Week \(weeks.count + 1)", focusMinutes: weekRecords.filter { !$0.isBreak }.reduce(0) { $0 + $1.durationMinutes }, breakMinutes: weekRecords.filter { $0.isBreak }.reduce(0) { $0 + $1.durationMinutes }))
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = nextWeek
        }
        return weeks
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            Text("This Month by Week").font(Theme.headlineFont).foregroundStyle(Theme.textPrimary)
            if weeklyData.isEmpty {
                Text("No data for this month").font(Theme.bodyFont).foregroundStyle(Theme.textSecondary).frame(height: 200)
            } else {
                Chart(weeklyData) { data in
                    BarMark(x: .value("Week", data.weekLabel), y: .value("Focus", data.focusMinutes)).foregroundStyle(Theme.focusColor).cornerRadius(4)
                    if data.breakMinutes > 0 { BarMark(x: .value("Week", data.weekLabel), y: .value("Break", data.breakMinutes)).foregroundStyle(Theme.breakColor).cornerRadius(4) }
                }
                .chartYScale(domain: 0...max(1, weeklyData.map { $0.focusMinutes + $0.breakMinutes }.max() ?? 1))
                .chartYAxis { AxisMarks(position: .leading) { value in AxisGridLine(); AxisValueLabel { if let m = value.as(Int.self) { Text(m >= 60 ? "\(m/60)h" : "\(m)m").font(.caption2) } } } }
                .frame(height: 200)
            }
            HStack(spacing: Theme.spacingL) { LegendItem(color: Theme.focusColor, label: "Focus"); LegendItem(color: Theme.breakColor, label: "Break") }
        }
        .padding(Theme.spacingM).cardStyle()
    }
}

struct WeeklyFocusData: Identifiable { let id = UUID(); let weekNumber: Int; let weekLabel: String; let focusMinutes: Int; let breakMinutes: Int }
