import SwiftUI

struct EditFeedbackSheet: View {
    @Environment(FeedbackStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let original: Feedback

    @State private var skillId: UUID
    @State private var title: String
    @State private var note: String
    @State private var importance: Int
    @State private var category: FeedbackCategory
    @State private var confirmingDiscard = false
    @FocusState private var focusedField: FeedbackField?

    init(feedback: Feedback) {
        self.original = feedback
        _skillId = State(initialValue: feedback.skillId)
        _title = State(initialValue: feedback.title)
        _note = State(initialValue: feedback.note)
        _importance = State(initialValue: feedback.importance)
        _category = State(initialValue: feedback.category)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentSkillName: String {
        store.skills.first(where: { $0.id == skillId })?.name ?? "선택 안 됨"
    }

    private var hasChanges: Bool {
        skillId != original.skillId ||
            title != original.title ||
            note != original.note ||
            importance != original.importance ||
            category != original.category
    }

    var body: some View {
        NavigationStack {
            Form {
                // 기본 기술이 맞게 잡혀도 틀릴 때가 있다. 지우고 다시 적으면
                // 횟수·날짜·자리가 모두 사라지므로 여기서 옮길 수 있게 한다.
                Section("기술") {
                    SkillMenuPicker(
                        skillId: $skillId,
                        skills: store.skills,
                        currentName: currentSkillName
                    )
                }

                FeedbackFormFields(
                    title: $title,
                    note: $note,
                    category: $category,
                    importance: $importance,
                    focus: $focusedField
                )

                // 카드에서는 중요도만 보여준다. 쌓인 기록은 여기서 본다.
                Section("기록") {
                    LabeledContent("또 한 횟수", value: "\(original.unresolvedCount)회")
                    LabeledContent("마지막으로 한 날") {
                        if let reviewed = original.lastReviewedAt {
                            Text(reviewed, format: .dateTime.month().day())
                        } else {
                            Text("아직 없음")
                        }
                    }
                    LabeledContent("적은 날") {
                        Text(original.createdAt, format: .dateTime.year().month().day())
                    }
                }
            }
            .navigationTitle("피드백 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        if hasChanges {
                            confirmingDiscard = true
                        } else {
                            close()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!canSave)
                }
            }
            .discardConfirmation(
                isPresented: $confirmingDiscard,
                title: "바꾼 내용을 버릴까요?",
                onDiscard: close
            )
            .interactiveDismissDisabled(hasChanges)
        }
    }

    private func save() {
        guard let skill = store.skills.first(where: { $0.id == skillId }) else { return }
        var updated = original
        updated.skillId = skill.id
        updated.skillName = skill.name
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.importance = importance
        updated.category = category
        store.updateFeedback(updated)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        close()
    }

    /// 한글 조합 중에 닫으면 키보드가 다음 화면까지 남는다. 먼저 내린다.
    private func close() {
        focusedField = nil
        dismiss()
    }
}

enum FeedbackField: Hashable {
    case title, note
}

/// 추가와 수정이 함께 쓰는 입력 칸. 예시 문구도 여기 한 곳에서 정한다.
struct FeedbackFormFields: View {
    @Binding var title: String
    @Binding var note: String
    @Binding var category: FeedbackCategory
    @Binding var importance: Int
    var focus: FocusState<FeedbackField?>.Binding

    var body: some View {
        Section {
            TextField("예: 가동범위 부족", text: $title, axis: .vertical)
                .lineLimit(1...3)
                .focused(focus, equals: .title)
                .submitLabel(.next)
                .onChange(of: title) { oldValue, newValue in
                    // 여러 줄로 보이는 칸이라 Return이 줄바꿈으로 들어온다.
                    // 빈 공간은 한 문장이므로 줄바꿈 대신 Cue 칸으로 넘어간다.
                    // 방금 들어온 줄바꿈만 본다. 예전에 줄바꿈을 넣어 저장한 제목을
                    // 고칠 때 한 글자 치자마자 Cue로 튀면 안 된다.
                    guard newValue.count(where: { $0 == "\n" }) > oldValue.count(where: { $0 == "\n" }) else { return }
                    title = newValue
                        .split(separator: "\n", omittingEmptySubsequences: true)
                        .joined(separator: " ")
                    focus.wrappedValue = .note
                }
        } header: {
            Text("빈 공간")
        }

        Section("Cue") {
            TextField("예: 강도 낮추고, 볼륨 채우기", text: $note, axis: .vertical)
                .lineLimit(3...8)
                .focused(focus, equals: .note)
        }

        Section("범주") {
            Picker("범주", selection: $category) {
                ForEach(FeedbackCategory.allCases) { c in
                    Text(c.displayName).tag(c)
                }
            }
            .pickerStyle(.segmented)
        }

        Section("중요도") {
            ImportancePicker(importance: $importance)
        }
    }
}

struct SkillMenuPicker: View {
    @Binding var skillId: UUID
    let skills: [Skill]
    let currentName: String

    var body: some View {
        Menu {
            Picker(selection: $skillId) {
                ForEach(skills) { skill in
                    Text(skill.name).tag(skill.id)
                }
            } label: { EmptyView() }
        } label: {
            HStack {
                Text(currentName)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
    }
}

extension View {
    /// 쓰던 내용을 버리기 전에 한 번 묻는다.
    func discardConfirmation(
        isPresented: Binding<Bool>,
        title: String,
        onDiscard: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button("버리기", role: .destructive, action: onDiscard)
            Button("계속 쓰기", role: .cancel) { }
        }
    }
}
