import XCTest
@testable import FeedbackBuffer

final class FeedbackScoringTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_730_000_000)
    private let skillId = UUID()

    private func makeFeedback(
        importance: Int = 3,
        unresolvedCount: Int = 0,
        daysSinceCreated: Double = 0,
        daysSinceLastReviewed: Double? = nil
    ) -> Feedback {
        let createdAt = now.addingTimeInterval(-daysSinceCreated * 86_400)
        let lastReviewedAt = daysSinceLastReviewed.map { now.addingTimeInterval(-$0 * 86_400) }
        return Feedback(
            skillId: skillId,
            skillName: "Test",
            title: "t",
            importance: importance,
            unresolvedCount: unresolvedCount,
            createdAt: createdAt,
            updatedAt: createdAt,
            lastReviewedAt: lastReviewedAt
        )
    }

    func test_scoreUsesAllFourFactors() {
        let f = makeFeedback(
            importance: 4,
            unresolvedCount: 2,
            daysSinceCreated: 10,
            daysSinceLastReviewed: 3
        )
        // 4*10 + 2*8 + 10*0.7 + 3*1.2 = 40 + 16 + 7 + 3.6 = 66.6
        let score = FeedbackScoring.score(for: f, now: now)
        XCTAssertEqual(score, 66.6, accuracy: 0.01)
    }

    func test_higherUnresolvedCountIncreasesScore() {
        let low = makeFeedback(importance: 3, unresolvedCount: 0)
        let high = makeFeedback(importance: 3, unresolvedCount: 5)
        XCTAssertGreaterThan(
            FeedbackScoring.score(for: high, now: now),
            FeedbackScoring.score(for: low, now: now)
        )
    }

    func test_lastReviewedAtNilFallsBackToCreatedAt() {
        let f = makeFeedback(importance: 1, unresolvedCount: 0, daysSinceCreated: 7, daysSinceLastReviewed: nil)
        // 1*10 + 0 + 7*0.7 + 7*1.2 = 10 + 4.9 + 8.4 = 23.3
        let score = FeedbackScoring.score(for: f, now: now)
        XCTAssertEqual(score, 23.3, accuracy: 0.01)
    }

    func test_olderUnreviewedFeedbackBubblesUp() {
        let fresh = makeFeedback(importance: 3, unresolvedCount: 0, daysSinceCreated: 0)
        let stale = makeFeedback(importance: 3, unresolvedCount: 0, daysSinceCreated: 30)
        let sorted = FeedbackScoring.sortedActive([fresh, stale], now: now)
        XCTAssertEqual(sorted.first?.id, stale.id)
    }

    func test_resolvedFeedbacksFilteredOut() {
        let active = makeFeedback(importance: 3)
        var resolved = makeFeedback(importance: 5)
        resolved.status = .resolved
        let sorted = FeedbackScoring.sortedActive([active, resolved], now: now)
        XCTAssertEqual(sorted.count, 1)
        XCTAssertEqual(sorted.first?.id, active.id)
    }

    func test_scoreRoundedToOneDecimal() {
        let f = makeFeedback(importance: 1, unresolvedCount: 0, daysSinceCreated: 1.0/3.0)
        let score = FeedbackScoring.score(for: f, now: now)
        let multiplied = score * 10
        XCTAssertEqual(multiplied, multiplied.rounded(), accuracy: 0.0001, "score should have at most 1 decimal")
    }

    func test_tierThresholds() {
        XCTAssertEqual(FeedbackScoring.tier(for: 90), .high)
        XCTAssertEqual(FeedbackScoring.tier(for: 80), .high)
        XCTAssertEqual(FeedbackScoring.tier(for: 79.9), .medium)
        XCTAssertEqual(FeedbackScoring.tier(for: 50), .medium)
        XCTAssertEqual(FeedbackScoring.tier(for: 49.9), .low)
    }
}
