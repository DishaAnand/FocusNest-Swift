import SwiftUI
import SwiftData
import Charts

@MainActor
public struct FocusProgressView: View {
    @Query(sort: \FocusRecord.date, order: .reverse) private var records: [FocusRecord]
    @State private var selectedTab: InsightTab = .insights
    @State private var showAllTasks = false
    @State private var appearAnimation = false
    @State private var chartAnimation = false

    public init() {}

    private var calendar: Calendar { Calendar.current }

    // MARK: - Data Calculations

    private var focusSessions: [FocusRecord] {
        records.filter { !$0.isBreak }
    }

    private var hasEnoughData: Bool {
        focusSessions.count >= 5
    }

    // MARK: - This Week Data

    private var thisWeekStart: Date {
        let weekday = calendar.component(.weekday, from: Date())
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: Date())) ?? Date()
    }

    private var lastWeekStart: Date {
        calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart
    }

    private var thisWeekMinutes: Int {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: thisWeekStart) ?? Date()
        return focusSessions.filter { $0.date >= thisWeekStart && $0.date < weekEnd }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private var lastWeekMinutes: Int {
        focusSessions.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private var weeklyDifference: Int {
        thisWeekMinutes - lastWeekMinutes
    }

    private var currentStreak: Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        while true {
            let hasSession = focusSessions.contains { calendar.isDate($0.date, inSameDayAs: checkDate) }
            if hasSession {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else { break }
        }
        return streak
    }

    private var averageFocus: Double {
        let focusScores = focusSessions.compactMap(\.actualFocus)
        guard !focusScores.isEmpty else { return 0 }
        return Double(focusScores.reduce(0, +)) / Double(focusScores.count)
    }

    private var totalDistractionsThisWeek: Int {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: thisWeekStart) ?? Date()
        let thisWeekSessions = focusSessions.filter { $0.date >= thisWeekStart && $0.date < weekEnd }
        return thisWeekSessions.map(\.distractionCount).reduce(0, +)
    }

    // MARK: - Recharge Score Data

    private var breakSessions: [FocusRecord] {
        records.filter { $0.isBreak }
    }

    private var thisWeekRechargeScore: Double {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: thisWeekStart) ?? Date()
        let weekBreaks = breakSessions.filter { $0.date >= thisWeekStart && $0.date < weekEnd }
        let rechargePercentages = weekBreaks.compactMap { $0.rechargePercentage }
        guard !rechargePercentages.isEmpty else { return 0 }
        return rechargePercentages.reduce(0, +) / Double(rechargePercentages.count)
    }

    private var lastWeekRechargeScore: Double {
        let weekBreaks = breakSessions.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
        let rechargePercentages = weekBreaks.compactMap { $0.rechargePercentage }
        guard !rechargePercentages.isEmpty else { return 0 }
        return rechargePercentages.reduce(0, +) / Double(rechargePercentages.count)
    }

    private var rechargeScoreChange: Double {
        guard lastWeekRechargeScore > 0 else { return 0 }
        return thisWeekRechargeScore - lastWeekRechargeScore
    }

    private var dailyFocusData: [DayFocusData] {
        let maxMinutes = (0..<7).map { dayOffset -> Int in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: thisWeekStart) ?? thisWeekStart
            return focusSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.durationMinutes }
        }.max() ?? 1

        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: thisWeekStart) ?? thisWeekStart
            let dayRecords = focusSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let minutes = dayRecords.reduce(0) { $0 + $1.durationMinutes }
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > Date()
            return DayFocusData(date: date, minutes: minutes, isToday: isToday, isFuture: isFuture, maxMinutes: max(maxMinutes, 1))
        }
    }

    // MARK: - Focus Profile Data

    private var bestTimeOfDay: String {
        guard hasEnoughData else { return "--" }
        let hourGroups = Dictionary(grouping: focusSessions) { record in
            calendar.component(.hour, from: record.date)
        }
        guard let bestHour = hourGroups.max(by: { a, b in
            let aScore = a.value.compactMap(\.actualFocus).reduce(0, +)
            let bScore = b.value.compactMap(\.actualFocus).reduce(0, +)
            return aScore < bScore
        })?.key else { return "--" }

        let endHour = (bestHour + 2) % 24
        return "\(formatHour(bestHour))-\(formatHour(endHour))"
    }

    private func formatHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h)\(ampm)"
    }

    private var bestDayOfWeek: String {
        guard hasEnoughData else { return "--" }
        let dayGroups = Dictionary(grouping: focusSessions) { record in
            calendar.component(.weekday, from: record.date)
        }
        guard let bestDay = dayGroups.max(by: { $0.value.count < $1.value.count })?.key else { return "--" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let date = calendar.date(bySetting: .weekday, value: bestDay, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private var completionRate: Int {
        guard !focusSessions.isEmpty else { return 0 }
        return Int(Double(focusSessions.filter(\.wasCompleted).count) / Double(focusSessions.count) * 100)
    }

    // MARK: - Task Breakdown Data

    private var taskBreakdown: [TaskTimeData] {
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: thisWeekStart) ?? Date()
        let weekSessions = focusSessions.filter { $0.date >= thisWeekStart && $0.date < weekEnd }

        var taskTimes: [String: Int] = [:]
        for session in weekSessions {
            let title = session.taskTitle ?? "No task"
            taskTimes[title, default: 0] += session.durationMinutes
        }

        return taskTimes.map { TaskTimeData(taskTitle: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
    }

    private var donutChartData: [DonutSegment] {
        guard !taskBreakdown.isEmpty else { return [] }
        let total = taskBreakdown.reduce(0) { $0 + $1.minutes }
        guard total > 0 else { return [] }

        let top3 = Array(taskBreakdown.prefix(3))
        let othersMinutes = taskBreakdown.dropFirst(3).reduce(0) { $0 + $1.minutes }

        var segments: [DonutSegment] = top3.enumerated().map { index, task in
            DonutSegment(
                label: task.taskTitle,
                value: Double(task.minutes),
                percentage: Double(task.minutes) / Double(total) * 100,
                color: segmentColors[index]
            )
        }

        if othersMinutes > 0 {
            segments.append(DonutSegment(
                label: "\(taskBreakdown.count - 3) others",
                value: Double(othersMinutes),
                percentage: Double(othersMinutes) / Double(total) * 100,
                color: Theme.textTertiary.opacity(0.5)
            ))
        }

        return segments
    }

    private let segmentColors: [Color] = [
        Theme.focusColor,
        Color.blue,
        Color.orange
    ]

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero Card
                    heroCard
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)

                    // Stats Grid
                    statsGrid
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(0.1), value: appearAnimation)

                    // Task Breakdown Card
                    if !taskBreakdown.isEmpty {
                        taskBreakdownCard
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                            .animation(.spring(response: 0.5).delay(0.15), value: appearAnimation)
                    }

                    // Tab Section
                    tabSection
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 20)
                        .animation(.spring(response: 0.5).delay(0.2), value: appearAnimation)
                }
                .padding(.horizontal, Theme.spacingM)
                .padding(.bottom, Theme.spacingXL)
                .frame(maxWidth: 700)  // iPad: constrain content width
                .frame(maxWidth: .infinity)  // Center on larger screens
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("Progress")
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    appearAnimation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        chartAnimation = true
                    }
                }
            }
            .sheet(isPresented: $showAllTasks) {
                AllTasksSheet(tasks: taskBreakdown)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 16) {
            // Big focus time with gradient
            VStack(spacing: 6) {
                Text(formatMinutes(thisWeekMinutes))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.focusColor, Theme.focusColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("focused this week")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            // Comparison pill
            if weeklyDifference != 0 {
                HStack(spacing: 6) {
                    Image(systemName: weeklyDifference > 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.system(size: 14))
                    Text("\(formatMinutes(abs(weeklyDifference))) \(weeklyDifference > 0 ? "more" : "less") than last week")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(weeklyDifference > 0 ? .green : .orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill((weeklyDifference > 0 ? Color.green : Color.orange).opacity(0.1))
                        .overlay(
                            Capsule()
                                .strokeBorder((weeklyDifference > 0 ? Color.green : Color.orange).opacity(0.2), lineWidth: 1)
                        )
                )
            }

            // Mini bar chart for week
            weekMiniChart
                .padding(.top, 8)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.backgroundSecondary)
                .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
        )
    }

    // MARK: - Week Mini Chart

    private var weekMiniChart: some View {
        HStack(spacing: 8) {
            ForEach(dailyFocusData) { day in
                VStack(spacing: 8) {
                    // Mini bar
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.textTertiary.opacity(0.1))
                            .frame(width: 28, height: 40)

                        if !day.isFuture {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    day.minutes > 0
                                        ? LinearGradient(
                                            colors: [Theme.focusColor, Theme.focusColor.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        : LinearGradient(
                                            colors: [Theme.textTertiary.opacity(0.3), Theme.textTertiary.opacity(0.2)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                )
                                .frame(width: 28, height: chartAnimation ? max(4, CGFloat(day.minutes) / CGFloat(day.maxMinutes) * 40) : 4)
                                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(Double(dailyFocusData.firstIndex(where: { $0.id == day.id }) ?? 0) * 0.05), value: chartAnimation)
                        }
                    }
                    .overlay(
                        day.isToday ?
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Theme.focusColor, lineWidth: 2)
                            .frame(width: 28, height: 40)
                        : nil
                    )

                    Text(day.dayInitial)
                        .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? Theme.focusColor : Theme.textTertiary)
                }
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Streak
                StatCard(
                    icon: "flame.fill",
                    iconColors: [.orange, .red],
                    value: "\(currentStreak)",
                    label: "day streak",
                    progress: chartAnimation ? min(Double(currentStreak) / 7.0, 1.0) : 0,
                    progressColor: .orange
                )

                // Focus Score
                StatCard(
                    icon: "brain.head.profile.fill",
                    iconColors: [Theme.focusColor, .blue],
                    value: String(format: "%.1f", averageFocus),
                    label: "avg focus",
                    progress: chartAnimation ? averageFocus / 5.0 : 0,
                    progressColor: Theme.focusColor
                )

                // Distractions
                StatCard(
                    icon: totalDistractionsThisWeek == 0 ? "shield.checkered" : "exclamationmark.triangle.fill",
                    iconColors: totalDistractionsThisWeek == 0 ? [.green, .mint] : totalDistractionsThisWeek <= 3 ? [.yellow, .orange] : [.orange, .red],
                    value: "\(totalDistractionsThisWeek)",
                    label: "dist. this week",
                    progress: nil,
                    progressColor: totalDistractionsThisWeek == 0 ? .green : totalDistractionsThisWeek <= 3 ? .yellow : .orange
                )
            }

            // Recharge Score (full width)
            RechargeScoreCard(
                score: thisWeekRechargeScore,
                change: rechargeScoreChange,
                animate: chartAnimation
            )
        }
    }

    // MARK: - Task Breakdown Card

    private var taskBreakdownCard: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.focusColor)
                    Text("Time Distribution")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                if taskBreakdown.count > 3 {
                    Button {
                        showAllTasks = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("See all")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.focusColor)
                    }
                }
            }

            HStack(spacing: 20) {
                // Donut Chart
                ZStack {
                    Circle()
                        .stroke(Theme.textTertiary.opacity(0.08), lineWidth: 14)
                        .frame(width: 100, height: 100)

                    DonutChartView(segments: donutChartData, animate: chartAnimation)
                        .frame(width: 100, height: 100)

                    VStack(spacing: 0) {
                        Text(formatMinutes(thisWeekMinutes))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text("total")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                // Legend
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(donutChartData) { segment in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(segment.color)
                                .frame(width: 12, height: 12)
                            Text(segment.label)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(segment.percentage))%")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.backgroundSecondary)
                .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        )
    }

    // MARK: - Tab Section

    private var tabSection: some View {
        VStack(spacing: 16) {
            // Custom tab picker
            HStack(spacing: 0) {
                ForEach(InsightTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedTab == tab ? .white : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? Theme.focusColor : Color.clear)
                            )
                    }
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(Theme.backgroundSecondary)
                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            )

            // Tab content
            switch selectedTab {
            case .insights:
                insightsContent
            case .charts:
                chartsContent
            }
        }
    }

    // MARK: - Insights Content

    private var insightsContent: some View {
        VStack(spacing: 12) {
            if hasEnoughData {
                HStack(spacing: 12) {
                    InsightCard(
                        icon: "sun.horizon.fill",
                        iconColors: [.orange, .yellow],
                        title: "Peak Time",
                        value: bestTimeOfDay
                    )
                    InsightCard(
                        icon: "calendar.badge.checkmark",
                        iconColors: [.blue, .cyan],
                        title: "Best Day",
                        value: bestDayOfWeek
                    )
                }

                HStack(spacing: 12) {
                    InsightCard(
                        icon: "checkmark.seal.fill",
                        iconColors: [.green, .mint],
                        title: "Completion",
                        value: "\(completionRate)%"
                    )
                    InsightCard(
                        icon: "number.circle.fill",
                        iconColors: [Theme.focusColor, .purple],
                        title: "Sessions",
                        value: "\(focusSessions.count)"
                    )
                }
            } else {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.focusColor.opacity(0.1))
                            .frame(width: 64, height: 64)
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.focusColor.opacity(0.6))
                    }
                    Text("Complete \(5 - focusSessions.count) more sessions")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("to unlock your focus insights")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.backgroundSecondary)
                )
            }
        }
    }

    // MARK: - Charts Content

    private var chartsContent: some View {
        VStack(spacing: 16) {
            DailyChartView(records: records)
            FocusQualityChartView(records: records)
        }
    }

    // MARK: - Formatting

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - InsightTab

private enum InsightTab: String, CaseIterable {
    case insights = "Insights"
    case charts = "Charts"
}

// MARK: - Supporting Views

private struct StatCard: View {
    let icon: String
    let iconColors: [Color]
    let value: String
    let label: String
    let progress: Double?
    let progressColor: Color

    var body: some View {
        VStack(spacing: 10) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconColors.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                // Progress ring
                if let progress = progress {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: iconColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)
                }

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.backgroundSecondary)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
        )
    }
}

private struct InsightCard: View {
    let icon: String
    let iconColors: [Color]
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: iconColors.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.backgroundSecondary)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
        )
    }
}

private struct DonutChartView: View {
    let segments: [DonutSegment]
    let animate: Bool

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 7
            var startAngle = Angle.degrees(-90)

            for segment in segments {
                let sweepAngle = animate ? segment.percentage * 3.6 : 0
                let endAngle = startAngle + Angle.degrees(sweepAngle)
                let path = Path { p in
                    p.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                }
                context.stroke(path, with: .color(segment.color), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                startAngle = endAngle
            }
        }
    }
}

private struct AllTasksSheet: View {
    let tasks: [TaskTimeData]
    @Environment(\.dismiss) private var dismiss

    private var totalMinutes: Int {
        tasks.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 14) {
                            // Rank badge
                            ZStack {
                                Circle()
                                    .fill(index < 3 ? Theme.focusColor.opacity(0.1) : Theme.textTertiary.opacity(0.1))
                                    .frame(width: 28, height: 28)
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(index < 3 ? Theme.focusColor : Theme.textTertiary)
                            }

                            Text(task.taskTitle)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatMinutes(task.minutes))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.focusColor)
                                Text("\(Int(Double(task.minutes) / Double(totalMinutes) * 100))%")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.backgroundSecondary)
                        )
                    }
                }
                .padding(Theme.spacingM)
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("All Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - Data Models

private struct DayFocusData: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
    let isToday: Bool
    let isFuture: Bool
    let maxMinutes: Int

    var dayInitial: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
}

private struct TaskTimeData: Identifiable {
    let id = UUID()
    let taskTitle: String
    let minutes: Int
}

private struct DonutSegment: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let percentage: Double
    let color: Color
}

// MARK: - Recharge Score Card

private struct RechargeScoreCard: View {
    let score: Double
    let change: Double
    let animate: Bool

    private var hasData: Bool {
        score > 0
    }

    private var changeText: String {
        if abs(change) < 1 { return "" }
        let direction = change >= 0 ? "↑" : "↓"
        return "\(direction) \(Int(abs(change)))% vs last week"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.breakColor.opacity(0.15), Color.cyan.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animate ? min(score / 100.0, 1.0) : 0)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.breakColor, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animate)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.breakColor, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Recharge Score")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 8) {
                    Text(hasData ? "\(Int(score))%" : "--")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    if !changeText.isEmpty {
                        Text(changeText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(change >= 0 ? .green : .orange)
                    }
                }
            }

            Spacer()

            if !hasData {
                Text("Move during breaks!")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.backgroundSecondary)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
        )
    }
}
