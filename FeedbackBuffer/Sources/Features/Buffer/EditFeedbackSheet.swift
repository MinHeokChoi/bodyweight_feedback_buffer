import SwiftUI

struct EditFeedbackSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let original: Feedback

    @State private var skillId: UUID
    @State private var title: String
    @State private var note: String
    @State private var importance: Int

    init(feedback: Feedback) {
        self.original = feedback
        _skillId = State(initialValue: feedback.skillId)
        _title = State(initialValue: feedback.title)
        _note = State(initialValue: feedback.note)
        _importance = State(initialValue: feedback.importance)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기술") {
                    Picker("기술", selection: $skillId) {
                        ForEach(store.skills) { skill in
                            Text(skill.name).tag(skill.id)
                        }
                    }
                }

                Section("제목") {
                    TextField("예: 골반이 흔들림", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("메모") {
                    TextField("상세 메모 (선택)", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("중요도") {
                    ImportancePicker(importance: $importance)
                }
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
        store.updateFeedback(updated)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
