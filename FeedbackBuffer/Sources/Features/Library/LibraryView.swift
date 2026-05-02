import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var addingFeedback = false
    @State private var managingSkills = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.skills) { skill in
                        NavigationLink(value: skill) {
                            SkillTile(skill: skill, count: store.activeCount(forSkillId: skill.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("기술 라이브러리")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        managingSkills = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("기술 관리")

                    Button {
                        addingFeedback = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("피드백 추가")
                }
            }
            .navigationDestination(for: Skill.self) { skill in
                SkillDetailView(skill: skill)
            }
            .sheet(isPresented: $addingFeedback) {
                AddFeedbackSheet().environment(store)
            }
            .sheet(isPresented: $managingSkills) {
                SkillManagementSheet().environment(store)
            }
        }
    }
}

private struct SkillTile: View {
    let skill: Skill
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: skill.symbolName)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.tint, in: Capsule())
                }
            }
            Text(skill.name)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(count == 0 ? "쌓인 피드백 없음" : "활성 피드백 \(count)개")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LibraryView().environment(AppStore())
}
