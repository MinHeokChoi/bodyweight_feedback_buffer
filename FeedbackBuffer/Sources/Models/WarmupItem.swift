import Foundation

struct WarmupItem: Identifiable, Codable, Hashable {
    let id: String
    var label: String
    var checked: Bool

    init(id: String, label: String, checked: Bool = false) {
        self.id = id
        self.label = label
        self.checked = checked
    }
}

enum DefaultWarmup {
    static let items: [WarmupItem] = [
        WarmupItem(id: "wrist", label: "손목 가동성"),
        WarmupItem(id: "shoulder_circle", label: "어깨 원 돌리기"),
        WarmupItem(id: "scap_pushup", label: "스캐풀라 푸시업"),
        WarmupItem(id: "hollow_body", label: "할로우 바디 홀드"),
        WarmupItem(id: "bridge", label: "브릿지 또는 흉추 열기"),
        WarmupItem(id: "hamstring", label: "햄스트링 스트레칭"),
        WarmupItem(id: "handstand_drill", label: "가벼운 물구나무 라인 드릴")
    ]
}

enum WarmupDateKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func today(_ date: Date = .now) -> String {
        formatter.string(from: date)
    }
}
