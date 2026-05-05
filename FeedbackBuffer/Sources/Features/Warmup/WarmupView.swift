import SwiftUI

struct WarmupView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmingReset = false
    @State private var editingRoutine = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    progressHeader
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section("오늘의 웜업") {
                    ForEach(store.warmup) { item in
                        WarmupRowView(item: item) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                store.toggleWarmup(item.id)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }

                resetSection
            }
            .navigationTitle("웜업")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingRoutine = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("웜업 루틴 수정")
                }
            }
            .sheet(isPresented: $editingRoutine) {
                WarmupRoutineEditorView().environment(store)
            }
        }
    }

    @ViewBuilder
    private var resetSection: some View {
        if confirmingReset {
            Section {
                Button(role: .destructive) {
                    withAnimation {
                        store.resetWarmupToday()
                        confirmingReset = false
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("예", systemImage: "checkmark")
                }

                Button(role: .cancel) {
                    withAnimation { confirmingReset = false }
                } label: {
                    Label("아니오", systemImage: "xmark")
                }
            } header: {
                Text("오늘의 웜업 체크를 모두 해제할까요?")
            }
        } else {
            Section {
                Button(role: .destructive) {
                    withAnimation { confirmingReset = true }
                } label: {
                    Label("다시 웜업하기", systemImage: "arrow.counterclockwise")
                }
                .disabled(!store.warmup.contains(where: \.checked))
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("진행률")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(store.warmupCompletionRatio * 100))%")
                    .font(.headline.monospacedDigit())
            }

            progressBar

            if store.isWarmupComplete {
                Label("훈련 준비 완료", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("\(store.warmup.filter(\.checked).count) / \(store.warmup.count) 항목 완료")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 0.5)
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let ratio = min(max(store.warmupCompletionRatio, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))

                Capsule()
                    .fill(store.isWarmupComplete ? Color.green : Color.accentColor)
                    .frame(width: proxy.size.width * ratio)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("웜업 진행률")
        .accessibilityValue("\(Int(store.warmupCompletionRatio * 100))퍼센트")
    }
}

#Preview {
    WarmupView().environment(AppStore())
}
