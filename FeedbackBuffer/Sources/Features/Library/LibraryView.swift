import SwiftUI

struct LibraryView: View {
    @Environment(AppStore.self) private var store
    @State private var managingSkills = false
    @State private var searchQuery: String = ""

    private var filteredSkills: [Skill] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.skills }
        return store.skills.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
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
                } else if filteredSkills.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                } else {
                    let unarchivedCounts = store.unarchivedCountsBySkill
                    let allCounts = store.feedbackCountsBySkill
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredSkills) { skill in
                                let activeCount = unarchivedCounts[skill.id] ?? 0
                                let archivedCount = (allCounts[skill.id] ?? 0) - activeCount
                                NavigationLink(value: skill) {
                                    SkillTile(
                                        skill: skill,
                                        activeCount: activeCount,
                                        archivedCount: archivedCount
                                    )
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
            .searchable(text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "기술 검색")
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
    let activeCount: Int
    let archivedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                SkillIconView(symbolName: skill.symbolName, size: 32)
                Spacer()
                if activeCount > 0 {
                    countCapsule(count: activeCount, color: .accentColor, systemImage: "flame.fill")
                }
                if archivedCount > 0 {
                    countCapsule(count: archivedCount, color: .green, systemImage: "archivebox.fill")
                }
            }
            Text(skill.name)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(footerText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(skill.name)
        .accessibilityValue(accessibilityValue)
    }

    private func countCapsule(count: Int, color: Color, systemImage: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
            Text("\(count)")
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color, in: Capsule())
    }

    private var footerText: String {
        switch (activeCount, archivedCount) {
        case (0, 0): return "쌓인 피드백 없음"
        case (let a, 0): return "활성 피드백 \(a)개"
        case (0, let r): return "보관 \(r)개"
        case (let a, let r): return "활성 \(a)개 · 보관 \(r)개"
        }
    }

    private var accessibilityValue: String {
        switch (activeCount, archivedCount) {
        case (0, 0): return "활성 피드백 없음"
        case (let a, 0): return "활성 피드백 \(a)개"
        case (0, let r): return "보관된 피드백 \(r)개"
        case (let a, let r): return "활성 \(a)개, 보관 \(r)개"
        }
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
        "qdr.full",
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
