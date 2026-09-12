import Foundation

/// 운동 세션 기록 저장소.
///
/// 완료된 세션과 진행 중인 세션을 파일을 나눠 보관한다. 진행 중 세션은
/// 상태가 바뀔 때마다(구간 전환·랩·일시정지) 즉시 저장해야 하므로,
/// 전체 기록을 매번 다시 쓰지 않도록 분리했다.
final class WorkoutRepository {
    private let store: FileStore
    private let sessionsFile = "workoutSessions.json"
    private let activeSessionFile = "workoutActiveSession.json"

    init(store: FileStore = JSONStore()) {
        self.store = store
    }

    // MARK: - 완료된 세션

    func loadSessions() throws -> [WorkoutSession] {
        try store.load([WorkoutSession].self, from: sessionsFile) ?? []
    }

    func saveSessions(_ sessions: [WorkoutSession]) throws {
        try store.save(sessions, to: sessionsFile)
    }

    // MARK: - 진행 중 세션

    /// 앱이 강제 종료되거나 기기가 재부팅돼도 이 파일로 세션을 되살린다.
    func loadActiveSession() throws -> WorkoutSession? {
        try store.load(WorkoutSession.self, from: activeSessionFile)
    }

    func saveActiveSession(_ session: WorkoutSession) throws {
        try store.save(session, to: activeSessionFile)
    }

    /// 세션을 끝냈거나 버렸을 때 진행 중 표시를 지운다.
    func clearActiveSession() throws {
        try store.remove(activeSessionFile)
    }
}
