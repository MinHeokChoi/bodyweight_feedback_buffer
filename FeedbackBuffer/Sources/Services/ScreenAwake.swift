import UIKit

/// 운동 중에는 화면 자동 잠금을 끈다.
///
/// 폰을 바닥에 두고 쓰는데, 화면이 잠기면 앱이 멈춰 세트 경계 진동도 오지 않는다.
/// 켜 둘 이유를 여러 곳에서 따로 알리고, 하나라도 남아 있으면 켜 둔다.
/// 앱이 백그라운드로 가면 iOS가 이 값을 무시하므로 따로 되돌리지 않는다.
@MainActor
enum ScreenAwake {
    enum Reason: Hashable {
        /// 구간이 진행 중이고 일시정지가 아닐 때
        case workoutSegment
        /// 웜업 러너가 떠 있을 때
        case warmupRunner
    }

    private static var reasons: Set<Reason> = []

    static func set(_ reason: Reason, active: Bool) {
        if active {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }
        UIApplication.shared.isIdleTimerDisabled = !reasons.isEmpty
    }
}
