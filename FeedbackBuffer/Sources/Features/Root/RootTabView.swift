import SwiftUI

struct RootTabView: View {
    @Environment(AppSessionStore.self) private var store
    @Environment(WorkoutTimerStore.self) private var workoutStore
    @State private var selection: Tab = .buffer

    enum Tab: Hashable {
        case warmup, timer, buffer, library
    }

    var body: some View {
        ZStack {
            mainTabs
                .accessibilityHidden(!store.hasCompletedOnboarding)

            if !store.hasCompletedOnboarding {
                OnboardingView(
                    onComplete: {
                        withAnimation(.easeOut(duration: 0.35)) {
                            store.completeOnboarding()
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selection) {
            WarmupView()
                .tabItem {
                    Label("웜업", systemImage: "flame.fill")
                }
                .tag(Tab.warmup)

            TimerView()
                .tabItem {
                    Label("타이머", systemImage: "stopwatch.fill")
                }
                .badge(workoutStore.isRunning ? "●" : nil)
                .tag(Tab.timer)

            BufferView(tabSelection: $selection)
                .tabItem {
                    Label("피드백 버퍼", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(Tab.buffer)

            LibraryView()
                .tabItem {
                    Label("기술 라이브러리", systemImage: "books.vertical.fill")
                }
                .tag(Tab.library)
        }
        .alert(
            store.persistenceIssue?.title ?? "데이터 문제",
            isPresented: persistenceIssueBinding
        ) {
            Button("확인") {
                store.clearPersistenceIssue()
            }
        } message: {
            if let issue = store.persistenceIssue {
                Text(issue.message)
            }
        }
    }

    private var persistenceIssueBinding: Binding<Bool> {
        Binding(
            get: { store.persistenceIssue != nil },
            set: { isPresented in
                if !isPresented {
                    store.clearPersistenceIssue()
                }
            }
        )
    }
}

#Preview {
    let container = AppContainer()
    RootTabView()
        .environment(container.appSessionStore)
        .environment(container.feedbackStore)
        .environment(container.warmupStore)
        .environment(container.workoutTimerStore)
}
