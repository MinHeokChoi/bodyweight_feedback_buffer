import Foundation

@MainActor
final class AppContainer {
    let appSessionStore: AppSessionStore
    let feedbackStore: FeedbackStore
    let warmupStore: WarmupStore
    let workoutTimerStore: WorkoutTimerStore

    init(
        feedbackRepository: FeedbackRepository = FeedbackRepository(),
        warmupRepository: WarmupRepository = WarmupRepository(),
        workoutRepository: WorkoutRepository = WorkoutRepository(),
        settingsRepository: UserSettingsRepository = UserSettingsRepository(),
        persistenceScheduler: PersistenceScheduler = .background
    ) {
        let appSessionStore = AppSessionStore(settingsRepository: settingsRepository)
        let reportIssue: (PersistenceIssue) -> Void = { [weak appSessionStore] issue in
            appSessionStore?.reportPersistenceIssue(issue)
        }
        let feedbackStore = FeedbackStore(
            feedbackRepository: feedbackRepository,
            settingsRepository: settingsRepository,
            persistenceScheduler: persistenceScheduler,
            reportIssue: reportIssue
        )
        let warmupStore = WarmupStore(
            warmupRepository: warmupRepository,
            persistenceScheduler: persistenceScheduler,
            reportIssue: reportIssue
        )
        let workoutTimerStore = WorkoutTimerStore(
            repository: workoutRepository,
            persistenceScheduler: persistenceScheduler,
            reportIssue: reportIssue
        )

        if !appSessionStore.hasCompletedOnboarding && !feedbackStore.feedbacks.isEmpty {
            appSessionStore.completeOnboarding()
        }

        self.appSessionStore = appSessionStore
        self.feedbackStore = feedbackStore
        self.warmupStore = warmupStore
        self.workoutTimerStore = workoutTimerStore
    }
}
