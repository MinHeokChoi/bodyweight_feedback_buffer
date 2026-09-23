import SwiftUI

struct WarmupSessionRunnerView: View {
    @Environment(WarmupStore.self) private var store
    @Environment(WorkoutTimerStore.self) private var timerStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int = 0
    /// 넘긴 직후 잠깐. 완료를 두 번 치면 한 항목을 보지도 못하고 넘어갔다.
    @State private var isAdvancing = false

    private var items: [WarmupItem] { store.warmup }

    private var currentItem: WarmupItem? {
        guard items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    private var nextItem: WarmupItem? {
        let next = currentIndex + 1
        return items.indices.contains(next) ? items[next] : nil
    }

    private var isFinished: Bool {
        currentIndex >= items.count
    }

    /// 타이머에서 웜업 구간이 돌고 있는가. 러너를 끝내면 구간도 끝낼 수 있게 한다.
    private var isTimingWarmup: Bool {
        timerStore.runningSegment?.kind == .warmup
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
                // 실수로 넘긴 항목으로 돌아간다. 체크 상태는 건드리지 않는다.
                ToolbarItem(placement: .topBarLeading) {
                    if currentIndex > 0 {
                        Button {
                            goBack()
                        } label: {
                            Label("이전", systemImage: "chevron.left")
                        }
                    }
                }
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
        // 중간에 닫았다 열면 그 자리에서 이어간다.
        .onAppear { currentIndex = store.runnerStartIndex() }
        // 완료 화면에서 이전으로 돌아온 것은 이어갈 자리가 아니다.
        // 끝까지 돈 뒤의 "웜업 다시 하기"는 처음부터다(WR-4).
        .onChange(of: currentIndex) { old, index in
            if index < items.count, old < items.count {
                store.saveRunnerPosition(index)
            }
        }
        // 폰을 내려놓고 동작을 하는 동안 화면이 꺼지면 다음 항목을 볼 수 없다.
        .onAppear { ScreenAwake.set(.warmupRunner, active: true) }
        .onDisappear { ScreenAwake.set(.warmupRunner, active: false) }
    }

    private func itemCard(item: WarmupItem) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 20) {
                progressHeader

                // 멀리서 보이는 것은 동작 이름이어야 한다. 몇 번째인지는 곁들이는 정보다.
                Text(item.label)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(item.checked ? .secondary : .primary)
                    .padding(.horizontal, 24)

                ZStack {
                    if item.checked {
                        Label("이미 완료", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.green.readableText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 32)

                if let nextItem {
                    Text("다음 · \(nextItem.label)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    store.setWarmupChecked(item.id, checked: true)
                    advance()
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
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .dsBorderedButton()
                .controlSize(.large)
            }
            .disabled(isAdvancing)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text("\(currentIndex + 1) / \(items.count)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
            ProgressView(value: Double(currentIndex), total: Double(max(items.count, 1)))
                .tint(.accentColor)
                .frame(maxWidth: 200)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("진행")
        .accessibilityValue("\(items.count)개 중 \(currentIndex + 1)번째")
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

            VStack(spacing: 12) {
                // 타이머 웜업 구간을 켜 둔 채 러너를 닫으면 종료를 잊어 시간이 부풀었다(FR-7).
                if isTimingWarmup {
                    Button {
                        timerStore.endCurrentSegment()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    } label: {
                        Text("웜업 구간 끝내기")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        dismiss()
                    } label: {
                        Text("닫기")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .dsBorderedButton()
                    .controlSize(.large)
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Text("닫기")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            // 마지막 항목의 완료를 두 번 치면 두 번째 탭이 같은 자리의 이 버튼에 들어간다.
            // 웜업 구간 끝내기는 되돌릴 수 없으니 넘긴 직후 잠깐은 받지 않는다.
            .allowsHitTesting(!isAdvancing)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        // 끝까지 도달한 순간이 완료다. 건너뛴 항목이 있어도 마찬가지다.
        .onAppear { store.markRunnerFinished() }
    }

    private func advance() {
        isAdvancing = true
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex += 1
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isAdvancing = false
        }
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex = max(0, min(currentIndex, items.count) - 1)
        }
    }
}

#Preview {
    WarmupSessionRunnerView()
        .environment(WarmupStore())
        .environment(WorkoutTimerStore())
}
