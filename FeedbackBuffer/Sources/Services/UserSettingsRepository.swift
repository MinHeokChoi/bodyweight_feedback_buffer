import Foundation

final class UserSettingsRepository {
    private let defaults: UserDefaults
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding_v1"
    private let quickPhrasesKey = "quickPhrases_v1"
    private let feedbackSchemaVersionKey = "feedbacks.schemaVersion_v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private static let defaultQuickPhrases = [
        "견갑이 풀림", "코어 힘이 풀림", "어깨가 으쓱",
        "가동범위 부족", "호흡 멈춤", "반동 사용"
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadHasCompletedOnboarding() -> Bool {
        defaults.bool(forKey: hasCompletedOnboardingKey)
    }

    func saveHasCompletedOnboarding() {
        defaults.set(true, forKey: hasCompletedOnboardingKey)
    }

    func loadQuickPhrases() -> [String] {
        guard let data = defaults.data(forKey: quickPhrasesKey),
              let saved = try? decoder.decode([String].self, from: data) else {
            return Self.defaultQuickPhrases
        }
        return saved
    }

    func saveQuickPhrases(_ phrases: [String]) throws {
        let data = try encoder.encode(phrases)
        defaults.set(data, forKey: quickPhrasesKey)
    }

    func loadFeedbackSchemaVersion() -> Int {
        defaults.integer(forKey: feedbackSchemaVersionKey)
    }

    func saveFeedbackSchemaVersion(_ version: Int) {
        defaults.set(version, forKey: feedbackSchemaVersionKey)
    }
}
