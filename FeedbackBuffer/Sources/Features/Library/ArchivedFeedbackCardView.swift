import SwiftUI

struct ArchivedFeedbackCardView: View {
    let feedback: Feedback
    let onUnarchive: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false
    @Environment(\.dynamicTypeSize) private var typeSize

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
        .dsCard(padding: 14)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .confirmationDialog(
            "이 피드백을 삭제할까요?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive, action: onDelete)
            Button("취소", role: .cancel) { }
        } message: {
            Text("지우면 되돌릴 수 없어요.")
        }
    }

    /// 보관함은 기술 화면 안에만 있다. 카드마다 같은 기술명을 되풀이하지 않는다.
    private var header: some View {
        CardHeaderText(skillName: nil, title: feedback.title)
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
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: DS.Radius.inner, style: .continuous))
    }

    /// 큰 글씨에서는 한 줄에 칩 하나씩 쌓는다. 너비를 재서 고르면(ViewThatFits)
    /// 어느 쪽도 맞지 않을 때 넘친 채로 그려져 카드가 화면 밖으로 밀렸다.
    private var metaRow: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    addedChip
                    archivedChip
                    lastPracticedChip
                    practiceCountChip
                    CategoryChip(category: feedback.category)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 14) {
                        addedChip
                        archivedChip
                    }
                    HStack(spacing: 14) {
                        lastPracticedChip
                        practiceCountChip
                        CategoryChip(category: feedback.category)
                    }
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var addedChip: some View {
        metaChip(systemImage: "calendar.badge.plus", text: "추가 \(feedback.daysSinceCreated)일 전")
    }

    @ViewBuilder
    private var archivedChip: some View {
        if let archivedAt = feedback.archivedAt {
            metaChip(systemImage: "archivebox", text: "보관 \(feedback.daysSince(archivedAt))일 전")
        }
    }

    /// 버퍼 카드와 같은 문법. 자주 누르는 것은 글자 버튼, 삭제는 아이콘만.
    private var actions: some View {
        HStack(spacing: 8) {
            CardActionButton.labeled(
                "다시 연습",
                systemImage: "arrow.uturn.backward",
                tint: .accentColor,
                text: DS.Tint.accentText,
                action: onUnarchive
            )
            CardActionButton.icon("삭제", systemImage: "trash") { showingDeleteConfirm = true }
        }
    }

    /// 한 번도 또 하지 않았으면 날짜를 지어내지 않는다. 수정 화면의 "아직 없음"과 같은 말이다.
    private var lastPracticedChip: some View {
        metaChip(
            systemImage: "clock",
            text: feedback.lastReviewedAt == nil
                ? "마지막 연습 아직 없음"
                : "마지막 연습 \(feedback.daysSinceLastReviewed)일 전"
        )
    }

    private var practiceCountChip: some View {
        metaChip(systemImage: "exclamationmark.bubble", text: "총 연습 \(feedback.unresolvedCount)회")
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
