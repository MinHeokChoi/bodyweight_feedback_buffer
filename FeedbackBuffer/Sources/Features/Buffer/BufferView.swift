import SwiftUI

/// 버퍼를 걸러 보는 조건. 범주(체력/기술)나 기술 하나.
enum BufferFilter: Hashable {
    case all
    case category(FeedbackCategory)
    case skill(UUID)

    /// 옛 값("all", "physical", "skill")을 그대로 읽는다. 기술 필터만 새 형식이다.
    init(storageValue: String) {
        if storageValue.hasPrefix(Self.skillPrefix),
           let id = UUID(uuidString: String(storageValue.dropFirst(Self.skillPrefix.count))) {
            self = .skill(id)
        } else if let category = FeedbackCategory(rawValue: storageValue) {
            self = .category(category)
        } else {
            self = .all
        }
    }

    var storageValue: String {
        switch self {
        case .all: "all"
        case let .category(category): category.rawValue
        case let .skill(id): Self.skillPrefix + id.uuidString
        }
    }

    func includes(_ feedback: Feedback) -> Bool {
        switch self {
        case .all: true
        case let .category(category): feedback.category == category
        case let .skill(id): feedback.skillId == id
        }
    }

    private static let skillPrefix = "skillId:"

    /// 버퍼·타이머·기술 화면이 함께 읽는 저장 키.
    static let storageKey = "buffer.categoryFilter"

    /// 저장된 필터. 지워진 기술을 가리키고 있으면 전체로 본다.
    static func stored(_ storageValue: String, skills: [Skill]) -> BufferFilter {
        let stored = BufferFilter(storageValue: storageValue)
        if case let .skill(id) = stored, !skills.contains(where: { $0.id == id }) {
            return .all
        }
        return stored
    }

    /// 새로 적을 때의 기본값으로 넘길 것. 지금 걸러 보는 것을 적을 가능성이 크다.
    var draftSkillId: UUID? {
        if case let .skill(id) = self { id } else { nil }
    }

    var draftCategory: FeedbackCategory? {
        if case let .category(category) = self { category } else { nil }
    }
}

struct BufferView: View {
    @Environment(FeedbackStore.self) private var store
    @Binding var tabSelection: RootTabView.Tab
    @State private var addingFeedback = false
    @State private var editing: Feedback?
    @AppStorage(BufferFilter.storageKey) private var filterValue: String = BufferFilter.all.storageValue
    /// 필터 중에 끌어서 만든 임시 순서. 저장하지 않는다.
    ///
    /// 운동하면서 "이번엔 이 순서로 보자"고 잠깐 늘어놓는 용도다. 다른 탭에 다녀와도
    /// 유지되고, 필터를 풀거나 바꾸면 버려져 저장된 순서로 돌아온다.
    @State private var temporaryOrder: [UUID]?
    /// 해결·또 하기 직후 목록이 움직이는 동안. 아래 카드가 손가락 밑으로 올라와
    /// 연달아 누른 탭이 엉뚱한 카드에 들어가지 않게 잠깐 입력을 받지 않는다.
    @State private var isSettling = false

    private enum ListSection { case today, backlog }

    var body: some View {
        NavigationStack {
            content
                .undoBanner()
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
            // 필터에 맞춘 기본값과 필터 풀기는 시트가 직접 한다.
            AddFeedbackSheet()
                .environment(store)
        }
        .sheet(item: $editing) { feedback in
            EditFeedbackSheet(feedback: feedback)
                .environment(store)
        }
        .onChange(of: filterValue) { _, _ in
            temporaryOrder = nil
        }
    }

    // MARK: - 필터

    private var filter: BufferFilter {
        BufferFilter.stored(filterValue, skills: store.skills)
    }

    private var isFiltering: Bool { filter != .all }


    /// 기술 칩. 피드백이 있는 기술만 보여준다. 다만 지금 고른 기술은 비어도 남겨서
    /// 풀 수 있게 한다.
    private var skillChips: [Skill] {
        var skills = store.skillsWithActiveFeedback
        if case let .skill(id) = filter,
           !skills.contains(where: { $0.id == id }),
           let selected = store.skills.first(where: { $0.id == id }) {
            skills.append(selected)
        }
        return skills
    }

    private func displayed(_ items: [Feedback]) -> [Feedback] {
        let filtered = items.filter(filter.includes)
        guard let temporaryOrder else { return filtered }
        return FeedbackOrdering.applyingTemporaryOrder(filtered, order: temporaryOrder)
    }

    // MARK: - 본문

    @ViewBuilder
    private var content: some View {
        let today = displayed(store.todayFeedbacks())
        let backlog = displayed(store.backlogFeedbacks())

        VStack(spacing: 0) {
            filterBar
            if store.unarchivedFeedbacks.isEmpty {
                emptyState
            } else if today.isEmpty && backlog.isEmpty {
                filteredEmptyState
            } else {
                List {
                    if temporaryOrder != nil {
                        temporaryOrderNotice
                    }

                    // 머리말은 Section 머리말이 아니라 보통 줄로 둔다. 목록 위에 고정되면
                    // 바탕 없는 머리말이 카드 글자 위에 겹쳐 그려졌다.
                    // 오늘 목록이 비어 있으면 구역 자체를 숨긴다. 안 쓸 때는 자리를 차지하지 않는다.
                    if !today.isEmpty {
                        sectionLabel("오늘 할 것", systemImage: "sun.max", emphasized: true)
                        Section {
                            rows(today, in: .today, today: today, backlog: backlog)
                        }
                    }

                    // 필터 칩의 "전체"(필터 없음)와 헷갈리지 않게 "나머지"라고 부른다.
                    if !today.isEmpty && !backlog.isEmpty {
                        sectionLabel("나머지", systemImage: nil, emphasized: false)
                    }
                    Section {
                        rows(backlog, in: .backlog, today: today, backlog: backlog)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .allowsHitTesting(!isSettling)
            }
        }
    }

    private func rows(
        _ items: [Feedback],
        in section: ListSection,
        today: [Feedback],
        backlog: [Feedback]
    ) -> some View {
        ForEach(items) { feedback in
            card(for: feedback)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                // 카드에 버튼이 이미 넷이라 오늘 할 것은 스와이프로 담고 뺀다.
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    switch section {
                    case .backlog:
                        Button {
                            withAnimation { store.addToToday(feedback.id) }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label("오늘", systemImage: "sun.max")
                        }
                        .tint(.accentColor)
                    case .today:
                        Button {
                            withAnimation { store.removeFromToday(feedback.id) }
                        } label: {
                            Label("빼기", systemImage: "minus.circle")
                        }
                        .tint(.gray)
                    }
                }
        }
        .onMove { source, destination in
            move(items, in: section, today: today, backlog: backlog, from: source, to: destination)
        }
    }

    private func sectionLabel(_ text: String, systemImage: String?, emphasized: Bool) -> some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(emphasized ? DS.Tint.accentText : Color.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 2, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityAddTraits(.isHeader)
    }

    private func card(for feedback: Feedback) -> some View {
        FeedbackCardView(
            feedback: feedback,
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
            onDelete: {
                withAnimation { store.delete(feedback.id) }
            }
        )
    }

    private func settle() {
        isSettling = true
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isSettling = false
        }
    }

    /// 필터가 없으면 저장하고, 필터 중이면 화면에만 늘어놓는다.
    ///
    /// 걸러낸 목록에서 옮긴 것을 전체 순서에 반영하면, 사이사이에 다른 기술의
    /// 피드백이 끼어 있어서 어디로 갔는지 예측할 수 없다.
    private func move(
        _ items: [Feedback],
        in section: ListSection,
        today: [Feedback],
        backlog: [Feedback],
        from source: IndexSet,
        to destination: Int
    ) {
        let ids = items.map(\.id)
        guard isFiltering else {
            store.moveFeedbacks(visibleIds: ids, fromOffsets: source, toOffset: destination)
            return
        }
        var moved = ids
        moveItems(&moved, fromOffsets: source, toOffset: destination)
        let todayIds = section == .today ? moved : today.map(\.id)
        let backlogIds = section == .backlog ? moved : backlog.map(\.id)
        temporaryOrder = todayIds + backlogIds
        // 저장하지 않는 끌기도 변경이다. 되살린 카드가 새 순서 어디에 들어갈지 알 수 없다.
        store.discardUndo()
    }

    private var temporaryOrderNotice: some View {
        HStack(spacing: 8) {
            Label("필터 중 순서는 저장되지 않아요", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("원래대로") {
                withAnimation { temporaryOrder = nil }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderless)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - 필터 막대

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(.all, title: "전체", systemImage: "list.bullet")
                chip(.category(.physical), title: FeedbackCategory.physical.displayName,
                     systemImage: FeedbackCategory.physical.systemImage)
                chip(.category(.skill), title: FeedbackCategory.skill.displayName,
                     systemImage: FeedbackCategory.skill.systemImage)

                if !skillChips.isEmpty {
                    Divider()
                        .frame(height: 20)
                    ForEach(skillChips) { skill in
                        chip(.skill(skill.id), title: skill.name, systemImage: nil)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func chip(_ target: BufferFilter, title: String, systemImage: String?) -> some View {
        let isSelected = filter == target
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                filterValue = target.storageValue
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .lineLimit(1)
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

    // MARK: - 빈 상태

    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 쌓인 피드백이 없습니다", systemImage: "tray")
        } description: {
            Text("오른쪽 위 + 버튼으로 오늘 느낀 점을 추가해보세요.")
        } actions: {
            Button("기술 라이브러리 보기") {
                tabSelection = .library
            }
            .buttonStyle(.bordered)
        }
    }

    private var filteredEmptyState: some View {
        ContentUnavailableView {
            Label("여기엔 쌓인 피드백이 없어요", systemImage: "line.3.horizontal.decrease.circle")
        } actions: {
            Button("전체 보기") {
                filterValue = BufferFilter.all.storageValue
            }
            .buttonStyle(.bordered)
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
    BufferView(tabSelection: .constant(.buffer)).environment(FeedbackStore())
}
