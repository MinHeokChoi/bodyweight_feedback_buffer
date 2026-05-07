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

    func seed(_ data: Data, to filename: String) {
        storage[filename] = data
    }

    func rawData(for filename: String) -> Data? {
        storage[filename]
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

@MainActor
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
            settingsRepository: UserSettingsRepository(defaults: defaults),
            persistenceScheduler: .immediate
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

    func test_quickPhrasesPersistAcrossReload() {
        let fileStore = InMemoryFileStore()
        let store = makeStore(fileStore: fileStore)
        let phrases = ["손목 눌림", "복압 풀림"]

        store.updateQuickPhrases(phrases)

        XCTAssertEqual(makeStore(fileStore: fileStore).quickPhrases, phrases)
    }

    func test_bootstrapNormalizesDefaultSkillAliasesWithoutDeletingCustomSkills() throws {
        let fileStore = InMemoryFileStore()
        let handstandId = UUID()
        let pullUpsId = UUID()
        let backLeverId = UUID()
        let otherId = UUID()
        try fileStore.save(
            [
                Skill(id: pullUpsId, name: "Pull Ups", symbolName: "figure.strengthtraining.traditional"),
                Skill(id: backLeverId, name: "Back Lever", symbolName: "figure.core.training"),
                Skill(id: handstandId, name: "물구나무", symbolName: "figure.gymnastics"),
                Skill(id: otherId, name: "기타", symbolName: "ellipsis.circle")
            ],
            to: "skills.json"
        )

        let store = makeStore(fileStore: fileStore)

        XCTAssertEqual(store.skills.map(\.id), [pullUpsId, backLeverId, handstandId, otherId])
        XCTAssertEqual(store.skills.map(\.name), ["Pull ups", "Back Lever", "Handstand", "기타"])
        XCTAssertEqual(store.skills.map(\.symbolName), ["pull.ups.full", "figure.core.training", "handstand.full", "ellipsis.circle"])
    }

    func test_bootstrapReportsPersistenceIssueOnLoadFailure() {
        let store = makeStore(fileStore: FailingFileStore())

        XCTAssertNotNil(store.persistenceIssue)
        XCTAssertFalse(store.skills.isEmpty)
        XCTAssertTrue(store.feedbacks.isEmpty)
        XCTAssertFalse(store.quickPhrases.isEmpty)
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

    func test_firstFeedbackPersistsSeededDefaultSkillsForStableIds() throws {
        let fileStore = InMemoryFileStore()
        let store = makeStore(fileStore: fileStore)
        let skill = store.skills.first!

        store.addFeedback(skill: skill, title: "라인 유지", note: "", importance: 3)

        let savedSkills = try fileStore.load([Skill].self, from: "skills.json")
        XCTAssertEqual(savedSkills?.first?.id, skill.id)

        let reloaded = makeStore(fileStore: fileStore)
        XCTAssertEqual(reloaded.feedbacks.first?.skillId, skill.id)
        XCTAssertEqual(reloaded.skills.first?.id, skill.id)
    }

    func test_addFeedbackRejectsBlankTitle() {
        let store = makeStore()
        let skill = store.skills.first!
        let before = store.feedbacks.count
        store.addFeedback(skill: skill, title: "   ", note: "", importance: 3)
        XCTAssertEqual(store.feedbacks.count, before)
    }

    func test_archiveRemovesFromUnarchived() {
        let store = makeStore()
        let target = addFeedback(to: store)
        let beforeCount = store.unarchivedFeedbacks.count

        store.archive(target.id)

        let updated = store.feedbacks.first { $0.id == target.id }!
        XCTAssertNotNil(updated.archivedAt)
        XCTAssertEqual(updated.phase, .archived)
        XCTAssertEqual(store.unarchivedFeedbacks.count, beforeCount - 1)
        XCTAssertFalse(store.unarchivedFeedbacks.contains { $0.id == target.id })
    }

    func test_unarchiveRestoresWithoutResettingPracticeCount() {
        let store = makeStore()
        let target = addFeedback(to: store)
        store.markPracticed(target.id)
        store.markPracticed(target.id)
        store.archive(target.id)
        XCTAssertFalse(store.unarchivedFeedbacks.contains { $0.id == target.id })

        store.unarchive(target.id)

        let updated = store.feedbacks.first { $0.id == target.id }!
        XCTAssertNil(updated.archivedAt)
        XCTAssertEqual(updated.unresolvedCount, 2)
        XCTAssertEqual(updated.phase, .practicing)
        XCTAssertTrue(store.unarchivedFeedbacks.contains { $0.id == target.id })
    }

    func test_phaseTransitions() {
        let store = makeStore()
        let target = addFeedback(to: store)

        func phase() -> FeedbackPhase? {
            store.feedbacks.first(where: { $0.id == target.id })?.phase
        }

        XCTAssertEqual(phase(), .new)
        store.markPracticed(target.id)
        XCTAssertEqual(phase(), .practicing)
        store.markPracticed(target.id)
        XCTAssertEqual(phase(), .practicing)
        store.markPracticed(target.id)
        XCTAssertEqual(phase(), .adapting)
        store.archive(target.id)
        XCTAssertEqual(phase(), .archived)
        store.unarchive(target.id)
        XCTAssertEqual(phase(), .adapting)
    }

    func test_legacyResolvedAtKeyMigratesToArchivedAtAndPersistsNewSchema() throws {
        let fileStore = InMemoryFileStore()
        let skillId = UUID()
        let feedbackId = UUID()
        let skillsJson = """
        [{"id":"\(skillId.uuidString)","name":"Handstand","symbolName":"figure.gymnastics"}]
        """
        let feedbacksJson = """
        [{
            "id": "\(feedbackId.uuidString)",
            "skillId": "\(skillId.uuidString)",
            "skillName": "Handstand",
            "title": "라인 유지",
            "note": "",
            "importance": 3,
            "unresolvedCount": 2,
            "category": "skill",
            "createdAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-05T00:00:00Z",
            "lastReviewedAt": "2025-01-05T00:00:00Z",
            "resolvedAt": "2025-01-05T00:00:00Z",
            "status": "resolved"
        }]
        """
        fileStore.seed(Data(skillsJson.utf8), to: "skills.json")
        fileStore.seed(Data(feedbacksJson.utf8), to: "feedbacks.json")

        let store = makeStore(fileStore: fileStore)

        let migrated = store.feedbacks.first { $0.id == feedbackId }
        XCTAssertNotNil(migrated)
        XCTAssertNotNil(migrated?.archivedAt)
        XCTAssertEqual(migrated?.phase, .archived)
        XCTAssertFalse(store.unarchivedFeedbacks.contains { $0.id == feedbackId })

        let rewritten = fileStore.rawData(for: "feedbacks.json")
        XCTAssertNotNil(rewritten)
        let rewrittenString = String(data: rewritten!, encoding: .utf8) ?? ""
        XCTAssertTrue(rewrittenString.contains("archivedAt"))
        XCTAssertFalse(rewrittenString.contains("\"status\""))
        XCTAssertFalse(rewrittenString.contains("\"resolvedAt\""))
    }

    func test_legacyResolvedStatusWithoutResolvedAtFallsBackToUpdatedAt() throws {
        let fileStore = InMemoryFileStore()
        let skillId = UUID()
        let feedbackId = UUID()
        let skillsJson = """
        [{"id":"\(skillId.uuidString)","name":"Handstand","symbolName":"figure.gymnastics"}]
        """
        let feedbacksJson = """
        [{
            "id": "\(feedbackId.uuidString)",
            "skillId": "\(skillId.uuidString)",
            "skillName": "Handstand",
            "title": "라인 유지",
            "note": "",
            "importance": 3,
            "unresolvedCount": 0,
            "category": "skill",
            "createdAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-05T00:00:00Z",
            "status": "resolved"
        }]
        """
        fileStore.seed(Data(skillsJson.utf8), to: "skills.json")
        fileStore.seed(Data(feedbacksJson.utf8), to: "feedbacks.json")

        let store = makeStore(fileStore: fileStore)

        let migrated = store.feedbacks.first { $0.id == feedbackId }
        let formatter = ISO8601DateFormatter()
        XCTAssertEqual(migrated?.archivedAt, formatter.date(from: "2025-01-05T00:00:00Z"))
        XCTAssertEqual(migrated?.phase, .archived)
    }

    func test_markPracticedIncrementsCountAndUpdatesReview() {
        let store = makeStore()
        let target = addFeedback(to: store)
        let beforeCount = target.unresolvedCount

        store.markPracticed(target.id)

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

    // MARK: - Warmup sessions (multi-session)

    func test_bootstrapSeedsDefaultWarmupSession() {
        let store = makeStore()

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

        let store = makeStore()

        XCTAssertEqual(store.warmupSessions.count, 1)
        XCTAssertEqual(store.warmupSessions[0].items.map(\.id), ["legacy_one", "legacy_two"])
        XCTAssertTrue(store.warmup.first { $0.id == "legacy_one" }?.checked == true)
        XCTAssertTrue(store.warmup.first { $0.id == "legacy_two" }?.checked == false)
        XCTAssertNotNil(defaults.data(forKey: "warmupSessions_v1"))
        XCTAssertNotNil(defaults.string(forKey: "warmupSelectedSessionId_v1"))
        XCTAssertNotNil(defaults.string(forKey: "warmupDefaultSessionId_v1"))
    }

    func test_addWarmupSessionAppendsAndAutoSelects() {
        let store = makeStore()
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
        let fileStore = InMemoryFileStore()
        let store = makeStore(fileStore: fileStore)
        let target = store.warmupSessions.first!

        store.renameWarmupSession(id: target.id, name: "  내 웜업  ")
        XCTAssertEqual(store.warmupSessions.first?.name, "내 웜업")

        let reloaded = makeStore(fileStore: fileStore)
        XCTAssertEqual(reloaded.warmupSessions.first?.name, "내 웜업")
    }

    func test_renameWarmupSessionRejectsBlank() {
        let store = makeStore()
        let target = store.warmupSessions.first!
        let originalName = target.name

        store.renameWarmupSession(id: target.id, name: "   ")

        XCTAssertEqual(store.warmupSessions.first?.name, originalName)
    }

    func test_deleteWarmupSessionRefusesLastSession() {
        let store = makeStore()
        let only = store.warmupSessions.first!

        store.deleteWarmupSession(only.id)

        XCTAssertEqual(store.warmupSessions.count, 1)
        XCTAssertEqual(store.selectedWarmupSessionId, only.id)
    }

    func test_deleteSelectedWarmupSessionSwitchesToFirst() {
        let store = makeStore()
        let original = store.warmupSessions.first!
        let added = store.addWarmupSession(name: "공원", items: [])
        XCTAssertEqual(store.selectedWarmupSessionId, added.id)

        store.deleteWarmupSession(added.id)

        XCTAssertEqual(store.warmupSessions.count, 1)
        XCTAssertEqual(store.selectedWarmupSessionId, original.id)
        XCTAssertEqual(store.warmup.map(\.id), DefaultWarmup.items.map(\.id))
    }

    func test_deleteWarmupSessionPurgesPerSessionCheckKeys() {
        let store = makeStore()
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
        let store = makeStore()
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
        let store = makeStore()
        let target = store.warmup.first!

        store.setWarmupChecked(target.id, checked: true)
        XCTAssertTrue(store.warmup.first { $0.id == target.id }?.checked == true)

        store.setWarmupChecked(target.id, checked: true)
        XCTAssertTrue(store.warmup.first { $0.id == target.id }?.checked == true)

        store.setWarmupChecked(target.id, checked: false)
        XCTAssertFalse(store.warmup.first { $0.id == target.id }?.checked == true)
    }

    func test_resetWarmupRoutineOnlyAffectsDefaultSession() {
        let store = makeStore()
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

    func test_addSkillRejectsDuplicateNamesIgnoringCaseAndWhitespace() {
        let store = makeStore()
        let beforeCount = store.skills.count

        XCTAssertTrue(store.addSkill(name: "  Back Lever  ", symbolName: "figure.core.training"))
        XCTAssertFalse(store.addSkill(name: "back lever", symbolName: "figure.gymnastics"))

        XCTAssertEqual(store.skills.count, beforeCount + 1)
        XCTAssertEqual(store.skills.last?.name, "Back Lever")
    }

    func test_customSkillWithDeprecatedDefaultNamePersistsAcrossReload() {
        let fileStore = InMemoryFileStore()
        let store = makeStore(fileStore: fileStore)

        XCTAssertTrue(store.addSkill(name: "  Back Lever  ", symbolName: "figure.core.training"))
        let added = store.skills.last!

        let reloaded = makeStore(fileStore: fileStore)

        XCTAssertTrue(reloaded.skills.contains { $0.id == added.id && $0.name == "Back Lever" })
    }

    func test_topFeedbackIsHighestScored() {
        let store = makeStore()
        addFeedback(to: store, title: "낮은 중요도", importance: 1)
        addFeedback(to: store, title: "높은 중요도", importance: 5)
        let top = store.topFeedback
        XCTAssertNotNil(top)
        let topScore = FeedbackScoring.score(for: top!)
        for f in store.unarchivedFeedbacks {
            XCTAssertLessThanOrEqual(FeedbackScoring.score(for: f), topScore)
        }
    }
}
