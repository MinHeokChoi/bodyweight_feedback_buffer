import SwiftUI

struct BufferView: View {
    @Environment(AppStore.self) private var store
    @State private var addingFeedback = false
    @State private var editing: Feedback?
    @AppStorage("buffer.showPhysical") private var showPhysical = true
    @AppStorage("buffer.showSkill") private var showSkill = true

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

    private func isVisible(_ category: FeedbackCategory) -> Bool {
        switch category {
        case .physical: showPhysical
        case .skill: showSkill
        }
    }

    @ViewBuilder
    private var content: some View {
        let scored = store.activeFeedbacksScored
        let filtered = scored.filter { isVisible($0.0.category) }
        VStack(spacing: 0) {
            categoryFilterBar
            if filtered.isEmpty {
                emptyState(hasAnyActive: !scored.isEmpty)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered, id: \.0.id) { feedback, score in
                            FeedbackCardView(
                                feedback: feedback,
                                score: score,
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
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var categoryFilterBar: some View {
        HStack(spacing: 8) {
            categoryToggle(.physical, isOn: $showPhysical)
            categoryToggle(.skill, isOn: $showSkill)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func categoryToggle(_ category: FeedbackCategory, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isOn.wrappedValue.toggle()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: category.systemImage)
                Text(category.displayName)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isOn.wrappedValue ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .modifier(CategoryToggleSurface(isSelected: isOn.wrappedValue))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

    @ViewBuilder
    private func emptyState(hasAnyActive: Bool) -> some View {
        if hasAnyActive {
            ContentUnavailableView {
                Label("표시할 범주를 선택해보세요", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("위 버튼으로 체력/기술 훈련 범주를 켜고 끌 수 있어요.")
            }
        } else {
            ContentUnavailableView {
                Label("아직 쌓인 피드백이 없습니다", systemImage: "tray")
            } description: {
                Text("오른쪽 위 + 버튼으로 오늘 느낀 점을 추가해보세요.")
            }
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
