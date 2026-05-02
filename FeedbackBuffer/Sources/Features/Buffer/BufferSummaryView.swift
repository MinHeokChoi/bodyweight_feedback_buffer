import SwiftUI

struct BufferSummaryView: View {
    let activeCount: Int
    let topFeedback: Feedback?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            metric(label: "남은 피드백", value: "\(activeCount)", systemImage: "tray.full")

            if let top = topFeedback {
                VStack(alignment: .leading, spacing: 6) {
                    Label("오늘 1순위", systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(top.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text(top.skillName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func metric(label: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
