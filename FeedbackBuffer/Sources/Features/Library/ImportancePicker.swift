import SwiftUI

struct ImportancePicker: View {
    @Binding var importance: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        importance = value
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Image(systemName: value <= importance ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(value <= importance ? .yellow : .secondary)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("중요도 \(value)")
                    .accessibilityValue(value == importance ? "선택됨" : "선택 안 됨")
                }
            }
            Text(label(for: importance))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func label(for value: Int) -> String {
        switch value {
        case 1: "가볍게 메모만"
        case 2: "여유 될 때 점검"
        case 3: "보통"
        case 4: "다음 훈련에 꼭 점검"
        case 5: "최우선 과제"
        default: ""
        }
    }
}
