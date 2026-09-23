import XCTest
@testable import FeedbackBuffer

/// 피드백을 새로 적을 때 미리 골라 둘 기술과 범주.
final class FeedbackDraftDefaultsTests: XCTestCase {

    private let handstand = Skill(name: "Handstand", symbolName: "a")
    private let pullUps = Skill(name: "Pull ups", symbolName: "b")
    private let dips = Skill(name: "Dips", symbolName: "c")
    private var skills: [Skill] { [handstand, pullUps, dips] }

    private func feedback(
        _ skill: Skill,
        category: FeedbackCategory = .skill,
        createdAt seconds: TimeInterval
    ) -> Feedback {
        Feedback(
            skillId: skill.id,
            skillName: skill.name,
            title: "t",
            category: category,
            createdAt: Date(timeIntervalSince1970: seconds)
        )
    }

    // MARK: - 기술

    func test_preferredSkillWins() {
        let feedbacks = [feedback(pullUps, createdAt: 100)]
        XCTAssertEqual(
            FeedbackDraftDefaults.skillId(preferred: dips.id, feedbacks: feedbacks, skills: skills),
            dips.id
        )
    }

    /// 순서는 끌어서 바뀌므로 배열 맨 앞이 아니라 가장 최근에 적은 것을 본다.
    func test_fallsBackToMostRecentlyWrittenSkill() {
        let feedbacks = [
            feedback(handstand, createdAt: 100),
            feedback(pullUps, createdAt: 300),
            feedback(dips, createdAt: 200)
        ]
        XCTAssertEqual(
            FeedbackDraftDefaults.skillId(preferred: nil, feedbacks: feedbacks, skills: skills),
            pullUps.id
        )
    }

    func test_unknownPreferredSkillIsIgnored() {
        let feedbacks = [feedback(dips, createdAt: 100)]
        XCTAssertEqual(
            FeedbackDraftDefaults.skillId(preferred: UUID(), feedbacks: feedbacks, skills: skills),
            dips.id
        )
    }

    func test_withoutFeedbacksUsesFirstSkill() {
        XCTAssertEqual(
            FeedbackDraftDefaults.skillId(preferred: nil, feedbacks: [], skills: skills),
            handstand.id
        )
        XCTAssertNil(FeedbackDraftDefaults.skillId(preferred: nil, feedbacks: [], skills: []))
    }

    // MARK: - 범주

    func test_preferredCategoryWins() {
        let feedbacks = [feedback(pullUps, category: .skill, createdAt: 100)]
        XCTAssertEqual(
            FeedbackDraftDefaults.category(preferred: .physical, skillId: pullUps.id, feedbacks: feedbacks),
            .physical
        )
    }

    func test_categoryFollowsSkillsLastFeedback() {
        let feedbacks = [
            feedback(pullUps, category: .skill, createdAt: 100),
            feedback(pullUps, category: .physical, createdAt: 200),
            feedback(handstand, category: .skill, createdAt: 300)
        ]
        XCTAssertEqual(
            FeedbackDraftDefaults.category(preferred: nil, skillId: pullUps.id, feedbacks: feedbacks),
            .physical
        )
    }

    func test_categoryDefaultsToSkill() {
        XCTAssertEqual(
            FeedbackDraftDefaults.category(preferred: nil, skillId: dips.id, feedbacks: []),
            .skill
        )
    }

    func test_categoryFromTimerSegment() {
        XCTAssertEqual(FeedbackDraftDefaults.category(for: .strength), .physical)
        XCTAssertEqual(FeedbackDraftDefaults.category(for: .fatigueResistance), .physical)
        XCTAssertEqual(FeedbackDraftDefaults.category(for: .skillPractice), .skill)
        XCTAssertNil(FeedbackDraftDefaults.category(for: .warmup))
        XCTAssertNil(FeedbackDraftDefaults.category(for: .stretching))
        XCTAssertNil(FeedbackDraftDefaults.category(for: .running))
    }
}
