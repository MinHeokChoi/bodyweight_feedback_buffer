import SwiftUI

struct SkillDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let skill: Skill

    @State private var addingFeedback = false
    @State private var editing: Feedback?

    private var scoredFeedbacks: [(Feedback, Double)] { store.activeFeedbacksScored(forSkillId: skill.id) }

    var body: some View {
        Group {
            if scoredFeedbacks.isEmpty {
                ContentUnavailableView {
                    Label("아직 피드백이 없어요", systemImage: "tray")
                } description: {
                    Text("이 기술에 대한 첫 피드백을 추가해보세요.")
                } actions: {
                    Button("피드백 추가") { addingFeedback = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(scoredFeedbacks, id: \.0.id) { feedback, score in
                            FeedbackCardView(
                                feedback: feedback,
                                score: score,
                                onArchive: { withAnimation { store.archive(feedback.id) } },
                                onMarkPracticed: { withAnimation { store.markPracticed(feedback.id) } },
                                onEdit: { editing = feedback },
                                onDelete: { withAnimation { store.delete(feedback.id) } }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addingFeedback = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("피드백 추가")
            }
        }
        .sheet(isPresented: $addingFeedback) {
            AddFeedbackSheet(skill, onSaved: { dismiss() })
                .environment(store)
        }
        .sheet(item: $editing) { feedback in
            EditFeedbackSheet(feedback: feedback).environment(store)
        }
    }
}
