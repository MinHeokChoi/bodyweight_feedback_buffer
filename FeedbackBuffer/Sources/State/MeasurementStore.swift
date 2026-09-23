import Foundation
import Observation

@MainActor
@Observable
final class MeasurementStore {
    private(set) var items: [MeasurementItem] = []
    private(set) var seasons: [MeasurementSeason] = []
    private(set) var records: [MeasurementRecord] = []

    private let repository: MeasurementRepository
    private let persistenceScheduler: PersistenceScheduler
    private let reportIssue: (PersistenceIssue) -> Void

    init(
        repository: MeasurementRepository = MeasurementRepository(),
        persistenceScheduler: PersistenceScheduler = .background,
        reportIssue: @escaping (PersistenceIssue) -> Void = { _ in }
    ) {
        self.repository = repository
        self.persistenceScheduler = persistenceScheduler
        self.reportIssue = reportIssue
        bootstrap()
    }

    private func bootstrap() {
        do {
            items = try repository.loadItems()
            seasons = try repository.loadSeasons().sorted { $0.startedAt > $1.startedAt }
            records = try repository.loadRecords().sorted { $0.measuredAt > $1.measuredAt }
        } catch {
            AppLog.persistence.error("measurement bootstrap failed: \(error.localizedDescription, privacy: .public)")
            reportPersistenceIssue(
                title: "측정 기록을 불러오지 못했어요",
                error: error,
                recovery: "빈 목록으로 시작해요. 저장된 파일은 그대로 있어요."
            )
        }
    }

    // MARK: - 읽기

    var currentSeason: MeasurementSeason? {
        MeasurementProgress.current(in: seasons)
    }

    /// 카테고리별로 묶은 종목. 카테고리 이름 순, 그 안에서는 만든 순.
    var itemsByCategory: [(category: String, items: [MeasurementItem])] {
        Dictionary(grouping: items) { $0.category }
            .map { (category: $0.key, items: $0.value.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.category < $1.category }
    }

    var categories: [String] {
        Array(Set(items.map(\.category))).filter { !$0.isEmpty }.sorted()
    }

    func item(_ id: UUID) -> MeasurementItem? { items.first { $0.id == id } }

    func history(of item: MeasurementItem) -> [MeasurementProgress.SeasonEntry] {
        MeasurementProgress.history(of: item, records: records, seasons: seasons)
    }

    func summary(of season: MeasurementSeason) -> [(item: MeasurementItem, entry: MeasurementProgress.SeasonEntry)] {
        MeasurementProgress.summary(of: season, items: items, records: records, seasons: seasons)
    }

    func recordCount(of item: MeasurementItem) -> Int {
        records.count { $0.itemId == item.id }
    }

    // MARK: - 종목

    @discardableResult
    func addItem(
        category: String,
        movement: String,
        constraint: String = "",
        unit: MeasurementUnit = .reps,
        direction: MeasurementDirection = .higherIsBetter
    ) -> MeasurementItem? {
        let item = MeasurementItem(
            category: category,
            movement: movement,
            constraint: constraint,
            unit: unit,
            direction: direction
        )
        guard !item.movement.isEmpty else { return nil }
        items.append(item)
        persistItems()
        return item
    }

    func updateItem(_ item: MeasurementItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              !item.movement.isEmpty else { return }
        items[index] = item
        persistItems()
    }

    /// 종목을 지우면 그 기록도 함께 사라진다. 기록만 남으면 무엇을 잰 것인지 알 수 없다.
    func deleteItem(_ id: UUID) {
        let before = items.count
        items.removeAll { $0.id == id }
        guard items.count != before else { return }
        records.removeAll { $0.itemId == id }
        persistItems()
        persistRecords()
    }

    // MARK: - 시즌

    /// 시즌 이름은 시작일에서 자동으로 짓는다. 비워두면 "2026 가을" 같은 이름이 붙는다.
    @discardableResult
    func addSeason(name: String = "", startedAt: Date = .now, calendar: Calendar = .current) -> MeasurementSeason {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty
            ? SeasonNaming.uniqueName(for: startedAt, existing: seasons.map(\.name), calendar: calendar)
            : trimmed
        let season = MeasurementSeason(name: resolved, startedAt: startedAt)
        seasons.append(season)
        seasons.sort { $0.startedAt > $1.startedAt }
        persistSeasons()
        return season
    }

    func renameSeason(_ id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = seasons.firstIndex(where: { $0.id == id }) else { return }
        seasons[index].name = trimmed
        persistSeasons()
    }

    /// 시즌을 지우면 그 시즌의 기록도 사라진다. 어느 시즌인지 모르는 기록은 비교에 쓸 수 없다.
    func deleteSeason(_ id: UUID) {
        let before = seasons.count
        seasons.removeAll { $0.id == id }
        guard seasons.count != before else { return }
        records.removeAll { $0.seasonId == id }
        persistSeasons()
        persistRecords()
    }

    // MARK: - 기록

    @discardableResult
    func addRecord(
        item: MeasurementItem,
        season: MeasurementSeason,
        value: Double,
        measuredAt: Date = .now,
        note: String = ""
    ) -> MeasurementRecord {
        let record = MeasurementRecord(
            itemId: item.id,
            seasonId: season.id,
            measuredAt: measuredAt,
            value: value,
            note: note,
            // 잴 당시의 조건을 박아 둔다. 종목 제약을 나중에 고쳐도 이 기록은 그대로다.
            constraintSnapshot: item.constraint
        )
        records.append(record)
        records.sort { $0.measuredAt > $1.measuredAt }
        persistRecords()
        return record
    }

    func updateRecord(_ record: MeasurementRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        records.sort { $0.measuredAt > $1.measuredAt }
        persistRecords()
    }

    func deleteRecord(_ id: UUID) {
        let before = records.count
        records.removeAll { $0.id == id }
        guard records.count != before else { return }
        persistRecords()
    }

    // MARK: - 저장

    private func persistItems() {
        let snapshot = items
        let repository = repository
        scheduleSave({ try repository.saveItems(snapshot) }, failureTitle: "측정 종목을 저장하지 못했어요")
    }

    private func persistSeasons() {
        let snapshot = seasons
        let repository = repository
        scheduleSave({ try repository.saveSeasons(snapshot) }, failureTitle: "시즌을 저장하지 못했어요")
    }

    private func persistRecords() {
        let snapshot = records
        let repository = repository
        scheduleSave({ try repository.saveRecords(snapshot) }, failureTitle: "측정 기록을 저장하지 못했어요")
    }

    private func scheduleSave(_ work: @escaping () throws -> Void, failureTitle: String) {
        persistenceScheduler.perform { [weak self] in
            do {
                try work()
            } catch {
                AppLog.persistence.error("save failed: \(failureTitle, privacy: .public) — \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    self?.reportPersistenceIssue(
                        title: failureTitle,
                        error: error,
                        recovery: "앱을 종료하기 전에 저장 공간과 파일 권한을 확인해 주세요."
                    )
                }
            }
        }
    }

    private func reportPersistenceIssue(title: String, error: Error, recovery: String) {
        reportIssue(
            PersistenceIssue(
                title: title,
                message: "\(recovery)\n\n원인: \(error.localizedDescription)"
            )
        )
    }
}
