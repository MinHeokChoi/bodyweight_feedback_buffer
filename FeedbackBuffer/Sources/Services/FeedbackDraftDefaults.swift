import Foundation

/// 피드백을 새로 적을 때 미리 골라 둘 기술과 범주.
///
/// 운동 중에 가장 자주 도는 경로라 메뉴를 한 번이라도 덜 만지게 하는 것이 목적이다.
/// 모두 입력 기본값일 뿐이고, 저장하는 데이터에는 아무것도 붙이지 않는다(N13).
enum FeedbackDraftDefaults {

    /// 여는 곳이 정해 준 기술 → 가장 최근에 적은 피드백의 기술 → 첫 기술.
    ///
    /// "최근에 적은 기술"은 따로 저장하지 않고 데이터에서 구한다. 그 기술을 지우면
    /// 피드백도 함께 지워지므로 저절로 맞는다.
    static func skillId(preferred: UUID?, feedbacks: [Feedback], skills: [Skill]) -> UUID? {
        let known = Set(skills.map(\.id))
        if let preferred, known.contains(preferred) {
            return preferred
        }
        if let recent = latestWritten(in: feedbacks)?.skillId, known.contains(recent) {
            return recent
        }
        return skills.first?.id
    }

    /// 여는 곳이 정해 준 범주 → 그 기술로 마지막에 적은 피드백의 범주 → 기술 훈련.
    static func category(
        preferred: FeedbackCategory?,
        skillId: UUID?,
        feedbacks: [Feedback]
    ) -> FeedbackCategory {
        if let preferred {
            return preferred
        }
        if let skillId, let last = latestWritten(in: feedbacks.filter { $0.skillId == skillId }) {
            return last.category
        }
        return .skill
    }

    /// 타이머 구간에서 짐작할 수 있는 범주. 웜업·스트레칭·러닝은 짐작하지 않는다.
    static func category(for kind: TrainingPhaseKind) -> FeedbackCategory? {
        switch kind {
        case .strength, .fatigueResistance: .physical
        case .skillPractice: .skill
        case .warmup, .stretching, .running: nil
        }
    }

    private static func latestWritten(in feedbacks: [Feedback]) -> Feedback? {
        feedbacks.max { $0.createdAt < $1.createdAt }
    }
}
