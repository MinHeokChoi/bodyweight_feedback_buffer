import Foundation

final class WarmupRepository {
    private let defaults: UserDefaults
    private let legacyDayKeyPrefix = "warmup_"
    private let legacyRoutineKey = "warmupRoutine_v1"
    private let sessionsKey = "warmupSessions_v1"
    private let selectedSessionKey = "warmupSelectedSessionId_v1"
    private let defaultSessionKey = "warmupDefaultSessionId_v1"
    private let runnerFinishedPrefix = "warmupDone_"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Legacy (read-only after migration)

    func legacyLoadDailyState(for date: Date = .now) -> [String: Bool] {
        let key = legacyDayKeyPrefix + WarmupDateKey.today(date)
        return defaults.dictionary(forKey: key) as? [String: Bool] ?? [:]
    }

    func legacyLoadRoutine() throws -> [WarmupItem]? {
        guard let data = defaults.data(forKey: legacyRoutineKey) else { return nil }
        return try decoder.decode([WarmupItem].self, from: data)
    }

    // MARK: - Sessions

    func loadSessions() throws -> [WarmupSession]? {
        guard let data = defaults.data(forKey: sessionsKey) else { return nil }
        return try decoder.decode([WarmupSession].self, from: data)
    }

    func saveSessions(_ sessions: [WarmupSession]) throws {
        let normalized = sessions.map { session in
            WarmupSession(
                id: session.id,
                name: session.name,
                items: session.items.map { WarmupItem(id: $0.id, label: $0.label) }
            )
        }
        let data = try encoder.encode(normalized)
        defaults.set(data, forKey: sessionsKey)
    }

    func loadSelectedSessionId() -> UUID? {
        guard let raw = defaults.string(forKey: selectedSessionKey) else { return nil }
        return UUID(uuidString: raw)
    }

    func saveSelectedSessionId(_ id: UUID) {
        defaults.set(id.uuidString, forKey: selectedSessionKey)
    }

    func loadDefaultSessionId() -> UUID? {
        guard let raw = defaults.string(forKey: defaultSessionKey) else { return nil }
        return UUID(uuidString: raw)
    }

    func saveDefaultSessionId(_ id: UUID) {
        defaults.set(id.uuidString, forKey: defaultSessionKey)
    }

    // MARK: - Per-session daily check state

    private func dayKey(sessionId: UUID, for date: Date) -> String {
        "warmup_\(sessionId.uuidString)_\(WarmupDateKey.today(date))"
    }

    func load(sessionId: UUID, for date: Date = .now) -> [String: Bool] {
        defaults.dictionary(forKey: dayKey(sessionId: sessionId, for: date)) as? [String: Bool] ?? [:]
    }

    func save(_ state: [String: Bool], sessionId: UUID, for date: Date = .now) {
        defaults.set(state, forKey: dayKey(sessionId: sessionId, for: date))
    }

    func reset(sessionId: UUID, for date: Date = .now) {
        defaults.removeObject(forKey: dayKey(sessionId: sessionId, for: date))
        resetRunnerFinished(sessionId: sessionId, for: date)
    }

    func deleteAllCheckStates(forSessionId id: UUID) {
        let prefixes = [
            "warmup_\(id.uuidString)_",
            "\(runnerFinishedPrefix)\(id.uuidString)_"
        ]
        let matchingKeys = defaults.dictionaryRepresentation().keys.filter { key in
            prefixes.contains { key.hasPrefix($0) }
        }
        for key in matchingKeys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Per-session daily runner completion

    // 체크 상태와 따로 둔다. 건너뛴 항목이 있어도 러너를 끝까지 돌았다면
    // 그날 웜업은 끝난 것으로 보기 때문이다.
    private func runnerFinishedKey(sessionId: UUID, for date: Date) -> String {
        "\(runnerFinishedPrefix)\(sessionId.uuidString)_\(WarmupDateKey.today(date))"
    }

    func loadRunnerFinished(sessionId: UUID, for date: Date = .now) -> Bool {
        defaults.bool(forKey: runnerFinishedKey(sessionId: sessionId, for: date))
    }

    func saveRunnerFinished(_ finished: Bool, sessionId: UUID, for date: Date = .now) {
        let key = runnerFinishedKey(sessionId: sessionId, for: date)
        if finished {
            defaults.set(true, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func resetRunnerFinished(sessionId: UUID, for date: Date = .now) {
        defaults.removeObject(forKey: runnerFinishedKey(sessionId: sessionId, for: date))
    }
}
