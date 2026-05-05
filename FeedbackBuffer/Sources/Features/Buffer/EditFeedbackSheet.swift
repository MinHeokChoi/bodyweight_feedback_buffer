import SwiftUI

struct EditFeedbackSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let original: Feedback

    @State private var skillId: UUID
    @State private var title: String
    @State private var note: String
    @State private var importance: Int
    @State private var category: FeedbackCategory

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

    var body: some View {
        NavigationStack {
            Form {
                FeedbackFormFields(
                    title: $title,
                    note: $note,
                    category: $category,
                    importance: $importance,
                    titlePlaceholder: "예: 골반이 흔들림",
                    notePlaceholder: "상세 메모"
                )
            }
            .navigationTitle("피드백 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!canSave)
                }
            }
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
        dismiss()
    }
}

struct FeedbackFormFields: View {
    @Binding var title: String
    @Binding var note: String
    @Binding var category: FeedbackCategory
    @Binding var importance: Int
    let titlePlaceholder: String
    let notePlaceholder: String

    var body: some View {
        Section {
            TextField(titlePlaceholder, text: $title, axis: .vertical)
                .lineLimit(1...3)
        } header: {
            Text("빈 공간")
        }

        Section("Cue") {
            TextField(notePlaceholder, text: $note, axis: .vertical)
                .lineLimit(3...8)
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
