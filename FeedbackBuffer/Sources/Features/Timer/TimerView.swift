import SwiftUI
import UIKit

struct TimerView: View {
    @Environment(WorkoutTimerStore.self) private var store
    @Environment(FeedbackStore.self) private var feedbackStore
    @Environment(WarmupStore.self) private var warmupStore
    @Binding var tabSelection: RootTabView.Tab
    @AppStorage(BufferFilter.storageKey) private var bufferFilterValue = BufferFilter.all.storageValue

    @State private var showingFinishConfirm = false
    @State private var showingFeedbackSheet = false
    @State private var showingRecoveryDialog = false
    @State private var showingWarmupRunner = false
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
                // 구간 진행 중에도 피드백을 적을 수 있어야 한다. 아래쪽은 이미
                // 큰 숫자와 버튼으로 꽉 차 있어서 툴바에 둔다. 오조작도 줄어든다.
                // 휴식 화면에는 자리가 있어서 이미 버튼이 따로 있다.
                // 기록보다 먼저 선언해 기록 버튼이 늘 맨 오른쪽에 있게 한다.
                if store.runningSegment != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingFeedbackSheet = true
                        } label: {
                            Image(systemName: Self.feedbackSymbol)
                        }
                        .accessibilityLabel("지금 피드백 적기")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        WorkoutHistoryView()
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .accessibilityLabel("기록")
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
        .fullScreenCover(isPresented: $showingWarmupRunner) {
            WarmupSessionRunnerView()
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

            // 큰 글씨에서 가운데가 넘치면 가운데만 스크롤한다. 아래 버튼 줄은 늘 제자리다.
            ViewThatFits(in: .vertical) {
                VStack(spacing: 0) {
                    Spacer(minLength: DS.Spacing.lg)
                    runningMiddle(segment: segment, pace: pace, segmentElapsed: segmentElapsed)
                    Spacer(minLength: DS.Spacing.lg)
                }
                ScrollView {
                    runningMiddle(segment: segment, pace: pace, segmentElapsed: segmentElapsed)
                        .padding(.vertical, DS.Spacing.lg)
                }
            }

            VStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        store.togglePause()
                        // 폰을 내려놓기 직전에 누르는 버튼이다. 눌렸는지 손으로 알게 한다.
                        haptics.action()
                    } label: {
                        Label(
                            store.isPaused ? "재개" : "일시정지",
                            systemImage: store.isPaused ? "play.fill" : "pause.fill"
                        )
                        .font(DS.Typo.buttonLabel)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .dsBorderedButton()
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

    /// 진행 화면 가운데. 숫자, 세트, 오늘 할 것, 웜업 러너 바로가기.
    @ViewBuilder
    private func runningMiddle(
        segment: TrainingSegment,
        pace: WorkoutClock.PaceState?,
        segmentElapsed: TimeInterval
    ) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.sm) {
                // 구간 이름은 여기 한 번이면 된다. 아래 종료 버튼에도 나온다.
                DSPill(text: segment.kind.displayName, color: segment.kind.tint)

                // 폰을 바닥에 두고 1~2m 떨어져 본다. 색은 검정 그대로 둔다 —
                // 구간 색으로 칠하면 밝은 바탕 대비가 2:1대로 떨어진다.
                Text(WorkoutTimeFormat.clock(pace?.lapElapsed ?? segmentElapsed))
                    .font(DS.Typo.timerHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(store.isPaused ? .secondary : .primary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("경과 시간")
                    .accessibilityValue(WorkoutTimeFormat.spoken(pace?.lapElapsed ?? segmentElapsed))

                if store.isPaused {
                    Label("일시정지", systemImage: "pause.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else if let pace {
                    Text("\(pace.lapIndex)번째 운동 · \(WorkoutTimeFormat.clock(pace.lapTarget)) 중")
                        .font(DS.Typo.metaLabel)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)

            if let pace {
                setProgressBar(pace: pace, tint: segment.kind.tint)
                    .padding(.top, DS.Spacing.xl)
                    .padding(.horizontal, DS.Spacing.xl)

                // 보조 동작이라 작게 두되, 누르는 영역은 넓히고 아래 버튼 줄과는 떨어뜨린다.
                Button {
                    // 넘어가지 않았으면 표시를 남기지 않는다. 남으면 나중의 진짜 경계를 삼킨다.
                    skippedToLapIndex = store.skipToNextLap()
                    haptics.action()
                } label: {
                    Text("지금 바로 다음 운동으로")
                        .font(DS.Typo.metaLabel)
                        .foregroundStyle(.secondary)
                        .underline(pattern: .solid)
                        .padding(.horizontal, DS.Spacing.lg)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, DS.Spacing.sm)
            }

            if segment.kind == .skillPractice {
                todayCues
                    .padding(.top, DS.Spacing.xl)
                    .padding(.horizontal, DS.Spacing.lg)
            }

            if segment.kind == .warmup {
                warmupRunnerLink
                    .padding(.top, DS.Spacing.xl)
                    .padding(.horizontal, DS.Spacing.xl)
            }
        }
    }

    // MARK: - 기술 연습 중 오늘 할 것

    /// 기술 연습 중에 오늘 할 것의 cue를 바로 본다(U2). 읽기만 한다 — 해결·또 하기는 버퍼에서 한다.
    /// 누르면 버퍼로 간다. 오늘 목록에 기술 훈련이 없으면 아무것도 그리지 않는다.
    @ViewBuilder
    private var todayCues: some View {
        let items = feedbackStore.todayFeedbacks().filter { $0.category == .skill }
        if !items.isEmpty {
            Button {
                // 버퍼에 남아 있던 필터가 방금 본 것을 가리면 필터를 푼다(U12와 같은 이유).
                let filter = BufferFilter.stored(bufferFilterValue, skills: feedbackStore.skills)
                if !items.allSatisfy(filter.includes) {
                    bufferFilterValue = BufferFilter.all.storageValue
                }
                tabSelection = .buffer
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Label("오늘 할 것", systemImage: "sun.max")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.Tint.accentText)

                    ForEach(items.prefix(Self.todayCueLimit)) { feedback in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(feedback.skillName) · \(feedback.title)")
                                .font(DS.Typo.metaLabel)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            // 세트 직전에 흘끗 볼 문장이다. cue가 없으면 빈 공간을 대신 크게 쓴다.
                            Text(feedback.note.isEmpty ? feedback.title : feedback.note)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if items.count > Self.todayCueLimit {
                        Text("외 \(items.count - Self.todayCueLimit)개는 버퍼에서")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                .dsCard(padding: DS.Spacing.md)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
            .buttonStyle(.plain)
            .accessibilityHint("피드백 버퍼로 가요")
        }
    }

    private static let todayCueLimit = 3

    // MARK: - 웜업 구간

    /// 타이머의 웜업 구간과 웜업 러너를 잇는다(FR-9).
    /// 오늘 이미 끝냈어도 둔다. 하루에 두 번 하는 날이 있다(N4).
    @ViewBuilder
    private var warmupRunnerLink: some View {
        if !warmupStore.warmup.isEmpty {
            let routine = warmupStore.currentWarmupSession?.name ?? "웜업"
            Button {
                showingWarmupRunner = true
            } label: {
                Label(
                    warmupStore.isWarmupComplete ? "웜업 다시 하기 · \(routine)" : "웜업 루틴 열기 · \(routine)",
                    systemImage: "list.bullet.clipboard"
                )
                .font(DS.Typo.buttonLabel)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .dsBorderedButton()
            .controlSize(.large)
        }
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
                    .frame(height: 14)
                }
            }

            HStack {
                ForEach(1...pace.setsPerLap, id: \.self) { index in
                    Text("\(index)세트")
                        .font(index == pace.setIndex ? .subheadline.weight(.bold) : .footnote)
                        .foregroundStyle(index == pace.setIndex ? Color.primary : Color.secondary)
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

                        // 예전 기록에서 일시정지가 열린 채 휴식으로 넘어온 경우. 멈춘 시계만 보이면
                        // 왜 안 가는지 알 수 없으니 풀 길을 둔다.
                        if store.isPaused {
                            Button {
                                store.togglePause()
                                haptics.action()
                            } label: {
                                Label("일시정지됨 · 재개", systemImage: "play.fill")
                                    .font(DS.Typo.buttonLabel)
                                    .frame(minHeight: 44)
                            }
                            .dsBorderedButton()
                        }
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
                            Label("지금 피드백 적기", systemImage: Self.feedbackSymbol)
                                .font(DS.Typo.metaLabel)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .dsBorderedButton()

                        // 한 번만 누르는 버튼이 쉬는 동안 가장 센 요소일 이유가 없다(N4와 같은 논리).
                        // 확인 창이 있으니 무게를 낮춰도 안전하다. 빨강은 확인 창의 "버리기"에만 남긴다.
                        Button {
                            showingFinishConfirm = true
                        } label: {
                            Text("운동 종료")
                                .font(DS.Typo.buttonLabel)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .dsBorderedButton(tint: Color.red.readableText)
                        .controlSize(.large)
                        .padding(.top, DS.Spacing.md)
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
                    .foregroundStyle(segment.kind.tint.readableText)
                Spacer()
                // 같은 구간을 여러 번 했다면 마지막 블록이 아니라 합친 시간을 보여준다.
                Text(WorkoutTimeFormat.clock(total))
                    .font(DS.Typo.number)
                    .foregroundStyle(segment.kind.tint.readableText)
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

    /// 진행 중(툴바)과 휴식 중(본문) 버튼이 같은 기호를 쓴다.
    private static let feedbackSymbol = "square.and.pencil"

    /// 지금 하고 있거나 방금 끝낸 구간으로 범주 기본값을 고른다. 저장하는 데이터에는 붙이지 않는다.
    private var feedbackContext: AddFeedbackSheet.Context {
        let kind = (store.runningSegment ?? store.lastFinishedSegment)?.kind
        return AddFeedbackSheet.Context(category: kind.flatMap(FeedbackDraftDefaults.category(for:)))
    }
}
