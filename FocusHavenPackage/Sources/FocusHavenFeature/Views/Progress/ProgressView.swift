import SwiftUI
import SwiftData
import Charts

@MainActor
public struct FocusProgressView: View {
    @Query(sort: \FocusRecord.date, order: .reverse) private var records: [FocusRecord]
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var selectedTab: InsightTab = .insights
    @State private var showAllTasks = false
    @State private var showInsightsUpgradePrompt = false
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

    // MARK: - Ring Progress (1 full ring = 1 hour of focus)

    private var ringProgress: Double {
        // 1 full ring = 60 minutes; wraps naturally for multi-hour weeks
        min(Double(thisWeekMinutes) / 60.0, 1.0)
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
                VStack(spacing: 28) {
                    // Focus Ring Hero
                    focusRingHero
                        .opacity(appearAnimation ? 1 : 0)
                        .scaleEffect(appearAnimation ? 1 : 0.9)

                    // Achievement Pills
                    achievementPills
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 15)
                        .animation(.spring(response: 0.5).delay(0.1), value: appearAnimation)

                    // Week Heatmap
                    weekHeatmap
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 15)
                        .animation(.spring(response: 0.5).delay(0.15), value: appearAnimation)

                    // Task Breakdown
                    if !taskBreakdown.isEmpty {
                        taskBreakdownCard
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 15)
                            .animation(.spring(response: 0.5).delay(0.2), value: appearAnimation)
                    }

                    // Insights / Charts
                    if subscriptionService.canAccessInsights {
                        tabSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 15)
                            .animation(.spring(response: 0.5).delay(0.25), value: appearAnimation)
                    } else {
                        lockedInsightsCard
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 15)
                            .animation(.spring(response: 0.5).delay(0.25), value: appearAnimation)
                    }
                }
                .padding(.horizontal, Theme.spacingM)
                .padding(.bottom, Theme.spacingXL)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("Progress")
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    appearAnimation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeOut(duration: 1.2)) {
                        chartAnimation = true
                    }
                }
            }
            .sheet(isPresented: $showAllTasks) {
                AllTasksSheet(tasks: taskBreakdown)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showInsightsUpgradePrompt) {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                        .onTapGesture { showInsightsUpgradePrompt = false }
                    UpgradePromptView.insightsLocked()
                }
                .presentationBackground(.clear)
            }
        }
    }

    // MARK: - Locked Insights Card

    private var lockedInsightsCard: some View {
        Button {
            showInsightsUpgradePrompt = true
        } label: {
            VStack(spacing: 14) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.focusColor.opacity(0.6))

                Text("Insights & Charts")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Text("Unlock detailed analytics on your focus patterns with Pro")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                    Text("Upgrade to Pro")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Theme.focusColor)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.backgroundSecondary)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Focus Ring Hero

    private var focusRingHero: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Theme.focusColor.opacity(0.1), style: StrokeStyle(lineWidth: 18))
                    .frame(width: 200, height: 200)

                // Progress ring
                Circle()
                    .trim(from: 0, to: chartAnimation ? min(ringProgress, 1.0) : 0)
                    .stroke(
                        AngularGradient(
                            colors: [Theme.focusColor, .cyan, Theme.focusColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.2, dampingFraction: 0.75), value: chartAnimation)

                // Center content
                VStack(spacing: 4) {
                    Text(formatMinutes(thisWeekMinutes))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    Text("focused this week")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)

                    if currentStreak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                            Text("\(currentStreak)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                    }
                }
            }

            // Comparison pill
            if weeklyDifference != 0 {
                HStack(spacing: 5) {
                    Image(systemName: weeklyDifference > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
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
        }
        .padding(.top, 8)
    }

    // MARK: - Achievement Pills

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var achievementPills: some View {
        let pills = achievementPillsContent
        return Group {
            if horizontalSizeClass == .regular {
                // iPad: evenly distributed, full width
                HStack(spacing: 12) {
                    pills
                }
                .padding(.horizontal, 4)
            } else {
                // iPhone: horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        pills
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var achievementPillsContent: some View {
        // Focus quality
        AchievementPill(
            icon: "brain.head.profile.fill",
            label: "Focus",
            value: String(format: "%.1f", averageFocus),
            color: Theme.focusColor,
            expand: horizontalSizeClass == .regular
        )

        // Distractions
        AchievementPill(
            icon: totalDistractionsThisWeek == 0 ? "shield.checkered" : "hand.raised.fill",
            label: "Distractions",
            value: "\(totalDistractionsThisWeek)",
            color: totalDistractionsThisWeek == 0 ? .green : totalDistractionsThisWeek <= 3 ? .yellow : .orange,
            expand: horizontalSizeClass == .regular
        )

        // Completion rate
        if hasEnoughData {
            AchievementPill(
                icon: "checkmark.seal.fill",
                label: "Completed",
                value: "\(completionRate)%",
                color: .green,
                expand: horizontalSizeClass == .regular
            )
        }
    }

    // MARK: - Week Heatmap

    private var weekHeatmap: some View {
        VStack(spacing: 14) {
            HStack {
                Text("This Week")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(formatMinutes(thisWeekMinutes))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.focusColor)
            }

            HStack(spacing: 0) {
                ForEach(Array(dailyFocusData.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 8) {
                        // Heatmap circle — sized + colored by intensity
                        let intensity = day.isFuture ? 0.0 : (day.minutes > 0 ? Double(day.minutes) / Double(day.maxMinutes) : 0)
                        let circleSize: CGFloat = day.isFuture ? 28 : (day.minutes > 0 ? max(28, min(44, 28 + CGFloat(intensity) * 16)) : 28)

                        ZStack {
                            Circle()
                                .fill(
                                    day.isFuture ? Theme.textTertiary.opacity(0.06) :
                                    day.minutes > 0 ? Theme.focusColor.opacity(0.15 + intensity * 0.55) :
                                    Theme.textTertiary.opacity(0.08)
                                )
                                .frame(
                                    width: chartAnimation ? circleSize : 28,
                                    height: chartAnimation ? circleSize : 28
                                )

                            if day.minutes > 0 && !day.isFuture {
                                Text("\(day.minutes)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.focusColor)
                            }
                        }
                        .overlay(
                            day.isToday ?
                            Circle()
                                .strokeBorder(Theme.focusColor, lineWidth: 2.5)
                                .frame(
                                    width: (chartAnimation ? circleSize : 28) + 6,
                                    height: (chartAnimation ? circleSize : 28) + 6
                                )
                            : nil
                        )
                        .frame(height: 50)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.06),
                            value: chartAnimation
                        )

                        Text(day.dayInitial)
                            .font(.system(size: 11, weight: day.isToday ? .bold : .medium))
                            .foregroundStyle(day.isToday ? Theme.focusColor : Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.backgroundSecondary)
        )
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
        )
    }

    // MARK: - Tab Section

    private var tabSection: some View {
        VStack(spacing: 16) {
            // Tab picker
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
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? Theme.focusColor : Color.clear)
                            )
                    }
                }
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(Theme.backgroundSecondary)
            )

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
                    Divider().padding(.leading, 52)
                    InsightRow(icon: "calendar.badge.checkmark", iconColor: .blue, title: "Best Day", value: bestDayOfWeek)
                    Divider().padding(.leading, 52)
                    InsightRow(icon: "number.circle.fill", iconColor: Theme.focusColor, title: "Total Sessions", value: "\(focusSessions.count)")
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.backgroundSecondary)
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
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.backgroundSecondary)
                )
            }
        }
    }

    // MARK: - Charts Content

    private var chartsContent: some View {
        VStack(spacing: 16) {
            DailyChartView(records: records)
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

private struct AchievementPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var expand: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            if expand {
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: expand ? .infinity : nil)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

private struct InsightRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
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
