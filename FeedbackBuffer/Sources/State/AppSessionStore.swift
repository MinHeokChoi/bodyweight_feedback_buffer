import Foundation
import Observation

@MainActor
@Observable
final class AppSessionStore {
    private let settingsRepository: UserSettingsRepository

    private(set) var hasCompletedOnboarding: Bool
    private(set) var persistenceIssue: PersistenceIssue?

    init(settingsRepository: UserSettingsRepository = UserSettingsRepository()) {
        self.settingsRepository = settingsRepository
        hasCompletedOnboarding = settingsRepository.loadHasCompletedOnboarding()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        settingsRepository.saveHasCompletedOnboarding()
    }

    func reportPersistenceIssue(_ issue: PersistenceIssue) {
        persistenceIssue = issue
    }

    func clearPersistenceIssue() {
        persistenceIssue = nil
    }
}
