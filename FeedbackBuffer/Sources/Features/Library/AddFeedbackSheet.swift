import SwiftUI

/// 피드백 추가. 버퍼, 타이머, 기술 화면이 함께 쓴다.
///
/// 버퍼 필터는 시트가 직접 읽는다. 어디서 열든 지금 걸러 보는 것이 기본값이 되고,
/// 필터와 맞지 않게 저장하면 필터를 푼다(U12) — 방금 적은 것은 버퍼에서 보여야 한다.
struct AddFeedbackSheet: View {
    /// 시트를 여는 곳이 아는 것. 기본값을 고르는 데만 쓰고 저장하지 않는다.
    struct Context {
        var skillId: UUID?
        var category: FeedbackCategory?

        static let none = Context()
    }

    @Environment(FeedbackStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(BufferFilter.storageKey) private var bufferFilterValue = BufferFilter.all.storageValue

    let context: Context

    /// 사용자가 직접 고른 값. 고르기 전에는 기본값을 따른다.
    /// 그래서 기술을 바꾸면, 범주를 직접 고르지 않은 동안은 범주도 따라 바뀐다.
    @State private var chosenSkillId: UUID?
    @State private var chosenCategory: FeedbackCategory?
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var importance: Int = 3
    @State private var confirmingDiscard = false
    @FocusState private var focusedField: FeedbackField?

    init(context: Context = .none) {
        self.context = context
    }

    private var bufferFilter: BufferFilter {
        BufferFilter.stored(bufferFilterValue, skills: store.skills)
    }

    /// 기술 화면에서 열었으면 그 기술, 아니면 버퍼의 기술 필터를 먼저 본다.
    private var skillId: UUID? {
        chosenSkillId ?? FeedbackDraftDefaults.skillId(
            preferred: context.skillId ?? bufferFilter.draftSkillId,
            feedbacks: store.feedbacks,
            skills: store.skills
        )
    }

    /// 버퍼의 범주 필터를 먼저 보고, 없으면 여는 곳(타이머 구간)이 정해 준 범주를 쓴다.
    private var category: FeedbackCategory {
        chosenCategory ?? FeedbackDraftDefaults.category(
            preferred: bufferFilter.draftCategory ?? context.category,
            skillId: skillId,
            feedbacks: store.feedbacks
        )
    }

    private var currentSkillName: String {
        guard let id = skillId,
              let skill = store.skills.first(where: { $0.id == id }) else {
            return "선택 안 됨"
        }
        return skill.name
    }

    private var hasContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            skillId != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기술") {
                    SkillMenuPicker(
                        skillId: Binding(
                            get: { skillId ?? UUID() },
                            set: { chosenSkillId = $0 }
                        ),
                        skills: store.skills,
                        currentName: currentSkillName
                    )
                }

                FeedbackFormFields(
                    title: $title,
                    note: $note,
                    category: Binding(
                        get: { category },
                        set: { chosenCategory = $0 }
                    ),
                    importance: $importance,
                    focus: $focusedField
                )
            }
            .navigationTitle("피드백 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        if hasContent {
                            confirmingDiscard = true
                        } else {
                            close()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!canSave)
                }
            }
            .discardConfirmation(
                isPresented: $confirmingDiscard,
                title: "작성 중인 내용을 버릴까요?",
                onDiscard: close
            )
            .interactiveDismissDisabled(hasContent)
            // 코치 말을 들은 직후에 여는 시트다. 열리자마자 바로 적을 수 있어야 한다.
            .onAppear { focusedField = .title }
        }
    }

    private func save() {
        let filter = bufferFilter
        guard let id = skillId,
              let skill = store.skills.first(where: { $0.id == id }),
              let saved = store.addFeedback(
                  skill: skill,
                  title: title,
                  note: note,
                  importance: importance,
                  category: category
              ) else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if !filter.includes(saved) {
            bufferFilterValue = BufferFilter.all.storageValue
        }
        close()
    }

    /// 한글 조합 중에 닫으면 키보드가 다음 화면까지 남는다. 먼저 내린다.
    private func close() {
        focusedField = nil
        dismiss()
    }
}
