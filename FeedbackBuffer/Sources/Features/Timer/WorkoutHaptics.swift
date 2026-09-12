import UIKit

/// 타이머 화면의 진동 신호를 한곳에 모은다.
///
/// 신호는 세기가 아니라 **횟수로 구분한다**. 운동 중에는 세기 차이를 구별하기
/// 어렵지만 몇 번 울렸는지는 알 수 있기 때문이다.
///
/// - 3분 세트 경계: 짧게 1회
/// - 9분 운동 경계: 짧게 2회
@MainActor
final class WorkoutHaptics {

    /// 두 번 울릴 때의 간격.
    ///
    /// 너무 좁으면 한 번처럼 뭉쳐 들리고, 너무 넓으면 별개의 신호 두 개로 들린다.
    /// 실제 손에서 느껴본 뒤 조정할 값이라 이 한 줄만 고치면 되도록 뽑아 뒀다.
    static let doublePulseInterval: TimeInterval = 0.16

    private let setGenerator = UIImpactFeedbackGenerator(style: .light)
    private let lapGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let actionGenerator = UIImpactFeedbackGenerator(style: .medium)

    /// Taptic Engine을 미리 깨워 둔다.
    ///
    /// 준비 없이 치면 첫 진동이 최대 수백 밀리초 늦거나 약하게 나온다. 경계에
    /// 정확히 맞춰야 하는 신호라 그 지연이 그대로 체감되므로, 구간이 시작될 때와
    /// 한 번 울린 직후에 다시 깨워 둔다.
    func prepare() {
        setGenerator.prepare()
        lapGenerator.prepare()
        actionGenerator.prepare()
    }

    /// 3분 세트 경계 — 짧게 1회
    func setBoundary() {
        setGenerator.impactOccurred()
        setGenerator.prepare()
    }

    /// 9분 운동 경계 — 짧게 2회
    func lapBoundary() {
        lapGenerator.impactOccurred()
        let generator = lapGenerator
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.doublePulseInterval) {
            generator.impactOccurred()
            generator.prepare()
        }
    }

    /// 구간 시작·종료처럼 사용자가 직접 누른 동작의 확인 신호
    func action() {
        actionGenerator.impactOccurred()
        actionGenerator.prepare()
    }

    /// 운동 종료처럼 흐름이 끝났을 때
    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
