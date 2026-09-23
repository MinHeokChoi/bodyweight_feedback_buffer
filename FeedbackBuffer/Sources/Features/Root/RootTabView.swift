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

            TimerView(tabSelection: $selection)
                .tabItem {
                    Label(timerTab.title, systemImage: timerTab.symbol)
                }
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
        // 구간이 도는 동안은 어느 탭에 있든 화면을 켜 둔다. 휴식과 일시정지는 제외한다.
        .onChange(of: keepsScreenAwake, initial: true) { _, active in
            ScreenAwake.set(.workoutSegment, active: active)
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

    /// 다른 탭에 있어도 운동이 어떤 상태인지 탭 이름으로 알린다(FR-1).
    /// 빨간 점 배지는 읽지 않은 알림처럼 보였고 진행·휴식·일시정지를 구분하지 못했다.
    private var timerTab: (title: String, symbol: String) {
        guard workoutStore.isRunning else { return ("타이머", "stopwatch.fill") }
        if workoutStore.isPaused { return ("일시정지", "pause.circle.fill") }
        if workoutStore.runningSegment != nil { return ("운동 중", "stopwatch.fill") }
        return ("휴식 중", "hourglass")
    }

    private var keepsScreenAwake: Bool {
        workoutStore.runningSegment != nil && !workoutStore.isPaused
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
