import SwiftUI

struct FeedbackCardView: View {
    let feedback: Feedback
    /// 기술 화면이나 기술 필터 중에는 모든 카드의 기술이 같다. 그때는 숨긴다.
    var showsSkillName = true
    let onArchive: () -> Void
    let onMarkPracticed: () -> Void
    let onEdit: () -> Void
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

    /// 기술명은 작게, 빈 공간은 온전한 글자색으로. 둘이 같은 굵기라 한 문장처럼 읽혔다.
    /// 한 덩어리 글로 이어 붙여서 큰 글씨에서도 제목이 좁은 칸에 들여 써지지 않고 자연스럽게 줄바꿈된다.
    private var header: some View {
        CardHeaderText(skillName: showsSkillName ? feedback.skillName : nil, title: feedback.title)
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

    /// 카드에는 중요도만 둔다. 순서를 사용자가 정하게 되면서 나머지 숫자는
    /// 설명해야 할 짐이 됐다. 연습 횟수는 수정 화면에서 볼 수 있다.
    private var metaRow: some View {
        HStack(spacing: 14) {
            ImportanceStars(importance: feedback.importance)
            // 오래 묵은 것만 스스로 드러난다. 순서는 건드리지 않는다.
            if feedback.isStale {
                metaChip(systemImage: "clock", text: "\(feedback.daysSinceLastReviewed)일째")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("\(feedback.daysSinceLastReviewed)일째 손대지 않음")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// 자주 누르는 해결·또 하기는 글자가 붙은 넓은 버튼, 드물게 누르는 수정·삭제는 아이콘만.
    /// 순서는 그대로 둔다 — 손이 자리를 기억한다. 큰 글씨에서는 두 줄로 나눈다.
    private var actions: some View {
        let resolve = CardActionButton.labeled(
            "해결", systemImage: "checkmark.circle", tint: .green, text: DS.Tint.successText, action: onArchive
        )
        let again = CardActionButton.labeled(
            "또 하기", systemImage: "arrow.clockwise", tint: .accentColor, text: DS.Tint.accentText, action: onMarkPracticed
        )
        let edit = CardActionButton.icon("수정", systemImage: "pencil", action: onEdit)
        let delete = CardActionButton.icon("삭제", systemImage: "trash") { showingDeleteConfirm = true }

        // 넓이를 재서 고르는 방식(ViewThatFits)은 버튼이 늘어나는 폭이라 줄바꿈을 고르지 못했다.
        // 글자 크기로 정한다.
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        resolve
                        again
                    }
                    HStack(spacing: 8) {
                        edit
                        delete
                    }
                }
            } else {
                HStack(spacing: 8) {
                    resolve
                    again
                    edit
                    delete
                }
            }
        }
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

/// 카드 첫 줄. 기술명은 작고 흐리게, 빈 공간은 또렷하게.
struct CardHeaderText: View {
    let skillName: String?
    let title: String

    var body: some View {
        text
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var text: Text {
        let title = Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
        guard let skillName else { return title }
        return Text(skillName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            + Text("  ")
            + title
    }
}

/// 카드 아래 버튼. 모두 44pt 높이라 한 손으로 눌러도 옆 버튼을 치지 않는다.
struct CardActionButton: View {
    private enum Style {
        case labeled(tint: Color, text: Color)
        case icon
    }

    private let title: String
    private let systemImage: String
    private let style: Style
    private let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    static func labeled(
        _ title: String,
        systemImage: String,
        tint: Color,
        text: Color,
        action: @escaping () -> Void
    ) -> CardActionButton {
        CardActionButton(title: title, systemImage: systemImage, style: .labeled(tint: tint, text: text), action: action)
    }

    static func icon(_ title: String, systemImage: String, action: @escaping () -> Void) -> CardActionButton {
        CardActionButton(title: title, systemImage: systemImage, style: .icon, action: action)
    }

    var body: some View {
        Button(action: action) {
            switch style {
            case let .labeled(tint, text):
                // 큰 글씨에서는 아이콘을 빼고 글자에 자리를 준다. 아이콘 때문에 "또..."로 잘렸다.
                Label(title, systemImage: systemImage)
                    .labelStyle(TitleOnlyWhen(typeSize.isAccessibilitySize))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(text)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(tint.opacity(0.14), in: Capsule())
                    .contentShape(Capsule())
            case .icon:
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemFill), in: Circle())
                    .contentShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct TitleOnlyWhen: LabelStyle {
    let titleOnly: Bool

    init(_ titleOnly: Bool) {
        self.titleOnly = titleOnly
    }

    func makeBody(configuration: Configuration) -> some View {
        if titleOnly {
            configuration.title
        } else {
            Label(configuration)
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
