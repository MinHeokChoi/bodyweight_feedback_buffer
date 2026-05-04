import SwiftUI

struct QuickPhrasesEditorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var phrases: [String]
    @State private var newPhrase = ""
    @State private var editMode: EditMode = .active

    init(phrases: [String]) {
        _phrases = State(initialValue: phrases)
    }

    private var canAdd: Bool {
        !newPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(phrases, id: \.self) { phrase in
                        Text(phrase)
                    }
                    .onDelete { indexSet in
                        phrases.remove(atOffsets: indexSet)
                    }
                    .onMove { source, destination in
                        phrases.move(fromOffsets: source, toOffset: destination)
                    }
                }

                Section("새 문구 추가") {
                    HStack {
                        TextField("예: 팔꿈치 구부러짐", text: $newPhrase)
                            .submitLabel(.done)
                            .onSubmit(addPhrase)
                        Button("추가", action: addPhrase)
                            .disabled(!canAdd)
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("빠른 문구 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        store.updateQuickPhrases(phrases)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                }
            }
        }
    }

    private func addPhrase() {
        let trimmed = newPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        phrases.append(trimmed)
        newPhrase = ""
    }
}

#Preview {
    QuickPhrasesEditorSheet(phrases: ["견갑이 풀림", "코어 힘이 풀림"])
        .environment(AppStore())
}
