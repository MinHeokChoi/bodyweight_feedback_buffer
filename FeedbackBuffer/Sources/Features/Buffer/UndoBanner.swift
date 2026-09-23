import SwiftUI

/// 해결·또 하기를 누른 뒤 잠깐 뜨는 되돌리기 띠.
///
/// 숫자나 축하 문구는 넣지 않는다. 세는 숫자가 또 하나의 점수가 되지 않게 하고(B14),
/// 잘못 누른 것을 그 자리에서 되돌릴 수 있게만 한다.
struct UndoBanner: View {
    let action: FeedbackStore.UndoableAction
    let onUndo: () -> Void

    private var message: String {
        switch action.kind {
        case .archive: "‘\(action.previous.title)’ 해결함"
        case .practiced: "‘\(action.previous.title)’ 또 하기"
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Text(message)
                .font(DS.Typo.metaLabel)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 누르는 영역은 버튼 안쪽(label)에 잡아야 44pt 전체가 눌린다.
            Button(action: onUndo) {
                Text("되돌리기")
                    .font(DS.Typo.buttonLabel)
                    .foregroundStyle(DS.Tint.accentText)
                    .padding(.horizontal, DS.Spacing.sm)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, DS.Spacing.lg)
        .padding(.trailing, DS.Spacing.md)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(DS.Line.color, lineWidth: DS.Line.width)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
        // 띠가 떠 있는 동안 다른 카드를 누르면 띠는 그대로 두고 내용만 바뀐다.
        // 그때도 무엇을 되돌리게 됐는지 읽어 준다.
        .onChange(of: action.id, initial: true) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

extension View {
    /// 화면 아래에 되돌리기 띠를 붙인다. 시간이 지나면 저절로 사라진다.
    func undoBanner() -> some View {
        modifier(UndoBannerHost())
    }
}

private struct UndoBannerHost: ViewModifier {
    @Environment(FeedbackStore.self) private var store

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                // 다른 탭에 있다 돌아왔을 때 이미 지난 띠가 잠깐 비치지 않게 시각도 본다.
                if let action = store.undoableAction, action.expiresAt > .now {
                    UndoBanner(action: action) {
                        withAnimation { store.undoLastAction() }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: action.id) {
                        try? await Task.sleep(for: .seconds(max(0, action.expiresAt.timeIntervalSinceNow)))
                        // 탭을 옮겨 작업이 취소된 것은 시간이 다 된 것이 아니다.
                        guard !Task.isCancelled else { return }
                        withAnimation { store.expireUndo(action.id) }
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: store.undoableAction?.id)
    }
}
