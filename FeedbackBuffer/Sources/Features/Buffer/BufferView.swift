import SwiftUI

struct BufferView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: Feedback?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("피드백 버퍼")
        }
        .sheet(item: $editing) { feedback in
            EditFeedbackSheet(feedback: feedback)
                .environment(store)
        }
    }

    @ViewBuilder
    private var content: some View {
        let active = store.activeFeedbacks
        if active.isEmpty {
            ContentUnavailableView {
                Label("아직 쌓인 피드백이 없습니다", systemImage: "tray")
            } description: {
                Text("기술 라이브러리 탭에서 오늘 느낀 점을 추가해보세요.")
            }
            } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    BufferSummaryView(
                        activeCount: active.count,
                        topFeedback: active.first
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ForEach(active) { feedback in
                        FeedbackCardView(
                            feedback: feedback,
                            score: FeedbackScoring.score(for: feedback),
                            onResolve: {
                                withAnimation { store.resolve(feedback.id) }
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            },
                            onMarkUnresolved: {
                                withAnimation { store.markUnresolved(feedback.id) }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            },
                            onEdit: { editing = feedback },
                            onDelete: {
                                withAnimation { store.delete(feedback.id) }
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    BufferView().environment(AppStore())
}
