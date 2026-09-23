import SwiftUI

/// 운동 기록 목록. 하루 단위로 묶는다.
struct WorkoutHistoryView: View {
    @Environment(WorkoutTimerStore.self) private var store
    /// 통계의 달력에서 하루를 눌러 들어왔으면 그날만 보여준다.
    var day: Date?
    @State private var pendingDelete: WorkoutSession?
    @State private var editorMode: WorkoutSessionEditorView.Mode?

    private var visibleSessions: [WorkoutSession] {
        guard let day else { return store.sessions }
        return store.sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: day) }
    }

    private var grouped: [(day: Date, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: visibleSessions) {
            calendar.startOfDay(for: $0.startedAt)
        }
        return buckets
            .map { (day: $0.key, sessions: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        Group {
            if visibleSessions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(DS.Surface.page.ignoresSafeArea())
        .navigationTitle(day.map { $0.formatted(.dateTime.month().day().weekday()) } ?? "기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("기록 직접 추가")
            }
        }
        // 하루만 보는 중에 새로 적으면 그날로 적는다. 오늘로 들어가면 보던 목록에 나타나지 않는다.
        .sheet(item: $editorMode) { mode in
            WorkoutSessionEditorView(mode: mode, initialDate: day).environment(store)
        }
        .confirmationDialog(
            "이 기록을 삭제할까요?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let session = pendingDelete { store.deleteSession(session.id) }
                pendingDelete = nil
            }
            Button("취소", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("지우면 되돌릴 수 없어요.")
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
                ForEach(grouped, id: \.day) { group in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack {
                            Text(group.day, format: .dateTime.month().day().weekday())
                                .font(DS.Typo.value)
                            Spacer()
                            Text(WorkoutTimeFormat.compact(
                                group.sessions.reduce(0) { $0 + $1.trainingDuration() }
                            ))
                            .font(DS.Typo.number)
                            .foregroundStyle(.secondary)
                        }

                        ForEach(group.sessions) { session in
                            NavigationLink {
                                WorkoutSessionDetailView(initial: session)
                            } label: {
                                sessionRow(session)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("수정", systemImage: "pencil") {
                                    editorMode = .edit(session)
                                }
                                Button("삭제", systemImage: "trash", role: .destructive) {
                                    pendingDelete = session
                                }
                            }
                        }
                    }
                }
            }
            .padding(DS.Spacing.lg)
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                // 직접 적은 기록은 시각을 묻지 않았다. 없는 값을 시계처럼 보여주지 않는다.
                Text(session.source == .manual
                     ? "직접 입력"
                     : session.startedAt.formatted(date: .omitted, time: .shortened))
                    .font(DS.Typo.metaLabel)
                    .foregroundStyle(.secondary)
                Spacer()
                // 기록은 "59분"처럼 읽는다. 날짜 머리말의 합계와 같은 표기다.
                // 시계 표기는 지금 흐르는 시간(운동 중 화면)에만 쓴다.
                Text(WorkoutTimeFormat.compact(session.trainingDuration()))
                    .font(DS.Typo.number)
            }

            SegmentRatioBar(byKind: session.durationByKind(), rest: session.restDuration())

            Text(session.segmentSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                // "×2"를 "곱하기 2"로 읽지 않게 한다.
                .accessibilityLabel(session.segmentSummarySpoken)
        }
        .dsCard(padding: DS.Spacing.md)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "stopwatch")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            if day == nil {
                Text("아직 기록이 없어요")
                    .font(DS.Typo.value)
                Text("타이머에서 구간을 시작하면 기록이 쌓여요.")
                    .font(DS.Typo.metaLabel)
                    .foregroundStyle(.secondary)
            } else {
                Text("이 날의 기록이 없어요")
                    .font(DS.Typo.value)
            }
            Button("직접 추가하기") { editorMode = .create }
                .dsBorderedButton()
                .padding(.top, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 구간별 시간 비율을 한 줄로 보여주는 막대.
struct SegmentRatioBar: View {
    let byKind: [TrainingPhaseKind: TimeInterval]
    var rest: TimeInterval = 0

    private var total: TimeInterval {
        byKind.values.reduce(0, +) + max(0, rest)
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(TrainingPhaseKind.recommendedOrder) { kind in
                    if let duration = byKind[kind], duration > 0 {
                        Rectangle()
                            .fill(kind.tint)
                            .frame(width: geo.size.width * (duration / max(1, total)))
                    }
                }
                if rest > 0 {
                    Rectangle()
                        .fill(DS.Segment.rest)
                        .frame(width: geo.size.width * (rest / max(1, total)))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
