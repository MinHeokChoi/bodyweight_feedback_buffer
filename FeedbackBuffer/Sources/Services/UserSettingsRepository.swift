import Foundation

final class UserSettingsRepository {
    private let defaults: UserDefaults
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding_v1"
    private let feedbackSchemaVersionKey = "feedbacks.schemaVersion_v1"

    /// 더 쓰지 않는 값. 기기에 남아 있으면 지운다.
    /// - `quickPhrases_v1`: 빠른 문구. 쓰지 않기로 했다(UX_IMPROVEMENT U4).
    private static let retiredKeys = ["quickPhrases_v1"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadHasCompletedOnboarding() -> Bool {
        defaults.bool(forKey: hasCompletedOnboardingKey)
    }

    func saveHasCompletedOnboarding() {
        defaults.set(true, forKey: hasCompletedOnboardingKey)
    }

    func removeRetiredValues() {
        for key in Self.retiredKeys where defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
        }
    }

    func loadFeedbackSchemaVersion() -> Int {
        defaults.integer(forKey: feedbackSchemaVersionKey)
    }

    func saveFeedbackSchemaVersion(_ version: Int) {
        defaults.set(version, forKey: feedbackSchemaVersionKey)
    }
}
