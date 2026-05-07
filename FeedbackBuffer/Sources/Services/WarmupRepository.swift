import Foundation

final class WarmupRepository {
    private let defaults: UserDefaults
    private let legacyDayKeyPrefix = "warmup_"
    private let legacyRoutineKey = "warmupRoutine_v1"
    private let sessionsKey = "warmupSessions_v1"
    private let selectedSessionKey = "warmupSelectedSessionId_v1"
    private let defaultSessionKey = "warmupDefaultSessionId_v1"
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
    }

    func deleteAllCheckStates(forSessionId id: UUID) {
        let prefix = "warmup_\(id.uuidString)_"
        let matchingKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        for key in matchingKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
