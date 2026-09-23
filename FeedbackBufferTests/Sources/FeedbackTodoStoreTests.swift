import XCTest
@testable import FeedbackBuffer

/// 점수제를 없애고 todo 방식으로 바꾼 버퍼의 스토어 동작.
@MainActor
final class FeedbackTodoStoreTests: StoreTestCase {

    private func titles(_ items: [Feedback]) -> [String] { items.map(\.title) }

    // MARK: - 순서

    func test_newFeedbackGoesOnTop() {
        let store = makeFeedbackStore()
        addFeedback(to: store, title: "먼저")
        addFeedback(to: store, title: "나중")

        XCTAssertEqual(titles(store.unarchivedFeedbacks), ["나중", "먼저"])
    }

    /// 점수제에서는 방금 적은 ★5가 한 달 묵은 ★1보다 아래에 깔렸다.
    func test_importanceDoesNotReorder() {
        let store = makeFeedbackStore()
        addFeedback(to: store, title: "중요", importance: 5)
        addFeedback(to: store, title: "사소", importance: 1)

        XCTAssertEqual(titles(store.unarchivedFeedbacks), ["사소", "중요"])
    }

    func test_practiceAgainMovesToTopAndCounts() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        addFeedback(to: store, title: "b")
        addFeedback(to: store, title: "c")

        store.markPracticed(a.id)

        XCTAssertEqual(titles(store.unarchivedFeedbacks), ["a", "c", "b"])
        let updated = store.feedbacks.first { $0.id == a.id }!
        XCTAssertEqual(updated.unresolvedCount, 1)
        XCTAssertNotNil(updated.lastReviewedAt)
    }

    func test_unarchiveMovesToTop() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        addFeedback(to: store, title: "b")
        store.archive(a.id)

        store.unarchive(a.id)

        XCTAssertEqual(titles(store.unarchivedFeedbacks), ["a", "b"])
    }

    func test_dragReorderPersists() {
        let fileStore = InMemoryFileStore()
        let store = makeFeedbackStore(fileStore: fileStore)
        addFeedback(to: store, title: "c")
        addFeedback(to: store, title: "b")
        addFeedback(to: store, title: "a")
        let visible = store.unarchivedFeedbacks.map(\.id)

        // c를 맨 위로 끈다.
        store.moveFeedbacks(visibleIds: visible, fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(titles(store.unarchivedFeedbacks), ["c", "a", "b"])

        let reloaded = makeFeedbackStore(fileStore: fileStore)
        XCTAssertEqual(titles(reloaded.unarchivedFeedbacks), ["c", "a", "b"])
    }

    func test_skillListFollowsSameOrder() {
        let store = makeFeedbackStore()
        let skill = store.skills.first!
        addFeedback(to: store, title: "먼저")
        addFeedback(to: store, title: "나중")

        XCTAssertEqual(titles(store.unarchivedFeedbacks(forSkillId: skill.id)), ["나중", "먼저"])
    }

    // MARK: - 오늘 할 것

    func test_addToTodayMovesItOutOfBacklog() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        addFeedback(to: store, title: "b")

        store.addToToday(a.id)

        XCTAssertEqual(titles(store.todayFeedbacks()), ["a"])
        XCTAssertEqual(titles(store.backlogFeedbacks()), ["b"])
    }

    func test_removeFromTodayReturnsToBacklog() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        store.addToToday(a.id)

        store.removeFromToday(a.id)

        XCTAssertTrue(store.todayFeedbacks().isEmpty)
        XCTAssertEqual(titles(store.backlogFeedbacks()), ["a"])
    }

    /// 오늘 목록에서 또 하기를 누르면 오늘 몫은 끝난 것이라 조용히 빠진다.
    func test_practiceAgainLeavesToday() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        addFeedback(to: store, title: "b")
        store.addToToday(a.id)

        store.markPracticed(a.id)

        XCTAssertTrue(store.todayFeedbacks().isEmpty)
        XCTAssertEqual(titles(store.backlogFeedbacks()), ["a", "b"])
    }

    func test_archiveLeavesToday() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        store.addToToday(a.id)

        store.archive(a.id)

        XCTAssertTrue(store.todayFeedbacks().isEmpty)
        // 다시 꺼내도 오늘 목록으로 돌아가지 않는다.
        store.unarchive(a.id)
        XCTAssertTrue(store.todayFeedbacks().isEmpty)
    }

    func test_todayEmptiesOnTheNextDay() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        store.addToToday(a.id)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!

        XCTAssertTrue(store.todayFeedbacks(now: tomorrow).isEmpty)
        XCTAssertEqual(titles(store.backlogFeedbacks(now: tomorrow)), ["a"])
    }

    func test_todaySurvivesReload() {
        let fileStore = InMemoryFileStore()
        let store = makeFeedbackStore(fileStore: fileStore)
        let a = addFeedback(to: store, title: "a")
        store.addToToday(a.id)

        let reloaded = makeFeedbackStore(fileStore: fileStore)

        XCTAssertEqual(titles(reloaded.todayFeedbacks()), ["a"])
    }

    func test_reorderInsideTodayDoesNotTouchBacklog() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        addFeedback(to: store, title: "x")
        let b = addFeedback(to: store, title: "b")
        store.addToToday(a.id)
        store.addToToday(b.id)
        XCTAssertEqual(titles(store.todayFeedbacks()), ["b", "a"])

        store.moveFeedbacks(
            visibleIds: store.todayFeedbacks().map(\.id),
            fromOffsets: IndexSet(integer: 1),
            toOffset: 0
        )

        XCTAssertEqual(titles(store.todayFeedbacks()), ["a", "b"])
        XCTAssertEqual(titles(store.backlogFeedbacks()), ["x"])
    }

    // MARK: - 기술 칩

    func test_skillsWithActiveFeedbackOnly() {
        let store = makeFeedbackStore()
        let skill = store.skills.first!
        XCTAssertTrue(store.skillsWithActiveFeedback.isEmpty)

        let a = addFeedback(to: store, title: "a")
        XCTAssertEqual(store.skillsWithActiveFeedback.map(\.id), [skill.id])

        store.archive(a.id)
        XCTAssertTrue(store.skillsWithActiveFeedback.isEmpty)
    }

    // MARK: - 이관

    /// 점수제 시절 파일은 추가된 순서(오래된 것이 앞)다. 한 번만 마지막으로 손댄 순으로 세운다.
    func test_schemaTwoMigrationSortsByLastTouch() throws {
        let fileStore = InMemoryFileStore()
        let skillId = UUID()
        fileStore.seed(Data("""
        [{"id":"\(skillId.uuidString)","name":"Handstand","symbolName":"figure.gymnastics"}]
        """.utf8), to: "skills.json")
        fileStore.seed(Data("""
        [
          {"id":"\(UUID().uuidString)","skillId":"\(skillId.uuidString)","skillName":"Handstand",
           "title":"오래됨","note":"","importance":1,"unresolvedCount":0,"category":"skill",
           "createdAt":"2026-06-01T00:00:00Z","updatedAt":"2026-06-01T00:00:00Z"},
          {"id":"\(UUID().uuidString)","skillId":"\(skillId.uuidString)","skillName":"Handstand",
           "title":"최근에 연습","note":"","importance":1,"unresolvedCount":2,"category":"skill",
           "createdAt":"2026-05-01T00:00:00Z","updatedAt":"2026-09-20T00:00:00Z",
           "lastReviewedAt":"2026-09-20T00:00:00Z"},
          {"id":"\(UUID().uuidString)","skillId":"\(skillId.uuidString)","skillName":"Handstand",
           "title":"새것","note":"","importance":5,"unresolvedCount":0,"category":"skill",
           "createdAt":"2026-09-10T00:00:00Z","updatedAt":"2026-09-10T00:00:00Z"}
        ]
        """.utf8), to: "feedbacks.json")
        UserSettingsRepository(defaults: defaults).saveFeedbackSchemaVersion(1)

        let store = makeFeedbackStore(fileStore: fileStore)

        XCTAssertEqual(titles(store.unarchivedFeedbacks), ["최근에 연습", "새것", "오래됨"])

        // 이관된 순서가 저장돼서, 다시 열어도 같은 순서다.
        let reloaded = makeFeedbackStore(fileStore: fileStore)
        XCTAssertEqual(titles(reloaded.unarchivedFeedbacks), ["최근에 연습", "새것", "오래됨"])
    }

    /// 이관은 한 번뿐이다. 이후에 손으로 바꾼 순서를 다시 덮어쓰지 않는다.
    func test_migrationDoesNotRunAgain() {
        let fileStore = InMemoryFileStore()
        let store = makeFeedbackStore(fileStore: fileStore)
        let old = addFeedback(to: store, title: "오래됨")
        addFeedback(to: store, title: "새것")
        // 손으로 "오래됨"을 위로 올렸다.
        store.moveFeedbacks(
            visibleIds: store.unarchivedFeedbacks.map(\.id),
            fromOffsets: IndexSet(integer: 1),
            toOffset: 0
        )
        XCTAssertEqual(store.unarchivedFeedbacks.first?.id, old.id)

        let reloaded = makeFeedbackStore(fileStore: fileStore)

        XCTAssertEqual(titles(reloaded.unarchivedFeedbacks), ["오래됨", "새것"])
    }
}
