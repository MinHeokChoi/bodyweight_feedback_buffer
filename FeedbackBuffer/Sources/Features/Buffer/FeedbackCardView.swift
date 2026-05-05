import SwiftUI

struct FeedbackCardView: View {
    let feedback: Feedback
    let score: Double
    let onResolve: () -> Void
    let onMarkUnresolved: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    private var tier: FeedbackScoring.Tier { FeedbackScoring.tier(for: score) }

    private var tierColor: Color {
        switch tier {
        case .critical: .red
        case .high: .orange
        case .medium: .yellow
        case .low: .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(tierColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    header
                    if !feedback.note.isEmpty {
                        cueView
                    }
                }
                metaRow
                actions
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .confirmationDialog(
            "이 피드백을 삭제할까요?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive, action: onDelete)
            Button("취소", role: .cancel) { }
        } message: {
            Text("삭제 후에는 되돌릴 수 없습니다.")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(feedback.skillName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(feedback.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .lineLimit(2)
                }
            }
            Spacer()
            Text("\(Int(score.rounded()))점")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tierColor)
        }
    }

    private var cueView: some View {
        HStack(alignment: .top, spacing: 6) {
//            Image(systemName: "quote.opening")
//                .font(.caption.weight(.semibold))
//                .foregroundStyle(.secondary)
//                .padding(.top, 2)

            Text(feedback.note)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var metaRow: some View {
        HStack(spacing: 14) {
            ImportanceStars(importance: feedback.importance)
            metaChip(systemImage: "exclamationmark.bubble", text: "연습 \(feedback.unresolvedCount)회")
            metaChip(systemImage: "clock", text: "\(feedback.daysSinceLastReviewed)일 경과")
            CategoryChip(category: feedback.category)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            actionButton("해결", systemImage: "checkmark.circle.fill", tint: .green, action: onResolve)
            actionButton("미해결", systemImage: "face.dashed", tint: .orange, action: onMarkUnresolved)
            actionButton("수정", systemImage: "pencil", tint: .blue, action: onEdit)
            actionButton("삭제", systemImage: "trash", tint: .red) { showingDeleteConfirm = true }
        }
    }

    private func actionButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 34)
            .modifier(ActionButtonSurface(tint: tint))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func metaChip(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct ActionButtonSurface: ViewModifier {
    let tint: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint.opacity(0.18)).interactive(), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                }
        } else {
            content
                .background(tint.opacity(0.18), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(tint.opacity(0.42), lineWidth: 1)
                }
        }
    }
}

private struct ImportanceStars: View {
    let importance: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= importance ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(i <= importance ? .yellow : .secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("중요도")
        .accessibilityValue("\(importance) / 5")
    }
}

struct CategoryChip: View {
    let category: FeedbackCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.systemImage)
            Text(category.displayName)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .fixedSize(horizontal: true, vertical: false)
    }
}
