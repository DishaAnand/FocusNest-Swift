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

    // MARK: - Glass Panel Helpers

    private var glassBackground: some ShapeStyle {
        .ultraThinMaterial
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
    }

    // MARK: - Hero Panel

    private var heroCard: some View {
        VStack(spacing: 16) {
            // Big focus time with shimmer gradient
            VStack(spacing: 6) {
                Text(formatMinutes(thisWeekMinutes))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.focusColor, .cyan, Theme.focusColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("focused this week")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            // Comparison pill
            if weeklyDifference != 0 {
                HStack(spacing: 6) {
                    Image(systemName: weeklyDifference > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(formatMinutes(abs(weeklyDifference))) \(weeklyDifference > 0 ? "more" : "less") than last week")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(weeklyDifference > 0 ? .green : .orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill((weeklyDifference > 0 ? Color.green : Color.orange).opacity(0.1))
                )
            }

            // Embedded sparkline
            weekSparkline
                .padding(.top, 4)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Week Sparkline

    private var weekSparkline: some View {
        HStack(spacing: 0) {
            ForEach(Array(dailyFocusData.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 6) {
                    // Dot sized by minutes
                    let dotSize: CGFloat = day.isFuture ? 4 : (day.minutes > 0 ? max(8, min(20, CGFloat(day.minutes) / CGFloat(day.maxMinutes) * 20)) : 5)

                    Circle()
                        .fill(
                            day.isFuture ? AnyShapeStyle(Theme.textTertiary.opacity(0.2)) :
                            day.minutes > 0 ?
                                AnyShapeStyle(LinearGradient(colors: [Theme.focusColor, .cyan], startPoint: .top, endPoint: .bottom)) :
                                AnyShapeStyle(Theme.textTertiary.opacity(0.3))
                        )
                        .frame(width: chartAnimation ? dotSize : 4, height: chartAnimation ? dotSize : 4)
                        .overlay(
                            day.isToday ?
                            Circle()
                                .strokeBorder(Theme.focusColor, lineWidth: 2)
                                .frame(width: dotSize + 6, height: dotSize + 6)
                            : nil
                        )
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.06), value: chartAnimation)

                    Text(day.dayInitial)
                        .font(.system(size: 10, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? Theme.focusColor : Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Asymmetric Stat Panels

    private var statsGrid: some View {
        VStack(spacing: 10) {
            // Row 1: Large streak + small distractions
            HStack(spacing: 10) {
                // Streak — large panel
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                            )
                        Spacer()
                        Text("\(currentStreak)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                    }

                    Text("day streak")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)

                    // Week activity dots
                    HStack(spacing: 6) {
                        ForEach(dailyFocusData) { day in
                            Circle()
                                .fill(day.isFuture ? Theme.textTertiary.opacity(0.15) :
                                      day.minutes > 0 ? Color.orange : Theme.textTertiary.opacity(0.25))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(glassBorder)
                )

                // Distractions — small panel
                VStack(spacing: 8) {
                    Image(systemName: totalDistractionsThisWeek == 0 ? "shield.checkered" : "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            totalDistractionsThisWeek == 0 ? Color.green :
                            totalDistractionsThisWeek <= 3 ? Color.yellow : Color.orange
                        )

                    Text("\(totalDistractionsThisWeek)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    Text("dist.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 110)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(glassBorder)
                )
                .frame(width: 100)
            }

            // Row 2: Small focus score + large recharge
            HStack(spacing: 10) {
                // Focus score — small panel
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.focusColor, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )

                    Text(String(format: "%.1f", averageFocus))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    Text("focus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 110)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(glassBorder)
                )
                .frame(width: 100)

                // Recharge — large panel
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Theme.textTertiary.opacity(0.1), lineWidth: 4)
                            .frame(width: 52, height: 52)

                        Circle()
                            .trim(from: 0, to: chartAnimation ? min(thisWeekRechargeScore / 100.0, 1.0) : 0)
                            .stroke(
                                LinearGradient(colors: [Theme.breakColor, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: chartAnimation)

                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.breakColor, .cyan], startPoint: .top, endPoint: .bottom)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recharge")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)

                        HStack(spacing: 6) {
                            Text(thisWeekRechargeScore > 0 ? "\(Int(thisWeekRechargeScore))%" : "--")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)

                            if abs(rechargeScoreChange) >= 1 {
                                Text("\(rechargeScoreChange >= 0 ? "+" : "")\(Int(rechargeScoreChange))%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(rechargeScoreChange >= 0 ? .green : .orange)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(glassBorder)
                )
            }
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
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Tab Section

    private var tabSection: some View {
        VStack(spacing: 16) {
            // Custom tab picker — glass style
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
                    .fill(.ultraThinMaterial)
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
        VStack(spacing: 0) {
            if hasEnoughData {
                VStack(spacing: 0) {
                    InsightRow(icon: "sun.horizon.fill", iconColor: .orange, title: "Peak Time", value: bestTimeOfDay)
                    Divider().padding(.leading, 48)
                    InsightRow(icon: "calendar.badge.checkmark", iconColor: .blue, title: "Best Day", value: bestDayOfWeek)
                    Divider().padding(.leading, 48)
                    InsightRow(icon: "checkmark.seal.fill", iconColor: .green, title: "Completion", value: "\(completionRate)%")
                    Divider().padding(.leading, 48)
                    InsightRow(icon: "number.circle.fill", iconColor: Theme.focusColor, title: "Sessions", value: "\(focusSessions.count)")
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.focusColor.opacity(0.6))
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
                        .fill(.ultraThinMaterial)
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

private struct InsightRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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


