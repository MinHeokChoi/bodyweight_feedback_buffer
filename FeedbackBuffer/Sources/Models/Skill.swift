import Foundation

struct Skill: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var symbolName: String

    init(id: UUID = UUID(), name: String, symbolName: String = "figure.strengthtraining.traditional") {
        self.id = id
        self.name = name
        self.symbolName = symbolName
    }
}

enum DefaultSkill: String, CaseIterable {
    case handstand = "물구나무"
    case planche = "플란체"
    case frontLever = "프론트레버"
    case muscleUp = "머슬업"
    case pullUp = "풀업"
    case dips = "딥스"
    case core = "코어"
    case mobility = "유연성"
    case other = "기타"

    var symbolName: String {
        switch self {
        case .handstand: "figure.gymnastics"
        case .planche: "figure.cooldown"
        case .frontLever: "figure.core.training"
        case .muscleUp: "figure.climbing"
        case .pullUp: "figure.pull.up"
        case .dips: "figure.strengthtraining.functional"
        case .core: "figure.core.training"
        case .mobility: "figure.flexibility"
        case .other: "ellipsis.circle"
        }
    }
}
