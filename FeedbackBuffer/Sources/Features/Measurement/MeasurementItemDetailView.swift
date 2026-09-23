import SwiftUI

/// 한 종목의 시즌별 이력. 이 화면이 기능의 목적 그 자체다 —
/// "지난 시즌엔 이 정도 했구나"를 보는 곳.
struct MeasurementItemDetailView: View {
    @Environment(MeasurementStore.self) private var store

    let item: MeasurementItem
    @State private var recording = false
    @State private var editing = false
    @State private var editingRecord: MeasurementRecord?
    @State private var pendingDeleteRecord: MeasurementRecord?

    private var current: MeasurementItem {
        store.item(item.id) ?? item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header

                let history = store.history(of: current)
                if history.isEmpty {
                    emptyState
                } else {
                    DSSectionLabel(text: "시즌별 기록")
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(history) { entry in
                            seasonCard(entry)
                        }
                    }
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Surface.page.ignoresSafeArea())
        .navigationTitle(current.movement)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    recording = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("측정값 기록")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("수정") { editing = true }
            }
        }
        .sheet(isPresented: $recording) {
            MeasurementRecordSheet(item: current).environment(store)
        }
        .sheet(isPresented: $editing) {
            MeasurementItemEditorSheet(item: current).environment(store)
        }
        .sheet(item: $editingRecord) { record in
            MeasurementRecordSheet(item: current, record: record).environment(store)
        }
        .confirmationDialog(
            "이 기록을 삭제할까요?",
            isPresented: Binding(
                get: { pendingDeleteRecord != nil },
                set: { if !$0 { pendingDeleteRecord = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let record = pendingDeleteRecord { store.deleteRecord(record.id) }
                pendingDeleteRecord = nil
            }
            Button("취소", role: .cancel) { pendingDeleteRecord = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                if !current.category.isEmpty {
                    DSPill(text: current.category, color: .accentColor)
                }
                DSPill(text: current.direction.displayName, color: .secondary)
            }

            if !current.constraint.isEmpty {
                Text(current.constraint)
                    .font(DS.Typo.metaLabel)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(padding: DS.Spacing.md)
    }

    private func seasonCard(_ entry: MeasurementProgress.SeasonEntry) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.season.name)
                    .font(DS.Typo.value)
                Spacer()
                Text(current.unit.format(entry.best))
                    .font(DS.Typo.metricValue)
            }

            HStack(spacing: DS.Spacing.sm) {
                MeasurementChangeBadge(entry: entry, unit: current.unit)
                if entry.records.count > 1 {
                    Text("\(entry.records.count)번 측정 · 가장 잘한 값")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // 값은 비교할 수 있게 보여주되, 조건이 달랐다면 숨기지 않는다.
            if entry.constraintChanged {
                Label("이때는 제약이 달랐어요", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            // 한 번만 잰 시즌도 줄을 그린다. 그래야 잘못 적은 값을 고치거나 지울 수 있다.
            Divider()
            ForEach(entry.records) { record in
                recordRow(record)
            }
        }
        .dsCard(padding: DS.Spacing.md)
    }

    private func recordRow(_ record: MeasurementRecord) -> some View {
        Button {
            editingRecord = record
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(record.measuredAt, format: .dateTime.month().day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(current.unit.format(record.value))
                        .font(DS.Typo.number)
                        .foregroundStyle(.primary)
                }
                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("누르면 고칠 수 있어요")
        .contextMenu {
            Button("수정", systemImage: "pencil") {
                editingRecord = record
            }
            Button("삭제", systemImage: "trash", role: .destructive) {
                pendingDeleteRecord = record
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("아직 잰 적이 없어요")
                .font(DS.Typo.value)
            Text("오른쪽 위 + 로 이번 시즌 결과를 남겨보세요.")
                .font(DS.Typo.metaLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}
