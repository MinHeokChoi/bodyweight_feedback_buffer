import SwiftUI

struct WarmupSessionPickerSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var creatingNew = false
    @State private var renamingSession: WarmupSession?
    @State private var deletingSession: WarmupSession?

    var body: some View {
        NavigationStack {
            List {
                Section("세션") {
                    ForEach(store.warmupSessions) { session in
                        Button {
                            store.selectWarmupSession(session.id)
                            UISelectionFeedbackGenerator().selectionChanged()
                            dismiss()
                        } label: {
                            row(for: session)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                renamingSession = session
                            } label: {
                                Label("이름 변경", systemImage: "pencil")
                            }
                            if store.warmupSessions.count > 1 {
                                Button(role: .destructive) {
                                    deletingSession = session
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if store.warmupSessions.count > 1 {
                                Button(role: .destructive) {
                                    deletingSession = session
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                            Button {
                                renamingSession = session
                            } label: {
                                Label("이름 변경", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }

                Section {
                    Button {
                        creatingNew = true
                    } label: {
                        Label("세션 추가", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("웜업 세션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $creatingNew) {
                QuickSessionCreateSheet().environment(store)
            }
            .sheet(item: $renamingSession) { session in
                RenameSessionSheet(session: session).environment(store)
            }
            .confirmationDialog(
                "이 세션을 삭제할까요?",
                isPresented: Binding(
                    get: { deletingSession != nil },
                    set: { if !$0 { deletingSession = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let deletingSession {
                        store.deleteWarmupSession(deletingSession.id)
                    }
                    deletingSession = nil
                }
                Button("취소", role: .cancel) { deletingSession = nil }
            } message: {
                Text("세션의 항목과 오늘의 체크 기록이 함께 사라져요.")
            }
        }
    }

    private func row(for session: WarmupSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .foregroundStyle(.primary)
                Text("\(session.items.count)개 항목")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if session.id == store.selectedWarmupSessionId {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

private struct RenameSessionSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let session: WarmupSession
    @State private var name: String

    init(session: WarmupSession) {
        self.session = session
        _name = State(initialValue: session.name)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("세션 이름") {
                    TextField("이름", text: $name)
                        .submitLabel(.done)
                }
            }
            .navigationTitle("세션 이름 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        store.renameWarmupSession(id: session.id, name: name)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    WarmupSessionPickerSheet().environment(AppStore())
}
