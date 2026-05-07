import SwiftUI

private enum BufferCategoryFilter: String {
    case all, physical, skill

    var displayName: String {
        switch self {
        case .all: "전체"
        case .physical: FeedbackCategory.physical.displayName
        case .skill: FeedbackCategory.skill.displayName
        }
    }

    var systemImage: String {
        switch self {
        case .all: "list.bullet"
        case .physical: FeedbackCategory.physical.systemImage
        case .skill: FeedbackCategory.skill.systemImage
        }
    }
}

struct BufferView: View {
    @Environment(AppStore.self) private var store
    @State private var addingFeedback = false
    @State private var editing: Feedback?
    @AppStorage("buffer.categoryFilter") private var categoryFilter: String = BufferCategoryFilter.all.rawValue

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("피드백 버퍼")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            addingFeedback = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(store.skills.isEmpty)
                        .accessibilityLabel("피드백 추가")
                    }
                }
        }
        .sheet(isPresented: $addingFeedback) {
            AddFeedbackSheet(nil)
                .environment(store)
        }
        .sheet(item: $editing) { feedback in
            EditFeedbackSheet(feedback: feedback)
                .environment(store)
        }
    }

    private var selectedFilter: BufferCategoryFilter {
        BufferCategoryFilter(rawValue: categoryFilter) ?? .all
    }

    private func isVisible(_ category: FeedbackCategory) -> Bool {
        switch selectedFilter {
        case .all: true
        case .physical: category == .physical
        case .skill: category == .skill
        }
    }

    @ViewBuilder
    private var content: some View {
        let scored = store.activeFeedbacksScored
        let filtered = scored.filter { isVisible($0.0.category) }
        VStack(spacing: 0) {
            categoryFilterBar
            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered, id: \.0.id) { feedback, score in
                            FeedbackCardView(
                                feedback: feedback,
                                score: score,
                                onArchive: {
                                    withAnimation { store.archive(feedback.id) }
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                },
                                onMarkPracticed: {
                                    withAnimation { store.markPracticed(feedback.id) }
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
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var categoryFilterBar: some View {
        HStack(spacing: 8) {
            categoryButton(.all)
            categoryButton(.physical)
            categoryButton(.skill)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func categoryButton(_ filter: BufferCategoryFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                categoryFilter = filter.rawValue
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: filter.systemImage)
                Text(filter.displayName)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .modifier(CategoryToggleSurface(isSelected: isSelected))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 쌓인 피드백이 없습니다", systemImage: "tray")
        } description: {
            Text("오른쪽 위 + 버튼으로 오늘 느낀 점을 추가해보세요.")
        }
    }
}

private struct CategoryToggleSurface: ViewModifier {
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        .interactive(),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.18), lineWidth: 1)
                }
        } else {
            content
                .background(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.accentColor.opacity(0.42) : Color.secondary.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

#Preview {
    BufferView().environment(AppStore())
}
