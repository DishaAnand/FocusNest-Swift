import SwiftUI
import Charts

public struct MonthlyChartView: View {
    let records: [FocusRecord]

    public init(records: [FocusRecord]) { self.records = records }

    private var monthlyData: [MonthlyFocusData] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())
        return (1...currentMonth).map { month in
            var components = DateComponents(); components.year = currentYear; components.month = month; components.day = 1
            guard let monthStart = calendar.date(from: components), let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return MonthlyFocusData(month: month, monthName: "", focusMinutes: 0, breakMinutes: 0) }
            let monthRecords = records.filter { $0.date >= monthStart && $0.date < monthEnd }
            let formatter = DateFormatter(); formatter.dateFormat = "MMM"
            return MonthlyFocusData(month: month, monthName: formatter.string(from: monthStart), focusMinutes: monthRecords.filter { !$0.isBreak }.reduce(0) { $0 + $1.durationMinutes }, breakMinutes: monthRecords.filter { $0.isBreak }.reduce(0) { $0 + $1.durationMinutes })
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            Text("This Year").font(Theme.headlineFont).foregroundStyle(Theme.textPrimary)
            Chart(monthlyData) { data in
                BarMark(x: .value("Month", data.monthName), y: .value("Focus", data.focusMinutes)).foregroundStyle(Theme.focusColor).cornerRadius(4)
                if data.breakMinutes > 0 { BarMark(x: .value("Month", data.monthName), y: .value("Break", data.breakMinutes)).foregroundStyle(Theme.breakColor).cornerRadius(4) }
            }
            .chartYScale(domain: 0...max(1, monthlyData.map { $0.focusMinutes + $0.breakMinutes }.max() ?? 1))
            .chartYAxis { AxisMarks(position: .leading) { value in AxisGridLine(); AxisValueLabel { if let m = value.as(Int.self) { Text(m >= 60 ? "\(m/60)h" : "\(m)m").font(.caption2) } } } }
            .chartScrollableAxes(.horizontal)
            .frame(height: 200)
            HStack(spacing: Theme.spacingL) { LegendItem(color: Theme.focusColor, label: "Focus"); LegendItem(color: Theme.breakColor, label: "Break") }
        }
        .padding(Theme.spacingM).cardStyle()
    }
}

struct MonthlyFocusData: Identifiable { let id = UUID(); let month: Int; let monthName: String; let focusMinutes: Int; let breakMinutes: Int }
