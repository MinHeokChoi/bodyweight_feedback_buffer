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
                    // 7일은 한두 주라 주 단위 막대가 한 줄로 화면을 채울 뿐이다.
                    if period != .last7Days {
                        weeklyTrend
                    }
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
            .fixedSize(horizontal: false, vertical: true)
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
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 시간 배분

    private var distribution: some View {
        let entries = TrainingPhaseKind.recommendedOrder.compactMap { kind -> (TrainingPhaseKind, TimeInterval)? in
            guard let duration = summary.byKind[kind], duration > 0 else { return nil }
            return (kind, duration)
        }
        // 비율은 운동 시간끼리만 나눈다. 휴식은 기록의 목적이 아니고, 직접 입력한 기록은
        // 휴식이 0이라 섞으면 기록 방식에 따라 비율이 흔들린다. 휴식은 위 타일에 따로 있다.
        let total = summary.trainingDuration

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionLabel(text: "구간별 시간 배분")

            SegmentRatioBar(byKind: summary.byKind)

            VStack(spacing: DS.Spacing.xs) {
                ForEach(entries, id: \.0) { kind, duration in
                    legendRow(
                        color: kind.tint,
                        name: kind.displayName,
                        duration: duration,
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
            Text(WorkoutTimeFormat.percent(duration, of: total))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
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
                // 기간 전체를 축으로 둔다. 운동한 주만 있으면 막대 하나가 폭을 다 차지하고
                // 쉰 주가 보이지 않았다.
                .chartXScale(domain: weekDomain)
                .frame(height: 180)
                .dsTile()
            }
        }
    }

    /// 주 차트의 가로 범위. 기간 첫 주의 시작부터 이번 주 끝까지.
    private var weekDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let first = period.dayCount
            .flatMap { calendar.date(byAdding: .day, value: -($0 - 1), to: today) }
            ?? store.sessions.map(\.startedAt).min()
            ?? today
        let start = WorkoutStatistics.startOfWeek(for: first, calendar: calendar)
        let end = calendar.date(
            byAdding: .day,
            value: 7,
            to: WorkoutStatistics.startOfWeek(for: today, calendar: calendar)
        ) ?? today
        return start...end
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
        let cells = calendarCells()

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                DSSectionLabel(text: "운동한 날")
                // 칸만 있으면 어느 날인지 추론해야 했다. 기간을 글로 적는다.
                if let first = cells.compactMap({ $0 }).first {
                    Text("\(first.formatted(.dateTime.month().day())) – 오늘")
                        .font(DS.Typo.sectionLabel)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }

            VStack(spacing: DS.Spacing.xs) {
                weekdayHeader

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                    spacing: 3
                ) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        if let day {
                            // 칸 날짜와 집계 키를 같은 하루 시작으로 맞춘다. 자정에 서머타임이
                            // 시작되는 지역에서는 하루를 빼 가며 만든 날짜가 한 시간 어긋났다.
                            let total = byDay[Calendar.current.startOfDay(for: day)]
                            // 운동한 날은 눌러서 그날 기록으로 간다(FR-8).
                            if total != nil {
                                NavigationLink {
                                    WorkoutHistoryView(day: day)
                                } label: {
                                    heatCell(day: day, total: total, maxDuration: maxDuration)
                                }
                                .buttonStyle(.plain)
                            } else {
                                heatCell(day: day, total: nil, maxDuration: maxDuration)
                            }
                        } else {
                            // 첫 주의 빈 칸. 열이 요일을 뜻하도록 자리를 맞춘다.
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .dsTile()
        }
    }

    /// 날짜 숫자와 오늘 테두리가 있는 칸. 매달 1일은 "10월"처럼 달을 적는다.
    private func heatCell(day: Date, total: WorkoutStatistics.DailyTotal?, maxDuration: TimeInterval) -> some View {
        let calendar = Calendar.current
        let dayNumber = calendar.component(.day, from: day)
        let isToday = calendar.isDateInToday(day)

        return RoundedRectangle(cornerRadius: DS.Radius.bar)
            .fill(heatColor(total?.trainingDuration ?? 0, max: maxDuration))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Text(dayNumber == 1 ? day.formatted(.dateTime.month()) : "\(dayNumber)")
                    .font(.caption2.weight(dayNumber == 1 ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(total == nil ? Color.secondary : Color.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(2)
            }
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: DS.Radius.bar)
                        .stroke(Color.primary.opacity(0.7), lineWidth: 1.5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(day, format: .dateTime.month().day()))
            .accessibilityValue(
                total.map { WorkoutTimeFormat.spoken($0.trainingDuration) } ?? "운동 없음"
            )
            .accessibilityHint(total == nil ? "" : "눌러서 그날 기록을 봐요")
    }

    private var weekdayHeader: some View {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        // firstWeekday 기준으로 회전시킨다. 지역 설정이 일요일 시작이든 월요일
        // 시작이든 아래 격자와 열이 어긋나지 않아야 한다.
        let ordered = (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }

        return HStack(spacing: 3) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// 히트맵 칸 목록. 앞쪽 nil은 첫 주의 빈 칸이다.
    private func calendarCells() -> [Date?] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let count = period.dayCount ?? max(28, daysSinceFirstSession())
        let days: [Date] = (0..<count)
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .reversed()

        guard let first = days.first else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + days.map { Optional($0) }
    }

    /// "전체" 기간일 때 히트맵이 덮을 날 수. 최소 4주는 보여준다.
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
