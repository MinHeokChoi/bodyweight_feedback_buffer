import SwiftUI

/// 구간 선택 격자.
///
/// 대기 화면과 휴식 화면이 이 하나를 공유한다. 둘 다 "어떤 구간을 시작할까"를
/// 묻는 같은 질문이고, 차이는 누적 타이머가 이미 돌고 있는지뿐이다.
struct SegmentPickerGrid: View {
    var highlighted: TrainingPhaseKind?
    let onSelect: (TrainingPhaseKind) -> Void

    /// 카드 순서는 언제나 같다.
    ///
    /// 다음에 할 법한 구간을 앞으로 끌어올리면 상황마다 위치가 달라져, 운동
    /// 중에 카드를 매번 읽고 찾아야 한다. 제안은 위치가 아니라 테두리로만
    /// 표시한다.
    private var kinds: [TrainingPhaseKind] { TrainingPhaseKind.recommendedOrder }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: DS.Spacing.sm),
                      GridItem(.flexible(), spacing: DS.Spacing.sm)],
            spacing: DS.Spacing.sm
        ) {
            ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                button(for: kind, isSuggested: kind == highlighted)
                    .gridCellColumns(index == kinds.count - 1 && kinds.count % 2 == 1 ? 2 : 1)
            }
        }
    }

    private func button(for kind: TrainingPhaseKind, isSuggested: Bool) -> some View {
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
            // 제안은 자리를 옮기지 않고 바탕을 칠해 알린다. 테두리만으로는 멀리서 잘 안 보였다.
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Surface.card)
                    .overlay {
                        if isSuggested {
                            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                                .fill(kind.tint.opacity(0.14))
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(
                        isSuggested ? kind.tint.opacity(0.8) : DS.Line.color,
                        lineWidth: isSuggested ? 1.5 : DS.Line.width
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.displayName) 시작")
        .accessibilityHint(isSuggested ? "다음으로 할 만한 구간이에요" : "")
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
        case .running: DS.Segment.running
        }
    }
}
