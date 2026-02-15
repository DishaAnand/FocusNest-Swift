import SwiftUI
import Charts

public struct DailyChartView: View {
    let records: [FocusRecord]
    @Environment(\.colorScheme) private var colorScheme
    @State private var animateChart = false
    @State private var selectedDay: DailyFocusData?

    public init(records: [FocusRecord]) {
        self.records = records
    }

    private var calendar: Calendar { Calendar.current }

    private var dailyData: [DailyFocusData] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return DailyFocusData(date: today, focusMinutes: 0, breakMinutes: 0, isToday: false)
            }
            let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let isToday = calendar.isDateInToday(date)
            return DailyFocusData(
                date: date,
                focusMinutes: dayRecords.filter { !$0.isBreak }.reduce(0) { $0 + $1.durationMinutes },
                breakMinutes: dayRecords.filter { $0.isBreak }.reduce(0) { $0 + $1.durationMinutes },
                isToday: isToday
            )
        }
    }

    private var maxMinutes: Int {
        max(1, dailyData.map(\.focusMinutes).max() ?? 1)
    }

    private var totalFocusThisWeek: Int {
        dailyData.reduce(0) { $0 + $1.focusMinutes }
    }

    private var averagePerDay: Int {
        let activeDays = dailyData.filter { $0.focusMinutes > 0 }.count
        guard activeDays > 0 else { return 0 }
        return totalFocusThisWeek / activeDays
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.focusColor.opacity(0.15), Theme.focusColor.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.focusColor)
                        }
                        Text("Daily Activity")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("Last 7 days")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 40)
                }

                Spacer()

                // Average stat
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(averagePerDay)m")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.focusColor)
                    Text("daily avg")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            // Chart
            Chart(dailyData) { data in
                BarMark(
                    x: .value("Day", data.dayName),
                    y: .value("Focus", animateChart ? data.focusMinutes : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.focusColor, Theme.focusColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(8)
                .opacity(selectedDay == nil || selectedDay?.id == data.id ? 1 : 0.35)

                // Today highlight
                if data.isToday {
                    RuleMark(x: .value("Day", data.dayName))
                        .foregroundStyle(Theme.focusColor.opacity(0.2))
                        .lineStyle(StrokeStyle(lineWidth: 40))
                        .zIndex(-1)
                }
            }
            .chartYScale(domain: 0...maxMinutes)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Theme.textTertiary.opacity(0.2))
                    AxisValueLabel {
                        if let m = value.as(Int.self) {
                            Text("\(m)m")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let day = value.as(String.self) {
                            let isCurrentDay = dailyData.first { $0.dayName == day }?.isToday ?? false
                            Text(day)
                                .font(.system(size: 11, weight: isCurrentDay ? .bold : .medium))
                                .foregroundStyle(isCurrentDay ? Theme.focusColor : Theme.textSecondary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x
                                    if let day = proxy.value(atX: x, as: String.self) {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            selectedDay = dailyData.first { $0.dayName == day }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedDay = nil
                                    }
                                }
                        )
                }
            }
            .frame(height: 140)
            .animation(.spring(response: 0.7, dampingFraction: 0.75), value: animateChart)

            // Selected day tooltip
            if let selected = selectedDay {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Theme.focusColor)
                        .frame(width: 8, height: 8)

                    Text(selected.fullDayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Text("\(selected.focusMinutes)m")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.focusColor)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.focusColor.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Theme.focusColor.opacity(0.15), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
            }

        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.backgroundSecondary)
                .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        )
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.15)) {
                animateChart = true
            }
        }
    }
}

// MARK: - Focus Quality Chart

public struct FocusQualityChartView: View {
    let records: [FocusRecord]
    @State private var animateLine = false

    public init(records: [FocusRecord]) {
        self.records = records
    }

    private var calendar: Calendar { Calendar.current }

    private var qualityData: [FocusQualityData] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let dayRecords = records.filter {
                !$0.isBreak && calendar.isDate($0.date, inSameDayAs: date)
            }
            let scores = dayRecords.compactMap(\.actualFocus)
            let avgScore = scores.isEmpty ? nil : Double(scores.reduce(0, +)) / Double(scores.count)
            return FocusQualityData(date: date, averageScore: avgScore)
        }
    }

    private var hasData: Bool {
        qualityData.contains { $0.averageScore != nil }
    }

    private var overallAverage: Double {
        let scores = qualityData.compactMap(\.averageScore)
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            Image(systemName: "brain.head.profile.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        Text("Focus Quality")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("Self-rated scores")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 40)
                }

                Spacer()

                if hasData {
                    QualityBadge(score: overallAverage)
                }
            }

            if hasData {
                Chart(qualityData) { data in
                    if let score = data.averageScore {
                        LineMark(
                            x: .value("Day", data.dayName),
                            y: .value("Score", animateLine ? score : 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", data.dayName),
                            y: .value("Score", animateLine ? score : 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.25), Color.blue.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", data.dayName),
                            y: .value("Score", animateLine ? score : 0)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(animateLine ? 80 : 0)

                        PointMark(
                            x: .value("Day", data.dayName),
                            y: .value("Score", animateLine ? score : 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolSize(animateLine ? 50 : 0)
                    }
                }
                .chartYScale(domain: 0...5)
                .chartYAxis {
                    AxisMarks(values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Theme.textTertiary.opacity(0.2))
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: 120)
                .animation(.spring(response: 1.0, dampingFraction: 0.7), value: animateLine)
            } else {
                // Empty state
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    Text("Rate your focus sessions")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text("to see quality trends here")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.backgroundSecondary)
                .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        )
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.3)) {
                animateLine = true
            }
        }
    }
}

private struct QualityBadge: View {
    let score: Double

    private var label: String {
        switch score {
        case 4.5...: return "Excellent"
        case 3.5..<4.5: return "Good"
        case 2.5..<3.5: return "Average"
        default: return "Needs Work"
        }
    }

    private var colors: [Color] {
        switch score {
        case 4.5...: return [.green, .mint]
        case 3.5..<4.5: return [Theme.focusColor, .blue]
        case 2.5..<3.5: return [.orange, .yellow]
        default: return [.red, .orange]
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: score >= 3.5 ? "star.fill" : "star.leadinghalf.filled")
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(
            LinearGradient(
                colors: colors,
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: colors.map { $0.opacity(0.12) },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: colors.map { $0.opacity(0.25) },
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Data Models

struct DailyFocusData: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let focusMinutes: Int
    let breakMinutes: Int
    let isToday: Bool

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var fullDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    static func == (lhs: DailyFocusData, rhs: DailyFocusData) -> Bool {
        lhs.id == rhs.id
    }
}

struct FocusQualityData: Identifiable {
    let id = UUID()
    let date: Date
    let averageScore: Double?

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
