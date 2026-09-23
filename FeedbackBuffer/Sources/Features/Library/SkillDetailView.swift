import SwiftUI

struct SkillDetailView: View {
    enum Section: Hashable { case active, archived }

    @Environment(FeedbackStore.self) private var store
    let skill: Skill

    @State private var section: Section = .active
    @State private var addingFeedback = false
    @State private var editing: Feedback?
    /// 해결·또 하기 직후 목록이 움직이는 동안 잠깐 입력을 받지 않는다. 버퍼와 같다.
    @State private var isSettling = false

    /// 버퍼와 같은 순서다. 끌기와 오늘 할 것은 버퍼에서만 한다.
    private var activeFeedbacks: [Feedback] {
        store.unarchivedFeedbacks(forSkillId: skill.id)
    }

    private var archivedFeedbacks: [Feedback] {
        store.feedbacks
            .filter { $0.skillId == skill.id && $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("탭", selection: $section) {
                // 버퍼 빈 상태와 라이브러리 타일이 쓰는 말("쌓인")과 맞춘다.
                Text("쌓인 것").tag(Section.active)
                Text("보관함").tag(Section.archived)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            content
        }
        .background(DS.Surface.page.ignoresSafeArea())
        .undoBanner()
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
        // 저장해도 이 화면에 머문다. 연달아 적을 수 있고, 새 카드는 맨 위에 보인다.
        .sheet(isPresented: $addingFeedback) {
            AddFeedbackSheet(context: AddFeedbackSheet.Context(skillId: skill.id))
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
        if activeFeedbacks.isEmpty {
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
                    ForEach(activeFeedbacks) { feedback in
                        FeedbackCardView(
                            feedback: feedback,
                            showsSkillName: false,
                            onArchive: {
                                withAnimation { store.archive(feedback.id) }
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                settle()
                            },
                            onMarkPracticed: {
                                withAnimation { store.markPracticed(feedback.id) }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                settle()
                            },
                            onEdit: { editing = feedback },
                            onDelete: { withAnimation { store.delete(feedback.id) } }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
            .allowsHitTesting(!isSettling)
        }
    }

    @ViewBuilder
    private var archivedContent: some View {
        if archivedFeedbacks.isEmpty {
            ContentUnavailableView {
                Label("보관한 피드백이 없어요", systemImage: "archivebox")
            } description: {
                Text("\"해결\"을 누른 피드백이 여기에 모여요.")
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

    private func settle() {
        isSettling = true
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isSettling = false
        }
    }
}
