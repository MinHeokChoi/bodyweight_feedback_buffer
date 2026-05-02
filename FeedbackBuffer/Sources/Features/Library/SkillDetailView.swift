import SwiftUI

struct SkillDetailView: View {
    @Environment(AppStore.self) private var store
    let skill: Skill

    @State private var addingFeedback = false
    @State private var editing: Feedback?

    private var feedbacks: [Feedback] { store.activeFeedbacks(forSkillId: skill.id) }

    var body: some View {
        Group {
            if feedbacks.isEmpty {
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
                        ForEach(feedbacks) { feedback in
                            FeedbackCardView(
                                feedback: feedback,
                                score: FeedbackScoring.score(for: feedback),
                                onResolve: { withAnimation { store.resolve(feedback.id) } },
                                onMarkUnresolved: { withAnimation { store.markUnresolved(feedback.id) } },
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
            AddFeedbackSheet(initialSkill: skill).environment(store)
        }
        .sheet(item: $editing) { feedback in
            EditFeedbackSheet(feedback: feedback).environment(store)
        }
    }
}
