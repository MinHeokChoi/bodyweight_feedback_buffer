import SwiftUI

struct AddFeedbackSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let onSaved: () -> Void

    @State private var skillId: UUID?
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var importance: Int = 3
    @State private var category: FeedbackCategory = .skill

    init(_ skill: Skill?, onSaved: @escaping () -> Void = {}) {
        self.onSaved = onSaved
        _skillId = State(initialValue: skill?.id)
    }

    private var resolvedSkillId: UUID? {
        skillId ?? store.skills.first?.id
    }

    private var currentSkillName: String {
        guard let id = resolvedSkillId,
              let skill = store.skills.first(where: { $0.id == id }) else {
            return "선택 안 됨"
        }
        return skill.name
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            resolvedSkillId != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기술") {
                    SkillMenuPicker(
                        skillId: Binding(
                            get: { resolvedSkillId ?? UUID() },
                            set: { skillId = $0 }
                        ),
                        skills: store.skills,
                        currentName: currentSkillName
                    )
                }


                Section {
                    TextField("예: 가동범위 부족", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("빈 공간")
                }
//                footer: {
//                    Text("짧고 구체적으로 적을수록 다음 훈련에 떠올리기 쉬워요.")
//                }

                Section("Cue") {
                    TextField("예: 강도 조금 낮추고, 범위 늘려서 채우기", text: $note, axis: .vertical)
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
            .navigationTitle("피드백 추가")
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
        guard let id = resolvedSkillId,
              let skill = store.skills.first(where: { $0.id == id }) else { return }
        store.addFeedback(
            skill: skill,
            title: title,
            note: note,
            importance: importance,
            category: category
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
        onSaved()
    }
}
