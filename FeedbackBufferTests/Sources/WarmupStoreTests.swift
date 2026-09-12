import XCTest
@testable import FeedbackBuffer

@MainActor
final class WarmupStoreTests: StoreTestCase {
    func test_warmupToggleAndReset() {
        let store = makeWarmupStore()
        let first = store.warmup.first!

        store.toggleWarmup(first.id)
        XCTAssertTrue(store.warmup.first { $0.id == first.id }!.checked)
        XCTAssertGreaterThan(store.warmupCompletionRatio, 0)

        store.resetWarmupToday()
        XCTAssertFalse(store.warmup.contains { $0.checked })
        XCTAssertEqual(store.warmupCompletionRatio, 0)
    }

    func test_warmupCompletionDetected() {
        let store = makeWarmupStore()
        for item in store.warmup {
            store.toggleWarmup(item.id)
        }

        XCTAssertTrue(store.isWarmupComplete)
        XCTAssertEqual(store.warmupCompletionRatio, 1.0, accuracy: 0.0001)
    }

    func test_warmupRefreshLoadsDateSpecificState() {
        let store = makeWarmupStore()
        let first = store.warmup.first!

        store.toggleWarmup(first.id)
        XCTAssertTrue(store.warmup.first { $0.id == first.id }!.checked)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!
        store.refreshWarmupIfNeeded(now: tomorrow)

        XCTAssertFalse(store.warmup.first { $0.id == first.id }!.checked)
    }

    func test_warmupRoutineMutationsPersistAcrossReload() {
        let store = makeWarmupStore()

        store.addWarmupItem(label: "  발목 가동성  ")
        let added = store.warmup.last!
        XCTAssertEqual(added.label, "발목 가동성")

        store.updateWarmupItem(id: added.id, label: "  발목 + 종아리  ")
        XCTAssertEqual(store.warmup.last?.label, "발목 + 종아리")

        store.moveWarmupItem(fromOffsets: IndexSet(integer: store.warmup.count - 1), toOffset: 0)
        XCTAssertEqual(store.warmup.first?.id, added.id)

        store.toggleWarmup(added.id)

        let reloaded = makeWarmupStore()
        XCTAssertEqual(reloaded.warmup.first?.id, added.id)
        XCTAssertEqual(reloaded.warmup.first?.label, "발목 + 종아리")
        XCTAssertTrue(reloaded.warmup.first?.checked == true)

        reloaded.deleteWarmupItem(added.id)
        XCTAssertFalse(reloaded.warmup.contains { $0.id == added.id })
    }

    // MARK: - Warmup sessions

    func test_bootstrapSeedsDefaultWarmupSession() {
        let store = makeWarmupStore()

        XCTAssertEqual(store.warmupSessions.count, 1)
        XCTAssertEqual(store.warmupSessions.first?.name, DefaultWarmupSession.initialName)
        XCTAssertEqual(store.selectedWarmupSessionId, store.warmupSessions.first?.id)
        XCTAssertEqual(store.defaultWarmupSessionId, store.warmupSessions.first?.id)
        XCTAssertTrue(store.isCurrentSessionDefault)
        XCTAssertEqual(store.warmup.map(\.id), DefaultWarmup.items.map(\.id))
    }

    func test_bootstrapMigratesLegacyRoutineAndTodayChecks() throws {
        let legacyItems = [
            WarmupItem(id: "legacy_one", label: "레거시 1"),
            WarmupItem(id: "legacy_two", label: "레거시 2")
        ]
        let routineData = try JSONEncoder().encode(legacyItems)
        defaults.set(routineData, forKey: "warmupRoutine_v1")
        defaults.set(["legacy_one": true], forKey: "warmup_\(WarmupDateKey.today())")

        let store = makeWarmupStore()

        XCTAssertEqual(store.warmupSessions.count, 1)
        XCTAssertEqual(store.warmupSessions[0].items.map(\.id), ["legacy_one", "legacy_two"])
        XCTAssertTrue(store.warmup.first { $0.id == "legacy_one" }?.checked == true)
        XCTAssertTrue(store.warmup.first { $0.id == "legacy_two" }?.checked == false)
        XCTAssertNotNil(defaults.data(forKey: "warmupSessions_v1"))
        XCTAssertNotNil(defaults.string(forKey: "warmupSelectedSessionId_v1"))
        XCTAssertNotNil(defaults.string(forKey: "warmupDefaultSessionId_v1"))
    }

    func test_addWarmupSessionAppendsAndAutoSelects() {
        let store = makeWarmupStore()
        let beforeCount = store.warmupSessions.count

        let new = store.addWarmupSession(
            name: "  공원 웜업  ",
            items: [WarmupItem(id: "park_1", label: "달리기")]
        )

        XCTAssertEqual(store.warmupSessions.count, beforeCount + 1)
        XCTAssertEqual(new.name, "공원 웜업")
        XCTAssertEqual(store.selectedWarmupSessionId, new.id)
        XCTAssertEqual(store.warmup.map(\.id), ["park_1"])
        XCTAssertFalse(store.isCurrentSessionDefault)
    }

    func test_renameWarmupSessionTrimsAndPersists() {
        let store = makeWarmupStore()
        let target = store.warmupSessions.first!

        store.renameWarmupSession(id: target.id, name: "  내 웜업  ")
        XCTAssertEqual(store.warmupSessions.first?.name, "내 웜업")

        let reloaded = makeWarmupStore()
        XCTAssertEqual(reloaded.warmupSessions.first?.name, "내 웜업")
    }

    func test_renameWarmupSessionRejectsBlank() {
        let store = makeWarmupStore()
        let target = store.warmupSessions.first!
        let originalName = target.name

        store.renameWarmupSession(id: target.id, name: "   ")

        XCTAssertEqual(store.warmupSessions.first?.name, originalName)
    }

    func test_deleteWarmupSessionRefusesLastSession() {
        let store = makeWarmupStore()
        let only = store.warmupSessions.first!

        store.deleteWarmupSession(only.id)

        XCTAssertEqual(store.warmupSessions.count, 1)
        XCTAssertEqual(store.selectedWarmupSessionId, only.id)
    }

    func test_deleteSelectedWarmupSessionSwitchesToFirst() {
        let store = makeWarmupStore()
        let original = store.warmupSessions.first!
        let added = store.addWarmupSession(name: "공원", items: [])
        XCTAssertEqual(store.selectedWarmupSessionId, added.id)

        store.deleteWarmupSession(added.id)

        XCTAssertEqual(store.warmupSessions.count, 1)
        XCTAssertEqual(store.selectedWarmupSessionId, original.id)
        XCTAssertEqual(store.warmup.map(\.id), DefaultWarmup.items.map(\.id))
    }

    func test_deleteWarmupSessionPurgesPerSessionCheckKeys() {
        let store = makeWarmupStore()
        let added = store.addWarmupSession(
            name: "공원",
            items: [WarmupItem(id: "park_a", label: "A")]
        )
        store.toggleWarmup("park_a")
        let prefix = "warmup_\(added.id.uuidString)_"
        XCTAssertTrue(defaults.dictionaryRepresentation().keys.contains { $0.hasPrefix(prefix) })

        store.deleteWarmupSession(added.id)

        XCTAssertFalse(defaults.dictionaryRepresentation().keys.contains { $0.hasPrefix(prefix) })
    }

    func test_selectWarmupSessionPreservesPerSessionChecks() {
        let store = makeWarmupStore()
        let original = store.warmupSessions.first!
        store.toggleWarmup(store.warmup.first!.id)
        let originalCheckedId = store.warmup.first!.id

        let added = store.addWarmupSession(
            name: "공원",
            items: [WarmupItem(id: "park_x", label: "X")]
        )
        XCTAssertFalse(store.warmup.contains { $0.checked })

        store.selectWarmupSession(original.id)
        XCTAssertTrue(store.warmup.first { $0.id == originalCheckedId }?.checked == true)

        store.selectWarmupSession(added.id)
        XCTAssertFalse(store.warmup.contains { $0.checked })
    }

    func test_setWarmupCheckedIsIdempotent() {
        let store = makeWarmupStore()
        let target = store.warmup.first!

        store.setWarmupChecked(target.id, checked: true)
        XCTAssertTrue(store.warmup.first { $0.id == target.id }?.checked == true)

        store.setWarmupChecked(target.id, checked: true)
        XCTAssertTrue(store.warmup.first { $0.id == target.id }?.checked == true)

        store.setWarmupChecked(target.id, checked: false)
        XCTAssertFalse(store.warmup.first { $0.id == target.id }?.checked == true)
    }

    func test_resetWarmupRoutineOnlyAffectsDefaultSession() {
        let store = makeWarmupStore()
        let added = store.addWarmupSession(
            name: "공원",
            items: [WarmupItem(id: "park_a", label: "A")]
        )
        let beforeItems = store.warmupSessions.first { $0.id == added.id }?.items.map(\.id)

        store.resetWarmupRoutine()

        XCTAssertEqual(store.warmupSessions.first { $0.id == added.id }?.items.map(\.id), beforeItems)
        XCTAssertEqual(store.warmup.map(\.id), beforeItems)

        if let defaultId = store.defaultWarmupSessionId {
            store.selectWarmupSession(defaultId)
            store.toggleWarmup(store.warmup.first!.id)
            XCTAssertTrue(store.warmup.contains { $0.checked })

            store.resetWarmupRoutine()

            XCTAssertEqual(store.warmup.map(\.id), DefaultWarmup.items.map(\.id))
            XCTAssertFalse(store.warmup.contains { $0.checked })
        } else {
            XCTFail("default session id should be set after bootstrap")
        }
    }
}
