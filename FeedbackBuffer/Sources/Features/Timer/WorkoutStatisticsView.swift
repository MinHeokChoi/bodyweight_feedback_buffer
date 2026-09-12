import SwiftUI
import Charts

/// 통계. 두 질문에 답한다 — 어떤 운동에 얼마나 투자하고 있나, 어느 날에 운동을 갔나.
struct WorkoutStatisticsView: View {
    @Environment(WorkoutTimerStore.self) private var store
    @State private var period: WorkoutStatistics.Period = .last30Days

    private var summary: WorkoutStatistics.Summary {
        WorkoutStatistics.summary(for: store.sessions, in: period)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                periodPicker

                if summary.isEmpty {
                    emptyState
                } else {
                    metrics
                    distribution
                    weeklyTrend
                    attendance
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Surface.page.ignoresSafeArea())
        .navigationTitle("통계")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var periodPicker: some View {
        Picker("기간", selection: $period) {
            ForEach(WorkoutStatistics.Period.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 요약 지표

    private var metrics: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                DSMetric(
                    label: "총 운동 시간",
                    value: WorkoutTimeFormat.compact(summary.trainingDuration),
                    caption: "휴식 \(WorkoutTimeFormat.compact(summary.restDuration)) 제외"
                )
                DSMetric(
                    label: "운동한 날",
                    value: "\(summary.dayCount)일",
                    caption: "세션 \(summary.sessionCount)회"
                )
            }
            HStack(spacing: DS.Spacing.sm) {
                DSMetric(
                    label: "세션당 평균",
                    value: WorkoutTimeFormat.compact(summary.averageSessionDuration)
                )
                DSMetric(
                    label: "연속 운동",
                    value: "\(summary.currentStreak)일",
                    caption: "최장 \(summary.longestStreak)일"
                )
            }
        }
    }

    // MARK: - 시간 배분

    private var distribution: some View {
        let entries = TrainingPhaseKind.recommendedOrder.compactMap { kind -> (TrainingPhaseKind, TimeInterval)? in
            guard let duration = summary.byKind[kind], duration > 0 else { return nil }
            return (kind, duration)
        }
        let total = summary.trainingDuration + summary.restDuration

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionLabel(text: "구간별 시간 배분")

            SegmentRatioBar(byKind: summary.byKind, rest: summary.restDuration)

            VStack(spacing: DS.Spacing.xs) {
                ForEach(entries, id: \.0) { kind, duration in
                    legendRow(
                        color: kind.tint,
                        name: kind.displayName,
                        duration: duration,
                        total: total
                    )
                }
                if summary.restDuration > 0 {
                    legendRow(
                        color: DS.Segment.rest,
                        name: "휴식",
                        duration: summary.restDuration,
                        total: total
                    )
                }
            }
        }
    }

    private func legendRow(color: Color, name: String, duration: TimeInterval, total: TimeInterval) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
                .font(DS.Typo.metaLabel)
            Spacer()
            Text(WorkoutTimeFormat.compact(duration))
                .font(DS.Typo.number)
                .foregroundStyle(.secondary)
            Text(total > 0 ? "\(Int((duration / total * 100).rounded()))%" : "0%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 주 단위 추이

    private var weeklyTrend: some View {
        let totals = WorkoutStatistics.weeklyKindTotals(for: store.sessions, in: period)

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionLabel(text: "주 단위 추이")

            if totals.isEmpty {
                Text("아직 추이를 볼 만큼 쌓이지 않았어요.")
                    .font(DS.Typo.metaLabel)
                    .foregroundStyle(.secondary)
                    .dsTile()
            } else {
                // 축 단위를 데이터 크기에 맞춘다. 시간으로 고정하면 한 시간이 안 되는
                // 주에는 눈금이 전부 0h로 보여 축이 아무것도 말해주지 않는다.
                let weekMax = weeklyMaximum(totals)
                let useHours = weekMax >= 3600

                Chart(totals) { item in
                    BarMark(
                        x: .value("주", item.weekStart, unit: .weekOfYear),
                        y: .value(useHours ? "시간" : "분", item.duration / 60)
                    )
                    .foregroundStyle(item.kind.tint)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text(useHours
                                     ? "\(Int((minutes / 60).rounded()))시간"
                                     : "\(Int(minutes.rounded()))분")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .frame(height: 180)
                .dsTile()
            }
        }
    }

    /// 한 주의 구간 시간을 합쳐 가장 큰 값을 구한다. 축 단위를 고르는 데 쓴다.
    private func weeklyMaximum(_ totals: [WorkoutStatistics.WeeklyKindTotal]) -> TimeInterval {
        var byWeek: [Date: TimeInterval] = [:]
        for item in totals {
            byWeek[item.weekStart, default: 0] += item.duration
        }
        return byWeek.values.max() ?? 0
    }

    // MARK: - 출석

    private var attendance: some View {
        let totals = WorkoutStatistics.dailyTotals(for: store.sessions, in: period)
        let byDay = Dictionary(uniqueKeysWithValues: totals.map { ($0.day, $0) })
        let maxDuration = totals.map(\.trainingDuration).max() ?? 1
        let days = calendarDays()

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionLabel(text: "운동한 날")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                spacing: 3
            ) {
                ForEach(days, id: \.self) { day in
                    let total = byDay[day]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(total?.trainingDuration ?? 0, max: maxDuration))
                        .aspectRatio(1, contentMode: .fit)
                        .accessibilityLabel(Text(day, format: .dateTime.month().day()))
                        .accessibilityValue(
                            total == nil
                                ? "운동 없음"
                                : WorkoutTimeFormat.spoken(total!.trainingDuration)
                        )
                }
            }
            .dsTile()
        }
    }

    private func calendarDays() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let count = period.dayCount ?? max(28, daysSinceFirstSession())
        return (0..<count)
            .compactMap { calendar.date(byAdding: .day, value: -($0), to: today) }
            .reversed()
    }

    private func daysSinceFirstSession() -> Int {
        guard let earliest = store.sessions.map(\.startedAt).min() else { return 28 }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: earliest),
            to: calendar.startOfDay(for: .now)
        ).day ?? 0
        return min(365, max(28, days + 1))
    }

    private func heatColor(_ duration: TimeInterval, max maxDuration: TimeInterval) -> Color {
        guard duration > 0 else { return Color(.tertiarySystemFill) }
        let ratio = min(1, duration / Swift.max(1, maxDuration))
        // 농도만 다르게 한다. 색이 여러 개면 "얼마나 했나"가 안 읽힌다.
        return DS.Segment.strength.opacity(0.25 + 0.75 * ratio)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("이 기간에는 기록이 없어요")
                .font(DS.Typo.value)
            Text("운동을 마치면 시간 배분과 출석이 여기에 쌓여요.")
                .font(DS.Typo.metaLabel)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl * 2)
    }
}
