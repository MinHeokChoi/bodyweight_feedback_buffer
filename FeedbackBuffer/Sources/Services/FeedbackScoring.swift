import Foundation

enum FeedbackScoring {
    private enum Constants {
        static let secondsPerDay: TimeInterval = 86_400
        static let importanceWeight = 10.0
        static let unresolvedWeight = 8.0
        static let ageWeight = 0.7
        static let staleReviewWeight = 1.2
        static let criticalTierThreshold = 100.0
        static let highTierThreshold = 60.0
        static let mediumTierThreshold = 35.0
    }

    static func score(for feedback: Feedback, now: Date = .now) -> Double {
        let daysSinceCreated = max(0, now.timeIntervalSince(feedback.createdAt) / Constants.secondsPerDay)
        let daysSinceReviewed = max(0, now.timeIntervalSince(feedback.referenceDate) / Constants.secondsPerDay)

        let raw = Double(feedback.importance) * Constants.importanceWeight
                + Double(feedback.unresolvedCount) * Constants.unresolvedWeight
                + daysSinceCreated * Constants.ageWeight
                + daysSinceReviewed * Constants.staleReviewWeight

        return (raw * 10).rounded() / 10
    }

    /// Computes each active feedback's score once, then sorts by precomputed score (descending).
    static func sortedActiveWithScores(_ feedbacks: [Feedback], now: Date = .now) -> [(Feedback, Double)] {
        var scored: [(Feedback, Double)] = []
        scored.reserveCapacity(feedbacks.count)
        for feedback in feedbacks where feedback.status == .active {
            scored.append((feedback, score(for: feedback, now: now)))
        }
        scored.sort { $0.1 > $1.1 }
        return scored
    }

    static func sortedActive(_ feedbacks: [Feedback], now: Date = .now) -> [Feedback] {
        sortedActiveWithScores(feedbacks, now: now).map(\.0)
    }

    enum Tier {
        case critical, high, medium, low
    }

    static func tier(for score: Double) -> Tier {
        if score >= Constants.criticalTierThreshold { return .critical }
        if score >= Constants.highTierThreshold { return .high }
        if score >= Constants.mediumTierThreshold { return .medium }
        return .low
    }
}
