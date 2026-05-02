import XCTest
@testable import FeedbackBuffer

final class InMemoryFileStore: FileStore {
    private var storage: [String: Data] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T? {
        guard let data = storage[filename] else { return nil }
        return try decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        let data = try encoder.encode(value)
        storage[filename] = data
    }
}

final class FailingFileStore: FileStore {
    enum TestError: LocalizedError {
        case failed

        var errorDescription: String? {
            "테스트 저장소 실패"
        }
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T? {
        throw TestError.failed
    }

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        throw TestError.failed
    }
}

final class AppStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "AppStoreTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeStore(fileStore: FileStore = InMemoryFileStore()) -> AppStore {
        AppStore(
            feedbackRepository: FeedbackRepository(store: fileStore),
            warmupRepository: WarmupRepository(defaults: defaults),
            defaults: defaults
        )
    }

    @discardableResult
    private func addFeedback(
        to store: AppStore,
        title: String = "라인 유지",
        importance: Int = 3
    ) -> Feedback {
        let skill = store.skills.first!
        store.addFeedback(skill: skill, title: title, note: "", importance: importance)
        return store.feedbacks.last!
    }

    func test_bootstrapSeedsDefaultSkillsWithoutSampleFeedbacks() {
        let store = makeStore()
        XCTAssertFalse(store.skills.isEmpty)
        XCTAssertTrue(store.feedbacks.isEmpty)
        XCTAssertFalse(store.hasCompletedOnboarding)
    }

    func test_completeOnboardingPersistsAcrossReload() {
        let fileStore = InMemoryFileStore()
        let store = makeStore(fileStore: fileStore)

        store.completeOnboarding()

        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertTrue(makeStore(fileStore: fileStore).hasCompletedOnboarding)
    }

    func test_existingFeedbackSkipsOnboardingOnReload() {
        let fileStore = InMemoryFileStore()
        let store = makeStore(fileStore: fileStore)

        addFeedback(to: store)

        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding_v1"))
        XCTAssertTrue(makeStore(fileStore: fileStore).hasCompletedOnboarding)
    }

    func test_bootstrapReportsPersistenceIssueOnLoadFailure() {
        let store = makeStore(fileStore: FailingFileStore())

        XCTAssertNotNil(store.persistenceIssue)
        XCTAssertFalse(store.skills.isEmpty)
        XCTAssertTrue(store.feedbacks.isEmpty)
    }

    func test_addFeedbackAppendsAndPersists() {
        let store = makeStore()
        let skill = store.skills.first!
        let before = store.feedbacks.count

        store.addFeedback(skill: skill, title: "  새 피드백  ", note: "memo", importance: 4)

        XCTAssertEqual(store.feedbacks.count, before + 1)
        let added = store.feedbacks.last!
        XCTAssertEqual(added.title, "새 피드백")
        XCTAssertEqual(added.importance, 4)
        XCTAssertEqual(added.skillId, skill.id)
    }

    func test_addFeedbackRejectsBlankTitle() {
        let store = makeStore()
        let skill = store.skills.first!
        let before = store.feedbacks.count
        store.addFeedback(skill: skill, title: "   ", note: "", importance: 3)
        XCTAssertEqual(store.feedbacks.count, before)
    }

    func test_resolveRemovesFromActive() {
        let store = makeStore()
        let target = addFeedback(to: store)
        let beforeCount = store.activeFeedbacks.count

        store.resolve(target.id)

        let updated = store.feedbacks.first { $0.id == target.id }!
        XCTAssertEqual(updated.status, .resolved)
        XCTAssertNotNil(updated.resolvedAt)
        XCTAssertEqual(store.activeFeedbacks.count, beforeCount - 1)
        XCTAssertFalse(store.activeFeedbacks.contains { $0.id == target.id })
    }

    func test_markUnresolvedIncrementsCountAndUpdatesReview() {
        let store = makeStore()
        let target = addFeedback(to: store)
        let beforeCount = target.unresolvedCount

        store.markUnresolved(target.id)

        let updated = store.feedbacks.first { $0.id == target.id }!
        XCTAssertEqual(updated.unresolvedCount, beforeCount + 1)
        XCTAssertNotNil(updated.lastReviewedAt)
    }

    func test_deleteRemovesPermanently() {
        let store = makeStore()
        let target = addFeedback(to: store)
        store.delete(target.id)
        XCTAssertFalse(store.feedbacks.contains { $0.id == target.id })
    }

    func test_warmupToggleAndReset() {
        let store = makeStore()
        let first = store.warmup.first!

        store.toggleWarmup(first.id)
        XCTAssertTrue(store.warmup.first { $0.id == first.id }!.checked)
        XCTAssertGreaterThan(store.warmupCompletionRatio, 0)

        store.resetWarmupToday()
        XCTAssertFalse(store.warmup.contains { $0.checked })
        XCTAssertEqual(store.warmupCompletionRatio, 0)
    }

    func test_warmupCompletionDetected() {
        let store = makeStore()
        for item in store.warmup {
            store.toggleWarmup(item.id)
        }
        XCTAssertTrue(store.isWarmupComplete)
        XCTAssertEqual(store.warmupCompletionRatio, 1.0, accuracy: 0.0001)
    }

    func test_warmupRefreshLoadsDateSpecificState() {
        let store = makeStore()
        let first = store.warmup.first!

        store.toggleWarmup(first.id)
        XCTAssertTrue(store.warmup.first { $0.id == first.id }!.checked)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!
        store.refreshWarmupIfNeeded(now: tomorrow)

        XCTAssertFalse(store.warmup.first { $0.id == first.id }!.checked)
    }

    func test_warmupRoutineMutationsPersistAcrossReload() {
        let fileStore = InMemoryFileStore()
        let store = makeStore(fileStore: fileStore)

        store.addWarmupItem(label: "  발목 가동성  ")
        let added = store.warmup.last!
        XCTAssertEqual(added.label, "발목 가동성")

        store.updateWarmupItem(id: added.id, label: "  발목 + 종아리  ")
        XCTAssertEqual(store.warmup.last?.label, "발목 + 종아리")

        store.moveWarmupItem(fromOffsets: IndexSet(integer: store.warmup.count - 1), toOffset: 0)
        XCTAssertEqual(store.warmup.first?.id, added.id)

        store.toggleWarmup(added.id)

        let reloaded = makeStore(fileStore: fileStore)
        XCTAssertEqual(reloaded.warmup.first?.id, added.id)
        XCTAssertEqual(reloaded.warmup.first?.label, "발목 + 종아리")
        XCTAssertTrue(reloaded.warmup.first?.checked == true)

        reloaded.deleteWarmupItem(added.id)
        XCTAssertFalse(reloaded.warmup.contains { $0.id == added.id })
    }

    func test_skillMutationsPersistAndSyncFeedbackNames() {
        let fileStore = InMemoryFileStore()
        let store = makeStore(fileStore: fileStore)
        let beforeCount = store.skills.count

        store.addSkill(name: "  백레버  ", symbolName: "figure.core.training")
        let added = store.skills.last!
        XCTAssertEqual(store.skills.count, beforeCount + 1)
        XCTAssertEqual(added.name, "백레버")

        store.addFeedback(skill: added, title: "라인 유지", note: "", importance: 3)
        XCTAssertTrue(store.feedbacks.contains { $0.skillId == added.id })

        store.updateSkill(id: added.id, name: "  백레버 홀드  ", symbolName: "figure.gymnastics")
        XCTAssertEqual(store.skills.first { $0.id == added.id }?.name, "백레버 홀드")
        XCTAssertEqual(store.feedbacks.first { $0.skillId == added.id }?.skillName, "백레버 홀드")

        store.moveSkill(fromOffsets: IndexSet(integer: store.skills.count - 1), toOffset: 0)
        XCTAssertEqual(store.skills.first?.id, added.id)

        let reloaded = makeStore(fileStore: fileStore)
        XCTAssertEqual(reloaded.skills.first?.id, added.id)
        XCTAssertEqual(reloaded.feedbacks.first { $0.skillId == added.id }?.skillName, "백레버 홀드")

        reloaded.deleteSkill(added.id)
        XCTAssertFalse(reloaded.skills.contains { $0.id == added.id })
        XCTAssertFalse(reloaded.feedbacks.contains { $0.skillId == added.id })
    }

    func test_topFeedbackIsHighestScored() {
        let store = makeStore()
        addFeedback(to: store, title: "낮은 중요도", importance: 1)
        addFeedback(to: store, title: "높은 중요도", importance: 5)
        let top = store.topFeedback
        XCTAssertNotNil(top)
        let topScore = FeedbackScoring.score(for: top!)
        for f in store.activeFeedbacks {
            XCTAssertLessThanOrEqual(FeedbackScoring.score(for: f), topScore)
        }
    }
}
