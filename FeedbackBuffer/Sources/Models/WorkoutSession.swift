import Foundation

// MARK: - Phase kind

/// 세션 안의 훈련 종류. 고정 5종이며 사용자가 추가하거나 이름을 바꿀 수 없다.
///
/// 휴식은 케이스가 아니다. 구간 타이머가 꺼져 있고 누적 타이머만 도는
/// 간격으로 계산된다. `WorkoutSession.restDuration` 참고.
enum TrainingPhaseKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case stretching
    case warmup
    case skillPractice
    case strength
    case fatigueResistance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stretching: "스트레칭"
        case .warmup: "웜업"
        case .skillPractice: "기술 연습"
        case .strength: "스트렝스"
        case .fatigueResistance: "피로저항"
        }
    }

    var systemImage: String {
        switch self {
        case .stretching: "figure.flexibility"
        case .warmup: "flame.fill"
        case .skillPractice: "figure.gymnastics"
        case .strength: "dumbbell.fill"
        case .fatigueResistance: "bolt.heart.fill"
        }
    }

    /// 화면에 카드가 놓이는 순서.
    ///
    /// 실제 훈련 흐름을 따른다. 스트레칭은 마무리에 하는 경우가 많아 끝에 둔다.
    /// 이 순서는 **고정이다.** 상황에 따라 카드 위치가 바뀌면 손이 위치를
    /// 기억할 수 없어 매번 읽고 찾아야 한다.
    static let recommendedOrder: [TrainingPhaseKind] = [
        .warmup, .skillPractice, .strength, .fatigueResistance, .stretching
    ]

    /// 페이스 타이머(9분 랩)를 쓰는 구간.
    ///
    /// 3분 × 3세트로 한 운동을 구성하는 것은 스트렝스뿐이다. 웜업이나
    /// 스트레칭에서 9분마다 "다음 운동"으로 넘어가는 것은 없는 개념이므로
    /// 이 구간들은 누적 시간만 잰다.
    var usesPaceTimer: Bool { self == .strength }
}

// MARK: - Lap

/// 페이스 타이머의 한 마디. 기본 9분이며 한 운동에 해당한다.
struct TrainingLap: Identifiable, Codable, Hashable {
    let id: UUID
    /// 구간 안에서 몇 번째 운동인가. 1부터 센다.
    var index: Int
    var duration: TimeInterval
    /// 이 랩의 목표 시간. 기본 9분이며 나중에 조정 기능이 붙어도 과거 기록은 그대로 남는다.
    var targetDuration: TimeInterval

    init(
        id: UUID = UUID(),
        index: Int,
        duration: TimeInterval,
        targetDuration: TimeInterval = PaceTimer.defaultLapDuration
    ) {
        self.id = id
        self.index = max(1, index)
        self.duration = max(0, duration)
        self.targetDuration = max(1, targetDuration)
    }
}

// MARK: - Pace constants

enum PaceTimer {
    /// 한 운동 = 3분 × 3세트
    static let defaultSetDuration: TimeInterval = 180
    static let defaultSetsPerLap: Int = 3
    static let defaultLapDuration: TimeInterval = defaultSetDuration * Double(defaultSetsPerLap)
}

// MARK: - Segment

/// 한 번 켜고 끈 구간. 같은 종류를 여러 번 시작하면 그만큼 여러 개가 쌓인다.
struct TrainingSegment: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: TrainingPhaseKind
    /// 기술 연습 구간에서만 쓴다. v2의 기술별 통계를 위해 자리를 미리 둔다.
    var skillId: UUID?
    var startedAt: Date
    /// nil이면 아직 진행 중이다.
    var endedAt: Date?
    /// 이미 끝난 랩들. 자동 전환분은 구간을 끝낼 때 한 번에 확정된다.
    var laps: [TrainingLap]
    /// 현재 랩이 시작된 시각.
    ///
    /// 보통은 구간 시작과 같지만, 사용자가 9분을 다 채우지 않고 "지금 바로
    /// 다음 운동으로"를 누르면 그 시점으로 옮겨진다. 이 앵커가 없으면 수동
    /// 전환 후의 랩을 경과 시간만으로 유도할 수 없다.
    var paceAnchoredAt: Date?

    init(
        id: UUID = UUID(),
        kind: TrainingPhaseKind,
        skillId: UUID? = nil,
        startedAt: Date,
        endedAt: Date? = nil,
        laps: [TrainingLap] = [],
        paceAnchoredAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.skillId = skillId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.laps = laps
        self.paceAnchoredAt = paceAnchoredAt
    }

    /// 현재 랩의 원점. 앵커가 없으면 구간 시작이 원점이다.
    var paceOrigin: Date { paceAnchoredAt ?? startedAt }

    var isRunning: Bool { endedAt == nil }
}

// MARK: - Pause

/// 일시정지 구간. 휴식과 달리 누적 타이머에서도 빠진다.
struct PauseInterval: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?

    init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var isOpen: Bool { endedAt == nil }
}

// MARK: - Session

/// 헬스장 도착부터 운동 종료까지 한 번의 운동.
struct WorkoutSession: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    /// nil이면 아직 진행 중이다.
    var endedAt: Date?
    var segments: [TrainingSegment]
    var pauses: [PauseInterval]
    var note: String

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        segments: [TrainingSegment] = [],
        pauses: [PauseInterval] = [],
        note: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.segments = segments
        self.pauses = pauses
        self.note = note
    }

    var isRunning: Bool { endedAt == nil }

    var runningSegment: TrainingSegment? {
        segments.first { $0.isRunning }
    }

    /// 구간 타이머가 꺼져 있는 상태. 세션이 진행 중일 때만 의미가 있다.
    var isResting: Bool { isRunning && runningSegment == nil }

    var isPaused: Bool { pauses.contains(where: \.isOpen) }
}
