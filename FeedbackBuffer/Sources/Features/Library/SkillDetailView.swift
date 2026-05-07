import SwiftUI

struct SkillDetailView: View {
    enum Section: Hashable { case active, archived }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let skill: Skill

    @State private var section: Section = .active
    @State private var addingFeedback = false
    @State private var editing: Feedback?

    private var scoredActive: [(Feedback, Double)] {
        store.unarchivedFeedbacksScored(forSkillId: skill.id)
    }

    private var archivedFeedbacks: [Feedback] {
        store.feedbacks
            .filter { $0.skillId == skill.id && $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("탭", selection: $section) {
                Text("활성").tag(Section.active)
                Text("보관함").tag(Section.archived)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            content
        }
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if section == .active {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addingFeedback = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("피드백 추가")
                }
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

    @ViewBuilder
    private var content: some View {
        switch section {
        case .active: activeContent
        case .archived: archivedContent
        }
    }

    @ViewBuilder
    private var activeContent: some View {
        if scoredActive.isEmpty {
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
                    ForEach(scoredActive, id: \.0.id) { feedback, score in
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

    @ViewBuilder
    private var archivedContent: some View {
        if archivedFeedbacks.isEmpty {
            ContentUnavailableView {
                Label("보관한 피드백이 없어요", systemImage: "archivebox")
            } description: {
                Text("\"보관\" 버튼을 누른 피드백이 여기에 모입니다.")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(archivedFeedbacks) { feedback in
                        ArchivedFeedbackCardView(
                            feedback: feedback,
                            onUnarchive: { withAnimation { store.unarchive(feedback.id) } },
                            onDelete: { withAnimation { store.delete(feedback.id) } }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }
}
