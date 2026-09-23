import SwiftUI
import UIKit

struct TimerView: View {
    @Environment(WorkoutTimerStore.self) private var store

    @State private var showingFinishConfirm = false
    @State private var showingFeedbackSheet = false
    @State private var showingRecoveryDialog = false
    /// "지금 바로 다음 운동으로"로 넘긴 랩. 직접 누른 것이라 경계 신호를 겹쳐 내지 않는다.
    @State private var skippedToLapIndex: Int?
    @State private var haptics = WorkoutHaptics()

    var body: some View {
        NavigationStack {
            // 1초마다 다시 그린다. 이 타이머는 표시 전용이고 아무 상태도 들지 않는다.
            // 화면이 보일 때만 돌기 때문에 배터리 부담도 없다.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(now: context.date)
            }
            .background(DS.Surface.page.ignoresSafeArea())
            .navigationTitle("타이머")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        WorkoutHistoryView()
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .accessibilityLabel("기록")
                }
                // 구간 진행 중에도 피드백을 적을 수 있어야 한다. 아래쪽은 이미
                // 큰 숫자와 버튼으로 꽉 차 있어서 툴바에 둔다. 오조작도 줄어든다.
                // 휴식 화면에는 자리가 있어서 이미 버튼이 따로 있다.
                if store.runningSegment != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingFeedbackSheet = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("지금 피드백 적기")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        WorkoutStatisticsView()
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                    }
                    .accessibilityLabel("통계")
                }
            }
        }
        .sheet(isPresented: $showingFeedbackSheet) {
            AddFeedbackSheet(context: feedbackContext)
        }
        // 종료 확인은 TimelineView 바깥에 둔다. 안에 두면 1초마다 다시 그려지면서
        // 다이얼로그가 재구성돼 버튼이 사라진다.
        .confirmationDialog(
            "운동을 종료할까요?",
            isPresented: $showingFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("종료하고 기록 저장") {
                store.finishSession()
                haptics.success()
            }
            Button("기록하지 않고 버리기", role: .destructive) {
                store.discardActiveSession()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("지금까지 \(WorkoutTimeFormat.compact(store.accumulatedDuration())) 기록됐어요. 잘못 시작한 운동이면 버릴 수 있어요.")
        }
        .onAppear {
            showingRecoveryDialog = store.needsRecoveryDecision
            haptics.prepare()
        }
        .onChange(of: store.runningSegment?.id) { _, _ in
            // 구간이 바뀌면 곧 경계 신호가 올 수 있으니 미리 깨워 둔다.
            haptics.prepare()
            skippedToLapIndex = nil
        }
        .confirmationDialog(
            "아직 진행 중인 운동이 있어요",
            isPresented: $showingRecoveryDialog,
            titleVisibility: .visible
        ) {
            Button("이어서 하기") { store.resumeRecoveredSession() }
            Button("여기서 종료") { store.finishRecoveredSessionAtLastKnownActivity() }
            Button("버리기", role: .destructive) { store.discardActiveSession() }
        } message: {
            Text("마지막으로 기록된 시점까지만 저장할 수도 있어요.")
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let segment = store.runningSegment {
            runningSegmentView(segment: segment, now: now)
        } else {
            segmentPickerView(now: now)
        }
    }

    // MARK: - 구간 진행 중

    private func runningSegmentView(segment: TrainingSegment, now: Date) -> some View {
        let pace = store.paceState(now: now)
        let segmentElapsed = store.currentSegmentDuration(now: now)

        return VStack(spacing: 0) {
            accumulatedBar(now: now, insetHorizontally: true)

            Spacer(minLength: DS.Spacing.lg)

            VStack(spacing: DS.Spacing.md) {
                DSPill(text: segment.kind.displayName, color: segment.kind.tint)

                Text(WorkoutTimeFormat.clock(pace?.lapElapsed ?? segmentElapsed))
                    .font(DS.Typo.timer)
                    .foregroundStyle(store.isPaused ? .secondary : .primary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("경과 시간")
                    .accessibilityValue(WorkoutTimeFormat.spoken(pace?.lapElapsed ?? segmentElapsed))

                if let pace {
                    Text("\(pace.lapIndex)번째 운동 · \(WorkoutTimeFormat.clock(pace.lapTarget)) 중")
                        .font(DS.Typo.metaLabel)
                        .foregroundStyle(.secondary)
                } else {
                    Text(segment.kind.displayName + " 진행 중")
                        .font(DS.Typo.metaLabel)
                        .foregroundStyle(.secondary)
                }
            }

            if let pace {
                setProgressBar(pace: pace, tint: segment.kind.tint)
                    .padding(.top, DS.Spacing.xl)
                    .padding(.horizontal, DS.Spacing.xl)
            }

            if store.isPaused {
                DSPill(text: "일시정지됨", color: .secondary)
                    .padding(.top, DS.Spacing.lg)
            }

            Spacer()

            VStack(spacing: DS.Spacing.md) {
                if pace != nil {
                    Button {
                        // 넘어가지 않았으면 표시를 남기지 않는다. 남으면 나중의 진짜 경계를 삼킨다.
                        skippedToLapIndex = store.skipToNextLap()
                        haptics.action()
                    } label: {
                        Text("지금 바로 다음 운동으로")
                            .font(DS.Typo.metaLabel)
                            .foregroundStyle(.secondary)
                            .underline(pattern: .solid)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        store.togglePause()
                    } label: {
                        Label(
                            store.isPaused ? "재개" : "일시정지",
                            systemImage: store.isPaused ? "play.fill" : "pause.fill"
                        )
                        .font(DS.Typo.buttonLabel)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button {
                        store.endCurrentSegment()
                        haptics.action()
                    } label: {
                        Text("\(segment.kind.displayName) 종료")
                            .font(DS.Typo.buttonLabel)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .onChange(of: pace) { old, new in fireBoundaryHaptic(from: old, to: new) }
    }

    /// 3분 세트 3칸. 지금 몇 세트째인지와 그 안의 진행을 함께 보여준다.
    private func setProgressBar(pace: WorkoutClock.PaceState, tint: Color) -> some View {
        let setDuration = pace.lapTarget / Double(pace.setsPerLap)

        return VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(1...pace.setsPerLap, id: \.self) { index in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill))
                            Capsule()
                                .fill(tint)
                                .frame(width: geo.size.width * fill(for: index, pace: pace, setDuration: setDuration))
                        }
                    }
                    .frame(height: 8)
                }
            }

            HStack {
                ForEach(1...pace.setsPerLap, id: \.self) { index in
                    Text("\(index)세트")
                        .font(.caption2)
                        .foregroundStyle(index == pace.setIndex ? tint : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("세트 진행")
        .accessibilityValue("\(pace.setsPerLap)세트 중 \(pace.setIndex)세트")
    }

    private func fill(for index: Int, pace: WorkoutClock.PaceState, setDuration: Double) -> Double {
        if index < pace.setIndex { return 1 }
        if index > pace.setIndex { return 0 }
        return min(1, max(0, pace.setElapsed / setDuration))
    }

    // MARK: - 구간 선택 (대기 / 휴식)

    private func segmentPickerView(now: Date) -> some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if store.isRunning {
                    accumulatedBar(now: now, insetHorizontally: false)

                    VStack(spacing: DS.Spacing.sm) {
                        DSPill(text: "휴식", color: .secondary)
                        Text(WorkoutTimeFormat.clock(store.currentRestDuration(now: now)))
                            .font(DS.Typo.timer)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .accessibilityLabel("휴식 경과")
                            .accessibilityValue(WorkoutTimeFormat.spoken(store.currentRestDuration(now: now)))
                    }
                    .padding(.top, DS.Spacing.sm)

                    if let last = store.lastFinishedSegment {
                        finishedSegmentRow(last, now: now)
                    }
                } else {
                    weeklySummary(now: now)
                }

                DSSectionLabel(
                    text: store.isRunning ? "다음 구간을 시작할까요?" : "어떤 구간부터 시작할까요?"
                )

                SegmentPickerGrid(highlighted: suggestedNext) { kind in
                    store.startSegment(kind)
                    haptics.action()
                }

                if store.isRunning {
                    VStack(spacing: DS.Spacing.sm) {
                        Button {
                            showingFeedbackSheet = true
                        } label: {
                            Label("지금 피드백 적기", systemImage: "plus")
                                .font(DS.Typo.metaLabel)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            showingFinishConfirm = true
                        } label: {
                            Text("운동 종료")
                                .font(DS.Typo.buttonLabel)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(.top, DS.Spacing.sm)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    /// 다음에 할 법한 구간. 권장 순서에서 방금 끝낸 구간 다음 것을 고른다.
    private var suggestedNext: TrainingPhaseKind? {
        guard let last = store.lastFinishedSegment?.kind,
              let index = TrainingPhaseKind.recommendedOrder.firstIndex(of: last) else {
            return store.isRunning ? nil : .warmup
        }
        let next = TrainingPhaseKind.recommendedOrder.index(after: index)
        return next < TrainingPhaseKind.recommendedOrder.count
            ? TrainingPhaseKind.recommendedOrder[next]
            : nil
    }

    // MARK: - 조각들

    private func accumulatedBar(now: Date, insetHorizontally: Bool) -> some View {
        HStack {
            Text("전체 누적")
                .font(DS.Typo.metaLabel)
                .foregroundStyle(.secondary)
            Spacer()
            Text(WorkoutTimeFormat.clock(store.accumulatedDuration(now: now)))
                .font(DS.Typo.timerSmall)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(DS.Surface.card)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .stroke(DS.Line.color, lineWidth: DS.Line.width)
        }
        .padding(.horizontal, insetHorizontally ? DS.Spacing.lg : 0)
        .padding(.top, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("전체 누적")
        .accessibilityValue(WorkoutTimeFormat.spoken(store.accumulatedDuration(now: now)))
    }

    private func finishedSegmentRow(_ segment: TrainingSegment, now: Date) -> some View {
        let total = store.accumulatedDuration(for: segment.kind, now: now)
        let blocks = store.blockCount(for: segment.kind)
        let thisBlock = store.duration(of: segment, now: now)

        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Label("\(segment.kind.displayName) 완료", systemImage: "checkmark.circle.fill")
                    .font(DS.Typo.metaLabel)
                    .foregroundStyle(segment.kind.tint)
                Spacer()
                // 같은 구간을 여러 번 했다면 마지막 블록이 아니라 합친 시간을 보여준다.
                Text(WorkoutTimeFormat.clock(total))
                    .font(DS.Typo.number)
                    .foregroundStyle(segment.kind.tint)
            }

            if blocks > 1 {
                Text("\(blocks)번째 · 이번 \(WorkoutTimeFormat.clock(thisBlock))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.md)
        .background(segment.kind.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(segment.kind.displayName) 완료")
        .accessibilityValue(
            blocks > 1
                ? "누적 \(WorkoutTimeFormat.spoken(total)), \(blocks)번째 블록 \(WorkoutTimeFormat.spoken(thisBlock))"
                : WorkoutTimeFormat.spoken(total)
        )
    }

    private func weeklySummary(now: Date) -> some View {
        let stats = WorkoutStatistics.summary(
            for: store.sessions,
            in: .last7Days,
            now: now
        )
        // 계산은 달력 주가 아니라 오늘부터 거꾸로 7일이다. 라벨도 그렇게 부른다.
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("최근 7일")
                .font(DS.Typo.sectionLabel)
                .foregroundStyle(.secondary)
            Text(WorkoutTimeFormat.compact(stats.trainingDuration))
                .font(DS.Typo.metricValue)
            Text(weeklyCaption(stats))
                .font(DS.Typo.sectionLabel)
                .foregroundStyle(.secondary)
        }
        .dsTile()
        .padding(.top, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    /// 기록이 있는데 없다고 말하지 않는다. 최근 7일만 비었으면 마지막으로 한 날을 알려준다.
    private func weeklyCaption(_ stats: WorkoutStatistics.Summary) -> String {
        if stats.dayCount > 0 {
            return "\(stats.dayCount)일 운동 · 세션 \(stats.sessionCount)회"
        }
        guard let last = store.sessions.map(\.startedAt).max() else {
            return "아직 기록이 없어요"
        }
        return "마지막 운동 " + last.formatted(.dateTime.month().day())
    }

    // MARK: - 햅틱

    /// 세기가 아니라 횟수로 구분한다. 3분 세트는 짧게 1회, 9분 운동은 짧게 3회.
    ///
    /// 이전 값은 SwiftUI가 넘겨주는 것을 쓴다. 뷰가 따로 들고 있으면 처음 경계와
    /// 다음 블록의 경계를 놓친다.
    private func fireBoundaryHaptic(from old: WorkoutClock.PaceState?, to new: WorkoutClock.PaceState?) {
        let skipped = skippedToLapIndex
        // 넘긴 표시는 한 번만 쓴다. 운동 번호가 바뀌면 맞든 안 맞든 버린다.
        if old?.lapIndex != new?.lapIndex {
            skippedToLapIndex = nil
        }
        guard let signal = WorkoutClock.boundarySignal(from: old, to: new, skippedToLap: skipped) else { return }
        switch signal {
        case .set: haptics.setBoundary()
        case .lap: haptics.lapBoundary()
        }
    }

    // MARK: - 피드백

    /// 지금 하고 있거나 방금 끝낸 구간으로 범주 기본값을 고른다. 저장하는 데이터에는 붙이지 않는다.
    private var feedbackContext: AddFeedbackSheet.Context {
        let kind = (store.runningSegment ?? store.lastFinishedSegment)?.kind
        return AddFeedbackSheet.Context(category: kind.flatMap(FeedbackDraftDefaults.category(for:)))
    }
}
