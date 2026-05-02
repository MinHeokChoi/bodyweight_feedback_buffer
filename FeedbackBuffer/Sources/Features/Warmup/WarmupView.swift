import SwiftUI

struct WarmupView: View {
    @Environment(AppStore.self) private var store
    @State private var showingResetConfirm = false
    @State private var editingRoutine = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    progressHeader
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
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

                Section {
                    Button(role: .destructive) {
                        showingResetConfirm = true
                    } label: {
                        Label("오늘 웜업 초기화", systemImage: "arrow.counterclockwise")
                    }
                }
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
            .confirmationDialog(
                "오늘의 웜업 체크를 모두 해제할까요?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("초기화", role: .destructive) {
                    withAnimation { store.resetWarmupToday() }
                }
                Button("취소", role: .cancel) { }
            }
            .sheet(isPresented: $editingRoutine) {
                WarmupRoutineEditorView().environment(store)
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

            ProgressView(value: store.warmupCompletionRatio)
                .tint(store.isWarmupComplete ? .green : .accentColor)

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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    WarmupView().environment(AppStore())
}
