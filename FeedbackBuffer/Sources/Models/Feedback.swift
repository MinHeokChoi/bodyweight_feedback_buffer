import Foundation

private enum FeedbackDateConstants {
    static let secondsPerDay: TimeInterval = 86_400
}

enum FeedbackStatus: String, Codable, Hashable {
    case active
    case resolved
}

struct Feedback: Identifiable, Codable, Hashable {
    let id: UUID
    var skillId: UUID
    var skillName: String
    var title: String
    var note: String
    var importance: Int
    var unresolvedCount: Int
    let createdAt: Date
    var updatedAt: Date
    var lastReviewedAt: Date?
    var resolvedAt: Date?
    var status: FeedbackStatus

    init(
        id: UUID = UUID(),
        skillId: UUID,
        skillName: String,
        title: String,
        note: String = "",
        importance: Int = 3,
        unresolvedCount: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastReviewedAt: Date? = nil,
        resolvedAt: Date? = nil,
        status: FeedbackStatus = .active
    ) {
        self.id = id
        self.skillId = skillId
        self.skillName = skillName
        self.title = title
        self.note = note
        self.importance = max(1, min(5, importance))
        self.unresolvedCount = max(0, unresolvedCount)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastReviewedAt = lastReviewedAt
        self.resolvedAt = resolvedAt
        self.status = status
    }

    var referenceDate: Date { lastReviewedAt ?? createdAt }

    func daysSince(_ date: Date, now: Date = .now) -> Int {
        let interval = now.timeIntervalSince(date)
        return max(0, Int(interval / FeedbackDateConstants.secondsPerDay))
    }

    var daysSinceCreated: Int { daysSince(createdAt) }
    var daysSinceLastReviewed: Int { daysSince(referenceDate) }
}
