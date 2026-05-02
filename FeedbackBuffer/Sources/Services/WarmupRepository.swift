import Foundation

final class WarmupRepository {
    private let defaults: UserDefaults
    private let keyPrefix = "warmup_"
    private let routineKey = "warmupRoutine_v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(for date: Date) -> String {
        keyPrefix + WarmupDateKey.today(date)
    }

    func load(for date: Date = .now) -> [String: Bool] {
        defaults.dictionary(forKey: key(for: date)) as? [String: Bool] ?? [:]
    }

    func save(_ state: [String: Bool], for date: Date = .now) {
        defaults.set(state, forKey: key(for: date))
    }

    func reset(for date: Date = .now) {
        defaults.removeObject(forKey: key(for: date))
    }

    func loadRoutine() throws -> [WarmupItem]? {
        guard let data = defaults.data(forKey: routineKey) else { return nil }
        return try decoder.decode([WarmupItem].self, from: data)
    }

    func saveRoutine(_ items: [WarmupItem]) throws {
        let routine = items.map { WarmupItem(id: $0.id, label: $0.label) }
        let data = try encoder.encode(routine)
        defaults.set(data, forKey: routineKey)
    }

    func resetRoutine() {
        defaults.removeObject(forKey: routineKey)
    }
}
