import SwiftUI

struct WarmupView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmingReset = false
    @State private var editingRoutine = false
    @State private var showingSessionPicker = false
    @State private var runningSession = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    sessionSwitcherRow
                }

                Section {
                    startCTA
                        .listRowInsets(EdgeInsets(top:0, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    progressHeader
                        .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
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
            .navigationTitle(store.currentWarmupSession?.name ?? "웜업")
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
            .sheet(isPresented: $showingSessionPicker) {
                WarmupSessionPickerSheet().environment(store)
            }
            .fullScreenCover(isPresented: $runningSession) {
                WarmupSessionRunnerView().environment(store)
            }
        }
    }

    @ViewBuilder
    private var startCTA: some View {
        let isComplete = store.isWarmupComplete
        let isEmpty = store.warmup.isEmpty
        let disabled = isComplete || isEmpty

        Button {
            runningSession = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isComplete ? "checkmark.seal.fill" : "play.fill")
                Text(isComplete ? "오늘 웜업 완료" : "오늘의 웜업 시작")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(isComplete ? .green : .accentColor)
        .disabled(disabled)
        .accessibilityLabel(isComplete ? "오늘 웜업 완료" : "오늘의 웜업 시작")
    }

    private var sessionSwitcherRow: some View {
        Button {
            showingSessionPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("세션 변경")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("항목 \(store.warmup.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
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
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityLabel("웜업 세션 변경")
        .accessibilityValue(store.currentWarmupSession?.name ?? "")
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
