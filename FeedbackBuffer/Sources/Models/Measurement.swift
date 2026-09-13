import Foundation

// MARK: - 단위

enum MeasurementUnit: String, Codable, CaseIterable, Identifiable, Hashable {
    case reps
    case kilograms
    case seconds
    case minutes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reps: "회"
        case .kilograms: "kg"
        case .seconds: "초"
        case .minutes: "분"
        }
    }

    /// 값을 사람이 읽는 문자열로. 초는 1분이 넘으면 mm:ss로 보여준다.
    func format(_ value: Double) -> String {
        switch self {
        case .seconds where value >= 60:
            let total = Int(value.rounded())
            return String(format: "%d:%02d", total / 60, total % 60)
        default:
            return "\(trimmed(value))\(displayName)"
        }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value.rounded()))
            : String(format: "%.1f", value)
    }
}

// MARK: - 방향

/// 값이 커야 잘한 것인가, 작아야 잘한 것인가.
///
/// "3분을 몇 번의 시도 안에 채우는지" 같은 종목은 값이 작을수록 잘한 것이다.
/// 방향이 없으면 5회 → 3회 개선을 "감소"로 표시하게 된다. 시즌 비교가
/// 이 기능의 전부인데 거기서 틀린 말을 하게 된다.
enum MeasurementDirection: String, Codable, CaseIterable, Identifiable, Hashable {
    case higherIsBetter
    case lowerIsBetter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .higherIsBetter: "높을수록 좋음"
        case .lowerIsBetter: "낮을수록 좋음"
        }
    }

    /// 두 값 중 더 나은 쪽.
    func better(_ lhs: Double, _ rhs: Double) -> Double {
        switch self {
        case .higherIsBetter: max(lhs, rhs)
        case .lowerIsBetter: min(lhs, rhs)
        }
    }

    /// 방향을 적용한 변화. 양수면 개선, 음수면 후퇴다.
    func improvement(from old: Double, to new: Double) -> Double {
        switch self {
        case .higherIsBetter: new - old
        case .lowerIsBetter: old - new
        }
    }
}

// MARK: - 종목

/// 한 번 정의하고 시즌마다 그대로 재사용하는 측정 항목.
struct MeasurementItem: Identifiable, Codable, Hashable {
    let id: UUID
    /// 물구나무 / 풀업 / 스트렝스처럼 묶는 이름.
    var category: String
    /// 밸런스 / 최대 개수처럼 실제로 재는 것.
    var movement: String
    /// 어떤 조건에서 쟀는가. 이것이 같아야 시즌 간 비교가 성립한다.
    var constraint: String
    var unit: MeasurementUnit
    var direction: MeasurementDirection
    var createdAt: Date

    init(
        id: UUID = UUID(),
        category: String,
        movement: String,
        constraint: String = "",
        unit: MeasurementUnit = .reps,
        direction: MeasurementDirection = .higherIsBetter,
        createdAt: Date = .now
    ) {
        self.id = id
        self.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        self.movement = movement.trimmingCharacters(in: .whitespacesAndNewlines)
        self.constraint = constraint.trimmingCharacters(in: .whitespacesAndNewlines)
        self.unit = unit
        self.direction = direction
        self.createdAt = createdAt
    }

    var displayName: String {
        category.isEmpty ? movement : "\(category) · \(movement)"
    }
}

// MARK: - 시즌

/// 훈련 시즌. 끝나는 날을 두지 않는다 — 다음 시즌이 시작하면 이전 시즌이 끝난다.
/// 그래서 겹치거나 비는 구간이 생길 수 없다.
struct MeasurementSeason: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var startedAt: Date

    init(id: UUID = UUID(), name: String, startedAt: Date) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.startedAt = startedAt
    }
}

// MARK: - 기록

struct MeasurementRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var itemId: UUID
    var seasonId: UUID
    var measuredAt: Date
    var value: Double
    var note: String
    /// 잴 당시의 제약. 종목의 제약을 나중에 고쳐도 이 기록이 어떤 조건이었는지는 남는다.
    var constraintSnapshot: String

    init(
        id: UUID = UUID(),
        itemId: UUID,
        seasonId: UUID,
        measuredAt: Date = .now,
        value: Double,
        note: String = "",
        constraintSnapshot: String = ""
    ) {
        self.id = id
        self.itemId = itemId
        self.seasonId = seasonId
        self.measuredAt = measuredAt
        self.value = value
        self.note = note
        self.constraintSnapshot = constraintSnapshot
    }
}

// MARK: - 시즌 이름

enum SeasonNaming {
    enum Season: CaseIterable {
        case spring, summer, autumn, winter

        var displayName: String {
            switch self {
            case .spring: "봄"
            case .summer: "여름"
            case .autumn: "가을"
            case .winter: "겨울"
            }
        }
    }

    static func season(ofMonth month: Int) -> Season {
        switch month {
        case 3...5: .spring
        case 6...8: .summer
        case 9...11: .autumn
        default: .winter
        }
    }

    /// 시작일에서 "연도 + 계절"을 만든다.
    ///
    /// 겨울은 해를 걸치므로 시작 연도를 쓴다. 2026년 12월에 시작한 시즌은
    /// 2027년 2월까지 이어져도 "2026 겨울"이다.
    static func suggestedName(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 1
        return "\(year) \(season(ofMonth: month).displayName)"
    }

    /// 이미 쓰고 있는 이름이면 뒤에 번호를 붙인다.
    static func uniqueName(for date: Date, existing: [String], calendar: Calendar = .current) -> String {
        let base = suggestedName(for: date, calendar: calendar)
        guard existing.contains(base) else { return base }
        var index = 2
        while existing.contains("\(base) (\(index))") {
            index += 1
        }
        return "\(base) (\(index))"
    }
}
