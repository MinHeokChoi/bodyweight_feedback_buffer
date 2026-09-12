import Foundation
import Observation

/// 진행 중 세션 상태와 사용자 액션을 관리한다.
///
/// 이 Store는 **타이머를 돌리지 않는다.** 시간은 전부 `WorkoutClock`이
/// 저장된 시각으로부터 계산하고, 화면 갱신은 View가 알아서 한다.
/// 덕분에 탭을 벗어나거나 앱이 백그라운드로 가도 상태가 흐트러지지 않는다.
@MainActor
@Observable
final class WorkoutTimerStore {
    /// 진행 중인 세션. nil이면 대기 상태다.
    private(set) var activeSession: WorkoutSession?
    /// 완료된 세션. 최신이 앞이다.
    private(set) var sessions: [WorkoutSession] = []
    /// 앱을 다시 켰을 때 끝나지 않은 세션을 발견한 경우 true.
    /// 사용자가 이어서/종료/버리기를 고를 때까지 유지된다.
    private(set) var needsRecoveryDecision = false

    private let repository: WorkoutRepository
    private let persistenceScheduler: PersistenceScheduler
    private let reportIssue: (PersistenceIssue) -> Void

    init(
        repository: WorkoutRepository = WorkoutRepository(),
        persistenceScheduler: PersistenceScheduler = .background,
        reportIssue: @escaping (PersistenceIssue) -> Void = { _ in }
    ) {
        self.repository = repository
        self.persistenceScheduler = persistenceScheduler
        self.reportIssue = reportIssue
        bootstrap()
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        do {
            sessions = try repository.loadSessions().sorted { $0.startedAt > $1.startedAt }
        } catch {
            AppLog.persistence.error("workout sessions load failed: \(error.localizedDescription, privacy: .public)")
            reportPersistenceIssue(
                title: "운동 기록을 불러오지 못했습니다",
                error: error,
                recovery: "새 운동은 정상적으로 기록할 수 있어요."
            )
        }

        do {
            if let active = try repository.loadActiveSession(), active.isRunning {
                activeSession = active
                needsRecoveryDecision = true
            }
        } catch {
            AppLog.persistence.error("active workout load failed: \(error.localizedDescription, privacy: .public)")
            reportPersistenceIssue(
                title: "진행 중이던 운동을 불러오지 못했습니다",
                error: error,
                recovery: "새 운동을 시작할 수 있어요."
            )
        }
    }

    // MARK: - 파생 상태

    var isRunning: Bool { activeSession?.isRunning ?? false }
    var isPaused: Bool { activeSession?.isPaused ?? false }
    var isResting: Bool { activeSession?.isResting ?? false }
    var runningSegment: TrainingSegment? { activeSession?.runningSegment }
    var runningKind: TrainingPhaseKind? { runningSegment?.kind }

    /// 방금 끝낸 구간. 휴식 화면에서 "스트렝스 완료 27:00"을 보여주는 데 쓴다.
    var lastFinishedSegment: TrainingSegment? {
        activeSession?.segments
            .filter { !$0.isRunning }
            .max { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
    }

    /// 이번 세션에서 그 구간에 들인 시간의 합.
    ///
    /// 같은 구간을 여러 번 들어갔다면 전부 더한다. 기술 연습을 두 번 하면
    /// 마지막 블록이 아니라 두 번을 합친 시간이 그 구간에 들인 시간이다.
    func accumulatedDuration(for kind: TrainingPhaseKind, now: Date = .now) -> TimeInterval {
        guard let session = activeSession else { return 0 }
        return session.durationByKind(now: now)[kind] ?? 0
    }

    /// 이번 세션에서 그 구간을 몇 번 들어갔는지.
    func blockCount(for kind: TrainingPhaseKind) -> Int {
        activeSession?.segments.filter { $0.kind == kind }.count ?? 0
    }

    func accumulatedDuration(now: Date = .now) -> TimeInterval {
        activeSession?.activeDuration(now: now) ?? 0
    }

    func currentSegmentDuration(now: Date = .now) -> TimeInterval {
        guard let session = activeSession, let segment = session.runningSegment else { return 0 }
        return segment.duration(pauses: session.pauses, now: now)
    }

    func currentRestDuration(now: Date = .now) -> TimeInterval {
        guard let session = activeSession else { return 0 }
        return WorkoutClock.currentRestDuration(of: session, now: now) ?? 0
    }

    func paceState(now: Date = .now) -> WorkoutClock.PaceState? {
        guard let session = activeSession, let segment = session.runningSegment else { return nil }
        return WorkoutClock.paceState(for: segment, pauses: session.pauses, now: now)
    }

    func duration(of segment: TrainingSegment, now: Date = .now) -> TimeInterval {
        guard let session = activeSession else { return 0 }
        return segment.duration(pauses: session.pauses, now: now)
    }

    // MARK: - 구간 intents

    /// 구간을 시작한다. 세션이 없으면 이것이 곧 세션 시작이다.
    ///
    /// 이미 다른 구간이 돌고 있으면 그 구간을 먼저 끝낸다. 휴식 없이 바로
    /// 이어가는 경우다.
    func startSegment(_ kind: TrainingPhaseKind, now: Date = .now) {
        var session = activeSession ?? WorkoutSession(startedAt: now)
        if session.runningSegment != nil {
            closeRunningSegment(in: &session, at: now)
        }
        session.segments.append(
            TrainingSegment(kind: kind, startedAt: now, paceAnchoredAt: now)
        )
        commit(session)
    }

    /// 현재 구간을 끝낸다. 누적 타이머는 계속 돌고, 여기서부터 휴식이 된다.
    func endCurrentSegment(now: Date = .now) {
        guard var session = activeSession, session.runningSegment != nil else { return }
        closeRunningSegment(in: &session, at: now)
        commit(session)
    }

    /// 9분을 다 채우지 않고 다음 운동으로 넘긴다.
    ///
    /// 지금까지의 랩을 확정하고 랩 원점을 지금으로 옮긴다. 구간 누적과 세션
    /// 누적은 건드리지 않는다.
    func skipToNextLap(now: Date = .now) {
        guard var session = activeSession,
              let index = session.segments.firstIndex(where: \.isRunning),
              session.segments[index].kind.usesPaceTimer else { return }

        let segment = session.segments[index]
        let elapsed = WorkoutClock.elapsedSinceAnchor(of: segment, pauses: session.pauses, now: now)
        guard elapsed >= 1 else { return }

        session.segments[index].laps = WorkoutClock.materializedLaps(
            for: segment,
            pauses: session.pauses,
            now: now
        )
        session.segments[index].paceAnchoredAt = now
        commit(session)
    }

    private func closeRunningSegment(in session: inout WorkoutSession, at date: Date) {
        guard let index = session.segments.firstIndex(where: \.isRunning) else { return }
        let segment = session.segments[index]
        session.segments[index].laps = WorkoutClock.materializedLaps(
            for: segment,
            pauses: session.pauses,
            now: date
        )
        session.segments[index].endedAt = date
    }

    // MARK: - 일시정지

    /// 누적과 구간을 모두 멈춘다. 휴식과 달리 누적에서도 빠진다.
    func pause(now: Date = .now) {
        guard var session = activeSession, !session.isPaused else { return }
        session.pauses.append(PauseInterval(startedAt: now))
        commit(session)
    }

    func resume(now: Date = .now) {
        guard var session = activeSession,
              let index = session.pauses.firstIndex(where: \.isOpen) else { return }
        session.pauses[index].endedAt = now
        commit(session)
    }

    func togglePause(now: Date = .now) {
        isPaused ? resume(now: now) : pause(now: now)
    }

    // MARK: - 세션 종료

    /// 운동을 끝내고 기록으로 남긴다.
    @discardableResult
    func finishSession(now: Date = .now) -> WorkoutSession? {
        guard var session = activeSession else { return nil }
        closeRunningSegment(in: &session, at: now)
        if let index = session.pauses.firstIndex(where: \.isOpen) {
            session.pauses[index].endedAt = now
        }
        session.endedAt = now

        activeSession = nil
        needsRecoveryDecision = false
        clearStoredActiveSession()

        // 구간이 없거나 실제로 한 시간이 0인 세션은 기록으로서 의미가 없다.
        //
        // 특히 복구에서 "여기서 종료"를 골랐는데 마지막으로 확인된 활동이
        // 없으면 0분짜리가 되는데, 그대로 저장하면 통계의 "운동한 날"만
        // 하루 늘고 운동 시간은 0인 유령 기록이 남는다.
        guard !session.segments.isEmpty,
              session.trainingDuration(now: now) >= 1 else { return nil }

        sessions.insert(session, at: 0)
        sessions.sort { $0.startedAt > $1.startedAt }
        persistSessions()
        return session
    }

    /// 잘못 시작한 세션을 기록에 남기지 않고 버린다.
    func discardActiveSession() {
        activeSession = nil
        needsRecoveryDecision = false
        clearStoredActiveSession()
    }

    func deleteSession(_ id: UUID) {
        let before = sessions.count
        sessions.removeAll { $0.id == id }
        guard sessions.count != before else { return }
        persistSessions()
    }

    // MARK: - 복구

    /// 끊긴 세션을 그대로 이어서 쓴다.
    func resumeRecoveredSession() {
        needsRecoveryDecision = false
    }

    /// 끊긴 세션을 마지막으로 확인된 시점에 끝낸 것으로 처리한다.
    ///
    /// 지금 시각으로 끝내면 앱을 이틀 뒤에 열었을 때 이틀짜리 세션이 남는다.
    /// 그래서 마지막 구간 종료 시각을 끝으로 삼고, 그것도 없으면 세션 시작
    /// 시각으로 끝내 0분짜리로 만든다.
    @discardableResult
    func finishRecoveredSessionAtLastKnownActivity() -> WorkoutSession? {
        guard let session = activeSession else { return nil }
        let lastKnown = session.segments
            .compactMap { $0.endedAt ?? ($0.isRunning ? nil : $0.startedAt) }
            .max() ?? session.startedAt
        needsRecoveryDecision = false
        return finishSession(now: lastKnown)
    }

    // MARK: - 저장

    private func commit(_ session: WorkoutSession) {
        activeSession = session
        // 진행 중 세션은 작은 파일이고 구간 전환·랩·일시정지에서만 바뀐다.
        // 강제 종료돼도 살아남아야 하므로 미루지 않고 바로 쓴다.
        do {
            try repository.saveActiveSession(session)
        } catch {
            AppLog.persistence.error("active workout save failed: \(error.localizedDescription, privacy: .public)")
            reportPersistenceIssue(
                title: "진행 중인 운동을 저장하지 못했습니다",
                error: error,
                recovery: "타이머는 계속 동작해요. 앱을 종료하면 이 세션이 사라질 수 있어요."
            )
        }
    }

    private func clearStoredActiveSession() {
        do {
            try repository.clearActiveSession()
        } catch {
            AppLog.persistence.error("active workout clear failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistSessions() {
        let snapshot = sessions
        let repository = repository
        persistenceScheduler.perform { [weak self] in
            do {
                try repository.saveSessions(snapshot)
            } catch {
                AppLog.persistence.error("workout sessions save failed: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    self?.reportPersistenceIssue(
                        title: "운동 기록을 저장하지 못했습니다",
                        error: error,
                        recovery: "앱을 종료하기 전에 저장 공간과 파일 권한을 확인해 주세요."
                    )
                }
            }
        }
    }

    private func reportPersistenceIssue(title: String, error: Error, recovery: String) {
        reportIssue(
            PersistenceIssue(
                title: title,
                message: "\(recovery)\n\n원인: \(error.localizedDescription)"
            )
        )
    }
}
