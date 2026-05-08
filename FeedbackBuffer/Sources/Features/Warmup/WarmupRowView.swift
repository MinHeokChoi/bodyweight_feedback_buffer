import SwiftUI

struct WarmupRowView: View {
    let item: WarmupItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(item.checked ? Color.accentColor : Color.secondary)
                .contentTransition(.symbolEffect(.replace))

            Text(item.label)
                .font(.body)
                .foregroundStyle(item.checked ? Color.secondary : Color.primary)
                .strikethrough(item.checked, color: .secondary)

            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.label), \(item.checked ? "완료" : "대기")")
    }
}
