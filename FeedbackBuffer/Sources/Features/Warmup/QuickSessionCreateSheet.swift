import SwiftUI

struct QuickSessionCreateSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var itemsText = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    private var parsedItems: [WarmupItem] {
        itemsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { WarmupItem(id: "custom_\(UUID().uuidString)", label: $0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("세션 이름") {
                    TextField("예: 공원 웜업", text: $name)
                        .submitLabel(.next)
                }

                Section {
                    TextEditor(text: $itemsText)
                        .frame(minHeight: 160)
                } header: {
                    Text("웜업 항목")
                } footer: {
                    Text("한 줄에 한 항목씩 적어주세요. 빈 줄은 자동으로 제외돼요.")
                }
            }
            .navigationTitle("새 웜업 세션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        store.addWarmupSession(name: trimmedName, items: parsedItems)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    QuickSessionCreateSheet().environment(AppStore())
}
