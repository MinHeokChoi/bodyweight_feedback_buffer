import SwiftUI

/// 한 세션의 구간 타임라인.
struct WorkoutSessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                summary

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
