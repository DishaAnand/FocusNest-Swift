import SwiftUI
import Charts

public struct DailyChartView: View {
    let records: [FocusRecord]
    @Environment(\.colorScheme) private var colorScheme

    public init(records: [FocusRecord]) { self.records = records }

    private var dailyData: [DailyFocusData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return DailyFocusData(date: today, focusMinutes: 0, breakMinutes: 0) }
            let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: date) }
            return DailyFocusData(date: date, focusMinutes: dayRecords.filter { !$0.isBreak }.reduce(0) { $0 + $1.durationMinutes }, breakMinutes: dayRecords.filter { $0.isBreak }.reduce(0) { $0 + $1.durationMinutes })
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            Text("This Week").font(Theme.headlineFont).foregroundStyle(Theme.textPrimary)
            Chart(dailyData) { data in
                BarMark(x: .value("Day", data.dayName), y: .value("Focus", data.focusMinutes)).foregroundStyle(Theme.focusColor).cornerRadius(4)
                if data.breakMinutes > 0 { BarMark(x: .value("Day", data.dayName), y: .value("Break", data.breakMinutes)).foregroundStyle(Theme.breakColor).cornerRadius(4) }
            }
            .chartYScale(domain: 0...max(1, dailyData.map { $0.focusMinutes + $0.breakMinutes }.max() ?? 1))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Theme.chartGridLine(colorScheme).opacity(Theme.chartGridOpacityMajor))
                    AxisValueLabel {
                        if let m = value.as(Int.self) {
                            Text("\(m)m")
                                .font(.caption2)
                                .foregroundStyle(Theme.chartAxisLabel(colorScheme))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(Theme.chartXAxisLabel(colorScheme))
                }
            }
            .frame(height: 200)
            HStack(spacing: Theme.spacingL) { LegendItem(color: Theme.focusColor, label: "Focus"); LegendItem(color: Theme.breakColor, label: "Break") }
        }
        .padding(Theme.spacingM).cardStyle()
    }
}

struct DailyFocusData: Identifiable {
    let id = UUID(); let date: Date; let focusMinutes: Int; let breakMinutes: Int
    var dayName: String { let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date) }
}

struct LegendItem: View {
    let color: Color; let label: String
    var body: some View { HStack(spacing: Theme.spacingXS) { Circle().fill(color).frame(width: 10, height: 10); Text(label).font(Theme.captionFont).foregroundStyle(Theme.textSecondary) } }
}
