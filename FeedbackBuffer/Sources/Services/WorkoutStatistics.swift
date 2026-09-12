import Foundation

/// 기간별 운동 집계. UI와 분리된 순수 로직이며 테스트 대상이다.
///
/// "총 운동 시간"은 구간 시간의 합이다. 휴식은 빼고 따로 표기한다.
/// 헬스장에서 얼쩡거린 시간이 운동량으로 섞이면 안 되기 때문이다.
enum WorkoutStatistics {

    // MARK: - 기간

    enum Period: String, CaseIterable, Identifiable {
        case last7Days
        case last30Days
        case last90Days
        case all

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .last7Days: "7일"
            case .last30Days: "30일"
            case .last90Days: "90일"
            case .all: "전체"
            }
        }

        var dayCount: Int? {
            switch self {
            case .last7Days: 7
            case .last30Days: 30
            case .last90Days: 90
            case .all: nil
            }
        }
    }

    // MARK: - 결과

    struct Summary: Equatable {
        /// 구간 시간의 합. 화면에서 "총 운동 시간"으로 부른다.
        var trainingDuration: TimeInterval = 0
        /// 일시정지를 뺀 체류 시간
        var activeDuration: TimeInterval = 0
        /// 구간 타이머가 꺼져 있던 시간
        var restDuration: TimeInterval = 0
        var sessionCount: Int = 0
        /// 운동한 날 수. 하루에 두 번 운동해도 하루로 센다.
        var dayCount: Int = 0
        var currentStreak: Int = 0
        var longestStreak: Int = 0
        var byKind: [TrainingPhaseKind: TimeInterval] = [:]

        var averageSessionDuration: TimeInterval {
            sessionCount > 0 ? trainingDuration / Double(sessionCount) : 0
        }

        /// 체류 시간 대비 실제 운동 비율
        var trainingRatio: Double {
            activeDuration > 0 ? trainingDuration / activeDuration : 0
        }

        var isEmpty: Bool { sessionCount == 0 }
    }

    /// 하루치 집계. 캘린더 히트맵과 하루 단위 목록에 쓴다.
    struct DailyTotal: Identifiable, Equatable {
        var day: Date
        var trainingDuration: TimeInterval
        var sessionCount: Int

        var id: Date { day }
    }

    /// 주 단위 구간별 누적. 추이 차트에 쓴다.
    struct WeeklyKindTotal: Identifiable, Equatable {
        var weekStart: Date
        var kind: TrainingPhaseKind
        var duration: TimeInterval

        var id: String { "\(weekStart.timeIntervalSince1970)-\(kind.rawValue)" }
    }

    // MARK: - 필터

    static func sessions(
        _ sessions: [WorkoutSession],
        in period: Period,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WorkoutSession] {
        let finished = sessions.filter { !$0.isRunning }
        guard let days = period.dayCount else { return finished }
        let today = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return finished
        }
        return finished.filter { $0.startedAt >= cutoff }
    }

    // MARK: - 요약

    static func summary(
        for allSessions: [WorkoutSession],
        in period: Period,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Summary {
        let scoped = sessions(allSessions, in: period, now: now, calendar: calendar)
        var summary = Summary()
        summary.sessionCount = scoped.count

        for session in scoped {
            summary.trainingDuration += session.trainingDuration(now: now)
            summary.activeDuration += session.activeDuration(now: now)
            summary.restDuration += session.restDuration(now: now)
            for (kind, duration) in session.durationByKind(now: now) {
                summary.byKind[kind, default: 0] += duration
            }
        }

        let days = workoutDays(in: scoped, calendar: calendar)
        summary.dayCount = days.count
        summary.longestStreak = longestStreak(in: days, calendar: calendar)
        summary.currentStreak = currentStreak(in: days, now: now, calendar: calendar)
        return summary
    }

    // MARK: - 날짜 집계

    /// 운동한 날의 집합. 하루에 여러 세션이어도 하나로 접힌다.
    static func workoutDays(
        in sessions: [WorkoutSession],
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
    }

    /// 하루 단위 집계. 최신 날짜가 앞이다.
    static func dailyTotals(
        for allSessions: [WorkoutSession],
        in period: Period,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyTotal] {
        let scoped = sessions(allSessions, in: period, now: now, calendar: calendar)
        var buckets: [Date: DailyTotal] = [:]

        for session in scoped {
            let day = calendar.startOfDay(for: session.startedAt)
            var total = buckets[day] ?? DailyTotal(day: day, trainingDuration: 0, sessionCount: 0)
            total.trainingDuration += session.trainingDuration(now: now)
            total.sessionCount += 1
            buckets[day] = total
        }

        return buckets.values.sorted { $0.day > $1.day }
    }

    /// 주 단위 구간별 누적. 오래된 주가 앞이다(차트가 왼쪽부터 흐르도록).
    static func weeklyKindTotals(
        for allSessions: [WorkoutSession],
        in period: Period,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WeeklyKindTotal] {
        let scoped = sessions(allSessions, in: period, now: now, calendar: calendar)
        var buckets: [Date: [TrainingPhaseKind: TimeInterval]] = [:]

        for session in scoped {
            let weekStart = startOfWeek(for: session.startedAt, calendar: calendar)
            for (kind, duration) in session.durationByKind(now: now) {
                buckets[weekStart, default: [:]][kind, default: 0] += duration
            }
        }

        var totals: [WeeklyKindTotal] = []
        for (weekStart, byKind) in buckets {
            for (kind, duration) in byKind {
                totals.append(
                    WeeklyKindTotal(weekStart: weekStart, kind: kind, duration: duration)
                )
            }
        }

        totals.sort { lhs, rhs in
            if lhs.weekStart != rhs.weekStart {
                return lhs.weekStart < rhs.weekStart
            }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        return totals
    }

    static func startOfWeek(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    // MARK: - 연속 일수

    /// 가장 긴 연속 운동 일수.
    static func longestStreak(in days: Set<Date>, calendar: Calendar = .current) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var longest = 1
        var current = 1

        for index in 1..<sorted.count {
            let gap = calendar.dateComponents([.day], from: sorted[index - 1], to: sorted[index]).day ?? 0
            if gap == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    /// 지금까지 이어지고 있는 연속 일수.
    ///
    /// 오늘 아직 운동을 안 했어도 어제까지 이어졌다면 연속은 살아 있는 것으로 본다.
    /// 저녁에 운동하는 사람의 오전이 0일로 보이면 안 되기 때문이다.
    static func currentStreak(
        in days: Set<Date>,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard !days.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: now)

        var cursor: Date
        if days.contains(today) {
            cursor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
