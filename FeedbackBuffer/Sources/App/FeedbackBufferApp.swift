import SwiftUI

@main
struct FeedbackBufferApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.refreshWarmupIfNeeded()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    store.refreshWarmupIfNeeded(force: true)
                }
        }
    }
}
