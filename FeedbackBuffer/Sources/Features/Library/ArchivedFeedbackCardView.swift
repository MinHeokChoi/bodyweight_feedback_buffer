import SwiftUI

struct ArchivedFeedbackCardView: View {
    let feedback: Feedback
    let onUnarchive: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
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

    private var cueView: some View {
        HStack(alignment: .top, spacing: 6) {
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                metaChip(systemImage: "calendar.badge.plus", text: "추가 \(feedback.daysSinceCreated)일 전")
                if let archivedAt = feedback.archivedAt {
                    metaChip(systemImage: "archivebox", text: "보관 \(feedback.daysSince(archivedAt))일 전")
                }
            }
            HStack(spacing: 14) {
                metaChip(systemImage: "clock", text: "마지막 연습 \(feedback.daysSinceLastReviewed)일 전")
                metaChip(systemImage: "exclamationmark.bubble", text: "총 연습 \(feedback.unresolvedCount)회")
                CategoryChip(category: feedback.category)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            actionButton("다시 연습", systemImage: "arrow.uturn.backward", tint: .blue, action: onUnarchive)
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
            .modifier(ArchivedActionSurface(tint: tint))
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

private struct ArchivedActionSurface: ViewModifier {
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
