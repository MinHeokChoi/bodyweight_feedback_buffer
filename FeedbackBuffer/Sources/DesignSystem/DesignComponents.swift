import SwiftUI

// MARK: - Card

extension View {
    /// 목업 문법의 카드: radius 12, 0.5pt hairline, secondary grouped 배경.
    func dsCard(padding: CGFloat = DS.Spacing.lg) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Surface.card)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .stroke(DS.Line.color, lineWidth: DS.Line.width)
            }
    }

    /// 테두리 없이 배경 tint만 쓰는 지표 타일.
    func dsTile(padding: CGFloat = DS.Spacing.md) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Surface.tile)
            }
    }
}

// MARK: - Bordered button

extension View {
    /// 테두리 버튼. 글자가 회색 바탕 위에 놓이므로 accent 코랄은 진한 글자색으로 쓴다.
    /// 코랄 그대로는 회색 바탕 위에서 약 2.2:1이었다("일시정지", "건너뛰기").
    func dsBorderedButton(tint: Color = DS.Tint.accentText) -> some View {
        buttonStyle(.bordered).tint(tint)
    }
}

// MARK: - Pill

/// 구간명처럼 상태를 나타내는 캡슐. 기존 웜업 러너의 "이미 완료" 배지와 같은 문법이다.
/// 바탕은 색을 옅게 깔고, 글자는 같은 색을 진하게 써서 읽히게 한다.
struct DSPill: View {
    let text: String
    var color: Color = .accentColor

    var body: some View {
        Text(text)
            .font(DS.Typo.metaLabel.weight(.semibold))
            .foregroundStyle(color.readableText)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Metric tile

/// 작은 뮤트 라벨 위, 큰 값 아래. 통계 요약에 쓴다.
/// 한 줄에 둘씩 놓이므로 설명이 없는 타일도 옆 타일과 높이를 맞춘다. 쓰는 곳의 HStack에는
/// `.fixedSize(horizontal: false, vertical: true)`를 건다.
struct DSMetric: View {
    let label: String
    let value: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typo.sectionLabel)
                .foregroundStyle(.secondary)
            Text(value)
                .font(DS.Typo.metricValue)
                .foregroundStyle(.primary)
            if let caption {
                Text(caption)
                    .font(DS.Typo.sectionLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dsTile()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Section label

struct DSSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DS.Typo.sectionLabel)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
