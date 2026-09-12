import XCTest
@testable import FeedbackBuffer

@MainActor
final class WorkoutTimerStoreTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func makeStore(
        fileStore: FileStore = InMemoryFileStore()
    ) -> WorkoutTimerStore {
        WorkoutTimerStore(
            repository: WorkoutRepository(store: fileStore),
            persistenceScheduler: .immediate
        )
    }

    // MARK: - 세션 시작

    func testStartingSegmentStartsSession() {
        let store = makeStore()
        XCTAssertFalse(store.isRunning)

        store.startSegment(.warmup, now: at(0))

        XCTAssertTrue(store.isRunning)
        XCTAssertEqual(store.runningKind, .warmup)
        XCTAssertEqual(store.activeSession?.startedAt, at(0))
    }

    func testEndingSegmentKeepsSessionRunningAndStartsRest() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))

        store.endCurrentSegment(now: at(600))

        XCTAssertTrue(store.isRunning, "구간을 끝내도 누적 타이머는 계속 돈다")
        XCTAssertTrue(store.isResting)
        XCTAssertNil(store.runningSegment)
        XCTAssertEqual(store.currentRestDuration(now: at(700)), 100, accuracy: 0.001)
    }

    func testStartingAnotherSegmentClosesPreviousOne() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))

        store.startSegment(.strength, now: at(600))

        XCTAssertEqual(store.runningKind, .strength)
        XCTAssertEqual(store.activeSession?.segments.count, 2)
        XCTAssertEqual(store.activeSession?.segments[0].endedAt, at(600))
        XCTAssertEqual(store.currentRestDuration(now: at(600)), 0, "휴식 없이 바로 이어간 경우")
    }

    func testAccumulatedKeepsRunningThroughRest() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))
        store.endCurrentSegment(now: at(600))

        XCTAssertEqual(store.accumulatedDuration(now: at(900)), 900, accuracy: 0.001)
    }

    // MARK: - 페이스 타이머

    func testPaceStateOnlyForStrength() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))
        XCTAssertNil(store.paceState(now: at(600)), "웜업은 페이스 타이머를 쓰지 않는다")

        store.startSegment(.strength, now: at(600))
        XCTAssertNotNil(store.paceState(now: at(700)))
    }

    func testPaceAdvancesAutomaticallyWithoutInteraction() {
        let store = makeStore()
        store.startSegment(.strength, now: at(0))

        // 손을 대지 않아도 28분 뒤에는 4번째 운동이어야 한다
        let state = store.paceState(now: at(1680))
        XCTAssertEqual(state?.lapIndex, 4)
        XCTAssertEqual(state?.lapElapsed ?? -1, 60, accuracy: 0.001)
    }

    func testSkipToNextLapRecordsPartialLapAndResetsAnchor() {
        let store = makeStore()
        store.startSegment(.strength, now: at(0))

        store.skipToNextLap(now: at(252))

        XCTAssertEqual(store.activeSession?.segments[0].laps.count, 1)
        XCTAssertEqual(store.activeSession?.segments[0].laps[0].duration ?? 0, 252, accuracy: 0.001)

        let state = store.paceState(now: at(252))
        XCTAssertEqual(state?.lapIndex, 2, "수동으로 넘긴 뒤에는 2번째 운동")
        XCTAssertEqual(state?.lapElapsed ?? -1, 0, accuracy: 0.001)
    }

    func testSkipDoesNotShrinkSegmentOrSessionTotals() {
        let store = makeStore()
        store.startSegment(.strength, now: at(0))
        store.skipToNextLap(now: at(252))
        store.skipToNextLap(now: at(500))

        XCTAssertEqual(store.currentSegmentDuration(now: at(500)), 500, accuracy: 0.001)
        XCTAssertEqual(store.accumulatedDuration(now: at(500)), 500, accuracy: 0.001)
    }

    func testSkipIsIgnoredForNonPaceSegment() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))

        store.skipToNextLap(now: at(300))

        XCTAssertTrue(store.activeSession?.segments[0].laps.isEmpty ?? false)
    }

    // MARK: - 일시정지

    func testPauseStopsBothClocks() {
        let store = makeStore()
        store.startSegment(.strength, now: at(0))
        store.pause(now: at(100))

        XCTAssertTrue(store.isPaused)
        // 300초 시점에 조회해도 100초에서 멈춰 있어야 한다
        XCTAssertEqual(store.accumulatedDuration(now: at(300)), 100, accuracy: 0.001)
        XCTAssertEqual(store.currentSegmentDuration(now: at(300)), 100, accuracy: 0.001)
    }

    func testResumeContinuesFromWhereItStopped() {
        let store = makeStore()
        store.startSegment(.strength, now: at(0))
        store.pause(now: at(100))
        store.resume(now: at(300))

        XCTAssertFalse(store.isPaused)
        XCTAssertEqual(store.accumulatedDuration(now: at(400)), 200, accuracy: 0.001)
    }

    func testPauseIsIgnoredWhenAlreadyPaused() {
        let store = makeStore()
        store.startSegment(.strength, now: at(0))
        store.pause(now: at(100))
        store.pause(now: at(150))

        XCTAssertEqual(store.activeSession?.pauses.count, 1)
    }

    // MARK: - 종료

    func testFinishSessionMovesItToRecords() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))
        store.endCurrentSegment(now: at(600))
        store.startSegment(.strength, now: at(900))

        let finished = store.finishSession(now: at(2400))

        XCTAssertNotNil(finished)
        XCTAssertNil(store.activeSession)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions[0].endedAt, at(2400))
        XCTAssertEqual(store.sessions[0].segments.last?.endedAt, at(2400), "열린 구간도 함께 닫힌다")
    }

    func testFinishSessionClosesOpenPause() {
        let store = makeStore()
        store.startSegment(.strength, now: at(0))
        store.pause(now: at(100))

        store.finishSession(now: at(500))

        XCTAssertEqual(store.sessions[0].pauses[0].endedAt, at(500))
        XCTAssertFalse(store.sessions[0].isPaused)
    }

    func testFinishSessionWithoutSegmentsIsNotRecorded() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))
        store.discardActiveSession()

        XCTAssertNil(store.activeSession)
        XCTAssertTrue(store.sessions.isEmpty)
    }

    func testFinishedSessionKeepsRestAndTrainingSplit() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))
        store.endCurrentSegment(now: at(600))
        store.startSegment(.strength, now: at(900))
        store.finishSession(now: at(1800))

        let session = store.sessions[0]
        XCTAssertEqual(session.trainingDuration(now: at(1800)), 1500, accuracy: 0.001)
        XCTAssertEqual(session.restDuration(now: at(1800)), 300, accuracy: 0.001)
    }

    func testDeleteSessionRemovesIt() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))
        store.finishSession(now: at(600))
        let id = store.sessions[0].id

        store.deleteSession(id)

        XCTAssertTrue(store.sessions.isEmpty)
    }

    // MARK: - 복구

    func testActiveSessionSurvivesRelaunch() {
        let fileStore = InMemoryFileStore()
        let first = makeStore(fileStore: fileStore)
        first.startSegment(.strength, now: at(0))

        let second = makeStore(fileStore: fileStore)

        XCTAssertTrue(second.isRunning)
        XCTAssertEqual(second.runningKind, .strength)
        XCTAssertTrue(second.needsRecoveryDecision)
        // 앱이 꺼져 있던 동안에도 시간은 흘러가 있어야 한다
        XCTAssertEqual(second.currentSegmentDuration(now: at(1200)), 1200, accuracy: 0.001)
    }

    func testResumeRecoveredSessionClearsPrompt() {
        let fileStore = InMemoryFileStore()
        makeStore(fileStore: fileStore).startSegment(.strength, now: at(0))
        let store = makeStore(fileStore: fileStore)

        store.resumeRecoveredSession()

        XCTAssertFalse(store.needsRecoveryDecision)
        XCTAssertTrue(store.isRunning)
    }

    /// 이틀 뒤에 앱을 열어도 이틀짜리 세션이 남으면 안 된다.
    func testFinishRecoveredSessionUsesLastKnownActivity() {
        let fileStore = InMemoryFileStore()
        let first = makeStore(fileStore: fileStore)
        first.startSegment(.warmup, now: at(0))
        first.endCurrentSegment(now: at(600))

        let store = makeStore(fileStore: fileStore)
        store.finishRecoveredSessionAtLastKnownActivity()

        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.sessions[0].endedAt, at(600), "마지막 구간 종료 시각으로 끝낸다")
        XCTAssertFalse(store.needsRecoveryDecision)
    }

    func testDiscardRecoveredSessionLeavesNoRecord() {
        let fileStore = InMemoryFileStore()
        makeStore(fileStore: fileStore).startSegment(.strength, now: at(0))
        let store = makeStore(fileStore: fileStore)

        store.discardActiveSession()

        XCTAssertNil(store.activeSession)
        XCTAssertTrue(store.sessions.isEmpty)
        // 다시 켜도 되살아나지 않아야 한다
        XCTAssertFalse(makeStore(fileStore: fileStore).isRunning)
    }

    func testFinishedSessionsPersistAcrossRelaunch() {
        let fileStore = InMemoryFileStore()
        let first = makeStore(fileStore: fileStore)
        first.startSegment(.warmup, now: at(0))
        first.finishSession(now: at(600))

        let second = makeStore(fileStore: fileStore)

        XCTAssertEqual(second.sessions.count, 1)
        XCTAssertFalse(second.isRunning)
    }

    func testLastFinishedSegmentIsTheMostRecentlyClosed() {
        let store = makeStore()
        store.startSegment(.warmup, now: at(0))
        store.endCurrentSegment(now: at(600))
        store.startSegment(.strength, now: at(900))
        store.endCurrentSegment(now: at(1800))

        XCTAssertEqual(store.lastFinishedSegment?.kind, .strength)
        XCTAssertEqual(store.duration(of: store.lastFinishedSegment!, now: at(1800)), 900, accuracy: 0.001)
    }
}
