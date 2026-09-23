import SwiftUI

struct LibraryView: View {
    @Environment(FeedbackStore.self) private var store
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
                                        archivedCount: archivedCount,
                                        lastActivity: store.lastActivityBySkill[skill.id]
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Surface.page.ignoresSafeArea())
            .navigationTitle("기술 라이브러리")
            .toolbar {
                // 타이머 탭과 같은 문법이다 — 부가 목적지는 툴바에 둔다.
                // 시즌당 몇 번 쓰는 화면에 탭을 하나 내주지 않는다.
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        MeasurementHomeView()
                    } label: {
                        Image(systemName: "ruler")
                    }
                    .accessibilityLabel("시즌 측정")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // 목록을 고치는 버튼은 앱 어디서나 연필이다(웜업 루틴 수정과 같다).
                    // 슬라이더 아이콘은 검색창 옆이라 필터처럼 읽혔다.
                    Button {
                        managingSkills = true
                    } label: {
                        Image(systemName: "pencil")
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
    let lastActivity: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                SkillIconView(symbolName: skill.symbolName, size: 32)
                Spacer()
                // 불꽃은 웜업의 기호라 쌓인 피드백에는 버퍼 탭과 같은 말풍선을 쓴다.
                if activeCount > 0 {
                    countCapsule(count: activeCount, color: .accentColor, systemImage: "bubble.left.fill")
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
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Surface.card)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Line.color, lineWidth: DS.Line.width)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(skill.name)
        .accessibilityValue(accessibilityValue)
    }

    /// 개수는 옅게 칠한 캡슐에 담는다. 진하게 채우면 타일에서 가장 센 요소가 됐다.
    private func countCapsule(count: Int, color: Color, systemImage: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
            Text("\(count)")
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(color.readableText)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: Capsule())
    }

    private var footerText: String {
        let activityStr = lastActivity.map { relativeActivity(from: $0) }
        switch activeCount {
        case 0 where archivedCount == 0:
            return "쌓인 피드백 없음"
        case 0:
            return activityStr.map { "보관 \(archivedCount)개 · \($0)" } ?? "보관 \(archivedCount)개"
        default:
            return activityStr.map { "쌓인 \(activeCount)개 · \($0)" } ?? "쌓인 \(activeCount)개"
        }
    }

    private func relativeActivity(from date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        switch days {
        case 0: return "오늘"
        case 1: return "어제"
        case 2...6: return "\(days)일 전"
        default: return "\(days / 7)주 전"
        }
    }

    private var accessibilityValue: String {
        let base: String
        switch (activeCount, archivedCount) {
        case (0, 0): base = "쌓인 피드백 없음"
        case (let a, 0): base = "쌓인 피드백 \(a)개"
        case (0, let r): base = "보관된 피드백 \(r)개"
        case (let a, let r): base = "쌓인 \(a)개, 보관 \(r)개"
        }
        if let date = lastActivity {
            return "\(base), 마지막 활동 \(relativeActivity(from: date))"
        }
        return base
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
    LibraryView().environment(FeedbackStore())
}
