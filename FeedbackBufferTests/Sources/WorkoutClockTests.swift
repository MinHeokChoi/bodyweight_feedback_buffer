import XCTest
@testable import FeedbackBuffer

/// 시간 계산은 타이머 탭의 전부다. 화면이 꺼져 있어도, 앱이 죽어도,
/// 재부팅해도 맞아야 하므로 여기서 촘촘히 잠근다.
final class WorkoutClockTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    // MARK: - 일시정지 겹침

    func testPausedDurationCountsOnlyOverlap() {
        // 구간은 100~200, 일시정지는 150~300 → 겹치는 건 50초뿐
        let pauses = [PauseInterval(startedAt: at(150), endedAt: at(300))]
        let overlap = WorkoutClock.pausedDuration(in: pauses, between: at(100), and: at(200))
        XCTAssertEqual(overlap, 50, accuracy: 0.001)
    }

    func testPausedDurationIgnoresNonOverlappingPause() {
        let pauses = [PauseInterval(startedAt: at(500), endedAt: at(600))]
        let overlap = WorkoutClock.pausedDuration(in: pauses, between: at(100), and: at(200))
        XCTAssertEqual(overlap, 0)
    }

    func testOpenPauseCountsUntilRangeEnd() {
        // 아직 재개하지 않은 일시정지는 조회 끝 시점까지 센다
        let pauses = [PauseInterval(startedAt: at(150))]
        let overlap = WorkoutClock.pausedDuration(in: pauses, between: at(100), and: at(200))
        XCTAssertEqual(overlap, 50, accuracy: 0.001)
    }

    func testMultiplePausesAccumulate() {
        let pauses = [
            PauseInterval(startedAt: at(110), endedAt: at(120)),
            PauseInterval(startedAt: at(150), endedAt: at(170))
        ]
        let overlap = WorkoutClock.pausedDuration(in: pauses, between: at(100), and: at(200))
        XCTAssertEqual(overlap, 30, accuracy: 0.001)
    }

    // MARK: - 구간 시간

    func testRunningSegmentUsesNow() {
        let segment = TrainingSegment(kind: .warmup, startedAt: at(0))
        XCTAssertEqual(segment.duration(pauses: [], now: at(600)), 600, accuracy: 0.001)
    }

    func testFinishedSegmentIgnoresNow() {
        let segment = TrainingSegment(kind: .warmup, startedAt: at(0), endedAt: at(600))
        // now가 한참 뒤여도 끝난 구간은 늘어나지 않는다
        XCTAssertEqual(segment.duration(pauses: [], now: at(99_999)), 600, accuracy: 0.001)
    }

    func testSegmentSubtractsPause() {
        let segment = TrainingSegment(kind: .strength, startedAt: at(0), endedAt: at(600))
        let pauses = [PauseInterval(startedAt: at(100), endedAt: at(250))]
        XCTAssertEqual(segment.duration(pauses: pauses, now: at(600)), 450, accuracy: 0.001)
    }

    /// 기기 시간을 뒤로 돌려도 음수가 나오면 안 된다.
    func testClockMovedBackwardYieldsZeroNotNegative() {
        let segment = TrainingSegment(kind: .warmup, startedAt: at(600))
        XCTAssertEqual(segment.duration(pauses: [], now: at(0)), 0)
    }

    // MARK: - 세션 파생값

    private func sampleSession(now: Date) -> WorkoutSession {
        // 0~600 웜업, 600~900 휴식, 900~1800 스트렝스, 1800~2000 휴식(진행 중)
        WorkoutSession(
            startedAt: at(0),
            segments: [
                TrainingSegment(kind: .warmup, startedAt: at(0), endedAt: at(600)),
                TrainingSegment(kind: .strength, startedAt: at(900), endedAt: at(1800))
            ]
        )
    }

    func testRestIsDerivedNotStored() {
        let session = sampleSession(now: at(2000))
        XCTAssertEqual(session.activeDuration(now: at(2000)), 2000, accuracy: 0.001)
        XCTAssertEqual(session.trainingDuration(now: at(2000)), 1500, accuracy: 0.001)
        // 휴식 = 2000 - 1500 = 500 (600~900 사이 300초 + 1800~2000 사이 200초)
        XCTAssertEqual(session.restDuration(now: at(2000)), 500, accuracy: 0.001)
    }

    func testActiveDurationExcludesPauseButTotalDoesNot() {
        var session = sampleSession(now: at(2000))
        session.pauses = [PauseInterval(startedAt: at(1000), endedAt: at(1200))]

        XCTAssertEqual(session.totalDuration(now: at(2000)), 2000, accuracy: 0.001)
        XCTAssertEqual(session.activeDuration(now: at(2000)), 1800, accuracy: 0.001)
        // 일시정지가 스트렝스 구간 안에 있었으므로 구간 시간도 줄어든다
        XCTAssertEqual(session.trainingDuration(now: at(2000)), 1300, accuracy: 0.001)
        XCTAssertEqual(session.restDuration(now: at(2000)), 500, accuracy: 0.001)
    }

    func testCurrentRestMeasuresFromLastSegmentEnd() {
        let session = sampleSession(now: at(2000))
        XCTAssertEqual(WorkoutClock.currentRestDuration(of: session, now: at(2000)) ?? -1, 200, accuracy: 0.001)
    }

    func testCurrentRestIsNilWhileSegmentRunning() {
        let session = WorkoutSession(
            startedAt: at(0),
            segments: [TrainingSegment(kind: .strength, startedAt: at(0))]
        )
        XCTAssertNil(WorkoutClock.currentRestDuration(of: session, now: at(500)))
    }

    func testCurrentRestMeasuresFromSessionStartWhenNoSegmentYet() {
        let session = WorkoutSession(startedAt: at(0))
        XCTAssertEqual(WorkoutClock.currentRestDuration(of: session, now: at(120)) ?? -1, 120, accuracy: 0.001)
    }

    func testDurationByKindSumsRepeatedSegments() {
        // 스트렝스에 두 번 들어간 경우 합산돼야 한다
        let session = WorkoutSession(
            startedAt: at(0),
            segments: [
                TrainingSegment(kind: .strength, startedAt: at(0), endedAt: at(600)),
                TrainingSegment(kind: .skillPractice, startedAt: at(700), endedAt: at(1000)),
                TrainingSegment(kind: .strength, startedAt: at(1100), endedAt: at(1400))
            ]
        )

        let byKind = session.durationByKind(now: at(1400))
        XCTAssertEqual(byKind[.strength] ?? 0, 900, accuracy: 0.001)
        XCTAssertEqual(byKind[.skillPractice] ?? 0, 300, accuracy: 0.001)
        XCTAssertNil(byKind[.warmup])
    }

    // MARK: - 페이스 타이머

    func testPaceStateAtStart() {
        let state = WorkoutClock.paceState(elapsed: 0)
        XCTAssertEqual(state.lapIndex, 1)
        XCTAssertEqual(state.setIndex, 1)
        XCTAssertEqual(state.lapElapsed, 0)
        XCTAssertEqual(state.lapRemaining, 540)
    }

    func testPaceStateMidSecondSet() {
        // 4분 12초 = 252초 → 1번째 운동, 2세트(180~360), 세트 안 72초
        let state = WorkoutClock.paceState(elapsed: 252)
        XCTAssertEqual(state.lapIndex, 1)
        XCTAssertEqual(state.setIndex, 2)
        XCTAssertEqual(state.setElapsed, 72, accuracy: 0.001)
        XCTAssertEqual(state.lapElapsed, 252, accuracy: 0.001)
    }

    func testPaceStateRollsToNextLapAtNineMinutes() {
        let state = WorkoutClock.paceState(elapsed: 540)
        XCTAssertEqual(state.lapIndex, 2, "9분에 닿으면 다음 운동으로 넘어가야 한다")
        XCTAssertEqual(state.lapElapsed, 0, accuracy: 0.001)
        XCTAssertEqual(state.setIndex, 1)
    }

    func testPaceStateSetIndexNeverExceedsSetsPerLap() {
        // 랩 끝 직전은 3세트여야 하며 4세트가 나오면 안 된다
        let state = WorkoutClock.paceState(elapsed: 539.9)
        XCTAssertEqual(state.setIndex, 3)
    }

    /// 백그라운드에 오래 있다 돌아와도 지나간 랩이 그대로 반영돼야 한다.
    func testPaceStateAfterLongBackgroundGap() {
        // 28분 = 1680초 → 540 x 3 = 1620 소비, 4번째 운동의 60초 지점
        let state = WorkoutClock.paceState(elapsed: 1680)
        XCTAssertEqual(state.lapIndex, 4)
        XCTAssertEqual(state.completedLaps, 3)
        XCTAssertEqual(state.lapElapsed, 60, accuracy: 0.001)
        XCTAssertEqual(state.setIndex, 1)
    }

    func testPaceStateHandlesNegativeElapsed() {
        let state = WorkoutClock.paceState(elapsed: -100)
        XCTAssertEqual(state.lapIndex, 1)
        XCTAssertEqual(state.lapElapsed, 0)
    }

    // MARK: - 랩 소급 기록

    func testCompletedLapsIsEmptyBeforeFirstTarget() {
        XCTAssertTrue(WorkoutClock.completedLaps(elapsed: 539).isEmpty)
    }

    func testCompletedLapsRetroactivelyFillsBackgroundGap() {
        let laps = WorkoutClock.completedLaps(elapsed: 1680)
        XCTAssertEqual(laps.count, 3)
        XCTAssertEqual(laps.map(\.index), [1, 2, 3])
        XCTAssertTrue(laps.allSatisfy { $0.duration == 540 })
    }

    func testCompletedLapsAtExactBoundary() {
        XCTAssertEqual(WorkoutClock.completedLaps(elapsed: 540).count, 1)
    }

    /// 랩이 아무리 돌아도 구간 누적은 줄지 않는다. 이 앱이 기본 시계 앱을
    /// 대체하는 이유가 정확히 이것이다.
    func testLapResetDoesNotShrinkSegmentDuration() {
        let segment = TrainingSegment(
            kind: .strength,
            startedAt: at(0),
            endedAt: at(1620),
            laps: WorkoutClock.completedLaps(elapsed: 1620)
        )
        XCTAssertEqual(segment.laps.count, 3)
        XCTAssertEqual(segment.duration(pauses: [], now: at(1620)), 1620, accuracy: 0.001)
    }
}
