import Foundation

final class MeasurementRepository {
    private let store: FileStore
    private let itemsFile = "measurementItems.json"
    private let seasonsFile = "measurementSeasons.json"
    private let recordsFile = "measurementRecords.json"

    init(store: FileStore = JSONStore()) {
        self.store = store
    }

    func loadItems() throws -> [MeasurementItem] {
        try store.load([MeasurementItem].self, from: itemsFile) ?? []
    }

    func saveItems(_ items: [MeasurementItem]) throws {
        try store.save(items, to: itemsFile)
    }

    func loadSeasons() throws -> [MeasurementSeason] {
        try store.load([MeasurementSeason].self, from: seasonsFile) ?? []
    }

    func saveSeasons(_ seasons: [MeasurementSeason]) throws {
        try store.save(seasons, to: seasonsFile)
    }

    func loadRecords() throws -> [MeasurementRecord] {
        try store.load([MeasurementRecord].self, from: recordsFile) ?? []
    }

    func saveRecords(_ records: [MeasurementRecord]) throws {
        try store.save(records, to: recordsFile)
    }
}
