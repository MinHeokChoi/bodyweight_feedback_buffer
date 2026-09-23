import XCTest
@testable import FeedbackBuffer

@MainActor
final class FeedbackStoreTests: StoreTestCase {
    func test_bootstrapSeedsDefaultSkillsWithoutSampleFeedbacks() {
        let store = makeFeedbackStore()

        XCTAssertFalse(store.skills.isEmpty)
        XCTAssertTrue(store.feedbacks.isEmpty)
    }

    func test_quickPhrasesPersistAcrossReload() {
        let fileStore = InMemoryFileStore()
        let store = makeFeedbackStore(fileStore: fileStore)
        let phrases = ["손목 눌림", "복압 풀림"]

        store.updateQuickPhrases(phrases)

        XCTAssertEqual(makeFeedbackStore(fileStore: fileStore).quickPhrases, phrases)
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

        let store = makeFeedbackStore(fileStore: fileStore)

        XCTAssertEqual(store.skills.map(\.id), [pullUpsId, backLeverId, handstandId, otherId])
        XCTAssertEqual(store.skills.map(\.name), ["Pull ups", "Back Lever", "Handstand", "기타"])
        XCTAssertEqual(store.skills.map(\.symbolName), ["pull.ups.full", "figure.core.training", "handstand.full", "ellipsis.circle"])
    }

    func test_addFeedbackGoesToTopAndPersists() {
        let store = makeFeedbackStore()
        let skill = store.skills.first!
        let before = store.feedbacks.count

        store.addFeedback(skill: skill, title: "  새 피드백  ", note: "memo", importance: 4)

        XCTAssertEqual(store.feedbacks.count, before + 1)
        let added = store.feedbacks.first!
        XCTAssertEqual(added.title, "새 피드백")
        XCTAssertEqual(added.importance, 4)
        XCTAssertEqual(added.skillId, skill.id)
    }

    func test_firstFeedbackPersistsSeededDefaultSkillsForStableIds() throws {
        let fileStore = InMemoryFileStore()
        let store = makeFeedbackStore(fileStore: fileStore)
        let skill = store.skills.first!

        store.addFeedback(skill: skill, title: "라인 유지", note: "", importance: 3)

        let savedSkills = try fileStore.load([Skill].self, from: "skills.json")
        XCTAssertEqual(savedSkills?.first?.id, skill.id)

        let reloaded = makeFeedbackStore(fileStore: fileStore)
        XCTAssertEqual(reloaded.feedbacks.first?.skillId, skill.id)
        XCTAssertEqual(reloaded.skills.first?.id, skill.id)
    }

    func test_addFeedbackRejectsBlankTitle() {
        let store = makeFeedbackStore()
        let skill = store.skills.first!
        let before = store.feedbacks.count

        store.addFeedback(skill: skill, title: "   ", note: "", importance: 3)

        XCTAssertEqual(store.feedbacks.count, before)
    }

    func test_archiveRemovesFromUnarchived() {
        let store = makeFeedbackStore()
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
        let store = makeFeedbackStore()
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
        let store = makeFeedbackStore()
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
        let skillsJSON = """
        [{"id":"\(skillId.uuidString)","name":"Handstand","symbolName":"figure.gymnastics"}]
        """
        let feedbacksJSON = """
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
        fileStore.seed(Data(skillsJSON.utf8), to: "skills.json")
        fileStore.seed(Data(feedbacksJSON.utf8), to: "feedbacks.json")

        let store = makeFeedbackStore(fileStore: fileStore)

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
        let skillsJSON = """
        [{"id":"\(skillId.uuidString)","name":"Handstand","symbolName":"figure.gymnastics"}]
        """
        let feedbacksJSON = """
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
        fileStore.seed(Data(skillsJSON.utf8), to: "skills.json")
        fileStore.seed(Data(feedbacksJSON.utf8), to: "feedbacks.json")

        let store = makeFeedbackStore(fileStore: fileStore)

        let migrated = store.feedbacks.first { $0.id == feedbackId }
        let formatter = ISO8601DateFormatter()
        XCTAssertEqual(migrated?.archivedAt, formatter.date(from: "2025-01-05T00:00:00Z"))
        XCTAssertEqual(migrated?.phase, .archived)
    }

    func test_markPracticedIncrementsCountAndUpdatesReview() {
        let store = makeFeedbackStore()
        let target = addFeedback(to: store)
        let beforeCount = target.unresolvedCount

        store.markPracticed(target.id)

        let updated = store.feedbacks.first { $0.id == target.id }!
        XCTAssertEqual(updated.unresolvedCount, beforeCount + 1)
        XCTAssertNotNil(updated.lastReviewedAt)
    }

    func test_deleteRemovesPermanently() {
        let store = makeFeedbackStore()
        let target = addFeedback(to: store)

        store.delete(target.id)

        XCTAssertFalse(store.feedbacks.contains { $0.id == target.id })
    }

    func test_skillMutationsPersistAndSyncFeedbackNames() {
        let fileStore = InMemoryFileStore()
        let store = makeFeedbackStore(fileStore: fileStore)
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

        let reloaded = makeFeedbackStore(fileStore: fileStore)
        XCTAssertEqual(reloaded.skills.first?.id, added.id)
        XCTAssertEqual(reloaded.feedbacks.first { $0.skillId == added.id }?.skillName, "백레버 홀드")

        reloaded.deleteSkill(added.id)
        XCTAssertFalse(reloaded.skills.contains { $0.id == added.id })
        XCTAssertFalse(reloaded.feedbacks.contains { $0.skillId == added.id })
    }

    func test_addSkillRejectsDuplicateNamesIgnoringCaseAndWhitespace() {
        let store = makeFeedbackStore()
        let beforeCount = store.skills.count

        XCTAssertTrue(store.addSkill(name: "  Back Lever  ", symbolName: "figure.core.training"))
        XCTAssertFalse(store.addSkill(name: "back lever", symbolName: "figure.gymnastics"))

        XCTAssertEqual(store.skills.count, beforeCount + 1)
        XCTAssertEqual(store.skills.last?.name, "Back Lever")
    }

    func test_customSkillWithDeprecatedDefaultNamePersistsAcrossReload() {
        let fileStore = InMemoryFileStore()
        let store = makeFeedbackStore(fileStore: fileStore)

        XCTAssertTrue(store.addSkill(name: "  Back Lever  ", symbolName: "figure.core.training"))
        let added = store.skills.last!

        let reloaded = makeFeedbackStore(fileStore: fileStore)

        XCTAssertTrue(reloaded.skills.contains { $0.id == added.id && $0.name == "Back Lever" })
    }
}
