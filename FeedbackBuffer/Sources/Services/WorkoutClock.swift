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
