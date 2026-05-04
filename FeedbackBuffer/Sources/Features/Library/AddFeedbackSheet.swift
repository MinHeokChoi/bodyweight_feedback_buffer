import SwiftUI

struct AddFeedbackSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let skill: Skill

    @State private var title: String = ""
    @State private var note: String = ""
    @State private var importance: Int = 3
    @State private var editingPhrases = false

    init(_ skill: Skill) {
        self.skill = skill
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("예: 가동범위 부족", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                    quickPhrasesView
                } header: {
                    Text("빈 공간")
                } footer: {
                    Text("짧고 구체적으로 적을수록 다음 훈련에 떠올리기 쉬워요.")
                }

                Section("Cue") {
                    TextField("상세 메모", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("중요도") {
                    ImportancePicker(importance: $importance)
                }
            }
            .navigationTitle(skill.name)
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
            .sheet(isPresented: $editingPhrases) {
                QuickPhrasesEditorSheet(phrases: store.quickPhrases)
                    .environment(store)
            }
        }
    }

    private var quickPhrasesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("빠른 문구")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    editingPhrases = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.quickPhrases, id: \.self) { phrase in
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
    }

    private func save() {
        store.addFeedback(skill: skill, title: title, note: note, importance: importance)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
