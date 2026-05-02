import Foundation

enum FeedbackScoring {
    private enum Constants {
        static let secondsPerDay: TimeInterval = 86_400
        static let importanceWeight = 10.0
        static let unresolvedWeight = 8.0
        static let ageWeight = 0.7
        static let staleReviewWeight = 1.2
        static let highTierThreshold = 80.0
        static let mediumTierThreshold = 50.0
    }

    static func score(for feedback: Feedback, now: Date = .now) -> Double {
        let referenceDate = feedback.lastReviewedAt ?? feedback.createdAt
        let daysSinceCreated = max(0, now.timeIntervalSince(feedback.createdAt) / Constants.secondsPerDay)
        let daysSinceReviewed = max(0, now.timeIntervalSince(referenceDate) / Constants.secondsPerDay)

        let raw = Double(feedback.importance) * Constants.importanceWeight
                + Double(feedback.unresolvedCount) * Constants.unresolvedWeight
                + daysSinceCreated * Constants.ageWeight
                + daysSinceReviewed * Constants.staleReviewWeight

        return (raw * 10).rounded() / 10
    }

    static func sortedActive(_ feedbacks: [Feedback], now: Date = .now) -> [Feedback] {
        feedbacks
            .filter { $0.status == .active }
            .sorted { score(for: $0, now: now) > score(for: $1, now: now) }
    }

    enum Tier {
        case high, medium, low
    }

    static func tier(for score: Double) -> Tier {
        if score >= Constants.highTierThreshold { return .high }
        if score >= Constants.mediumTierThreshold { return .medium }
        return .low
    }
}
