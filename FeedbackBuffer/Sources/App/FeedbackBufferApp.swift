import SwiftUI

@main
struct FeedbackBufferApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(container.appSessionStore)
                .environment(container.feedbackStore)
                .environment(container.warmupStore)
                .environment(container.workoutTimerStore)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        container.warmupStore.refreshWarmupIfNeeded()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    container.warmupStore.refreshWarmupIfNeeded(force: true)
                }
        }
    }
}
