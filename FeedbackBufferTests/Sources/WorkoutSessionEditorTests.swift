import XCTest
@testable import FeedbackBuffer

final class WorkoutSessionEditorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 0) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: .current,
            year: y, month: m, day: d, hour: h, minute: min
        ).date!
    }

    private func block(_ kind: TrainingPhaseKind, minutes: Double) -> WorkoutSessionEditor.Block {
        WorkoutSessionEditor.Block(kind: kind, duration: minutes * 60)
    }

    // MARK: - 수동 기록 만들기

    func test_manualSessionLaysBlocksBackToBack() {
        let session = WorkoutSessionEditor.makeManualSession(
            date: date(2026, 9, 10),
            blocks: [block(.stretching, minutes: 10), block(.skillPractice, minutes: 20)],
            calendar: calendar
        )!

        XCTAssertEqual(session.source, .manual)
        XCTAssertEqual(session.segments.count, 2)
        XCTAssertEqual(session.trainingDuration(), 30 * 60, accuracy: 0.5)
        // 사후 입력에는 구간 사이의 간격이라는 사실이 없다. 지어내지 않는다.
        XCTAssertEqual(session.restDuration(), 0, accuracy: 0.5)
        XCTAssertEqual(session.segments[0].endedAt, session.segments[1].startedAt)
    }

    func test_manualSessionLandsOnTheChosenDay() {
        let day = date(2026, 9, 10)
        let session = WorkoutSessionEditor.makeManualSession(
            date: day,
            blocks: [block(.warmup, minutes: 15)],
            calendar: calendar
        )!

        XCTAssertEqual(
            calendar.startOfDay(for: session.startedAt),
            calendar.startOfDay(for: day)
        )
    }

    func test_manualSessionDropsEmptyBlocks() {
        let session = WorkoutSessionEditor.makeManualSession(
            date: date(2026, 9, 10),
            blocks: [block(.warmup, minutes: 0), block(.strength, minutes: 18)],
            calendar: calendar
        )!

        XCTAssertEqual(session.segments.count, 1)
        XCTAssertEqual(session.segments[0].kind, .strength)
    }

    func test_manualSessionWithoutUsableBlocksIsNil() {
        XCTAssertNil(WorkoutSessionEditor.makeManualSession(
            date: date(2026, 9, 10),
            blocks: [block(.warmup, minutes: 0)],
            calendar: calendar
        ))
    }

    func test_manualStrengthGetsLapsFromDuration() {
        let session = WorkoutSessionEditor.makeManualSession(
            date: date(2026, 9, 10),
            blocks: [block(.strength, minutes: 27)],
            calendar: calendar
        )!

        // 27분 = 9분 × 3랩. 랩은 입력하지 않고 길이에서 유도한다.
        XCTAssertEqual(session.segments[0].laps.count, 3)
        XCTAssertEqual(session.segments[0].laps.map(\.index), [1, 2, 3])
    }

    func test_nonPaceKindsHaveNoLaps() {
        let laps = WorkoutSessionEditor.derivedLaps(kind: .stretching, duration: 27 * 60)
        XCTAssertTrue(laps.isEmpty)
    }

    func test_remainderBecomesLastLap() {
        let laps = WorkoutSessionEditor.derivedLaps(kind: .strength, duration: 23 * 60)
        XCTAssertEqual(laps.count, 3)
        XCTAssertEqual(laps[2].duration, 5 * 60, accuracy: 0.5)
    }

    // MARK: - 기존 기록 고치기

    /// 웜업 20분 → 휴식 10분 → 스트렝스 30분
    private func timerSession() -> WorkoutSession {
        let start = date(2026, 9, 11, 9, 0)
        let warmup = TrainingSegment(
            kind: .warmup,
            startedAt: start,
            endedAt: start.addingTimeInterval(20 * 60)
        )
        let strengthStart = start.addingTimeInterval(30 * 60)
        let strength = TrainingSegment(
            kind: .strength,
            startedAt: strengthStart,
            endedAt: strengthStart.addingTimeInterval(30 * 60),
            laps: WorkoutSessionEditor.derivedLaps(kind: .strength, duration: 30 * 60)
        )
        return WorkoutSession(
            startedAt: start,
            endedAt: strengthStart.addingTimeInterval(30 * 60),
            segments: [warmup, strength]
        )
    }

    func test_blocksRoundTripUnchanged() {
        let session = timerSession()
        let blocks = WorkoutSessionEditor.blocks(of: session)

        XCTAssertEqual(blocks.map(\.kind), [.warmup, .strength])
        XCTAssertEqual(blocks[0].duration, 20 * 60, accuracy: 0.5)
        XCTAssertEqual(blocks[1].duration, 30 * 60, accuracy: 0.5)

        let applied = WorkoutSessionEditor.apply(blocks, to: session)!
        XCTAssertEqual(applied.trainingDuration(), session.trainingDuration(), accuracy: 0.5)
        XCTAssertEqual(applied.restDuration(), session.restDuration(), accuracy: 0.5)
    }

    func test_extendingPushesLaterSegmentsAndKeepsRest() {
        let session = timerSession()
        var blocks = WorkoutSessionEditor.blocks(of: session)
        blocks[0].duration = 45 * 60  // 웜업 20 → 45분

        let applied = WorkoutSessionEditor.apply(blocks, to: session)!

        XCTAssertEqual(applied.trainingDuration(), 75 * 60, accuracy: 0.5)
        // 다음 구간을 침범하지 않고 통째로 밀린다. 휴식 10분은 그대로다.
        XCTAssertEqual(applied.restDuration(), 10 * 60, accuracy: 0.5)
        let byKind = applied.durationByKind()
        XCTAssertEqual(byKind[.strength] ?? 0, 30 * 60, accuracy: 0.5)
    }

    func test_shrinkingKeepsRest() {
        let session = timerSession()
        var blocks = WorkoutSessionEditor.blocks(of: session)
        blocks[1].duration = 9 * 60

        let applied = WorkoutSessionEditor.apply(blocks, to: session)!

        XCTAssertEqual(applied.trainingDuration(), 29 * 60, accuracy: 0.5)
        XCTAssertEqual(applied.restDuration(), 10 * 60, accuracy: 0.5)
    }

    func test_changedStrengthRecalculatesLaps() {
        let session = timerSession()
        XCTAssertEqual(session.segments[1].laps.count, 4) // 30분 = 9+9+9+3

        var blocks = WorkoutSessionEditor.blocks(of: session)
        blocks[1].duration = 18 * 60

        let applied = WorkoutSessionEditor.apply(blocks, to: session)!
        let strength = applied.segments.first { $0.kind == .strength }!

        // 18분짜리 구간에 30분어치 랩이 남아 있으면 합이 맞지 않는다.
        XCTAssertEqual(strength.laps.count, 2)
        XCTAssertEqual(strength.laps.reduce(0) { $0 + $1.duration }, 18 * 60, accuracy: 0.5)
    }

    func test_untouchedSegmentKeepsItsOwnLaps() {
        var session = timerSession()
        // 손으로 넘겨서 불규칙해진 랩. 그날 실제로 그렇게 한 기록이다.
        session.segments[1].laps = [
            TrainingLap(index: 1, duration: 4 * 60),
            TrainingLap(index: 2, duration: 9 * 60),
            TrainingLap(index: 3, duration: 17 * 60)
        ]

        var blocks = WorkoutSessionEditor.blocks(of: session)
        blocks[0].duration = 25 * 60  // 웜업만 고친다

        let applied = WorkoutSessionEditor.apply(blocks, to: session)!
        let strength = applied.segments.first { $0.kind == .strength }!

        XCTAssertEqual(strength.laps.count, 3)
        XCTAssertEqual(strength.laps[0].duration, 4 * 60, accuracy: 0.5)
    }

    func test_addedBlockIsAppendedWithoutRest() {
        let session = timerSession()
        var blocks = WorkoutSessionEditor.blocks(of: session)
        blocks.append(block(.stretching, minutes: 10))

        let applied = WorkoutSessionEditor.apply(blocks, to: session)!

        XCTAssertEqual(applied.segments.count, 3)
        XCTAssertEqual(applied.trainingDuration(), 60 * 60, accuracy: 0.5)
        XCTAssertEqual(applied.restDuration(), 10 * 60, accuracy: 0.5)
    }

    func test_deletingBlockRemovesItsTime() {
        let session = timerSession()
        var blocks = WorkoutSessionEditor.blocks(of: session)
        blocks.removeLast()

        let applied = WorkoutSessionEditor.apply(blocks, to: session)!

        XCTAssertEqual(applied.segments.count, 1)
        XCTAssertEqual(applied.trainingDuration(), 20 * 60, accuracy: 0.5)
    }

    func test_applyWithNoUsableBlocksIsNil() {
        let session = timerSession()
        XCTAssertNil(WorkoutSessionEditor.apply([], to: session))
    }

    func test_editKeepsSourceAndId() {
        let session = timerSession()
        var blocks = WorkoutSessionEditor.blocks(of: session)
        blocks[0].duration = 21 * 60

        let applied = WorkoutSessionEditor.apply(blocks, to: session)!

        XCTAssertEqual(applied.id, session.id)
        // 타이머로 시작한 것은 사실이므로 출처는 바뀌지 않는다.
        XCTAssertEqual(applied.source, .timer)
    }

    func test_pausesAreDroppedSoDurationsMatchWhatWasTyped() {
        var session = timerSession()
        let pauseStart = session.startedAt.addingTimeInterval(5 * 60)
        session.pauses = [PauseInterval(startedAt: pauseStart, endedAt: pauseStart.addingTimeInterval(3 * 60))]

        var blocks = WorkoutSessionEditor.blocks(of: session)
        // 일시정지 3분이 빠져 웜업은 17분으로 보인다
        XCTAssertEqual(blocks[0].duration, 17 * 60, accuracy: 0.5)

        blocks[0].duration = 20 * 60
        let applied = WorkoutSessionEditor.apply(blocks, to: session)!

        XCTAssertTrue(applied.pauses.isEmpty)
        // 입력한 20분이 그대로 20분으로 보여야 한다
        XCTAssertEqual(applied.durationByKind()[.warmup] ?? 0, 20 * 60, accuracy: 0.5)
    }

    // MARK: - 호환

    func test_oldRecordsWithoutSourceDecodeAsTimer() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "startedAt": "2026-09-11T09:00:00Z",
          "segments": [],
          "pauses": [],
          "note": ""
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let session = try decoder.decode(WorkoutSession.self, from: json)

        XCTAssertEqual(session.source, .timer)
    }
}
