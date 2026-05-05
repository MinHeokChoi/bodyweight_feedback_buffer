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
        WarmupItem(id: "palm_press", label: "손바닥 짚기"),
        WarmupItem(id: "light_qdr_line", label: "가벼운 Q.D.R 라인"),
        WarmupItem(id: "cartwheel", label: "카트휠"),
        WarmupItem(id: "light_handstand_line", label: "가벼운 물구나무 라인"),
        WarmupItem(id: "hspu_line", label: "HSPU 라인"),
        WarmupItem(id: "bridge_circle", label: "브릿지 서클"),
        WarmupItem(id: "side_front_split", label: "좌우, 앞뒤 스플릿"),
        WarmupItem(id: "bridge_hold", label: "브릿지 홀드"),
        WarmupItem(id: "tight_area_stretching", label: "덜 풀린 곳 스트레칭")
    ]
}

enum WarmupDateKey {
    static func today(_ date: Date = .now) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
