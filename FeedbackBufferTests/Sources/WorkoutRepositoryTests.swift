import XCTest
@testable import FeedbackBuffer

final class WorkoutRepositoryTests: XCTestCase {

    private func makeSession(startedAt: Date = Date(timeIntervalSince1970: 1_000_000)) -> WorkoutSession {
        WorkoutSession(
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(3600),
            segments: [
                TrainingSegment(
                    kind: .warmup,
                    startedAt: startedAt,
                    endedAt: startedAt.addingTimeInterval(600)
                ),
                TrainingSegment(
                    kind: .strength,
                    startedAt: startedAt.addingTimeInterval(900),
                    endedAt: startedAt.addingTimeInterval(2700),
                    laps: [
                        TrainingLap(index: 1, duration: 540),
                        TrainingLap(index: 2, duration: 540)
                    ]
                )
            ],
            pauses: [
                PauseInterval(
                    startedAt: startedAt.addingTimeInterval(3000),
                    endedAt: startedAt.addingTimeInterval(3120)
                )
            ],
            note: "어깨 좋았음"
        )
    }

    func testSessionsRoundTrip() throws {
        let store = InMemoryFileStore()
        let repository = WorkoutRepository(store: store)
        let session = makeSession()

        try repository.saveSessions([session])
        let loaded = try repository.loadSessions()

        XCTAssertEqual(loaded, [session])
    }

    func testLoadSessionsReturnsEmptyWhenNothingSaved() throws {
        let repository = WorkoutRepository(store: InMemoryFileStore())
        XCTAssertEqual(try repository.loadSessions(), [])
    }

    func testActiveSessionRoundTrip() throws {
        let repository = WorkoutRepository(store: InMemoryFileStore())
        let active = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 2_000_000),
            segments: [TrainingSegment(kind: .strength, startedAt: Date(timeIntervalSince1970: 2_000_000))]
        )

        try repository.saveActiveSession(active)

        let loaded = try repository.loadActiveSession()
        XCTAssertEqual(loaded, active)
        XCTAssertEqual(loaded?.isRunning, true)
        XCTAssertEqual(loaded?.runningSegment?.kind, .strength)
    }

    func testClearActiveSessionRemovesIt() throws {
        let repository = WorkoutRepository(store: InMemoryFileStore())
        try repository.saveActiveSession(WorkoutSession(startedAt: .now))

        try repository.clearActiveSession()

        XCTAssertNil(try repository.loadActiveSession())
    }

    func testClearActiveSessionIsSafeWhenNothingStored() throws {
        let repository = WorkoutRepository(store: InMemoryFileStore())
        XCTAssertNoThrow(try repository.clearActiveSession())
    }

    /// 완료 기록과 진행 중 세션은 파일이 달라야 한다. 진행 중 세션을 지워도
    /// 지난 기록이 사라지면 안 된다.
    func testClearingActiveSessionKeepsFinishedSessions() throws {
        let repository = WorkoutRepository(store: InMemoryFileStore())
        let finished = makeSession()
        try repository.saveSessions([finished])
        try repository.saveActiveSession(WorkoutSession(startedAt: .now))

        try repository.clearActiveSession()

        XCTAssertEqual(try repository.loadSessions(), [finished])
    }
}

final class WorkoutSessionModelTests: XCTestCase {

    func testRunningSegmentIsTheOneWithoutEndDate() {
        let start = Date(timeIntervalSince1970: 0)
        let session = WorkoutSession(
            startedAt: start,
            segments: [
                TrainingSegment(kind: .warmup, startedAt: start, endedAt: start.addingTimeInterval(300)),
                TrainingSegment(kind: .strength, startedAt: start.addingTimeInterval(400))
            ]
        )

        XCTAssertEqual(session.runningSegment?.kind, .strength)
        XCTAssertFalse(session.isResting)
    }

    func testSessionIsRestingWhenNoSegmentRunning() {
        let start = Date(timeIntervalSince1970: 0)
        let session = WorkoutSession(
            startedAt: start,
            segments: [
                TrainingSegment(kind: .warmup, startedAt: start, endedAt: start.addingTimeInterval(300))
            ]
        )

        XCTAssertTrue(session.isResting)
        XCTAssertNil(session.runningSegment)
    }

    func testFinishedSessionIsNotResting() {
        let start = Date(timeIntervalSince1970: 0)
        let session = WorkoutSession(
            startedAt: start,
            endedAt: start.addingTimeInterval(1000),
            segments: []
        )

        XCTAssertFalse(session.isResting)
        XCTAssertFalse(session.isRunning)
    }

    func testIsPausedReflectsOpenPause() {
        let start = Date(timeIntervalSince1970: 0)
        var session = WorkoutSession(startedAt: start)
        XCTAssertFalse(session.isPaused)

        session.pauses.append(PauseInterval(startedAt: start.addingTimeInterval(10)))
        XCTAssertTrue(session.isPaused)

        session.pauses[0].endedAt = start.addingTimeInterval(20)
        XCTAssertFalse(session.isPaused)
    }

    /// 페이스 타이머는 스트렝스에서만 돈다. 웜업 12분이 "2번째 운동"으로
    /// 기록되는 일이 없어야 한다.
    func testOnlyStrengthUsesPaceTimer() {
        XCTAssertTrue(TrainingPhaseKind.strength.usesPaceTimer)
        for kind in TrainingPhaseKind.allCases where kind != .strength {
            XCTAssertFalse(kind.usesPaceTimer, "\(kind.displayName)은 페이스 타이머를 쓰지 않아야 한다")
        }
    }

    func testLapClampsInvalidValues() {
        let lap = TrainingLap(index: 0, duration: -50, targetDuration: 0)
        XCTAssertEqual(lap.index, 1)
        XCTAssertEqual(lap.duration, 0)
        XCTAssertEqual(lap.targetDuration, 1)
    }

    func testDefaultLapIsNineMinutes() {
        XCTAssertEqual(PaceTimer.defaultLapDuration, 540)
        XCTAssertEqual(PaceTimer.defaultSetDuration, 180)
        XCTAssertEqual(PaceTimer.defaultSetsPerLap, 3)
    }

    /// 카드 순서는 고정이다. 바뀌면 손이 기억한 위치가 어긋나므로 못 박아 둔다.
    func testCardOrderIsFixed() {
        XCTAssertEqual(
            TrainingPhaseKind.recommendedOrder,
            [.warmup, .skillPractice, .strength, .fatigueResistance, .stretching, .running]
        )
    }

    func testAllPhaseKindsAreInRecommendedOrder() {
        XCTAssertEqual(
            Set(TrainingPhaseKind.recommendedOrder),
            Set(TrainingPhaseKind.allCases),
            "권장 순서에 빠진 구간이 있으면 화면에서 고를 수 없다"
        )
    }
}
