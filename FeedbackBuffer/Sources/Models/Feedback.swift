import Foundation

private enum FeedbackDateConstants {
    static let secondsPerDay: TimeInterval = 86_400
}

enum FeedbackCategory: String, Codable, Hashable, CaseIterable, Identifiable {
    case physical
    case skill

    var id: String { rawValue }

    /// "기술 훈련"은 타이머 구간 "기술 연습"과 같은 아이콘을 쓰면서 이름이 달랐다.
    /// 범주는 짧게 "체력 / 기술"로 부른다. 필터 칩 자리도 넉넉해진다.
    var displayName: String {
        switch self {
        case .physical: "체력"
        case .skill: "기술"
        }
    }

    var systemImage: String {
        switch self {
        case .physical: "dumbbell.fill"
        case .skill: "figure.gymnastics"
        }
    }
}

enum FeedbackPhase: Hashable {
    case new
    case practicing
    case adapting
    case archived
}

struct Feedback: Identifiable, Codable, Hashable {
    let id: UUID
    var skillId: UUID
    var skillName: String
    var title: String
    var note: String
    var importance: Int
    /// 연습 횟수. 옛 스키마에서는 "미해결 횟수"였으나 1.0.1부터 의미를 재해석했고 키 이름은 호환성 위해 유지한다.
    var unresolvedCount: Int
    var category: FeedbackCategory
    let createdAt: Date
    var updatedAt: Date
    var lastReviewedAt: Date?
    var archivedAt: Date?
    /// 오늘 할 것에 담은 시각. 날짜가 오늘이 아니면 담겨 있지 않은 것이다.
    ///
    /// 날짜로 두는 이유는 날이 바뀌면 저절로 비워지게 하려는 것이다.
    /// 어제 못 한 것을 치우는 일을 만들지 않는다.
    var todayAddedAt: Date?

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
        archivedAt: Date? = nil,
        todayAddedAt: Date? = nil
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
        self.archivedAt = archivedAt
        self.todayAddedAt = todayAddedAt
    }

    var referenceDate: Date { lastReviewedAt ?? createdAt }

    func isInToday(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard archivedAt == nil, let todayAddedAt else { return false }
        return calendar.isDate(todayAddedAt, inSameDayAs: now)
    }

    func daysSince(_ date: Date, now: Date = .now) -> Int {
        let interval = now.timeIntervalSince(date)
        return max(0, Int(interval / FeedbackDateConstants.secondsPerDay))
    }

    var daysSinceCreated: Int { daysSince(createdAt) }
    var daysSinceLastReviewed: Int { daysSince(referenceDate) }

    /// 이만큼 손대지 않으면 카드에 경과일을 드러낸다.
    ///
    /// 순서는 사용자가 정하므로 오래 방치된 것이 위로 올라오지 않는다.
    /// 대신 순서는 건드리지 않고 사실만 알려준다.
    static let staleThresholdDays = 30

    var isStale: Bool { daysSinceLastReviewed >= Self.staleThresholdDays }

    /// 임계값(3)은 이 한 곳에만 정의한다.
    var phase: FeedbackPhase {
        if archivedAt != nil { return .archived }
        switch max(0, unresolvedCount) {
        case 0: return .new
        case 1...2: return .practicing
        default: return .adapting
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, skillId, skillName, title, note
        case importance, unresolvedCount, category
        case createdAt, updatedAt, lastReviewedAt, archivedAt
        case todayAddedAt
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case resolvedAt, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.skillId = try c.decode(UUID.self, forKey: .skillId)
        self.skillName = try c.decode(String.self, forKey: .skillName)
        self.title = try c.decode(String.self, forKey: .title)
        self.note = try c.decode(String.self, forKey: .note)
        self.importance = try c.decode(Int.self, forKey: .importance)
        self.unresolvedCount = max(0, try c.decode(Int.self, forKey: .unresolvedCount))
        self.category = try c.decodeIfPresent(FeedbackCategory.self, forKey: .category) ?? .skill
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        self.lastReviewedAt = try c.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        self.todayAddedAt = try c.decodeIfPresent(Date.self, forKey: .todayAddedAt)

        if let archived = try c.decodeIfPresent(Date.self, forKey: .archivedAt) {
            self.archivedAt = archived
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            if let resolvedAt = try legacy.decodeIfPresent(Date.self, forKey: .resolvedAt) {
                self.archivedAt = resolvedAt
            } else if (try? legacy.decodeIfPresent(String.self, forKey: .status)) == "resolved" {
                self.archivedAt = self.updatedAt
            } else {
                self.archivedAt = nil
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(skillId, forKey: .skillId)
        try c.encode(skillName, forKey: .skillName)
        try c.encode(title, forKey: .title)
        try c.encode(note, forKey: .note)
        try c.encode(importance, forKey: .importance)
        try c.encode(unresolvedCount, forKey: .unresolvedCount)
        try c.encode(category, forKey: .category)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(lastReviewedAt, forKey: .lastReviewedAt)
        try c.encodeIfPresent(archivedAt, forKey: .archivedAt)
        try c.encodeIfPresent(todayAddedAt, forKey: .todayAddedAt)
    }
}
