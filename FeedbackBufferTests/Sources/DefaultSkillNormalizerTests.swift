import XCTest
@testable import FeedbackBuffer

final class DefaultSkillNormalizerTests: XCTestCase {

    func test_oldKoreanNamesMigrateToCanonical() {
        var skills = [
            Skill(name: "물구나무", symbolName: "dumbbell.fill"),
            Skill(name: "딥스", symbolName: "dumbbell.fill")
        ]

        XCTAssertTrue(DefaultSkillNormalizer.normalize(&skills))
        XCTAssertEqual(skills.map(\.name), ["Handstand", "Dips"])
    }

    func test_migrationKeepsIdsSoFeedbacksStayAttached() {
        let original = Skill(name: "딥스")
        var skills = [original]

        _ = DefaultSkillNormalizer.normalize(&skills)

        XCTAssertEqual(skills[0].id, original.id)
    }

    /// 사용자가 라이브러리에서 "딥스"를 직접 만들면 이미 "Dips"가 따로 있다.
    /// 이때 이름을 바꾸면 똑같은 카드가 둘 생기고, 방금 적은 피드백이 어느 쪽에
    /// 붙었는지 알 수 없게 된다.
    func test_doesNotRenameIntoAnExistingSkillName() {
        let userMade = Skill(name: "딥스")
        var skills = [
            Skill(name: "Dips"),
            userMade
        ]

        _ = DefaultSkillNormalizer.normalize(&skills)

        XCTAssertEqual(skills.map(\.name), ["Dips", "딥스"])
        XCTAssertEqual(skills.filter { $0.name == "Dips" }.count, 1)
        XCTAssertEqual(skills[1].id, userMade.id)
    }

    func test_collisionLeavesUserSkillUntouched() {
        var skills = [
            Skill(name: "Handstand", symbolName: DefaultSkill.handstand.symbolName),
            Skill(name: "물구나무", symbolName: "figure.gymnastics")
        ]

        let didChange = DefaultSkillNormalizer.normalize(&skills)

        // 사용자가 고른 아이콘도 건드리지 않는다.
        XCTAssertFalse(didChange)
        XCTAssertEqual(skills[1].symbolName, "figure.gymnastics")
    }

    func test_symbolIsNormalizedForCanonicalNames() {
        var skills = [Skill(name: "Dips", symbolName: "dumbbell.fill")]

        XCTAssertTrue(DefaultSkillNormalizer.normalize(&skills))
        XCTAssertEqual(skills[0].symbolName, DefaultSkill.dips.symbolName)
    }

    func test_customSkillsAreLeftAlone() {
        var skills = [
            Skill(name: "Handstand", symbolName: DefaultSkill.handstand.symbolName),
            Skill(name: "Back Lever", symbolName: "dumbbell.fill")
        ]

        XCTAssertFalse(DefaultSkillNormalizer.normalize(&skills))
        XCTAssertEqual(skills.map(\.name), ["Handstand", "Back Lever"])
    }

    func test_defaultOnlyListGetsSortedIntoCanonicalOrder() {
        var skills = [
            Skill(name: "Dips", symbolName: DefaultSkill.dips.symbolName),
            Skill(name: "Handstand", symbolName: DefaultSkill.handstand.symbolName)
        ]

        XCTAssertTrue(DefaultSkillNormalizer.normalize(&skills))
        XCTAssertEqual(skills.map(\.name), ["Handstand", "Dips"])
    }
}
