import SwiftUI

/// 구간 선택 격자.
///
/// 대기 화면과 휴식 화면이 이 하나를 공유한다. 둘 다 "어떤 구간을 시작할까"를
/// 묻는 같은 질문이고, 차이는 누적 타이머가 이미 돌고 있는지뿐이다.
struct SegmentPickerGrid: View {
    var highlighted: TrainingPhaseKind?
    let onSelect: (TrainingPhaseKind) -> Void

    private var kinds: [TrainingPhaseKind] {
        guard let highlighted else { return TrainingPhaseKind.recommendedOrder }
        // 다음에 할 법한 구간을 맨 앞으로 올린다. 순서만 바뀌고 목록은 같다.
        var ordered = TrainingPhaseKind.recommendedOrder
        ordered.removeAll { $0 == highlighted }
        return [highlighted] + ordered
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: DS.Spacing.sm),
                      GridItem(.flexible(), spacing: DS.Spacing.sm)],
            spacing: DS.Spacing.sm
        ) {
            ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                button(for: kind, isLead: index == 0)
                    .gridCellColumns(index == kinds.count - 1 && kinds.count % 2 == 1 ? 2 : 1)
            }
        }
    }

    private func button(for kind: TrainingPhaseKind, isLead: Bool) -> some View {
        Button {
            onSelect(kind)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: kind.systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(kind.tint)
                Text(kind.displayName)
                    .font(DS.Typo.buttonLabel)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, DS.Spacing.xs)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Surface.card)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(
                        isLead ? kind.tint.opacity(0.6) : DS.Line.color,
                        lineWidth: isLead ? 1 : DS.Line.width
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.displayName) 시작")
    }
}

extension TrainingPhaseKind {
    /// 구간 구분색. 앱 아이콘에서 파생한 팔레트를 쓴다.
    var tint: Color {
        switch self {
        case .stretching: DS.Segment.stretching
        case .warmup: DS.Segment.warmup
        case .skillPractice: DS.Segment.skillPractice
        case .strength: DS.Segment.strength
        case .fatigueResistance: DS.Segment.fatigueResistance
        }
    }
}
