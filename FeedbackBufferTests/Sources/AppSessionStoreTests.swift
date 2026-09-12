import XCTest
@testable import FeedbackBuffer

@MainActor
final class AppSessionStoreTests: StoreTestCase {
    func test_completeOnboardingPersistsAcrossReload() {
        let settingsRepository = UserSettingsRepository(defaults: defaults)
        let store = AppSessionStore(settingsRepository: settingsRepository)

        store.completeOnboarding()

        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertTrue(AppSessionStore(settingsRepository: settingsRepository).hasCompletedOnboarding)
    }
}

@MainActor
final class AppContainerTests: StoreTestCase {
    func test_existingFeedbackSkipsOnboardingOnReload() {
        let fileStore = InMemoryFileStore()
        let firstContainer = makeContainer(fileStore: fileStore)
        addFeedback(to: firstContainer.feedbackStore)

        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding_v1"))
        XCTAssertTrue(makeContainer(fileStore: fileStore).appSessionStore.hasCompletedOnboarding)
    }

    func test_bootstrapReportsPersistenceIssueOnLoadFailure() {
        let container = makeContainer(fileStore: FailingFileStore())

        XCTAssertNotNil(container.appSessionStore.persistenceIssue)
        XCTAssertFalse(container.feedbackStore.skills.isEmpty)
        XCTAssertTrue(container.feedbackStore.feedbacks.isEmpty)
        XCTAssertFalse(container.feedbackStore.quickPhrases.isEmpty)
    }
}
