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
        case .high: .red
        case .medium: .orange
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
                        Text(feedback.note)
                            .font(.subheadline)
                            .lineLimit(3)
                    }
                }
                metaRow
                actions
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
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
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", score))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(tierColor)
                Text("점")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 14) {
            ImportanceStars(importance: feedback.importance)
            metaChip(systemImage: "exclamationmark.bubble", text: "연습 횟수 \(feedback.unresolvedCount)")
            metaChip(systemImage: "clock", text: "\(feedback.daysSinceLastReviewed)일 경과")
            CategoryChip(category: feedback.category)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func metaChip(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
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
                    .font(.caption)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(tint)
    }
}

struct CategoryChip: View {
    let category: FeedbackCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.systemImage)
                //.foregroundStyle(tint)
            Text(category.displayName)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
//        .background(tint.opacity(0.16), in: Capsule())
//        .overlay {
//            Capsule()
//                .stroke(tint.opacity(0.42), lineWidth: 1)
//        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var tint: Color {
        switch category {
        case .physical: .teal
        case .skill: .blue
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
    }
}
