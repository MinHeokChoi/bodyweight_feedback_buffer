import SwiftUI

// MARK: - 종목 만들기 · 고치기

struct MeasurementItemEditorSheet: View {
    @Environment(MeasurementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let item: MeasurementItem?

    @State private var category = ""
    @State private var movement = ""
    @State private var constraint = ""
    @State private var unit: MeasurementUnit = .reps
    @State private var direction: MeasurementDirection = .higherIsBetter
    @State private var didSeed = false

    private var canSave: Bool {
        !movement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("카테고리") {
                    TextField("예: 물구나무", text: $category)
                    if !store.categories.isEmpty {
                        categoryShortcuts
                    }
                }

                Section("세부 동작") {
                    TextField("예: 밸런스", text: $movement)
                }

                Section {
                    TextField(
                        "예: 20~25분 동안 서 있는 시간만 세서 3분 채우기",
                        text: $constraint,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                } header: {
                    Text("제약")
                } footer: {
                    Text("어떤 조건에서 쟀는지 적어두세요. 이 조건이 같아야 시즌끼리 비교할 수 있어요.")
                }

                Section("단위") {
                    Picker("단위", selection: $unit) {
                        ForEach(MeasurementUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("방향", selection: $direction) {
                        ForEach(MeasurementDirection.allCases) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                } header: {
                    Text("잘한 것의 방향")
                } footer: {
                    Text("\"3분을 몇 번 안에 채우는지\"처럼 적을수록 잘한 종목이면 낮을수록 좋음을 고르세요. 시즌 변화를 개선으로 볼지 후퇴로 볼지가 여기서 갈려요.")
                }
            }
            .navigationTitle(item == nil ? "측정 종목 추가" : "종목 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }.disabled(!canSave)
                }
            }
            .onAppear(perform: seed)
        }
    }

    private var categoryShortcuts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(store.categories, id: \.self) { name in
                    Button(name) { category = name }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    private func seed() {
        guard !didSeed, let item else { didSeed = true; return }
        didSeed = true
        category = item.category
        movement = item.movement
        constraint = item.constraint
        unit = item.unit
        direction = item.direction
    }

    private func save() {
        if var existing = item {
            existing.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.movement = movement.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.constraint = constraint.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.unit = unit
            existing.direction = direction
            store.updateItem(existing)
        } else {
            store.addItem(
                category: category,
                movement: movement,
                constraint: constraint,
                unit: unit,
                direction: direction
            )
        }
        dismiss()
    }
}

// MARK: - 측정값 남기기·고치기

struct MeasurementRecordSheet: View {
    @Environment(MeasurementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let item: MeasurementItem
    /// 고칠 기록. 없으면 새로 남긴다.
    let record: MeasurementRecord?

    @State private var valueText: String
    @State private var seasonId: UUID?
    @State private var measuredAt: Date
    @State private var note: String
    /// 시즌을 직접 골랐는지. 고르기 전에는 잰 날이 속한 시즌을 따라간다.
    @State private var seasonChosen = false
    @State private var confirmingDelete = false

    init(item: MeasurementItem, record: MeasurementRecord? = nil) {
        self.item = item
        self.record = record
        _valueText = State(initialValue: record.map { Self.editableText($0.value) } ?? "")
        _seasonId = State(initialValue: record?.seasonId)
        _measuredAt = State(initialValue: record?.measuredAt ?? .now)
        _note = State(initialValue: record?.note ?? "")
    }

    /// 고칠 때 칸에 넣을 값. 소수점이 없으면 정수로 보여준다.
    private static func editableText(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value.rounded())) : String(value)
    }

    private var value: Double? {
        Double(valueText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        (value ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(item.displayName) {
                    HStack {
                        TextField("값", text: $valueText)
                            .keyboardType(.decimalPad)
                        Text(item.unit.displayName)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if store.seasons.isEmpty {
                        // 시즌이 하나도 없으면 저장할 때 잰 날로 자동으로 만든다.
                        // 기록을 남기려고 먼저 설정을 하러 가게 만들지 않는다.
                        LabeledContent("시즌") {
                            Text(newSeasonName)
                        }
                    } else {
                        Picker("시즌", selection: Binding(
                            get: { seasonId },
                            set: {
                                seasonId = $0
                                seasonChosen = true
                            }
                        )) {
                            ForEach(store.seasons) { season in
                                Text(season.name).tag(Optional(season.id))
                            }
                            // 첫 시즌보다 앞선 날짜는 속한 시즌이 없다. 이번 시즌에 넣지 않고 새로 만든다.
                            if seasonId == nil || containingSeason == nil {
                                Text("새 시즌 · \(newSeasonName)").tag(UUID?.none)
                            }
                        }
                    }
                } header: {
                    Text("시즌")
                } footer: {
                    if seasonId == nil {
                        Text("이 날짜가 속한 시즌이 없어서 저장할 때 새로 만들어요.")
                    }
                }

                Section("잰 날") {
                    DatePicker("날짜", selection: $measuredAt, in: ...Date.now, displayedComponents: .date)
                }

                Section("메모") {
                    TextField("남길 말", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if !item.constraint.isEmpty {
                    Section {
                        Text(item.constraint)
                            .font(DS.Typo.metaLabel)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("이 종목의 제약")
                    }
                }

                if record != nil {
                    Section {
                        Button("이 기록 삭제", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(record == nil ? "측정값 기록" : "측정값 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }.disabled(!canSave)
                }
            }
            .onAppear {
                seasonId = seasonId ?? containingSeason?.id
            }
            // 시즌은 시작일로만 정해지므로 잰 날이 곧 시즌이다(N16).
            // 과거 날짜로 적으면 그때의 시즌으로 들어가야 한다.
            .onChange(of: measuredAt) {
                guard !seasonChosen else { return }
                seasonId = containingSeason?.id
            }
            .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let record { store.deleteRecord(record.id) }
                    dismiss()
                }
                Button("취소", role: .cancel) { }
            }
        }
    }

    /// 잰 날이 속한 시즌. 첫 시즌보다 앞선 날이면 없다.
    private var containingSeason: MeasurementSeason? {
        MeasurementProgress.season(containing: measuredAt, in: store.seasons)
    }

    /// 속한 시즌이 없을 때 저장하면서 만들 시즌의 이름
    private var newSeasonName: String {
        SeasonNaming.uniqueName(for: measuredAt, existing: store.seasons.map(\.name))
    }

    private func save() {
        guard let value else { return }
        let season = store.seasons.first { $0.id == seasonId }
            ?? store.addSeason(startedAt: measuredAt)
        if var existing = record {
            existing.value = value
            existing.seasonId = season.id
            existing.measuredAt = measuredAt
            existing.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            store.updateRecord(existing)
        } else {
            store.addRecord(item: item, season: season, value: value, measuredAt: measuredAt, note: note)
        }
        dismiss()
    }
}

// MARK: - 시즌 관리

struct MeasurementSeasonsSheet: View {
    @Environment(MeasurementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newSeasonDate: Date = .now
    @State private var renaming: MeasurementSeason?
    @State private var pendingDelete: MeasurementSeason?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("시작일", selection: $newSeasonDate, displayedComponents: .date)
                    LabeledContent("이름") {
                        Text(SeasonNaming.uniqueName(for: newSeasonDate, existing: store.seasons.map(\.name)))
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        store.addSeason(startedAt: newSeasonDate)
                    } label: {
                        Label("시즌 시작", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("새 시즌")
                } footer: {
                    Text("이름은 시작일에서 자동으로 붙어요. 언제든 고칠 수 있어요.")
                }

                if !store.seasons.isEmpty {
                    Section("시즌") {
                        ForEach(store.seasons) { season in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(season.name)
                                    Text(season.startedAt, format: .dateTime.year().month().day())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if season.id == store.currentSeason?.id {
                                    Text("진행 중")
                                        .font(.caption2)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button("이름 변경", systemImage: "pencil") { renaming = season }
                                Button("삭제", systemImage: "trash", role: .destructive) {
                                    pendingDelete = season
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("시즌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .sheet(item: $renaming) { season in
                SeasonRenameSheet(season: season).environment(store)
            }
            .confirmationDialog(
                "이 시즌을 삭제할까요?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let season = pendingDelete { store.deleteSeason(season.id) }
                    pendingDelete = nil
                }
                Button("취소", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("이 시즌에 남긴 측정 기록도 함께 사라져요.")
            }
        }
    }
}

private struct SeasonRenameSheet: View {
    @Environment(MeasurementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let season: MeasurementSeason
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("시즌 이름") {
                    TextField("예: 2026 가을", text: $name)
                }
            }
            .navigationTitle("이름 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        store.renameSeason(season.id, name: name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { if name.isEmpty { name = season.name } }
        }
    }
}
