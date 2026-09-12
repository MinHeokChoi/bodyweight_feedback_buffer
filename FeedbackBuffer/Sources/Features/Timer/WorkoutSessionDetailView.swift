import SwiftUI

/// 한 세션의 구간 타임라인.
struct WorkoutSessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                summary

                kindTotals

                DSSectionLabel(text: "구간 타임라인")

                VStack(spacing: DS.Spacing.sm) {
                    ForEach(session.segments) { segment in
                        segmentCard(segment)
                    }
                }

                if !session.note.isEmpty {
                    DSSectionLabel(text: "메모")
                    Text(session.note)
                        .font(DS.Typo.metaLabel)
                        .dsCard(padding: DS.Spacing.md)
                }
            }
            .padding(DS.Spacing.lg)
        }
        .background(DS.Surface.page.ignoresSafeArea())
        .navigationTitle(Text(session.startedAt, format: .dateTime.month().day().weekday()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                DSMetric(label: "운동 시간", value: WorkoutTimeFormat.compact(session.trainingDuration()))
                DSMetric(label: "휴식", value: WorkoutTimeFormat.compact(session.restDuration()))
            }
            HStack(spacing: DS.Spacing.sm) {
                DSMetric(
                    label: "시작",
                    value: session.startedAt.formatted(date: .omitted, time: .shortened)
                )
                DSMetric(
                    label: "종료",
                    value: session.endedAt?.formatted(date: .omitted, time: .shortened) ?? "-"
                )
            }
            SegmentRatioBar(byKind: session.durationByKind(), rest: session.restDuration())
        }
    }

    /// 구간별 누적. 같은 구간을 여러 번 했을 때 합친 시간이 여기서 드러난다.
    /// 아래 타임라인은 순서와 랩을 보여주므로 둘은 서로를 대체하지 않는다.
    private var kindTotals: some View {
        let byKind = session.durationByKind()
        let entries = TrainingPhaseKind.recommendedOrder.compactMap { kind -> (TrainingPhaseKind, TimeInterval, Int)? in
            guard let duration = byKind[kind], duration > 0 else { return nil }
            let blocks = session.segments.filter { $0.kind == kind }.count
            return (kind, duration, blocks)
        }

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionLabel(text: "구간별 누적")

            VStack(spacing: DS.Spacing.xs) {
                ForEach(entries, id: \.0) { kind, duration, blocks in
                    HStack(spacing: DS.Spacing.sm) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(kind.tint)
                            .frame(width: 8, height: 8)
                        Text(kind.displayName)
                            .font(DS.Typo.metaLabel)
                        if blocks > 1 {
                            Text("\(blocks)회")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(WorkoutTimeFormat.clock(duration))
                            .font(DS.Typo.number)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func segmentCard(_ segment: TrainingSegment) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Label(segment.kind.displayName, systemImage: segment.kind.systemImage)
                    .font(DS.Typo.value)
                    .foregroundStyle(segment.kind.tint)
                Spacer()
                Text(WorkoutTimeFormat.clock(segment.duration(pauses: session.pauses)))
                    .font(DS.Typo.number)
            }

            Text("\(segment.startedAt.formatted(date: .omitted, time: .shortened)) – \(segment.endedAt?.formatted(date: .omitted, time: .shortened) ?? "진행 중")")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !segment.laps.isEmpty {
                Divider()
                ForEach(segment.laps) { lap in
                    HStack {
                        Text("\(lap.index)번째 운동")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(WorkoutTimeFormat.clock(lap.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(lap.duration >= lap.targetDuration ? .primary : .secondary)
                    }
                }
            }
        }
        .dsCard(padding: DS.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}
