import SwiftUI

/// 운동 기록을 손으로 적거나 고치는 화면.
///
/// 시각은 다루지 않는다. 이 기록의 목적은 구간별 누적 시간이고,
/// 휴식은 구간 사이에 남는 시간일 뿐이다. 그래서 여기서 정할 것은
/// "무엇을 몇 분 했나" 뿐이다.
struct WorkoutSessionEditorView: View {
    enum Mode: Equatable, Identifiable {
        case create
        case edit(WorkoutSession)

        var id: String {
            switch self {
            case .create: "create"
            case let .edit(session): session.id.uuidString
            }
        }
    }

    @Environment(WorkoutTimerStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var date: Date = .now
    @State private var blocks: [WorkoutSessionEditor.Block] = []
    /// 분 단위 입력값. 손대지 않은 구간은 초 단위 원본을 그대로 두려고 따로 둔다.
    @State private var minuteText: [UUID: String] = [:]
    @State private var didSeed = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var totalDuration: TimeInterval {
        blocks.reduce(0) { $0 + $1.duration }
    }

    private var canSave: Bool {
        blocks.contains { $0.duration >= 1 } && !isFutureDate
    }

    private var isFutureDate: Bool {
        guard !isEditing else { return false }
        return Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                blockSection
                totalSection
            }
            .navigationTitle(isEditing ? "기록 수정" : "기록 직접 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: seed)
        }
    }

    // MARK: - 구역

    @ViewBuilder
    private var dateSection: some View {
        if isEditing {
            Section("날짜") {
                LabeledContent("날짜") {
                    Text(date, format: .dateTime.year().month().day().weekday())
                }
            }
        } else {
            Section("날짜") {
                DatePicker(
                    "날짜",
                    selection: $date,
                    in: ...Date.now,
                    displayedComponents: .date
                )
            }
        }
    }

    private var blockSection: some View {
        Section {
            ForEach($blocks) { $block in
                blockRow($block)
            }
            .onDelete { blocks.remove(atOffsets: $0) }
            .onMove { blocks.move(fromOffsets: $0, toOffset: $1) }

            Menu {
                ForEach(TrainingPhaseKind.recommendedOrder) { kind in
                    Button(kind.displayName) { addBlock(kind) }
                }
            } label: {
                Label("구간 추가", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("구간")
        } footer: {
            Text(isEditing
                 ? "길이를 바꾸면 뒤 구간이 그만큼 밀려요. 스트렝스는 새 길이에 맞춰 9분 단위로 다시 나뉘어요."
                 : "구간이 순서대로 이어져요. 직접 적은 기록에는 휴식이 없어요.")
        }
    }

    private func blockRow(_ block: Binding<WorkoutSessionEditor.Block>) -> some View {
        let id = block.wrappedValue.id
        let seconds = Int(block.wrappedValue.duration.rounded()) % 60

        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Menu {
                    ForEach(TrainingPhaseKind.recommendedOrder) { kind in
                        Button(kind.displayName) { block.wrappedValue.kind = kind }
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(block.wrappedValue.kind.tint)
                            .frame(width: 8, height: 8)
                        Text(block.wrappedValue.kind.displayName)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                TextField(
                    "0",
                    text: Binding(
                        get: { minuteText[id] ?? "" },
                        set: { newValue in
                            let digits = String(newValue.filter(\.isNumber).prefix(3))
                            minuteText[id] = digits
                            block.wrappedValue.duration = TimeInterval((Int(digits) ?? 0) * 60)
                        }
                    )
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 56)

                Text("분")
                    .foregroundStyle(.secondary)
            }

            // 타이머로 잰 구간은 초까지 남아 있다. 손대지 않으면 그대로 저장된다.
            if seconds != 0 {
                Text("지금 기록 \(WorkoutTimeFormat.clock(block.wrappedValue.duration))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var totalSection: some View {
        Section {
            LabeledContent("운동 시간") {
                Text(WorkoutTimeFormat.compact(totalDuration))
                    .font(DS.Typo.number)
            }
        } footer: {
            if isFutureDate {
                Text("아직 오지 않은 날짜예요.")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - 동작

    private func seed() {
        guard !didSeed else { return }
        didSeed = true

        if case let .edit(session) = mode {
            date = session.startedAt
            blocks = WorkoutSessionEditor.blocks(of: session)
        } else {
            blocks = [WorkoutSessionEditor.Block(kind: .warmup, duration: 0)]
        }
        for block in blocks {
            minuteText[block.id] = block.duration >= 60
                ? String(Int(block.duration) / 60)
                : ""
        }
    }

    private func addBlock(_ kind: TrainingPhaseKind) {
        let block = WorkoutSessionEditor.Block(kind: kind, duration: 0)
        blocks.append(block)
        minuteText[block.id] = ""
    }

    private func save() {
        switch mode {
        case .create:
            store.addManualSession(date: date, blocks: blocks)
        case let .edit(session):
            store.updateSession(session.id, blocks: blocks)
        }
        dismiss()
    }
}
