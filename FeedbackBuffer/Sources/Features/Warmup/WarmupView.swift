import SwiftUI

struct WarmupView: View {
    @Environment(WarmupStore.self) private var store
    @State private var confirmingReset = false
    @State private var editingRoutine = false
    @State private var showingSessionPicker = false
    @State private var runningSession = false

    var body: some View {
        NavigationStack {
            // 항목 목록은 두지 않는다. 시작을 누르면 러너에서 하나씩 보이므로
            // 탭에서 미리 볼 이유가 없다. 여기서 답할 질문은 하나뿐이다 —
            // 지금 시작할까, 오늘 이미 했나.
            List {
                Section {
                    routineRow
                }

                Section {
                    startCTA
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    progressHeader
                        .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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
            .sheet(isPresented: $showingSessionPicker) {
                WarmupSessionPickerSheet().environment(store)
            }
            .fullScreenCover(isPresented: $runningSession) {
                WarmupSessionRunnerView().environment(store)
            }
        }
    }

    /// 완료한 뒤에도 다시 시작할 수 있다. 하루에 두 번 하는 날이 있고,
    /// 건너뛴 항목을 마저 하고 싶을 때도 이 버튼으로 들어간다.
    @ViewBuilder
    private var startCTA: some View {
        // 오늘 할 일이 끝났으면 화면에서 가장 센 요소일 이유가 없다.
        if store.isWarmupComplete {
            startButton(title: "웜업 다시 하기", symbol: "arrow.counterclockwise")
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(store.warmup.isEmpty)
        } else {
            startButton(title: "오늘의 웜업 시작", symbol: "play.fill")
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.warmup.isEmpty)
        }
    }

    private func startButton(title: String, symbol: String) -> some View {
        Button {
            runningSession = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityLabel(title)
    }

    private var routineRow: some View {
        Button {
            showingSessionPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    // 고정 문구 대신 지금 고른 루틴 이름을 보여준다.
                    Text(store.currentWarmupSession?.name ?? "루틴 없음")
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
        .accessibilityLabel("웜업 루틴 변경")
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
                Text("오늘의 웜업 기록을 지울까요?")
            }
        } else {
            Section {
                Button(role: .destructive) {
                    withAnimation { confirmingReset = true }
                } label: {
                    Label("오늘 기록 지우기", systemImage: "arrow.counterclockwise")
                }
                .disabled(!store.isWarmupComplete && store.checkedCount == 0)
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.isWarmupComplete ? "오늘의 웜업" : "진행률")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                // 건너뛰고 끝냈으면 100%가 아니다. 완료했다고 퍼센트를 부풀리는 대신
                // 실제로 몇 개를 했는지 그대로 적는다.
                if store.isWarmupComplete {
                    Text(completionDetail)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(Int(store.warmupCompletionRatio * 100))%")
                        .font(.headline.monospacedDigit())
                }
            }

            progressBar

            if store.isWarmupComplete {
                Label("오늘의 웜업 완료!", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("\(store.checkedCount) / \(store.warmup.count) 항목 완료")
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

    private var completionDetail: String {
        let skipped = store.skippedCount
        guard skipped > 0 else { return "\(store.checkedCount)개 완료" }
        return "\(store.checkedCount)개 완료 · \(skipped)개 건너뜀"
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            // 완료하면 막대는 가득 찬다. 숫자는 위에서 사실대로 말하고 있다.
            let ratio = store.isWarmupComplete
                ? 1
                : min(max(store.warmupCompletionRatio, 0), 1)

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
        .accessibilityValue(
            store.isWarmupComplete
                ? "완료. \(completionDetail)"
                : "\(Int(store.warmupCompletionRatio * 100))퍼센트"
        )
    }
}

#Preview {
    WarmupView().environment(WarmupStore())
}
