import SwiftUI

struct WarmupRoutineEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newLabel = ""
    @State private var editingItem: WarmupItem?
    @State private var deletingItem: WarmupItem?
    @State private var showingResetConfirm = false
    @State private var editMode: EditMode = .active

    private var canAdd: Bool {
        !newLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section("새 항목") {
                    HStack(spacing: 10) {
                        TextField("예: kneeling push up", text: $newLabel)
                            .submitLabel(.done)
                            .onSubmit(addItem)

                        Button(action: addItem) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .disabled(!canAdd)
                        .accessibilityLabel("추가")
                    }
                }

                Section("루틴 순서") {
                    ForEach(store.warmup) { item in
                        row(for: item)
                    }
                    .onMove { source, destination in
                        withAnimation {
                            store.moveWarmupItem(fromOffsets: source, toOffset: destination)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Label("기본 루틴으로 되돌리기", systemImage: "arrow.uturn.backward")
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("웜업 루틴 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(item: $editingItem) { item in
                WarmupItemFormSheet(item: item).environment(store)
            }
            .confirmationDialog(
                "이 웜업 항목을 삭제할까요?",
                isPresented: Binding(
                    get: { deletingItem != nil },
                    set: { if !$0 { deletingItem = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let deletingItem {
                        withAnimation { store.deleteWarmupItem(deletingItem.id) }
                    }
                    deletingItem = nil
                }
                Button("취소", role: .cancel) { deletingItem = nil }
            } message: {
                Text("삭제 후에는 되돌릴 수 없습니다.")
            }
            .confirmationDialog(
                "웜업 루틴을 기본값으로 되돌릴까요?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("되돌리기", role: .destructive) {
                    withAnimation { store.resetWarmupRoutine() }
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("오늘의 체크 상태도 함께 초기화됩니다.")
            }
        }
    }

    private func row(for item: WarmupItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.checked ? Color.accentColor : Color.secondary)

            Text(item.label)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                editingItem = item
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("수정")

            Button(role: .destructive) {
                deletingItem = item
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("삭제")
        }
        .padding(.vertical, 4)
    }

    private func addItem() {
        guard canAdd else { return }
        withAnimation {
            store.addWarmupItem(label: newLabel)
        }
        newLabel = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct WarmupItemFormSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let item: WarmupItem

    @State private var label: String

    init(item: WarmupItem) {
        self.item = item
        _label = State(initialValue: item.label)
    }

    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("항목 이름") {
                    TextField("예: 손목 가동성", text: $label)
                        .submitLabel(.done)
                }
            }
            .navigationTitle("웜업 항목 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        store.updateWarmupItem(id: item.id, label: label)
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
    WarmupRoutineEditorView().environment(AppStore())
}
