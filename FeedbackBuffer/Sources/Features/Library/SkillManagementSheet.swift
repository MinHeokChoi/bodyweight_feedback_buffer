import SwiftUI

struct SkillManagementSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var editingSkill: Skill?
    @State private var deletingSkill: Skill?
    @State private var editMode: EditMode = .active

    private var canAdd: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section("새 기술") {
                    TextField("예: Human Flag", text: $newName)
                        .submitLabel(.done)
                        .onSubmit(addSkill)

                    Button(action: addSkill) {
                        Label("새 기술 추가", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canAdd)
                }

                Section("기술 순서") {
                    let activeCounts = store.activeCountsBySkill
                    ForEach(store.skills) { skill in
                        row(for: skill, activeCount: activeCounts[skill.id] ?? 0)
                    }
                    .onMove { source, destination in
                        withAnimation {
                            store.moveSkill(fromOffsets: source, toOffset: destination)
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("기술 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(item: $editingSkill) { skill in
                SkillFormSheet(skill: skill).environment(store)
            }
            .confirmationDialog(
                "이 기술을 삭제할까요?",
                isPresented: Binding(
                    get: { deletingSkill != nil },
                    set: { if !$0 { deletingSkill = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let deletingSkill {
                        withAnimation { store.deleteSkill(deletingSkill.id) }
                    }
                    deletingSkill = nil
                }
                Button("취소", role: .cancel) { deletingSkill = nil }
            } message: {
                if let deletingSkill {
                    let count = store.feedbackCount(forSkillId: deletingSkill.id)
                    Text(count == 0 ? "삭제 후에는 되돌릴 수 없습니다." : "연결된 피드백 \(count)개도 함께 삭제됩니다.")
                }
            }
        }
    }

    private func row(for skill: Skill, activeCount: Int) -> some View {
        HStack(spacing: 12) {
            SkillIconView(symbolName: skill.symbolName, size: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .foregroundStyle(.primary)
                Text("활성 피드백 \(activeCount)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                editingSkill = skill
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("수정")

            Button(role: .destructive) {
                deletingSkill = skill
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("삭제")
        }
        .padding(.vertical, 4)
    }

    private func addSkill() {
        guard canAdd else { return }
        withAnimation {
            store.addSkill(name: newName)
        }
        newName = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct SkillFormSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let skill: Skill

    @State private var name: String

    init(skill: Skill) {
        self.skill = skill
        _name = State(initialValue: skill.name)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("예: Back Lever", text: $name)
                        .submitLabel(.done)
                }
            }
            .navigationTitle("기술 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        store.updateSkill(id: skill.id, name: name, symbolName: skill.symbolName)
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
    SkillManagementSheet().environment(AppStore())
}
