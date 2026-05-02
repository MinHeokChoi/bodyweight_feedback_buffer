import SwiftUI

struct RootTabView: View {
    @Environment(AppStore.self) private var store
    @State private var selection: Tab = .buffer

    enum Tab: Hashable {
        case warmup, buffer, library
    }

    var body: some View {
        TabView(selection: $selection) {
            WarmupView()
                .tabItem {
                    Label("웜업", systemImage: "flame.fill")
                }
                .tag(Tab.warmup)

            BufferView()
                .tabItem {
                    Label("피드백 버퍼", systemImage: "bolt.heart.fill")
                }
                .tag(Tab.buffer)

            LibraryView()
                .tabItem {
                    Label("기술 라이브러리", systemImage: "books.vertical.fill")
                }
                .tag(Tab.library)
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView {
                store.completeOnboarding()
            }
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

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !store.hasCompletedOnboarding },
            set: { isPresented in
                if !isPresented {
                    store.completeOnboarding()
                }
            }
        )
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
    RootTabView()
        .environment(AppStore())
}
