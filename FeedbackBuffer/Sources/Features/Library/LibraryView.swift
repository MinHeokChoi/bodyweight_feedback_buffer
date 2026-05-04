import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var managingSkills = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.skills.isEmpty {
                    ContentUnavailableView {
                        Label("기술을 추가해보세요", systemImage: "plus.circle")
                    } description: {
                        Text("훈련에서 집중할 기술을 만들고 피드백을 기록해보세요.")
                    } actions: {
                        Button("첫 기술 추가") { managingSkills = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
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
                }
            }
            .navigationTitle("기술 라이브러리")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        managingSkills = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("기술 관리")
                }
            }
            .navigationDestination(for: Skill.self) { skill in
                SkillDetailView(skill: skill)
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
                SkillIconView(symbolName: skill.symbolName, size: 32)
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

struct SkillIconView: View {
    let symbolName: String
    var size: CGFloat = 28

    var body: some View {
        Group {
            if SkillIconAsset.names.contains(symbolName) {
                Image(symbolName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.tint)
            } else {
                Image(systemName: symbolName)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .padding(size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private enum SkillIconAsset {
    static let names: Set<String> = [
        "handstand.full",
        "bridge.full",
        "cartwheel.full",
        "hspu.full",
        "pull.ups.full",
        "front.lever.full",
        "dips.full",
        "muscle.up.full",
        "pia.stretching.full"
    ]
}

#Preview {
    LibraryView().environment(AppStore())
}
