import Foundation

enum WorkoutTimeFormat {

    /// 타이머 표시용. 1시간 미만은 `mm:ss`, 넘으면 `h:mm:ss`.
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 통계·목록용. "1시간 24분" 형태로 읽기 쉽게.
    static func compact(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)시간 \(minutes)분" }
        if hours > 0 { return "\(hours)시간" }
        if minutes > 0 { return "\(minutes)분" }
        return "\(total)초"
    }

    /// VoiceOver가 읽을 문자열.
    static func spoken(_ interval: TimeInterval) -> String {
        compact(interval)
    }
}
