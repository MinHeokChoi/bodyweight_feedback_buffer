import SwiftUI

struct AddFeedbackSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let initialSkill: Skill?

    @State private var skillId: UUID?
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var importance: Int = 3

    private let quickPhrases = ["골반이 흔들림", "견갑이 무너짐", "코어 힘이 풀림", "라인이 무너짐", "어깨가 으쓱"]

    init(initialSkill: Skill? = nil) {
        self.initialSkill = initialSkill
        _skillId = State(initialValue: initialSkill?.id)
    }

    private var canSave: Bool {
        skillId != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기술") {
                    Picker("기술 선택", selection: $skillId) {
                        Text("선택 안 함").tag(UUID?.none)
                        ForEach(store.skills) { skill in
                            Text(skill.name).tag(Optional(skill.id))
                        }
                    }
                }

                Section {
                    TextField("예: 골반이 흔들림", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                    quickPhrasesView
                } header: {
                    Text("제목")
                } footer: {
                    Text("짧고 구체적으로 적을수록 다음 훈련에 떠올리기 쉬워요.")
                }

                Section("메모") {
                    TextField("상세 메모 (선택)", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("중요도") {
                    ImportancePicker(importance: $importance)
                }
            }
            .navigationTitle("새 피드백")
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

    private var quickPhrasesView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPhrases, id: \.self) { phrase in
                    Button(phrase) {
                        title = phrase
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func save() {
        guard let id = skillId,
              let skill = store.skills.first(where: { $0.id == id }) else { return }
        store.addFeedback(skill: skill, title: title, note: note, importance: importance)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
