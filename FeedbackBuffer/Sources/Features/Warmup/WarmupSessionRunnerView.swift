import SwiftUI

struct WarmupSessionRunnerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0

    private var items: [WarmupItem] { store.warmup }

    private var currentItem: WarmupItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    private var isFinished: Bool {
        currentIndex >= items.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if let item = currentItem, !isFinished {
                    itemCard(item: item)
                } else {
                    completionView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("닫기")
                }
            }
            .navigationTitle(store.currentWarmupSession?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func itemCard(item: WarmupItem) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 16) {
                ZStack {
                    if item.checked {
                        Label("이미 완료", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 32)

                Text("\(currentIndex + 1) / \(items.count)")
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(item.checked ? Color.secondary : Color.primary)

                Text(item.label)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(item.checked ? .secondary : .primary)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    advance()
                    store.setWarmupChecked(item.id, checked: true)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("완료")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    advance()
                } label: {
                    Text("건너뛰기")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var completionView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 88))
                .foregroundStyle(Color.green)

            Text("오늘의 웜업 완료")
                .font(.title.weight(.bold))

            Text("훈련 시작!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("닫기")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex += 1
        }
    }
}

#Preview {
    WarmupSessionRunnerView().environment(AppStore())
}
