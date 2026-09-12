import UIKit

/// 타이머 화면의 진동 신호를 한곳에 모은다.
///
/// 신호는 세기가 아니라 **횟수로 구분한다**. 운동 중에는 세기 차이를 구별하기
/// 어렵지만 몇 번 울렸는지는 알 수 있기 때문이다.
///
/// - 3분 세트 경계: 짧게 1회
/// - 9분 운동 경계: 짧게 3회
@MainActor
final class WorkoutHaptics {

    /// 연속으로 울릴 때의 간격.
    ///
    /// 0.16초로는 여러 번이 뭉쳐 한 번처럼 느껴졌다. 세어야 하는 신호이므로
    /// 붙여 두기보다 넉넉히 떨어뜨리는 쪽이 맞다.
    static let pulseInterval: TimeInterval = 0.28

    /// 9분 운동 경계에서 울릴 횟수.
    ///
    /// 2회가 아니라 3회인 이유는, 운동 중에 1회와 2회를 세어 구별하기가
    /// 생각보다 어렵기 때문이다. 1회와 3회는 "한 번"과 "드르륵"으로 성격이
    /// 달라져서 세지 않고도 구분된다.
    static let lapPulseCount: Int = 3

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

    /// 9분 운동 경계 — 짧게 3회
    func lapBoundary() {
        fire(lapGenerator, times: Self.lapPulseCount)
    }

    /// 일정 간격으로 여러 번 울린다. 매번 다시 깨워 뒤 진동이 약해지지 않게 한다.
    private func fire(_ generator: UIImpactFeedbackGenerator, times: Int) {
        guard times > 0 else { return }
        for index in 0..<times {
            let delay = Double(index) * Self.pulseInterval
            if delay == 0 {
                generator.impactOccurred()
                generator.prepare()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    generator.impactOccurred()
                    generator.prepare()
                }
            }
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
