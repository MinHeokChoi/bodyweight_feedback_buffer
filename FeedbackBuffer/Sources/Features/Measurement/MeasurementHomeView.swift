import SwiftUI

/// 시즌 측정 기록의 첫 화면. 종목을 카테고리로 묶어 보여주고,
/// 각 종목의 최신 시즌 결과와 직전 시즌 대비 변화를 함께 적는다.
struct MeasurementHomeView: View {
    @Environment(MeasurementStore.self) private var store

    @State private var editingItem: MeasurementItem?
    @State private var creatingItem = false
    @State private var managingSeasons = false
    @State private var recordingFor: MeasurementItem?
    @State private var pendingDeleteItem: MeasurementItem?

    var body: some View {
        Group {
            if store.items.isEmpty {
                // 종목을 다 지워도 시즌은 남는다. 시즌 관리로 가는 길은 빈 화면에도 둔다.
                VStack(spacing: 0) {
                    if !store.seasons.isEmpty {
                        currentSeasonBar
                            .padding(DS.Spacing.lg)
                    }
                    emptyState
                }
            } else {
                list
            }
        }
        .background(DS.Surface.page.ignoresSafeArea())
        .navigationTitle("시즌 측정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 시즌 관리는 "이번 시즌" 줄을 눌러 연다. 뒤로 가기 옆의 달력 아이콘은
            // 무엇을 여는지 알기 어려웠다.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    creatingItem = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("측정 종목 추가")
            }
        }
        .sheet(isPresented: $creatingItem) {
            MeasurementItemEditorSheet(item: nil).environment(store)
        }
        .sheet(item: $editingItem) { item in
            MeasurementItemEditorSheet(item: item).environment(store)
        }
        .sheet(item: $recordingFor) { item in
            MeasurementRecordSheet(item: item).environment(store)
        }
        .sheet(isPresented: $managingSeasons) {
            MeasurementSeasonsSheet().environment(store)
        }
        // 종목을 지우면 모든 시즌의 기록이 함께 사라진다. 되돌릴 수 없으니 한 번 묻는다.
        .confirmationDialog(
            "‘\(pendingDeleteItem?.movement ?? "")’ 종목을 삭제할까요?",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let item = pendingDeleteItem { store.deleteItem(item.id) }
                pendingDeleteItem = nil
            }
            Button("취소", role: .cancel) { pendingDeleteItem = nil }
        } message: {
            if let item = pendingDeleteItem, store.recordCount(of: item) > 0 {
                Text("측정 기록 \(store.recordCount(of: item))개도 함께 사라져요.")
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
                currentSeasonBar

                ForEach(store.itemsByCategory, id: \.category) { group in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionLabel(text: group.category.isEmpty ? "기타" : group.category)

                        ForEach(group.items) { item in
                            NavigationLink {
                                MeasurementItemDetailView(item: item)
                            } label: {
                                itemRow(item)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("측정값 기록", systemImage: "plus.circle") {
                                    recordingFor = item
                                }
                                Button("종목 수정", systemImage: "pencil") {
                                    editingItem = item
                                }
                                Button("종목 삭제", systemImage: "trash", role: .destructive) {
                                    pendingDeleteItem = item
                                }
                            }
                        }
                    }
                }
            }
            .padding(DS.Spacing.lg)
        }
    }

    private var currentSeasonBar: some View {
        Button {
            managingSeasons = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text("이번 시즌")
                    .font(DS.Typo.metaLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.currentSeason?.name ?? "아직 없음")
                    .font(DS.Typo.value)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .dsCard(padding: DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("시즌을 관리해요")
    }

    private func itemRow(_ item: MeasurementItem) -> some View {
        let history = store.history(of: item)
        let latest = history.first

        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.movement)
                    .font(DS.Typo.value)
                Spacer()
                if let latest {
                    Text(item.unit.format(latest.best))
                        .font(DS.Typo.metricValue)
                } else {
                    Text("기록 없음")
                        .font(DS.Typo.metaLabel)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(spacing: DS.Spacing.sm) {
                if let latest {
                    Text(latest.season.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    MeasurementChangeBadge(entry: latest, unit: item.unit)
                } else if !item.constraint.isEmpty {
                    Text(item.constraint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .dsCard(padding: DS.Spacing.md)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "ruler")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("아직 측정 종목이 없어요")
                .font(DS.Typo.value)
            Text("풀업 최대 개수, 물구나무 밸런스처럼\n시즌마다 재는 것을 만들어 두세요.")
                .font(DS.Typo.metaLabel)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("첫 종목 만들기") { creatingItem = true }
                .buttonStyle(.borderedProminent)
                .padding(.top, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.lg)
    }
}

/// 직전 시즌 대비 변화. 방향을 이미 적용한 값이므로 양수면 언제나 개선이다.
struct MeasurementChangeBadge: View {
    let entry: MeasurementProgress.SeasonEntry
    let unit: MeasurementUnit

    var body: some View {
        if let improvement = entry.improvement, improvement != 0 {
            Label(
                unit.format(abs(improvement)),
                systemImage: improvement > 0 ? "arrow.up.right" : "arrow.down.right"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle((improvement > 0 ? Color.green : Color.orange).readableText)
            .accessibilityLabel(improvement > 0 ? "개선" : "후퇴")
            .accessibilityValue(unit.format(abs(improvement)))
        }
    }
}
