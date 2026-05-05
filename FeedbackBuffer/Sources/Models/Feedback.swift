import Foundation

private enum FeedbackDateConstants {
    static let secondsPerDay: TimeInterval = 86_400
}

enum FeedbackStatus: String, Codable, Hashable {
    case active
    case resolved
}

enum FeedbackCategory: String, Codable, Hashable, CaseIterable, Identifiable {
    case physical
    case skill

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .physical: "체력 훈련"
        case .skill: "기술 훈련"
        }
    }

    var systemImage: String {
        switch self {
        case .physical: "dumbbell.fill"
        case .skill: "figure.gymnastics"
        }
    }
}

struct Feedback: Identifiable, Codable, Hashable {
    let id: UUID
    var skillId: UUID
    var skillName: String
    var title: String
    var note: String
    var importance: Int
    var unresolvedCount: Int
    var category: FeedbackCategory
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
        category: FeedbackCategory = .skill,
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
        self.category = category
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

    // Custom decoder so existing JSON without `category` defaults to `.skill`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.skillId = try c.decode(UUID.self, forKey: .skillId)
        self.skillName = try c.decode(String.self, forKey: .skillName)
        self.title = try c.decode(String.self, forKey: .title)
        self.note = try c.decode(String.self, forKey: .note)
        self.importance = try c.decode(Int.self, forKey: .importance)
        self.unresolvedCount = try c.decode(Int.self, forKey: .unresolvedCount)
        self.category = try c.decodeIfPresent(FeedbackCategory.self, forKey: .category) ?? .skill
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        self.lastReviewedAt = try c.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        self.resolvedAt = try c.decodeIfPresent(Date.self, forKey: .resolvedAt)
        self.status = try c.decode(FeedbackStatus.self, forKey: .status)
    }
}
