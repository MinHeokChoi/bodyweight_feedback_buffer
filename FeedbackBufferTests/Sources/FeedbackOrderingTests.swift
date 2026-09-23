import XCTest
@testable import FeedbackBuffer

final class FeedbackOrderingTests: XCTestCase {
    private let skillId = UUID()
    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)

    private func feedback(
        _ title: String,
        createdDaysAgo: Double = 0,
        reviewedDaysAgo: Double? = nil,
        archived: Bool = false
    ) -> Feedback {
        Feedback(
            skillId: skillId,
            skillName: "Handstand",
            title: title,
            createdAt: t0.addingTimeInterval(-createdDaysAgo * 86_400),
            lastReviewedAt: reviewedDaysAgo.map { t0.addingTimeInterval(-$0 * 86_400) },
            archivedAt: archived ? t0 : nil
        )
    }

    private func titles(_ items: [Feedback]) -> [String] { items.map(\.title) }

    // MARK: - 이관

    func test_migrationPutsMostRecentlyTouchedFirst() {
        // 점수제 시절 배열은 추가된 순서 — 오래된 것이 앞이다.
        let old = feedback("오래됨", createdDaysAgo: 60)
        let reviewed = feedback("최근에 연습", createdDaysAgo: 90, reviewedDaysAgo: 1)
        let fresh = feedback("새것", createdDaysAgo: 5)

        let migrated = FeedbackOrdering.migratedOrder([old, reviewed, fresh])

        XCTAssertEqual(titles(migrated), ["최근에 연습", "새것", "오래됨"])
    }

    func test_migrationKeepsOriginalOrderOnTies() {
        let a = feedback("a", createdDaysAgo: 3)
        let b = feedback("b", createdDaysAgo: 3)

        XCTAssertEqual(titles(FeedbackOrdering.migratedOrder([a, b])), ["a", "b"])
    }

    // MARK: - 맨 앞으로

    func test_movingToFront() {
        let items = ["a", "b", "c"].map { feedback($0) }

        let moved = FeedbackOrdering.movingToFront(items[2].id, in: items)

        XCTAssertEqual(titles(moved), ["c", "a", "b"])
    }

    func test_movingToFrontIgnoresUnknownIdAndFirstItem() {
        let items = ["a", "b"].map { feedback($0) }

        XCTAssertEqual(titles(FeedbackOrdering.movingToFront(UUID(), in: items)), ["a", "b"])
        XCTAssertEqual(titles(FeedbackOrdering.movingToFront(items[0].id, in: items)), ["a", "b"])
    }

    // MARK: - 끌어서 옮기기

    func test_reorderingWholeVisibleList() {
        let items = ["a", "b", "c"].map { feedback($0) }

        let result = FeedbackOrdering.reordering(
            items,
            visibleIds: items.map(\.id),
            fromOffsets: IndexSet(integer: 2),
            toOffset: 0
        )

        XCTAssertEqual(titles(result), ["c", "a", "b"])
    }

    /// 보이는 항목들이 차지하던 자리만 다시 채운다. 보관한 것이나 다른 구역의
    /// 항목은 한 칸도 움직이지 않는다.
    func test_reorderingKeepsHiddenItemsInPlace() {
        let a = feedback("a")
        let archived = feedback("보관", archived: true)
        let b = feedback("b")
        let today = feedback("오늘")
        let c = feedback("c")
        let all = [a, archived, b, today, c]

        // 화면에는 a, b, c만 보인다. c를 맨 위로 끈다.
        let result = FeedbackOrdering.reordering(
            all,
            visibleIds: [a.id, b.id, c.id],
            fromOffsets: IndexSet(integer: 2),
            toOffset: 0
        )

        XCTAssertEqual(titles(result), ["c", "보관", "a", "오늘", "b"])
    }

    func test_reorderingNoOpReturnsSameArray() {
        let items = ["a", "b"].map { feedback($0) }

        let result = FeedbackOrdering.reordering(
            items,
            visibleIds: items.map(\.id),
            fromOffsets: IndexSet(integer: 0),
            toOffset: 0
        )

        XCTAssertEqual(titles(result), ["a", "b"])
    }

    // MARK: - 임시 순서

    func test_temporaryOrderIsApplied() {
        let items = ["a", "b", "c"].map { feedback($0) }
        let order = [items[2].id, items[0].id, items[1].id]

        let result = FeedbackOrdering.applyingTemporaryOrder(items, order: order)

        XCTAssertEqual(titles(result), ["c", "a", "b"])
    }

    func test_newItemsGoOnTopOfTemporaryOrder() {
        let items = ["a", "b"].map { feedback($0) }
        let fresh = feedback("방금 적음")

        // 임시 순서를 만든 뒤에 새 피드백이 생겼다.
        let order = [items[1].id, items[0].id]
        let result = FeedbackOrdering.applyingTemporaryOrder([fresh] + items, order: order)

        XCTAssertEqual(titles(result), ["방금 적음", "b", "a"])
    }

    func test_removedItemsDropOutOfTemporaryOrder() {
        let items = ["a", "b", "c"].map { feedback($0) }
        let order = [items[2].id, items[1].id, items[0].id]

        // b를 해결해서 목록에서 빠졌다.
        let result = FeedbackOrdering.applyingTemporaryOrder([items[0], items[2]], order: order)

        XCTAssertEqual(titles(result), ["c", "a"])
    }

    func test_emptyTemporaryOrderKeepsSavedOrder() {
        let items = ["a", "b"].map { feedback($0) }

        XCTAssertEqual(titles(FeedbackOrdering.applyingTemporaryOrder(items, order: [])), ["a", "b"])
    }
}

final class FeedbackModelTodayTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func feedback(todayAddedAt: Date?, archived: Bool = false) -> Feedback {
        Feedback(
            skillId: UUID(),
            skillName: "Handstand",
            title: "라인",
            archivedAt: archived ? .now : nil,
            todayAddedAt: todayAddedAt
        )
    }

    func test_inTodayOnlyOnTheSameDay() {
        let morning = DateComponents(calendar: calendar, year: 2026, month: 9, day: 23, hour: 8).date!
        let evening = DateComponents(calendar: calendar, year: 2026, month: 9, day: 23, hour: 22).date!
        let nextDay = DateComponents(calendar: calendar, year: 2026, month: 9, day: 24, hour: 7).date!
        let item = feedback(todayAddedAt: morning)

        XCTAssertTrue(item.isInToday(now: evening, calendar: calendar))
        // 날이 바뀌면 아무것도 하지 않아도 오늘 목록에서 빠진다.
        XCTAssertFalse(item.isInToday(now: nextDay, calendar: calendar))
    }

    func test_archivedIsNeverInToday() {
        XCTAssertFalse(feedback(todayAddedAt: .now, archived: true).isInToday())
    }

    func test_todayAddedAtRoundTrips() throws {
        let item = feedback(todayAddedAt: Date(timeIntervalSince1970: 1_750_000_000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(Feedback.self, from: encoder.encode(item))

        XCTAssertEqual(decoded.todayAddedAt, item.todayAddedAt)
    }

    func test_oldRecordsWithoutTodayDecode() throws {
        let json = """
        {"id":"\(UUID().uuidString)","skillId":"\(UUID().uuidString)","skillName":"Handstand",
         "title":"라인","note":"","importance":3,"unresolvedCount":0,"category":"skill",
         "createdAt":"2026-09-01T00:00:00Z","updatedAt":"2026-09-01T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(Feedback.self, from: Data(json.utf8))

        XCTAssertNil(decoded.todayAddedAt)
    }

    func test_staleAfterThirtyDaysUntouched() {
        let fresh = Feedback(skillId: UUID(), skillName: "a", title: "a",
                             createdAt: .now.addingTimeInterval(-29 * 86_400))
        let stale = Feedback(skillId: UUID(), skillName: "a", title: "a",
                             createdAt: .now.addingTimeInterval(-31 * 86_400))
        let revived = Feedback(skillId: UUID(), skillName: "a", title: "a",
                               createdAt: .now.addingTimeInterval(-90 * 86_400),
                               lastReviewedAt: .now)

        XCTAssertFalse(fresh.isStale)
        XCTAssertTrue(stale.isStale)
        // 오래전에 적었어도 최근에 또 했으면 묵은 게 아니다.
        XCTAssertFalse(revived.isStale)
    }
}

final class BufferFilterTests: XCTestCase {
    func test_legacyValuesStillRead() {
        XCTAssertEqual(BufferFilter(storageValue: "all"), .all)
        XCTAssertEqual(BufferFilter(storageValue: "physical"), .category(.physical))
        XCTAssertEqual(BufferFilter(storageValue: "skill"), .category(.skill))
        XCTAssertEqual(BufferFilter(storageValue: "뭔가 이상한 값"), .all)
    }

    func test_skillFilterRoundTrips() {
        let id = UUID()
        let filter = BufferFilter.skill(id)

        XCTAssertEqual(BufferFilter(storageValue: filter.storageValue), filter)
    }

    func test_includes() {
        let skillId = UUID()
        let item = Feedback(skillId: skillId, skillName: "Handstand", title: "라인", category: .physical)

        XCTAssertTrue(BufferFilter.all.includes(item))
        XCTAssertTrue(BufferFilter.category(.physical).includes(item))
        XCTAssertFalse(BufferFilter.category(.skill).includes(item))
        XCTAssertTrue(BufferFilter.skill(skillId).includes(item))
        XCTAssertFalse(BufferFilter.skill(UUID()).includes(item))
    }
}
