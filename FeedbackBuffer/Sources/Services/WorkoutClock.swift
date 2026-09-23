import Foundation

/// 세션 시간 계산. UI와 완전히 분리된 순수 로직이다.
///
/// 원칙 하나로 요약된다. **틱을 누적하지 않는다.** 모든 경과 시간은
/// 저장된 시각(`startedAt`, `endedAt`, 일시정지 구간)과 기준 시각 `now`로
/// 매번 다시 계산한다. 그래서 앱이 백그라운드로 가도, 강제 종료돼도,
/// 기기를 재부팅해도 시간이 어긋나지 않는다.
///
/// 화면 갱신용 타이머는 이 계산을 다시 부르기 위한 트리거일 뿐이며,
/// 그 자체로는 아무 상태도 들고 있지 않다.
enum WorkoutClock {

    // MARK: - 겹침 계산

    /// `[start, end)`와 일시정지 구간들이 겹치는 총 시간.
    ///
    /// 일시정지가 구간 경계를 걸쳐 있어도 그 구간에 실제로 걸린 부분만 센다.
    static func pausedDuration(
        in pauses: [PauseInterval],
        between start: Date,
        and end: Date
    ) -> TimeInterval {
        guard end > start else { return 0 }
        return pauses.reduce(0) { total, pause in
            let pauseEnd = pause.endedAt ?? end
            let overlapStart = max(pause.startedAt, start)
            let overlapEnd = min(pauseEnd, end)
            return total + max(0, overlapEnd.timeIntervalSince(overlapStart))
        }
    }

    // MARK: - 구간

    /// 한 구간의 순수 진행 시간. 일시정지로 멈춰 있던 시간은 뺀다.
    static func duration(
        of segment: TrainingSegment,
        pauses: [PauseInterval],
        now: Date
    ) -> TimeInterval {
        let end = segment.endedAt ?? now
        // 기기 시간이 뒤로 당겨진 경우에도 음수가 나오지 않게 막는다.
        let raw = max(0, end.timeIntervalSince(segment.startedAt))
        let paused = pausedDuration(in: pauses, between: segment.startedAt, and: end)
        return max(0, raw - paused)
    }

    // MARK: - 세션

    /// 세션 총 시간. 일시정지를 포함한 벽시계 기준 체류 시간이다.
    static func totalDuration(of session: WorkoutSession, now: Date) -> TimeInterval {
        let end = session.endedAt ?? now
        return max(0, end.timeIntervalSince(session.startedAt))
    }

    /// 누적 타이머가 보여주는 값. 일시정지를 뺀 순수 시간이다.
    static func activeDuration(of session: WorkoutSession, now: Date) -> TimeInterval {
        let end = session.endedAt ?? now
        let paused = pausedDuration(in: session.pauses, between: session.startedAt, and: end)
        return max(0, totalDuration(of: session, now: now) - paused)
    }

    /// 모든 구간 시간의 합. 통계의 "총 운동 시간"이 이 값이다.
    static func trainingDuration(of session: WorkoutSession, now: Date) -> TimeInterval {
        session.segments.reduce(0) { total, segment in
            total + duration(of: segment, pauses: session.pauses, now: now)
        }
    }

    /// 휴식. 구간 타이머가 꺼져 있고 누적만 돌던 시간이며 저장하지 않는다.
    ///
    /// 구간들이 겹치지 않는다는 전제(활성 구간은 항상 최대 하나)에서
    /// `순수 시간 - 구간 시간 합`으로 구한다.
    static func restDuration(of session: WorkoutSession, now: Date) -> TimeInterval {
        max(0, activeDuration(of: session, now: now) - trainingDuration(of: session, now: now))
    }

    /// 지금 이어지고 있는 휴식의 경과 시간. 휴식 중이 아니면 nil.
    ///
    /// 마지막으로 끝난 구간의 종료 시각부터 잰다. 아직 아무 구간도 하지
    /// 않았다면 세션 시작부터 잰다.
    static func currentRestDuration(of session: WorkoutSession, now: Date) -> TimeInterval? {
        guard session.isResting else { return nil }
        let lastEnd = session.segments.compactMap(\.endedAt).max() ?? session.startedAt
        let raw = max(0, now.timeIntervalSince(lastEnd))
        let paused = pausedDuration(in: session.pauses, between: lastEnd, and: now)
        return max(0, raw - paused)
    }

    // MARK: - 페이스 타이머

    /// 진행 중인 구간의 페이스 타이머 상태.
    ///
    /// 랩은 저장된 목록에 없더라도 **경과 시간으로부터 유도된다.** 백그라운드에
    /// 20분 있다 돌아와도 지나간 랩이 그대로 반영되는 이유가 이것이다.
    struct PaceState: Equatable {
        /// 몇 번째 운동인가. 1부터.
        let lapIndex: Int
        /// 현재 랩 안에서의 경과 시간
        let lapElapsed: TimeInterval
        /// 현재 랩의 목표 시간
        let lapTarget: TimeInterval
        /// 현재 세트 번호. 1부터 `setsPerLap`까지.
        let setIndex: Int
        /// 현재 세트 안에서의 경과 시간
        let setElapsed: TimeInterval
        let setsPerLap: Int

        var lapRemaining: TimeInterval { max(0, lapTarget - lapElapsed) }
        /// 완료된 랩 수. 화면의 "3번째 운동"은 lapIndex를 그대로 쓴다.
        var completedLaps: Int { lapIndex - 1 }
    }

    /// 구간 경과 시간으로부터 페이스 상태를 유도한다.
    ///
    /// - Parameter elapsed: `duration(of:pauses:now:)`로 구한 구간 순수 시간
    static func paceState(
        elapsed: TimeInterval,
        lapTarget: TimeInterval = PaceTimer.defaultLapDuration,
        setDuration: TimeInterval = PaceTimer.defaultSetDuration,
        setsPerLap: Int = PaceTimer.defaultSetsPerLap
    ) -> PaceState {
        let safeElapsed = max(0, elapsed)
        let safeTarget = max(1, lapTarget)
        let safeSet = max(1, setDuration)
        let safeSets = max(1, setsPerLap)

        let completed = Int(safeElapsed / safeTarget)
        let lapElapsed = safeElapsed - Double(completed) * safeTarget

        // 세트는 랩 안에서만 센다. 세트 길이 x 세트 수가 랩 길이와 달라도
        // 세트 번호가 범위를 벗어나지 않도록 자른다.
        let setIndex = min(safeSets, Int(lapElapsed / safeSet) + 1)
        let setElapsed = lapElapsed - Double(setIndex - 1) * safeSet

        return PaceState(
            lapIndex: completed + 1,
            lapElapsed: lapElapsed,
            lapTarget: safeTarget,
            setIndex: setIndex,
            setElapsed: max(0, setElapsed),
            setsPerLap: safeSets
        )
    }

    /// 진행 중인 구간의 페이스 상태. 페이스 타이머를 쓰지 않는 구간이면 nil.
    ///
    /// 랩 번호는 이미 확정된 `segment.laps`에 이어서 센다. 그래서 수동으로
    /// 일찍 넘긴 랩과 자동으로 넘어간 랩이 같은 번호 체계를 쓴다.
    static func paceState(
        for segment: TrainingSegment,
        pauses: [PauseInterval],
        now: Date,
        lapTarget: TimeInterval = PaceTimer.defaultLapDuration
    ) -> PaceState? {
        guard segment.kind.usesPaceTimer else { return nil }
        let elapsed = elapsedSinceAnchor(of: segment, pauses: pauses, now: now)
        let base = paceState(elapsed: elapsed, lapTarget: lapTarget)
        return PaceState(
            lapIndex: base.lapIndex + segment.laps.count,
            lapElapsed: base.lapElapsed,
            lapTarget: base.lapTarget,
            setIndex: base.setIndex,
            setElapsed: base.setElapsed,
            setsPerLap: base.setsPerLap
        )
    }

    // MARK: - 경계 신호

    enum PaceSignal: Equatable {
        /// 3분 세트 경계 — 짧게 1회
        case set
        /// 9분 운동 경계 — 짧게 3회
        case lap
    }

    /// 경계를 넘은 뒤 이 시간 안에 알게 됐을 때만 신호를 낸다.
    ///
    /// 화면은 보일 때만 갱신된다. 다른 탭이나 백그라운드에 있다가 돌아오면 이미 지난
    /// 경계를 뒤늦게 알게 되는데, 그때 울리면 "지금 바뀌었다"는 잘못된 신호가 된다.
    static let boundarySignalWindow: TimeInterval = 3

    /// 직전에 그린 상태와 지금 상태 사이에서 낼 경계 신호.
    ///
    /// 이전 값을 뷰가 따로 들고 있지 않고 두 상태만 비교한다. 따로 들고 있으면
    /// 처음에는 비어 있어 첫 경계를 놓치고, 앞 블록의 값이 남아 다음 블록 경계를 놓쳤다.
    ///
    /// - Parameter skippedToLap: "지금 바로 다음 운동으로"로 넘어간 운동 번호.
    ///   직접 누른 것이라 누름 확인 진동만 내고 운동 경계 신호는 겹쳐 내지 않는다.
    static func boundarySignal(
        from old: PaceState?,
        to new: PaceState?,
        skippedToLap: Int? = nil
    ) -> PaceSignal? {
        guard let old, let new else { return nil }
        let setIsFresh = new.setElapsed < boundarySignalWindow
        if new.lapIndex > old.lapIndex {
            if new.lapIndex == skippedToLap { return nil }
            // 랩이 넘어가면 세트 번호는 3에서 1로 줄어든다. 운동 경계 신호만 낸다.
            if new.lapElapsed < boundarySignalWindow { return .lap }
            // 운동 경계는 오래전에 지났어도 방금 넘은 세트 경계는 알린다.
            return new.setIndex > 1 && setIsFresh ? .set : nil
        }
        if new.lapIndex == old.lapIndex, new.setIndex > old.setIndex {
            return setIsFresh ? .set : nil
        }
        return nil
    }

    /// 현재 랩 원점부터 지금까지의 순수 경과 시간.
    static func elapsedSinceAnchor(
        of segment: TrainingSegment,
        pauses: [PauseInterval],
        now: Date
    ) -> TimeInterval {
        let end = segment.endedAt ?? now
        let origin = segment.paceOrigin
        let raw = max(0, end.timeIntervalSince(origin))
        let paused = pausedDuration(in: pauses, between: origin, and: end)
        return max(0, raw - paused)
    }

    /// 구간을 끝낼 때 확정할 랩 목록.
    ///
    /// 이미 확정된 랩 뒤에, 앵커 이후 자동으로 넘어간 랩들을 붙이고,
    /// 마지막에 남은 자투리를 부분 랩으로 더한다. 9분을 다 못 채우고 끝낸
    /// 마지막 운동도 기록에 남아야 하기 때문이다.
    static func materializedLaps(
        for segment: TrainingSegment,
        pauses: [PauseInterval],
        now: Date,
        lapTarget: TimeInterval = PaceTimer.defaultLapDuration
    ) -> [TrainingLap] {
        guard segment.kind.usesPaceTimer else { return segment.laps }
        let safeTarget = max(1, lapTarget)
        let elapsed = elapsedSinceAnchor(of: segment, pauses: pauses, now: now)
        var laps = segment.laps

        let fullCount = Int(elapsed / safeTarget)
        for _ in 0..<fullCount {
            laps.append(
                TrainingLap(index: laps.count + 1, duration: safeTarget, targetDuration: safeTarget)
            )
        }

        let remainder = elapsed - Double(fullCount) * safeTarget
        if remainder >= 1 {
            laps.append(
                TrainingLap(index: laps.count + 1, duration: remainder, targetDuration: safeTarget)
            )
        }
        return laps
    }

    /// 경과 시간으로부터 완료된 랩 목록을 만든다.
    ///
    /// 자동 전환은 사용자가 화면을 보고 있지 않아도 일어나야 한다. 백그라운드
    /// 복귀 시 이 함수로 지나간 랩을 소급해서 채운다.
    static func completedLaps(
        elapsed: TimeInterval,
        lapTarget: TimeInterval = PaceTimer.defaultLapDuration
    ) -> [TrainingLap] {
        let safeTarget = max(1, lapTarget)
        let count = Int(max(0, elapsed) / safeTarget)
        guard count > 0 else { return [] }
        return (1...count).map { index in
            TrainingLap(index: index, duration: safeTarget, targetDuration: safeTarget)
        }
    }
}

// MARK: - 편의 접근자

extension WorkoutSession {
    func totalDuration(now: Date = .now) -> TimeInterval {
        WorkoutClock.totalDuration(of: self, now: now)
    }

    func activeDuration(now: Date = .now) -> TimeInterval {
        WorkoutClock.activeDuration(of: self, now: now)
    }

    func trainingDuration(now: Date = .now) -> TimeInterval {
        WorkoutClock.trainingDuration(of: self, now: now)
    }

    func restDuration(now: Date = .now) -> TimeInterval {
        WorkoutClock.restDuration(of: self, now: now)
    }

    /// 구간 종류별 누적 시간. 같은 구간에 여러 번 들어갔으면 합산된다.
    func durationByKind(now: Date = .now) -> [TrainingPhaseKind: TimeInterval] {
        segments.reduce(into: [:]) { result, segment in
            result[segment.kind, default: 0] += WorkoutClock.duration(
                of: segment,
                pauses: pauses,
                now: now
            )
        }
    }
}

extension TrainingSegment {
    func duration(pauses: [PauseInterval], now: Date = .now) -> TimeInterval {
        WorkoutClock.duration(of: self, pauses: pauses, now: now)
    }
}
