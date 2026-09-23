import XCTest
@testable import FeedbackBuffer

/// 해결·또 하기 되돌리기.
@MainActor
final class FeedbackUndoTests: StoreTestCase {

    private func titles(_ items: [Feedback]) -> [String] { items.map(\.title) }

    func test_undoPracticedRestoresPlaceCountAndToday() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        addFeedback(to: store, title: "b")
        addFeedback(to: store, title: "c")
        store.addToToday(a.id)
        let before = store.feedbacks

        store.markPracticed(a.id)
        XCTAssertEqual(store.undoableAction?.kind, .practiced)

        store.undoLastAction()

        XCTAssertEqual(store.feedbacks, before, "자리·횟수·마지막으로 한 날·오늘 할 것이 모두 돌아와야 한다")
        XCTAssertNil(store.undoableAction)
    }

    func test_undoArchiveRestoresToSamePlaceAndToday() {
        let store = makeFeedbackStore()
        addFeedback(to: store, title: "a")
        let b = addFeedback(to: store, title: "b")
        addFeedback(to: store, title: "c")
        store.addToToday(b.id)
        let before = store.feedbacks

        store.archive(b.id)
        XCTAssertEqual(store.undoableAction?.kind, .archive)
        XCTAssertFalse(store.todayFeedbacks().contains { $0.id == b.id })

        store.undoLastAction()

        XCTAssertEqual(store.feedbacks, before)
        XCTAssertEqual(titles(store.todayFeedbacks()), ["b"])
    }

    func test_undoIsPersisted() {
        let fileStore = InMemoryFileStore()
        let store = makeFeedbackStore(fileStore: fileStore)
        let a = addFeedback(to: store, title: "a")
        addFeedback(to: store, title: "b")

        store.markPracticed(a.id)
        store.undoLastAction()

        let reloaded = makeFeedbackStore(fileStore: fileStore)
        XCTAssertEqual(titles(reloaded.unarchivedFeedbacks), ["b", "a"])
        XCTAssertEqual(reloaded.feedbacks.first { $0.id == a.id }?.unresolvedCount, 0)
    }

    /// 되돌리기가 그 사이의 다른 변경까지 되감으면 안 된다. 다른 변경이 생기면 사라진다.
    func test_anyOtherChangeDiscardsUndo() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        let b = addFeedback(to: store, title: "b")

        store.markPracticed(a.id)
        store.addToToday(b.id)
        XCTAssertNil(store.undoableAction)

        store.archive(a.id)
        addFeedback(to: store, title: "c")
        XCTAssertNil(store.undoableAction)

        store.markPracticed(b.id)
        store.moveFeedbacks(visibleIds: store.unarchivedFeedbacks.map(\.id), fromOffsets: [0], toOffset: 2)
        XCTAssertNil(store.undoableAction)

        store.markPracticed(b.id)
        store.delete(a.id)
        XCTAssertNil(store.undoableAction)
    }

    func test_undoWithoutActionDoesNothing() {
        let store = makeFeedbackStore()
        addFeedback(to: store, title: "a")
        let before = store.feedbacks

        store.undoLastAction()

        XCTAssertEqual(store.feedbacks, before)
    }

    /// 앞 띠가 사라지는 시점에 이미 새 동작이 있었다면 새 것은 남는다.
    func test_expiringOldUndoKeepsNewerOne() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        let b = addFeedback(to: store, title: "b")

        store.markPracticed(a.id)
        let first = store.undoableAction!.id
        store.markPracticed(b.id)

        store.expireUndo(first)

        XCTAssertEqual(store.undoableAction?.previous.id, b.id)
    }

    func test_undoExpiresAfterWindow() {
        let store = makeFeedbackStore()
        let a = addFeedback(to: store, title: "a")
        let now = Date(timeIntervalSince1970: 1_000_000)

        store.markPracticed(a.id, now: now)

        XCTAssertEqual(store.undoableAction?.expiresAt, now.addingTimeInterval(FeedbackStore.undoWindow))
    }
}
