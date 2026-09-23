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

    /// 통계·목록·기록용. "1시간 24분" 형태로 읽기 쉽게.
    ///
    /// 표기 규칙: 기록과 통계는 이것으로, 운동 중 화면(휴식 화면 포함, FR-1의 "스트렝스 완료 27:00")과
    /// 9:00과 견주는 랩은 `clock`으로 쓴다.
    ///
    /// 0은 "0분"이다. "0초"는 초 단위로 잰 것처럼 읽힌다.
    static func compact(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)시간 \(minutes)분" }
        if hours > 0 { return "\(hours)시간" }
        if minutes > 0 { return "\(minutes)분" }
        if total == 0 { return "0분" }
        return "\(total)초"
    }

    /// 전체 중 몇 %인가. 조금이라도 했으면 "0%"라고 쓰지 않는다.
    static func percent(_ part: TimeInterval, of total: TimeInterval) -> String {
        guard total > 0, part > 0 else { return "0%" }
        let value = part / total * 100
        return value < 1 ? "<1%" : "\(Int(value.rounded()))%"
    }

    /// VoiceOver가 읽을 문자열.
    static func spoken(_ interval: TimeInterval) -> String {
        compact(interval)
    }
}
