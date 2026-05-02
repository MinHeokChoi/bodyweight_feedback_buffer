import SwiftUI

struct SkillManagementSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var newSymbolName = SkillSymbolOption.fallback.name
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
                    TextField("예: 백레버", text: $newName)
                        .submitLabel(.done)
                        .onSubmit(addSkill)

                    Picker("아이콘", selection: $newSymbolName) {
                        ForEach(SkillSymbolOption.all) { option in
                            Label(option.title, systemImage: option.name)
                                .tag(option.name)
                        }
                    }

                    Button(action: addSkill) {
                        Label("추가", systemImage: "plus.circle.fill")
                    }
                    .disabled(!canAdd)
                }

                Section("기술 순서") {
                    ForEach(store.skills) { skill in
                        row(for: skill)
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
                    let count = feedbackCount(for: deletingSkill)
                    Text(count == 0 ? "삭제 후에는 되돌릴 수 없습니다." : "연결된 피드백 \(count)개도 함께 삭제됩니다.")
                }
            }
        }
    }

    private func row(for skill: Skill) -> some View {
        HStack(spacing: 12) {
            Image(systemName: skill.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .foregroundStyle(.primary)
                Text("활성 피드백 \(store.activeCount(forSkillId: skill.id))개")
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
            store.addSkill(name: newName, symbolName: newSymbolName)
        }
        newName = ""
        newSymbolName = SkillSymbolOption.fallback.name
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func feedbackCount(for skill: Skill) -> Int {
        store.feedbacks.filter { $0.skillId == skill.id }.count
    }
}

private struct SkillFormSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let skill: Skill

    @State private var name: String
    @State private var symbolName: String

    init(skill: Skill) {
        self.skill = skill
        _name = State(initialValue: skill.name)
        _symbolName = State(initialValue: skill.symbolName)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("예: 백레버", text: $name)
                        .submitLabel(.done)
                }

                Section("아이콘") {
                    Picker("아이콘", selection: $symbolName) {
                        ForEach(SkillSymbolOption.all) { option in
                            Label(option.title, systemImage: option.name)
                                .tag(option.name)
                        }
                    }
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
                        store.updateSkill(id: skill.id, name: name, symbolName: symbolName)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private struct SkillSymbolOption: Identifiable {
    let name: String
    let title: String

    var id: String { name }

    static let fallback = SkillSymbolOption(
        name: "figure.strengthtraining.traditional",
        title: "훈련"
    )

    static let all: [SkillSymbolOption] = [
        .fallback,
        SkillSymbolOption(name: "figure.gymnastics", title: "물구나무"),
        SkillSymbolOption(name: "figure.cooldown", title: "밸런스"),
        SkillSymbolOption(name: "figure.core.training", title: "코어"),
        SkillSymbolOption(name: "figure.climbing", title: "당기기"),
        SkillSymbolOption(name: "figure.pull.up", title: "풀업"),
        SkillSymbolOption(name: "figure.strengthtraining.functional", title: "근력"),
        SkillSymbolOption(name: "figure.flexibility", title: "유연성"),
        SkillSymbolOption(name: "ellipsis.circle", title: "기타")
    ]
}

#Preview {
    SkillManagementSheet().environment(AppStore())
}
