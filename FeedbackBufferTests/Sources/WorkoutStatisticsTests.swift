import XCTest
@testable import FeedbackBuffer

final class WorkoutStatisticsTests: XCTestCase {

    /// 요일이 고정된 달력으로 고정해 테스트가 실행 요일에 흔들리지 않게 한다.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()

    /// 2026-09-12 12:00 KST
    private let now = Date(timeIntervalSince1970: 1_789_268_400)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    /// 지정한 날에 웜업 10분 + 휴식 5분 + 스트렝스 30분짜리 세션을 만든다.
    private func session(dayOffset: Int, warmup: TimeInterval = 600, strength: TimeInterval = 1800) -> WorkoutSession {
        let start = day(dayOffset)
        return WorkoutSession(
            startedAt: start,
            endedAt: start.addingTimeInterval(warmup + 300 + strength),
            segments: [
                TrainingSegment(
                    kind: .warmup,
                    startedAt: start,
                    endedAt: start.addingTimeInterval(warmup)
                ),
                TrainingSegment(
                    kind: .strength,
                    startedAt: start.addingTimeInterval(warmup + 300),
                    endedAt: start.addingTimeInterval(warmup + 300 + strength)
                )
            ]
        )
    }

    // MARK: - 기간 필터

    func testPeriodFilterExcludesOlderSessions() {
        let sessions = [session(dayOffset: 0), session(dayOffset: -10)]

        let recent = WorkoutStatistics.sessions(sessions, in: .last7Days, now: now, calendar: calendar)
        XCTAssertEqual(recent.count, 1)

        let all = WorkoutStatistics.sessions(sessions, in: .all, now: now, calendar: calendar)
        XCTAssertEqual(all.count, 2)
    }

    func testRunningSessionIsExcludedFromStatistics() {
        let running = WorkoutSession(
            startedAt: now,
            segments: [TrainingSegment(kind: .strength, startedAt: now)]
        )

        let scoped = WorkoutStatistics.sessions([running], in: .all, now: now, calendar: calendar)
        XCTAssertTrue(scoped.isEmpty, "아직 안 끝난 세션은 통계에 들어가면 안 된다")
    }

    // MARK: - 요약

    func testTotalTrainingTimeExcludesRest() {
        let summary = WorkoutStatistics.summary(
            for: [session(dayOffset: 0)],
            in: .all,
            now: now,
            calendar: calendar
        )

        // 웜업 600 + 스트렝스 1800 = 2400, 휴식 300은 빠진다
        XCTAssertEqual(summary.trainingDuration, 2400, accuracy: 0.001)
        XCTAssertEqual(summary.restDuration, 300, accuracy: 0.001)
        XCTAssertEqual(summary.activeDuration, 2700, accuracy: 0.001)
    }

    func testByKindSplitsSegments() {
        let summary = WorkoutStatistics.summary(
            for: [session(dayOffset: 0), session(dayOffset: -1)],
            in: .all,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.byKind[.warmup] ?? 0, 1200, accuracy: 0.001)
        XCTAssertEqual(summary.byKind[.strength] ?? 0, 3600, accuracy: 0.001)
        XCTAssertNil(summary.byKind[.skillPractice])
    }

    func testTrainingRatioComparesAgainstTimeInGym() {
        let summary = WorkoutStatistics.summary(
            for: [session(dayOffset: 0)],
            in: .all,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(summary.trainingRatio, 2400.0 / 2700.0, accuracy: 0.0001)
    }

    /// 하루에 두 번 운동해도 "운동한 날"은 하루다.
    func testTwoSessionsSameDayCountAsOneDay() {
        let first = session(dayOffset: 0)
        var second = session(dayOffset: 0)
        second = WorkoutSession(
            startedAt: first.startedAt.addingTimeInterval(20_000),
            endedAt: first.startedAt.addingTimeInterval(22_400),
            segments: [
                TrainingSegment(
                    kind: .strength,
                    startedAt: first.startedAt.addingTimeInterval(20_000),
                    endedAt: first.startedAt.addingTimeInterval(22_400)
                )
            ]
        )

        let summary = WorkoutStatistics.summary(
            for: [first, second],
            in: .all,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.dayCount, 1, "하루에 두 번 가도 운동한 날은 하루")
    }

    func testEmptySummary() {
        let summary = WorkoutStatistics.summary(for: [], in: .all, now: now, calendar: calendar)
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.averageSessionDuration, 0)
        XCTAssertEqual(summary.trainingRatio, 0)
        XCTAssertEqual(summary.currentStreak, 0)
    }

    func testAverageSessionDuration() {
        let summary = WorkoutStatistics.summary(
            for: [session(dayOffset: 0), session(dayOffset: -1)],
            in: .all,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(summary.averageSessionDuration, 2400, accuracy: 0.001)
    }

    // MARK: - 연속 일수

    func testLongestStreakFindsRun() {
        let days = Set([-6, -5, -4, -2, -1, 0].map { calendar.startOfDay(for: day($0)) })
        XCTAssertEqual(WorkoutStatistics.longestStreak(in: days, calendar: calendar), 3)
    }

    func testCurrentStreakCountsBackFromToday() {
        let days = Set([-2, -1, 0].map { calendar.startOfDay(for: day($0)) })
        XCTAssertEqual(
            WorkoutStatistics.currentStreak(in: days, now: now, calendar: calendar),
            3
        )
    }

    /// 저녁에 운동하는 사람의 오전에 연속이 0으로 보이면 안 된다.
    func testCurrentStreakSurvivesUntilTodayEnds() {
        let days = Set([-2, -1].map { calendar.startOfDay(for: day($0)) })
        XCTAssertEqual(
            WorkoutStatistics.currentStreak(in: days, now: now, calendar: calendar),
            2,
            "오늘 아직 안 했어도 어제까지 이어졌으면 연속은 살아 있다"
        )
    }

    func testCurrentStreakBreaksAfterTwoMissedDays() {
        let days = Set([-3, -2].map { calendar.startOfDay(for: day($0)) })
        XCTAssertEqual(
            WorkoutStatistics.currentStreak(in: days, now: now, calendar: calendar),
            0
        )
    }

    func testStreaksAreZeroWithNoDays() {
        XCTAssertEqual(WorkoutStatistics.longestStreak(in: [], calendar: calendar), 0)
        XCTAssertEqual(WorkoutStatistics.currentStreak(in: [], now: now, calendar: calendar), 0)
    }

    // MARK: - 하루 / 주 단위

    func testDailyTotalsGroupByDayNewestFirst() {
        let totals = WorkoutStatistics.dailyTotals(
            for: [session(dayOffset: 0), session(dayOffset: -1), session(dayOffset: -1)],
            in: .all,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(totals.count, 2)
        XCTAssertEqual(totals[0].day, calendar.startOfDay(for: day(0)))
        XCTAssertEqual(totals[1].sessionCount, 2)
        XCTAssertEqual(totals[1].trainingDuration, 4800, accuracy: 0.001)
    }

    func testWeeklyKindTotalsAreSortedOldestFirst() {
        let totals = WorkoutStatistics.weeklyKindTotals(
            for: [session(dayOffset: 0), session(dayOffset: -14)],
            in: .all,
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(totals.isEmpty)
        let weeks = totals.map(\.weekStart)
        XCTAssertEqual(weeks, weeks.sorted(), "차트가 왼쪽부터 흐르도록 오래된 주가 앞이어야 한다")
    }

    func testWeeklyKindTotalsSumSameWeek() {
        // 같은 주 안의 두 세션은 구간별로 합산돼야 한다
        let totals = WorkoutStatistics.weeklyKindTotals(
            for: [session(dayOffset: 0), session(dayOffset: -1)],
            in: .all,
            now: now,
            calendar: calendar
        )

        let strength = totals.filter { $0.kind == .strength }
        XCTAssertEqual(strength.count, 1, "같은 주는 한 항목으로 합쳐진다")
        XCTAssertEqual(strength[0].duration, 3600, accuracy: 0.001)
    }
}

final class WorkoutTimeFormatTests: XCTestCase {

    func testClockUnderOneHour() {
        XCTAssertEqual(WorkoutTimeFormat.clock(252), "4:12")
        XCTAssertEqual(WorkoutTimeFormat.clock(0), "0:00")
        XCTAssertEqual(WorkoutTimeFormat.clock(59), "0:59")
    }

    func testClockOverOneHour() {
        XCTAssertEqual(WorkoutTimeFormat.clock(3661), "1:01:01")
        XCTAssertEqual(WorkoutTimeFormat.clock(4522), "1:15:22")
    }

    func testClockClampsNegative() {
        XCTAssertEqual(WorkoutTimeFormat.clock(-10), "0:00")
    }

    func testCompactReadsNaturally() {
        XCTAssertEqual(WorkoutTimeFormat.compact(5040), "1시간 24분")
        XCTAssertEqual(WorkoutTimeFormat.compact(3600), "1시간")
        XCTAssertEqual(WorkoutTimeFormat.compact(600), "10분")
        XCTAssertEqual(WorkoutTimeFormat.compact(45), "45초")
        XCTAssertEqual(WorkoutTimeFormat.compact(0), "0초")
    }
}
