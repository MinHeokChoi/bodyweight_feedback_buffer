import XCTest
@testable import FeedbackBuffer

final class SeasonNamingTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, timeZone: .current, year: y, month: m, day: d).date!
    }

    func test_seasonBoundaries() {
        XCTAssertEqual(SeasonNaming.suggestedName(for: date(2026, 3, 1), calendar: calendar), "2026 봄")
        XCTAssertEqual(SeasonNaming.suggestedName(for: date(2026, 6, 30), calendar: calendar), "2026 여름")
        XCTAssertEqual(SeasonNaming.suggestedName(for: date(2026, 9, 13), calendar: calendar), "2026 가을")
        XCTAssertEqual(SeasonNaming.suggestedName(for: date(2026, 11, 30), calendar: calendar), "2026 가을")
    }

    func test_winterUsesStartingYear() {
        // 겨울은 해를 걸친다. 2026년 12월에 시작한 시즌은 2027년 2월까지 "2026 겨울"이다.
        XCTAssertEqual(SeasonNaming.suggestedName(for: date(2026, 12, 20), calendar: calendar), "2026 겨울")
        XCTAssertEqual(SeasonNaming.suggestedName(for: date(2027, 1, 5), calendar: calendar), "2027 겨울")
    }

    func test_duplicateNamesGetNumbered() {
        let existing = ["2026 가을"]
        XCTAssertEqual(
            SeasonNaming.uniqueName(for: date(2026, 9, 13), existing: existing, calendar: calendar),
            "2026 가을 (2)"
        )
        XCTAssertEqual(
            SeasonNaming.uniqueName(for: date(2026, 9, 13), existing: existing + ["2026 가을 (2)"], calendar: calendar),
            "2026 가을 (3)"
        )
    }
}

final class MeasurementDirectionTests: XCTestCase {
    func test_higherIsBetter() {
        let direction = MeasurementDirection.higherIsBetter
        XCTAssertEqual(direction.better(12, 15), 15)
        XCTAssertEqual(direction.improvement(from: 12, to: 15), 3)
        XCTAssertEqual(direction.improvement(from: 15, to: 12), -3)
    }

    func test_lowerIsBetter() {
        // "3분을 몇 번의 시도 안에 채우는지" — 5회에서 3회가 되면 개선이다.
        let direction = MeasurementDirection.lowerIsBetter
        XCTAssertEqual(direction.better(5, 3), 3)
        XCTAssertEqual(direction.improvement(from: 5, to: 3), 2)
        XCTAssertEqual(direction.improvement(from: 3, to: 5), -2)
    }
}

final class MeasurementUnitTests: XCTestCase {
    func test_secondsBecomeClockPastAMinute() {
        XCTAssertEqual(MeasurementUnit.seconds.format(45), "45초")
        XCTAssertEqual(MeasurementUnit.seconds.format(185), "3:05")
    }

    func test_wholeNumbersDropDecimals() {
        XCTAssertEqual(MeasurementUnit.kilograms.format(60), "60kg")
        XCTAssertEqual(MeasurementUnit.kilograms.format(62.5), "62.5kg")
    }
}

final class MeasurementProgressTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateComponents(calendar: calendar, timeZone: .current, year: y, month: m, day: d).date!
    }

    private func fixture(
        direction: MeasurementDirection = .higherIsBetter,
        constraint: String = "키핑 없이"
    ) -> (MeasurementItem, [MeasurementSeason]) {
        let item = MeasurementItem(
            category: "풀업",
            movement: "최대 개수",
            constraint: constraint,
            unit: .reps,
            direction: direction
        )
        let seasons = [
            MeasurementSeason(name: "2026 봄", startedAt: date(2026, 3, 1)),
            MeasurementSeason(name: "2026 여름", startedAt: date(2026, 6, 1)),
            MeasurementSeason(name: "2026 가을", startedAt: date(2026, 9, 1))
        ]
        return (item, seasons)
    }

    private func record(
        _ item: MeasurementItem,
        _ season: MeasurementSeason,
        _ value: Double,
        on day: Int = 10,
        constraint: String? = nil
    ) -> MeasurementRecord {
        MeasurementRecord(
            itemId: item.id,
            seasonId: season.id,
            measuredAt: calendar.date(byAdding: .day, value: day, to: season.startedAt)!,
            value: value,
            constraintSnapshot: constraint ?? item.constraint
        )
    }

    func test_historyIsNewestFirstWithImprovements() {
        let (item, seasons) = fixture()
        let records = [
            record(item, seasons[0], 10),
            record(item, seasons[1], 13),
            record(item, seasons[2], 12)
        ]

        let history = MeasurementProgress.history(of: item, records: records, seasons: seasons)

        XCTAssertEqual(history.map(\.season.name), ["2026 가을", "2026 여름", "2026 봄"])
        XCTAssertEqual(history[0].improvement, -1)   // 13 → 12
        XCTAssertEqual(history[1].improvement, 3)    // 10 → 13
        XCTAssertNil(history[2].improvement)         // 첫 시즌
        XCTAssertTrue(history[0].isRegressed)
        XCTAssertTrue(history[1].isImproved)
    }

    func test_lowerIsBetterReadsFewerAsImprovement() {
        var (item, seasons) = fixture(direction: .lowerIsBetter)
        item.movement = "밸런스"
        let records = [
            record(item, seasons[0], 5),
            record(item, seasons[1], 3)
        ]
        seasons = Array(seasons.prefix(2))

        let history = MeasurementProgress.history(of: item, records: records, seasons: seasons)

        // 5회 → 3회. 숫자는 줄었지만 개선이다.
        XCTAssertEqual(history[0].improvement, 2)
        XCTAssertTrue(history[0].isImproved)
    }

    func test_seasonBestRespectsDirection() {
        let (item, seasons) = fixture(direction: .lowerIsBetter)
        let records = [
            record(item, seasons[0], 7, on: 1),
            record(item, seasons[0], 4, on: 5),
            record(item, seasons[0], 6, on: 9)  // 마지막이 최고는 아니다
        ]

        let history = MeasurementProgress.history(of: item, records: records, seasons: seasons)

        XCTAssertEqual(history[0].best, 4)
        XCTAssertEqual(history[0].records.count, 3)
    }

    func test_changedConstraintIsFlagged() {
        let (item, seasons) = fixture(constraint: "키핑 없이")
        let records = [
            record(item, seasons[0], 10, constraint: "키핑 허용"),
            record(item, seasons[1], 13)
        ]

        let history = MeasurementProgress.history(of: item, records: records, seasons: seasons)

        XCTAssertFalse(history[0].constraintChanged)  // 2026 여름 — 지금 제약과 같다
        XCTAssertTrue(history[1].constraintChanged)   // 2026 봄 — 다른 조건이었다
    }

    func test_recordsOfOtherItemsAreIgnored() {
        let (item, seasons) = fixture()
        let other = MeasurementItem(category: "물구나무", movement: "밸런스")
        let records = [
            record(item, seasons[0], 10),
            record(other, seasons[0], 99)
        ]

        let history = MeasurementProgress.history(of: item, records: records, seasons: seasons)

        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].best, 10)
    }

    func test_currentSeasonIsTheLatestStart() {
        let (_, seasons) = fixture()
        XCTAssertEqual(MeasurementProgress.current(in: seasons)?.name, "2026 가을")
        XCTAssertNil(MeasurementProgress.current(in: []))
    }
}

@MainActor
final class MeasurementStoreTests: XCTestCase {
    private func makeStore(fileStore: FileStore = InMemoryFileStore()) -> MeasurementStore {
        MeasurementStore(
            repository: MeasurementRepository(store: fileStore),
            persistenceScheduler: .immediate
        )
    }

    func test_addItemRequiresMovement() {
        let store = makeStore()
        XCTAssertNil(store.addItem(category: "풀업", movement: "   "))
        XCTAssertTrue(store.items.isEmpty)
    }

    func test_seasonNameIsGeneratedWhenBlank() {
        let store = makeStore()
        let season = store.addSeason(startedAt: .now)
        XCTAssertEqual(season.name, SeasonNaming.suggestedName(for: season.startedAt))
    }

    func test_recordSnapshotsTheConstraintAtTheTime() {
        let store = makeStore()
        var item = store.addItem(category: "물구나무", movement: "밸런스", constraint: "20분 동안")!
        let season = store.addSeason()
        store.addRecord(item: item, season: season, value: 5)

        item.constraint = "25분 동안"
        store.updateItem(item)

        // 종목 제약을 고쳐도 이미 남은 기록의 조건은 그대로다.
        XCTAssertEqual(store.records.first?.constraintSnapshot, "20분 동안")
        XCTAssertTrue(store.history(of: store.item(item.id)!)[0].constraintChanged)
    }

    func test_deletingItemRemovesItsRecords() {
        let store = makeStore()
        let item = store.addItem(category: "풀업", movement: "최대 개수")!
        let season = store.addSeason()
        store.addRecord(item: item, season: season, value: 12)

        store.deleteItem(item.id)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertTrue(store.records.isEmpty)
    }

    func test_deletingSeasonRemovesItsRecords() {
        let store = makeStore()
        let item = store.addItem(category: "풀업", movement: "최대 개수")!
        let season = store.addSeason()
        store.addRecord(item: item, season: season, value: 12)

        store.deleteSeason(season.id)

        XCTAssertTrue(store.seasons.isEmpty)
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertEqual(store.items.count, 1)
    }

    func test_dataSurvivesReload() {
        let fileStore = InMemoryFileStore()
        let store = makeStore(fileStore: fileStore)
        let item = store.addItem(category: "스트렝스", movement: "벤치프레스", unit: .kilograms)!
        let season = store.addSeason(name: "2026 가을", startedAt: .now)
        store.addRecord(item: item, season: season, value: 60)

        let reloaded = makeStore(fileStore: fileStore)

        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.unit, .kilograms)
        XCTAssertEqual(reloaded.seasons.first?.name, "2026 가을")
        XCTAssertEqual(reloaded.records.first?.value, 60)
    }

    func test_itemsAreGroupedByCategory() {
        let store = makeStore()
        store.addItem(category: "풀업", movement: "최대 개수")
        store.addItem(category: "물구나무", movement: "밸런스")
        store.addItem(category: "물구나무", movement: "HSPU")

        let groups = store.itemsByCategory

        XCTAssertEqual(groups.map(\.category), ["물구나무", "풀업"])
        XCTAssertEqual(groups[0].items.count, 2)
    }
}
